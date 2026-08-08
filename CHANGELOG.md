# Changelog

## v1.1.0.0 (unreleased)

### Removed

- `--linkdirs-file` is gone from `qmcorecmd deploy`. Nothing in the CMake layer passed it, and the file it read was written by `qm_win_record_deps`, which is gone with it.
- `qm_win_record_deps` is gone, along with the part of `qm_deploy_directory` that read what it wrote.
- `qm_win_applocal_deps` no longer declares a `TARGET` keyword. Nothing read it, and declaring one is not free: a word spelt `TARGET` in an `EXCLUDE` list was taken for a keyword and went missing.

### Deprecated

- `CMAKE_BUILD_SHARE_DIR` is now `QMSETUP_BUILD_SHARE_DIR`. The old name is still set and will go, having never belonged in CMake's own namespace.

### Added

- `qm_skip_automoc` takes `RECURSIVE`, which reaches the sources under a directory as well as the ones directly in it.
- `qm_install_package` takes `HOST`, for a package that has to be built for the machine doing the building.
- `cmake/buildsystem/BuildRepoHelpers.cmake`, a set of helpers for a repository laid out the way this one is.

### Changed

- `qmcorecmd` is built on [stdcorelib](https://github.com/stdware/stdcorelib) rather than syscmdline. It arrives as a submodule under `src`, so a clone wants `--recursive`, and an installed copy is used instead where there is one.
- On Linux, deployment reads what a binary asks for with `patchelf --print-needed` and works out where each of those resolves to with `ldd`, where it used to read `ldd` alone. `ldd` reports the whole closure flattened, so excluding a library with `-e` left everything behind it looking as though the binary had asked for it directly. Excluding one now hides what only it asked for, which is what the option means everywhere else.
- `qm_get_subdirs` keeps what matches any of the `REGEX_INCLUDE` expressions rather than what matches all of them. Two names could not both be true of one directory, so asking for two gave nothing.
- `qm_find_qt` takes `QUIET` and `REQUIRED` together. They were one chain of `elseif`, so asking for two used the first and dropped the rest. `EXACT` is still accepted and still does nothing, there being no version for it to match.
- `qm_compiler_eliminate_dead_code` leaves the symbols in a `Debug` or `RelWithDebInfo` build, and asks the linker whether it understands `--icf=all` rather than guessing from the compiler.
- `qm_create_protobuf` turns down a `TARGET` that already exists. The generated files are handed to `add_custom_target`, which takes them, rather than to `add_dependencies`, which takes only the names of targets and stopped the generate step with one error per file.
- `qm_add_binary_resource` always writes the array with the script under `cmake/scripts`, never with a real `xxd`. The two disagreed about what to call the array, `xxd -i` naming it after the input path as written, so the same call gave one symbol on a machine with `xxd` installed and another on a machine without.

### Fixed

- `qm_configure_target` applies `LINKS_INTERFACE`. It was parsed and documented and never passed on.
- `qm_collect_targets` reads `DIRECTORY`. It was declared as `DIR`, so it was never parsed and every call started from the current directory whatever it was given.
- `qm_get_subdirs` reads `REGEX_INCLUDE` and `REGEX_EXCLUDE`. The first was never declared and the second was declared misspelt, so the body filtered on nothing.
- `qm_sync_include` reads `STANDARD`. It was never declared, which showed only where `QMSETUP_SYNC_INCLUDE_STANDARD` was off.
- `qm_add_copy_command` passes `EXTRA_ARGS` through, in both the build rule and the install rule. A list became one argument per item, leaving the script with the first and handing the rest to CMake.
- `qm_future_configure_file` takes `FORCE`. Written as `list(APPLE ...)` it was not an option but an outright error, so no call using it ever worked.
- `qm_win_applocal_deps` makes its `OUTPUT_DIR` rather than stopping the build on a directory that is not there yet.
- `qm_create_win_shortcut` works. Two things stopped it, either alone enough that no call can have produced a shortcut: the file handed to `configure_file` was named after the one carrying `$<CONFIG>`, which is not a name Windows allows, and the shortcut was declared as a byproduct, which takes no target dependent generator expression.
- `qm_generate_build_info` makes an identifier of the `PREFIX` it is given, as it already did of the one it works out. `PREFIX my-lib` asked for macros no compiler would take.
- `qm_compiler_no_warnings` removes every warning flag rather than the first. The patterns wanted a space on either side, so a flag at either end of the string was never seen, and a match took with it the space the next flag needed.
- `qm_deploy_directory` copies an `EXTRA_LIBRARIES` entry once rather than once for every search path that has it.
- `qm_add_translation` releases only the catalogue that changed. Every `.qm` was named as depending on every `.ts`, so touching one translation rebuilt all of them.
- `qm_add_definition`, `qm_remove_definition` and `qm_generate_config` write to the scope asked for. `qm_remove_definition` worked out the scope after reading the property rather than before, so the read had no property name and the write that followed put an empty list where the definitions had been.
- `qm_get_windows_proxy` answers nothing where it found nothing, rather than leaving whatever the variable held before.
- `qmcorecmd incsync` writes a usable include when the source tree and the build directory are on different drives. There is no relative path between two drives, and asking for one gives an empty answer rather than an error, so the generated file was `#include ""`. Reported by fnMrRice as [#16](https://github.com/stdware/qmsetup/issues/16).
- `qmcorecmd deploy` turns down a file that is not a Mach-O binary rather than reading whatever `otool` said about it.
- `qmcorecmd deploy` copies a macOS framework as a bundle, keeps the links inside it, and rewrites the install names of the library within a bundle it has copied.

### Internal

- Both halves have a test suite that runs from CTest on Windows, macOS and Linux. `tests/cli` runs `qmcorecmd` as a black box against real binaries built for the purpose, and `tests/cmake` runs the `qm_*` functions, some as scripts and some by configuring and building a project of their own. What neither reaches is written down in [docs/TODO.md](docs/TODO.md).
- One of those tests is a lint rather than a test of behaviour. `cmake_parse_arguments` says nothing about a keyword that appears in the declaration and not the body, or the other way about, and that is the shape of eight of the fixes above, so it is now asked mechanically.
- CI builds and tests on Linux with gcc and with clang, on macOS, and on Windows with MSVC, with clang-cl and with MinGW, and installs the package and uses it from another project. Qt and protobuf are installed so the tests that want them run, and each job names the tests it expects and stops if one of them did not register.
- `qmcorecmd` is laid out as `commands/` and `utils/`, with the platform specific half of deploying behind a seam that each platform answers.

## v1.0.0.0 (2026-01-18)

The first release.
