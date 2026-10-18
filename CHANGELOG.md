# Changelog

## Unreleased

### Added

- `QMSETUP_FORCE_EXECUTABLE_PERMISSIONS`, which grants execute permission to every binary that qmsetup installs or deploys. It defaults to `OFF`.
- `EXCLUDE` for `qm_deploy_directory`, which skips the dependencies whose paths match the given regular expressions.
- `QMSETUP_MSVC_ABI`, which is `ON` if the C or the C++ compiler targets the MSVC ABI, clang with the GNU front end included.

### Changed

- The dry run of `qmcorecmd configure`, `incsync` and `deploy` is now `-n, --dry-run`, the names that GNU make, rsync and Git use, in place of `-d, --dryrun`. `--not-all` of `incsync` no longer has the short name `-n`. The former names are no longer accepted.
- The `<proj>_add_*` commands in `cmake/buildsystem` no longer grant execute permission to the installed binaries unless `QMSETUP_FORCE_EXECUTABLE_PERMISSIONS` is on.

### Fixed

- `qmcorecmd copy` built with libc++ before LLVM 20 no longer refuses a destination outside the source on Windows if one of the two paths is written with `/` and the other with `\`. That libc++ compares the root directories of the two paths as written.
- `qm_add_win_rc` and `qm_add_win_rc_enhanced` now compile the resource again after an icon changes, under Ninja, the Makefiles and Visual Studio. The icon was previously compared with the resource script only at configure time, and a build after a changed icon did not configure.
- `qm_deploy_directory` on Linux and macOS now processes binaries installed without execute permission, and skips separate debug files.
- `qm_deploy_directory` on macOS now passes a framework in the install tree to `qmcorecmd` as one item. The framework previously received an rpath that resolved its dependencies only through the rpaths of the application.
- `qm_add_win_manifest` with clang with the GNU front end targeting the MSVC ABI now passes the manifest to the linker as it does with cl. The manifest previously went into a resource script, beside the manifest that the linker embeds by default.
- `qm_compiler_eliminate_dead_code` with clang with the GNU front end targeting the MSVC ABI now passes `/OPT:REF` and `/OPT:ICF` to the linker. The options of the GNU linkers that it passed were ignored by lld-link with a warning.
- `qm_compiler_enable_secure_code` with clang with the GNU front end targeting the MSVC ABI now enables the stack protector, control flow guard, the EH continuation guard and CET compatibility. It previously passed the options of the Linux branch, which failed to compile.
- `qm_deploy_directory` on Linux and macOS now searches the Qt library directory if qmake is known, as it searches the Qt binary directory on Windows. A Qt library that only a library outside Qt requires was previously not deployed.

## v1.1.2.0 (2026-08-20)

### Removed

- `QMSETUP_VCPKG_TOOLS_HINT`. `qmcorecmd` now installs to the binary directory, and a vcpkg port moves it with `vcpkg_copy_tools`.
- `CompilerOptions` is now imported as `private/CompilerOptions`.

### Deprecated

- `Qml` is now `QtQml` and `Translate` is now `QtLinguist`. The old names still import, with a warning.

### Added

- A reference for the `qm_*` commands, built with `QMSETUP_BUILD_DOCUMENTATIONS=ON` and published to GitHub Pages.

### Fixed

- `qmcorecmd rmdir` no longer walks through a link and removes directories outside the tree it was given.
- `qmcorecmd copy` now refuses a destination inside a source, and an empty source.
- `qmcorecmd` builds as C++17 again.

## v1.1.1.0 (2026-08-10)

### Fixed

- Installation now fails when `qm_add_copy_command` cannot copy its files.
- `qm_install_qml_modules` now supports modules without a plugin or generated type information.

## v1.1.0.0 (2026-08-08)

### Changed

- `qmcorecmd` now uses stdcorelib instead of syscmdline, and Linux deployment resolves each binary's direct dependencies with `patchelf` and `ldd`.
- `CMAKE_BUILD_SHARE_DIR` is deprecated in favor of `QMSETUP_BUILD_SHARE_DIR`.
- `qm_win_record_deps`, deploy's unused `--linkdirs-file`, and the unused `TARGET` keyword of `qm_win_applocal_deps` were removed.

### Fixed

- Corrected ignored or misspelled CMake arguments across target configuration, directory collection, include synchronization, file generation, deployment and translation helpers.
- Fixed Windows shortcut generation and creation of custom deployment output directories.
- Fixed cross-drive include synchronization and macOS framework deployment, including bundle links and install names.
- Protobuf generation now rejects an existing custom target instead of producing invalid dependencies.

### Internal

- Added cross-platform CLI and CMake test suites, dependency-backed Qt and protobuf coverage, argument declaration linting, and expanded CI coverage.

## v1.0.0.0 (2026-01-18)

The first release.
