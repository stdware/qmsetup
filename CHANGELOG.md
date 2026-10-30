# Changelog

## Unreleased

### Added

- `VERSION_TEMPLATE` for `qm_basic_install`, which configures the package version file from a template in place of the file that `write_basic_package_version_file` writes.
- `QMSETUP_FORCE_EXECUTABLE_PERMISSIONS`, which grants execute permission to every binary that qmsetup installs or deploys. It defaults to `OFF`.
- `EXCLUDE` for `qm_deploy_directory`, which skips the dependencies whose paths match the given regular expressions.
- `QMSETUP_MSVC_ABI`, which is `ON` if the C or the C++ compiler targets the MSVC ABI, clang with the GNU front end included.
- `--list <source|target|mapping>` for `qmcorecmd deploy` and `incsync`, which prints each file and its target on stdout in a stable format, one line ended by `\n` per file. The messages of `-V` then go to stderr. See `docs/AboutCoreCMD.md`.
- `private/QtPlugins`, with `qm_get_qt_plugins`, which lists the Qt plugins of Qt modules from the module descriptions of a Qt 6 installation, `qm_get_qt_modules`, which recognizes the Qt libraries in a listing of `qmcorecmd`, and `qm_select_qt_plugins`, which selects the plugins of a deployment, resolving each plugin as windeployqt does.
- `QT_PLUGINS`, `QT_PLUGINS_EXCLUDE`, `QT_PLUGINS_EXCLUDE_MODULES` and `QT_PLUGINS_PLATFORMS` for `qm_deploy_directory`. `QT_PLUGINS` deploys the Qt plugins of the Qt modules that the installed binaries require, worked out while installing. `QT_PLUGINS_EXCLUDE` leaves out plugins of that list, and a plugin that requires a module of `QT_PLUGINS_EXCLUDE_MODULES`, such as `Quick`, is left out as well. Nothing is left out by default. `PLUGINS` is deployed beside them and is not affected. Qt 6.9 or later is supported. With an older Qt 6, set `QT6_INSTALL_DESCRIPTIONSDIR` and name the platforms with `QT_PLUGINS_PLATFORMS`.

### Changed

- `qm_basic_install` names the package files after the spelling of the config template. A template named `<lowercase-name>-config.cmake.in` produces `<lowercase-name>-config.cmake` and `<lowercase-name>-config-version.cmake`, the other form that `find_package` searches for, where `<lowercase-name>` is the package name in lower case. Any other template produces `<name>Config.cmake` and `<name>ConfigVersion.cmake` as before. Without `CONFIG_TEMPLATE`, `qm_basic_install` takes `<lowercase-name>-config.cmake.in` of the current list directory if that file exists and `<name>Config.cmake.in` does not.
- `<proj>_init_buildsystem` takes `<lowercase-name>-config.cmake.in` of the current list directory as the default of `<proj>_INSTALL_CONFIG_TEMPLATE` under the same condition, and then names the export set `<lowercase-name>-targets` in place of `<name>Targets`.
- `<proj>_install` forwards the arguments it does not parse to `qm_basic_install`, such as `COMPATIBILITY` and `VERSION_TEMPLATE`.
- The dry run of `qmcorecmd configure`, `incsync` and `deploy` is now `-n, --dry-run`, the names that GNU make, rsync and Git use, in place of `-d, --dryrun`. `--not-all` of `incsync` no longer has the short name `-n`. The former names are no longer accepted.
- The `<proj>_add_*` commands in `cmake/buildsystem` no longer grant execute permission to the installed binaries unless `QMSETUP_FORCE_EXECUTABLE_PERMISSIONS` is on.

### Fixed

- `<proj>_add_application` of a module with `<proj>_MACOSX_BUNDLE_NAME` now removes the archives of static libraries from the installed bundle unless `<proj>_DEVEL` is set, before a later install rule such as `qm_deploy_directory` signs the bundle. `cmake --install` copies the bundle whole from the build, where the archives are built into `Contents/Frameworks`, and codesign rejects a bundle that holds an archive.
- `qm_deploy_directory` with `STANDARD` and `qmcorecmd deploy -s` on Linux now leave a library under a library directory of the system, such as libGL of the graphics driver and libxcb, to the machine, and deploy the ICU that Qt installs beside its libraries. They previously deployed those libraries of the system and passed over the ICU by its name.
- `qm_deploy_directory`, `qm_add_copy_command`, `qm_sync_include` and `qm_setup_doxygen` now install into a relative prefix of `cmake --install --prefix`, which CMake resolves against the current directory. The destination was previously resolved against the directory in which the command of the install rule runs, and `qm_deploy_directory` found no binary to deploy.
- `qm_deploy_directory` now resolves its directories while installing, a relative `<install_dir>` against the install prefix, so that `cmake --install --prefix` moves the deployment with the other install rules. The directories were previously fixed while configuring, and the deployment went into the configured prefix. `"${CMAKE_INSTALL_PREFIX}"` still names the configured prefix, and `.` names the install prefix. A relative `LIBRARY_DIR`, `PLUGIN_DIR` or `QML_DIR` remains relative to `<install_dir>`.
- `qm_deploy_directory` on Windows without `VERBOSE` now deploys. `windeps.bat` wrote `ECHO is off.` in place of the absent `-V`, which `qmcorecmd` could not open, and the failure was not passed on, so the install succeeded with nothing deployed. Every error of the script now fails the install, and the arguments file is no longer left in the install tree.
- The batch scripts are checked out with CRLF line endings whatever `core.autocrlf` says, and the shell scripts with LF. cmd reads a batch file with LF line endings unreliably, and `windeps.bat` failed to parse its own arguments that way.
- `qm_sync_include` with `INSTALL_DIR` now installs a header whose path contains a semicolon. The paths were previously taken from the messages of `-V` and split as a CMake list. They now come from `incsync --list mapping`.
- `qmcorecmd copy` built with libc++ before LLVM 20 no longer refuses a destination outside the source on Windows if one of the two paths is written with `/` and the other with `\`. That libc++ compares the root directories of the two paths as written.
- `qm_add_win_rc` and `qm_add_win_rc_enhanced` now compile the resource again at the next build after an icon changes, under every generator and without a configure, and accept an icon that a custom command writes while building. The resource script is written while building from a script configured beside it, `<target>_res.rc.configured`. The icon was previously compared with the resource script only at configure time, and a build after a changed icon did not configure.
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
