# Status

Both halves have a suite that runs from CTest on Windows, Linux and macOS: `tests/cli` runs `qmcorecmd` as a black box, and `tests/cmake` runs the `qm_*` functions. What follows is what neither of them reaches.

## Not tested, and will not be

- Doxygen for `qm_setup_doxygen`, which wants the tool installed to say anything at all.
- `qm_compiler_*`. Each is a list of compiler flags chosen per compiler, so a test could only read the list back to itself, which says nothing about whether the flags are the right ones. What would catch a mistake there is compiling with them.
- Everything under `cmake/modules/private`. It says on it that it may be modified or removed, and nothing outside qmsetup should be calling it. That takes `qm_install_package` with it, which configures and builds an external package during configure and wants a network to do anything worth asserting on.

## Tested only where Qt is

`qm_find_qt`, `qm_link_qt`, `qm_include_qt_private` and `qm_add_translation` are covered, against a real installation, by `tests/cmake/QMSetupAPI/test_qt_targets` and `tests/cmake/modules/Translate/test_translation`. Both are registered only when the configure found a Qt, so pass `-DCMAKE_PREFIX_PATH=/path/to/Qt/<version>/<compiler>` to have them run. A machine without one registers neither rather than registering tests that pass themselves over, and CI has no Qt, so nothing there runs them yet.

`qm_install_qml_modules` is still untested. It wants a QML module to install, which is a fixture of a different size from the ones above.

`qm_create_protobuf` is not covered yet either, though it can be. It needs a protobuf, found the same way with `CMAKE_PREFIX_PATH`, and the search path takes more than one entry so Qt and protobuf can both be named. Worth knowing before writing it: the function asks for the `protobuf::protoc` target, and `find_package(Protobuf)` in module mode does not create one. `find_package(protobuf CONFIG)` does. The two cannot be used one after the other, the second reporting that some of the targets are already defined.

## Not tested yet

- The pass that strips a universal binary down to the architecture in use, which needs a binary built for two. `lipo` itself is on every machine with the command line tools, so what is missing is the fixture: building one means a second pass over the whole deploy tree with `CMAKE_OSX_ARCHITECTURES`, and it would test one function.
- The scripts under `cmake/scripts`, called directly rather than through the function that wraps them. `copy.cmake` is reached through `qm_add_copy_command` and `configure_file.cmake` through `qm_future_configure_file`, both against a real build, so what a direct call would add is the refusal each makes when an argument is missing. `xxd.cmake` is reached only by `qm_add_binary_resource`, which is private.

## Unverified

- The standard library filter cannot be seen to work on macOS. Everything under `/usr/lib` now lives in the dyld shared cache rather than on disk, so `libSystem` is reported as not found whether or not `--standard` was asked for, and the deployment has nothing to leave behind. Checked on Windows and Linux, where the filter has files to act on.
- Nothing compiles what `qm_add_win_rc` and `qm_add_win_rc_enhanced` write. The tests read the generated `.rc` and check what is in it, and the icons they name are files with the right extension and nothing else in them, so that a resource compiler would accept the result is not checked. The same holds for `qm_add_win_manifest`, which nothing embeds.
- Nothing builds what `qm_add_mac_bundle` sets up. The properties it puts on the target are read back, but the `Info.plist` CMake writes out of them is not, so a property spelt wrongly would pass.
