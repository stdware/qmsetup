# Status

Both halves have a suite that runs from CTest on Windows, Linux and macOS: `tests/cli` runs `qmcorecmd` as a black box, and `tests/cmake` runs the `qm_*` functions. What follows is what they do not reach.

The ones wanting Qt or protobuf run against a real installation rather than a stub, and each registers itself only where the configure found what it needs, so a machine without one of them runs a shorter suite rather than one full of tests that pass themselves over. Name the installations the ordinary way and they all run, `CMAKE_PREFIX_PATH` taking more than one entry. The QML ones ask for Qt 6.5 on top of that.

```sh
cmake -B build -DQMSETUP_BUILD_TESTS=ON \
      "-DCMAKE_PREFIX_PATH=/path/to/Qt/<version>/<compiler>;/path/to/protobuf"
```

## Not tested, and will not be

- Doxygen for `qm_setup_doxygen`, which wants the tool installed to say anything at all.
- Most behavior under `cmake/modules/private`. It says on it that it may be modified or removed, and nothing outside qmsetup should be calling it. `qm_install_package` has a local regression test for forwarding the selected generator program, but its external package workflows are otherwise left alone because useful coverage would want a network.
- `qm_compiler_*`, which is under `private` for the same reason and has one of its own. Each is a list of compiler flags chosen per compiler, so a test could only read the list back to itself, which says nothing about whether the flags are the right ones. What would catch a mistake there is compiling with them.

## Not tested yet

- The pass that strips a universal binary down to the architecture in use, which needs a binary built for two. `lipo` itself is on every machine with the command line tools, so what is missing is the fixture: building one means a second pass over the whole deploy tree with `CMAKE_OSX_ARCHITECTURES`, and it would test one function.
- `FORCE`, on `qm_deploy_directory` and on `qm_win_applocal_deps`. It is what makes a copy happen where the destination already holds a file of the same name and no older, so a test wants two runs with something put in the way between them, and either function copies enough that doing it twice is the slowest thing in the suite.
- The scripts under `cmake/scripts`, called directly rather than through the function that wraps them. `copy.cmake` is reached through `qm_add_copy_command`, `configure_file.cmake` through `qm_future_configure_file`, and `xxd.cmake` through `qm_add_binary_resource`, all against a real build. What a direct call would add is the refusal each makes when an argument is missing.
- `cmake/buildsystem/BuildRepoHelpers.cmake`, including its use of `QMSETUP_FORCE_EXECUTABLE_PERMISSIONS`. No test includes the file.
- The rejection of a dSYM companion file by `qm_deploy_directory` on macOS. `test_deploy_directory` writes a separate debug file with the objcopy of the toolchain, and AppleClang provides none, so the check is skipped there.
- A framework inside a QML directory deployed by `qm_deploy_directory` on macOS. `test_deploy_framework` covers a framework in the install tree, which `search_input_dir` handles. A framework in a QML directory takes the separate branch in `search_qml_dir`, and Qt installs its QML plugins as plain dynamic libraries.

## Unverified

- The standard library filter cannot be seen to work on macOS. Everything under `/usr/lib` now lives in the dyld shared cache rather than on disk, so `libSystem` is reported as not found whether or not `--standard` was asked for, and the deployment has nothing to leave behind. Checked on Windows and Linux, where the filter has files to act on.
- Nothing compiles what `qm_add_win_rc_enhanced` writes. `test_win_resources` reads the configured script and checks what is in it, and the icons it names are files with the right extension and nothing else in them, so that a resource compiler would accept the result is not checked. `test_win_rc_icon` compiles the script of `qm_add_win_rc` with real icons. The same holds for `qm_add_win_manifest`, which nothing embeds.
- The branches of `qm_compiler_eliminate_dead_code` and `qm_compiler_enable_secure_code` for clang with the GNU front end targeting the MSVC ABI are checked only on x86_64, by building a probe and reading the binary: the removal of an unreferenced function, `GUARD_CF`, the tables of control flow guard and of the EH continuation guard, and `CET_COMPAT`. On 32-bit x86 the branch passes no `/SAFESEH`, unlike the branch for cl, and whether lld-link then marks the image as safe for structured exception handling is not checked.
- The branch of `qm_compiler_enable_secure_code` for other compilers passes `-fsanitize=cfi -fsanitize-cfi-cross-dso` to clang without `-flto`. clang targeting the MSVC ABI rejects that combination with "only allowed with '-flto'". Whether clang on Linux rejects it as well is not checked.
- The branches of the `qm_compiler_*` functions for cl were not rebuilt when the branches for the MSVC ABI were added. They are unchanged.
- Nothing builds what `qm_add_mac_bundle` sets up. The properties it puts on the target are read back, but the `Info.plist` CMake writes out of them is not, so a property spelt wrongly would pass.

# Planned

## Extension commands of qmcorecmd

A command that `qmcorecmd` does not provide runs as a separate program, as Git runs `git-send-email` for `git send-email`, Cargo runs `cargo-<name>` and kubectl runs `kubectl-<name>`. `qmcorecmd <name> <args...>` runs `qmcorecmd-<name>` with the arguments and returns its exit code. A tool with dependencies that qmsetup does not take, such as Qt, is then installed separately and called in the same way as a command of qmsetup, and `qmcorecmd` keeps no dependency beyond stdcorelib. Not started.

- **Lookup.** A command of `qmcorecmd` takes precedence, and an extension cannot replace one. An extension is looked up in the directories of `--exec-path` and of the environment variable `QMCORECMD_EXEC_PATH`, then in the directory of `qmcorecmd`, then in `PATH`. The functions of qmsetup always pass `--exec-path`, so that a build does not depend on `PATH`, where another program of the same name may come first.
- **Execution.** The standard streams are inherited. Windows has no `exec`, so `stdc::Popen` starts the extension and `qmcorecmd` waits for it.
- **A missing extension.** `qmcorecmd` reports that the name is no command, and names the package of an extension that it knows.
- **Help.** `qmcorecmd --help` lists the extensions found, as `git help -a` does. The option is not `--list`, which `deploy` and `incsync` take.
- **CMake.** `qm_find_corecmd_extension(<name> <var>)` finds an extension while configuring and fails with the package to install if absent, so that a missing extension stops the configure rather than the build. A function built on an extension adds the custom command that runs it.
- **vcpkg.** The port of an extension installs into its own tools directory rather than into that of qmsetup, and the functions pass that directory with `--exec-path`.
- **Tests.** `tests/cli` builds a stub extension that reports its arguments, and checks the arguments, the exit code, the precedence of the commands of `qmcorecmd`, the order of the lookup and the report of a missing extension.
