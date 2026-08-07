# Status

Both halves have a suite that runs from CTest on Windows, Linux and macOS: `tests/cli` runs `qmcorecmd` as a black box, and `tests/cmake` runs the `qm_*` functions. What follows is what neither of them reaches.

## Not tested, and will not be

- Anything wanting something installed to say anything. Qt for `qm_find_qt`, `qm_link_qt`, `qm_include_qt_private`, `qm_add_translation` and `qm_install_qml_modules`, protobuf for `qm_create_protobuf`, doxygen for `qm_setup_doxygen`.
- `qm_compiler_*`. Each is a list of compiler flags chosen per compiler, so a test could only read the list back to itself, which says nothing about whether the flags are the right ones. What would catch a mistake there is compiling with them.
- Everything under `cmake/modules/private`. It says on it that it may be modified or removed, and nothing outside qmsetup should be calling it. That takes `qm_install_package` with it, which configures and builds an external package during configure and wants a network to do anything worth asserting on.

## Not tested yet

- The pass that strips a universal binary down to the architecture in use, which needs a binary built for two. `lipo` itself is on every machine with the command line tools, so what is missing is the fixture: building one means a second pass over the whole deploy tree with `CMAKE_OSX_ARCHITECTURES`, and it would test one function.
- The scripts under `cmake/scripts`, called directly rather than through the function that wraps them. `copy.cmake` is reached through `qm_add_copy_command` and `configure_file.cmake` through `qm_future_configure_file`, both against a real build, so what a direct call would add is the refusal each makes when an argument is missing. `xxd.cmake` is reached only by `qm_add_binary_resource`, which is private.

## Unverified

- The standard library filter cannot be seen to work on macOS. Everything under `/usr/lib` now lives in the dyld shared cache rather than on disk, so `libSystem` is reported as not found whether or not `--standard` was asked for, and the deployment has nothing to leave behind. Checked on Windows and Linux, where the filter has files to act on.
- Nothing compiles what `qm_add_win_rc` and `qm_add_win_rc_enhanced` write. The tests read the generated `.rc` and check what is in it, and the icons they name are files with the right extension and nothing else in them, so that a resource compiler would accept the result is not checked. The same holds for `qm_add_win_manifest`, which nothing embeds.
- Nothing builds what `qm_add_mac_bundle` sets up. The properties it puts on the target are read back, but the `Info.plist` CMake writes out of them is not, so a property spelt wrongly would pass.
