"""Deploying on a platform where a binary carries its own search path.

The portable tests in ``test_deploy`` all reach their libraries through ``-L``,
because they scatter the fixtures somewhere the built-in rpath cannot point at.
That exercises only half of the resolver. The other half is the one that
matters in practice: a package manager such as vcpkg puts everything under one
prefix and bakes that prefix into the binary, so ``ldd`` on Linux and the
loader paths on macOS resolve it with no help from the command line at all.

These tests rebuild that shape. Every fixture is moved into one prefix, every
binary is pointed at it with an absolute rpath, and the deployment is run with
no ``-L`` whatsoever. They also check the other half of what a Unix deployment
does, which is rewriting those rpaths afterwards so the copies can find each
other in their new home.

Nothing here runs on Windows, which has no rpath, and nothing runs without the
tool that edits one, so the whole module skips itself where it does not apply.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

from test_deploy import DeployTestCase

#: The prefix the fixtures are gathered into, in the shape a package manager uses.
PREFIX = "vcpkg/installed/lib"

#: Names a deployment is meant to leave behind when --standard is asked for.
#: Taken from what the tool itself filters, so that a test says what the tool
#: says rather than what this file guesses.
RUNTIME_PREFIXES = (
    "libc++",
    "libc.so",
    "libc-",
    "libdl.so",
    "libdl-",
    "libgcc",
    "libglib",
    "libgthread",
    "libicu",
    "libpthread",
    "libstdc++",
    "libsystem",
)


def rpath_problem() -> str:
    """Empty when this platform has an rpath and the tool to edit one."""
    if sys.platform == "darwin":
        if not shutil.which("install_name_tool"):
            return "install_name_tool is not on the path"
        if not shutil.which("otool"):
            return "otool is not on the path"
        return ""
    if sys.platform.startswith("linux"):
        if not shutil.which("patchelf"):
            return "patchelf is not on the path"
        return ""
    return f"{sys.platform} binaries do not carry a search path"


def _run(argv: list[str]) -> str:
    completed = subprocess.run(
        argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60
    )
    out = completed.stdout.decode("utf-8", errors="replace")
    if completed.returncode != 0:
        raise RuntimeError(f"{' '.join(argv)} failed:\n{out}")
    return out


def set_rpath(binary: Path, directory: Path):
    if sys.platform == "darwin":
        _run(["install_name_tool", "-add_rpath", str(directory), str(binary)])
    else:
        _run(["patchelf", "--set-rpath", str(directory), str(binary)])


def read_rpath(binary: Path) -> str:
    """Whatever the binary now says about where to look, as one string."""
    if sys.platform == "darwin":
        listing = _run(["otool", "-l", str(binary)])
        found = []
        lines = listing.splitlines()
        for index, line in enumerate(lines):
            if "LC_RPATH" not in line:
                continue
            for following in lines[index : index + 6]:
                if "path " in following:
                    found.append(following.split("path ", 1)[1].split(" (offset")[0])
                    break
        return ":".join(found)
    return _run(["patchelf", "--print-rpath", str(binary)]).strip()


class UnixDeployTestCase(DeployTestCase):
    """Gathers the fixtures into one prefix and points every binary at it."""

    needs_resolution = True

    def setUp(self):
        super().setUp()
        problem = rpath_problem()
        if problem:
            self.skipTest(problem)

        prefix = self.path(PREFIX)
        prefix.mkdir(parents=True, exist_ok=True)
        for artifact in ("base", "util", "render", "audio"):
            source = self.path(self.layout.path(artifact))
            source.replace(prefix / source.name)
        self.prefix = prefix

        pointed = [self.path(self.layout.path("app"))]
        pointed += [self.path(self.layout.path(p)) for p in ("plugin_a", "plugin_b")]
        pointed += sorted(prefix.iterdir())
        for binary in pointed:
            set_rpath(binary, prefix)

    def is_runtime(self, name: str) -> bool:
        lowered = name.lower()
        return any(lowered.startswith(p) for p in RUNTIME_PREFIXES)


class TestResolutionThroughAnRpath(UnixDeployTestCase):
    def test_libraries_under_a_prefix_are_found_without_a_search_path(self):
        r = self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s", "-V")
        self.assertOk(r)
        for artifact in ("render", "util", "base"):
            self.assertResolved(r, artifact)

    def test_they_are_copied_out_of_the_prefix(self):
        r = self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s")
        self.assertOk(r)
        landed = self.deployed()
        for artifact in ("render", "util", "base"):
            self.assertIn(self.layout.name(artifact), landed)

    def test_the_prefix_is_left_as_it_was(self):
        self.assertOk(self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s"))
        for artifact in ("render", "util", "base", "audio"):
            self.assertTrue(
                (self.prefix / self.layout.name(artifact)).is_file(),
                msg=f"{artifact} should still be in the prefix",
            )

    def test_a_branch_nothing_asked_for_stays_in_the_prefix(self):
        self.assertOk(self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s"))
        self.assertNotIn(self.layout.name("audio"), self.deployed())

    def test_a_plugin_pulls_its_own_branch_out_of_the_prefix(self):
        r = self.run_cmd(
            "deploy", self.layout.path("app"),
            "-c", self.layout.path("plugin_b"), "out/plugins",
            "-o", "out", "-s",
        )
        self.assertOk(r)
        self.assertIn(self.layout.name("audio"), self.deployed())
        self.assertFile(f"out/plugins/{self.layout.plugin_name('plugin_b')}")


class TestRpathsAreRewritten(UnixDeployTestCase):
    """A copy is no use where it lands unless it can find its own dependencies."""

    def test_a_deployed_library_is_pointed_at_its_new_neighbours(self):
        self.assertOk(self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s"))
        copied = self.path("out") / self.layout.name("render")
        self.assertTrue(copied.is_file(), msg=f"tree: {self.tree()}")
        rpath = read_rpath(copied)
        expected = "@loader_path" if sys.platform == "darwin" else "$ORIGIN"
        self.assertIn(expected, rpath)

    def test_the_prefix_is_no_longer_named_by_the_copies(self):
        """Otherwise the deployment still depends on the machine it was built on."""
        self.assertOk(self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s"))
        for name in self.deployed():
            copied = self.path("out") / name
            self.assertNotIn(str(self.prefix), read_rpath(copied))

    def test_the_application_is_pointed_at_the_output_directory(self):
        self.assertOk(self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s"))
        rpath = read_rpath(self.path(self.layout.path("app")))
        expected = "@loader_path" if sys.platform == "darwin" else "$ORIGIN"
        self.assertIn(expected, rpath)


class TestSystemLibraries(UnixDeployTestCase):
    """What comes along from outside the prefix, and what --standard leaves."""

    def deployed_runtime(self, *extra: str) -> set[str]:
        self.assertOk(
            self.run_cmd("deploy", self.layout.path("app"), "-o", "out", *extra)
        )
        return {name for name in self.deployed() if self.is_runtime(name)}

    def test_standard_leaves_the_c_runtime_behind(self):
        with_standard = self.deployed_runtime("-s")
        self.assertEqual(
            with_standard,
            set(),
            msg="--standard should have left every one of these on the system",
        )

    def test_without_standard_the_c_runtime_comes_along(self):
        """Unlike Windows, where system libraries are always left behind, here
        nothing is filtered until --standard says so. A deployment that does not
        ask for it carries the C library with it."""
        plain = self.deployed_runtime()
        if not plain:
            self.skipTest("the fixtures pulled in no runtime library to judge by")
        self.assertTrue(plain)

    def test_standard_deploys_a_subset_of_what_it_would_otherwise(self):
        self.assertOk(self.run_cmd("deploy", self.layout.path("app"), "-o", "out"))
        plain = self.deployed()
        shutil.rmtree(self.path("out"))
        self.assertOk(self.run_cmd("deploy", self.layout.path("app"), "-o", "out", "-s"))
        standard = self.deployed()
        self.assertTrue(standard <= plain, msg=f"{sorted(standard - plain)} appeared")
        for artifact in ("render", "util", "base"):
            self.assertIn(self.layout.name(artifact), standard)
