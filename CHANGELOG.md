# Changelog

## v1.1.1.0 (2026-08-10)

### Removed

- `QMSETUP_VCPKG_TOOLS_HINT` is gone, and `qmcorecmd` is installed to the binary directory whatever a port wants. A port that wants it under `tools/<port>` moves it there with `vcpkg_copy_tools`, which is also what brings along the libraries it loads and what a build installing it there directly leaves it without.

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
