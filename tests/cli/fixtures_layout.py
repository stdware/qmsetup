"""Finding the fixture binaries, and laying them out for a test to deploy.

The binaries are built by ``fixtures/CMakeLists.txt`` into one directory. What
makes them worth deploying is where they are put, and that is declared in
``deploy_scenarios.json`` rather than here, so that the layout and the
expectations that depend on it stay in one file.
"""

from __future__ import annotations

import json
import os
import shutil
from pathlib import Path

LIBRARY_SUFFIXES = (".dll", ".so", ".dylib")
EXECUTABLE_SUFFIXES = (".exe", "")


def scenario_file() -> Path:
    """The declaration to read, which the build system decides on.

    Nothing here knows where the file is, or what it is called. That is what
    ``QMTEST_SCENARIOS`` says. CTest sets it, and ``run.py`` sets it for a run
    by hand.
    """
    raw = os.environ.get("QMTEST_SCENARIOS")
    if not raw:
        raise SystemExit(
            "QMTEST_SCENARIOS is not set. It has to name the deploy declaration to "
            "read. Run the suite through CTest, or through run.py, which sets it."
        )
    path = Path(raw)
    if not path.is_file():
        raise SystemExit(f"QMTEST_SCENARIOS points at nothing: {path}")
    return path


def load_declaration() -> dict:
    with scenario_file().open(encoding="utf-8") as handle:
        return json.load(handle)


def _find(directory: Path, stem: str, suffixes: tuple[str, ...]) -> Path | None:
    """The one artifact named ``stem``, whatever the platform decorates it with."""
    wanted = {stem, "lib" + stem}
    for entry in sorted(directory.iterdir()):
        if entry.is_file() and entry.stem in wanted and entry.suffix in suffixes:
            return entry
    return None


class Layout:
    """Where each artifact went, as paths relative to the sandbox."""

    def __init__(self, sandbox: Path, directories: dict, placed: dict):
        self.sandbox = sandbox
        self.directories = directories
        self._placed = placed

    def path(self, artifact: str) -> str:
        """The artifact's path in the sandbox."""
        return self._placed[artifact]

    def name(self, artifact: str) -> str:
        """The artifact's file name, which is what a deployment produces."""
        return Path(self._placed[artifact]).name

    def directory(self, key: str) -> str:
        return self.directories[key]

    def names(self) -> dict[str, str]:
        return {artifact: Path(p).name for artifact, p in self._placed.items()}

    def artifact_of(self, file_name: str) -> str | None:
        """The artifact a produced file came from, for readable failures."""
        for artifact, name in self.names().items():
            if name == file_name:
                return artifact
        return None


class Fixtures:
    """The built fixture binaries, and the layout they are put into."""

    def __init__(self, directory: Path, declaration: dict | None = None):
        self.directory = directory
        self.declaration = declaration or load_declaration()
        self.directories = self.declaration["directories"]
        self.artifacts = self.declaration["artifacts"]

        self.files: dict[str, Path | None] = {}
        for artifact, spec in self.artifacts.items():
            suffixes = (
                EXECUTABLE_SUFFIXES
                if spec["kind"] == "application"
                else LIBRARY_SUFFIXES
            )
            self.files[artifact] = _find(directory, f"qmtest_{artifact}", suffixes)

    @property
    def missing(self) -> list[str]:
        return [artifact for artifact, path in self.files.items() if path is None]

    def scatter(self, sandbox: Path) -> Layout:
        """Copies every artifact into the place the declaration gives it."""
        placed = {}
        for artifact, spec in self.artifacts.items():
            source = self.files[artifact]
            directory = self.directories[spec["directory"]]
            target_dir = sandbox / directory
            target_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target_dir / source.name)
            placed[artifact] = f"{directory}/{source.name}"
        return Layout(sandbox, dict(self.directories), placed)


def load() -> Fixtures | None:
    """The fixtures, or None when they were not built."""
    raw = os.environ.get("QMTEST_FIXTURES")
    if not raw:
        return None
    directory = Path(raw)
    if not directory.is_dir():
        return None
    fixtures = Fixtures(directory)
    return None if fixtures.missing else fixtures
