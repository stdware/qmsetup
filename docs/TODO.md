# Status

Both halves have a suite that runs from CTest on Windows, Linux and macOS: `tests/cli` runs `qmcorecmd` as a black box, and `tests/cmake` runs the `qm_*` functions. What follows is what they do not reach, and what they reach only where something else is installed.

## Not tested, and will not be

- Doxygen for `qm_setup_doxygen`, which wants the tool installed to say anything at all.
- `qm_compiler_*`. Each is a list of compiler flags chosen per compiler, so a test could only read the list back to itself, which says nothing about whether the flags are the right ones. What would catch a mistake there is compiling with them.
- Everything under `cmake/modules/private`. It says on it that it may be modified or removed, and nothing outside qmsetup should be calling it. That takes `qm_install_package` with it, which configures and builds an external package during configure and wants a network to do anything worth asserting on.

## Tested where the dependency is there

`qm_find_qt`, `qm_link_qt` and `qm_include_qt_private` are covered by `tests/cmake/QMSetupAPI/test_qt_targets`, `qm_add_translation` by `tests/cmake/modules/Translate/test_translation`, `qm_install_qml_modules` by `tests/cmake/modules/Qml/test_install_qml_modules`, and `qm_create_protobuf` by `tests/cmake/modules/Protobuf/test_create_protobuf`. All of them run against a real installation rather than a stub.

The QML half of `qm_deploy_directory` is one of these, in `tests/cmake/modules/Deploy/test_deploy_qml`, and the rest of that function is covered without a Qt in `test_deploy_directory` beside it. What splits them is qmake: a QML module is named relative to a directory only qmake can say where is, while `PLUGINS` given `EXTRA_PLUGIN_PATHS` never asks for one.

Each registers itself only where the configure found what it needs, so a machine without one of them runs a shorter suite rather than one full of tests that pass themselves over. Name the installations the ordinary way and they all run, `CMAKE_PREFIX_PATH` taking more than one entry:

```sh
cmake -B build -DQMSETUP_BUILD_TESTS=ON \
      "-DCMAKE_PREFIX_PATH=/path/to/Qt/<version>/<compiler>;/path/to/protobuf"
```

The QML one asks for Qt 6.5 on top of that, `qt_query_qml_module` having arrived then.

Protobuf is asked for both ways, since neither reaches every installation. One built and installed the upstream way, which is what vcpkg ships, answers `find_package(Protobuf CONFIG)` and gives module mode the libraries without the `protobuf::protoc` that `qm_create_protobuf` wants. A distribution package is the other way about: Ubuntu's `libprotobuf-dev` carries no CMake configuration at all, so `CONFIG` cannot see it, and `FindProtobuf` looks for the compiler on the path and makes the target out of what it finds. `CONFIG` is asked first, the other order being an error where the second call stops on targets the first has already defined.

CI installs Qt on the four matrix jobs, and protobuf on Linux, on macOS and in the MinGW job from msys2. The two MSVC jobs go without, the only route to a development package there being vcpkg building it and abseil from source. Since a dependency that failed to install would be a shorter run rather than a failure, each job names the tests it expects and stops if one of them did not register, which is how the distribution package was found out about in the first place.

Between them the jobs reach both ways of finding protobuf: Linux has the distribution one at 3.21 through `FindProtobuf`, and macOS and MinGW have one at 35 through `CONFIG`.

## Not tested yet

- The pass that strips a universal binary down to the architecture in use, which needs a binary built for two. `lipo` itself is on every machine with the command line tools, so what is missing is the fixture: building one means a second pass over the whole deploy tree with `CMAKE_OSX_ARCHITECTURES`, and it would test one function.
- `FORCE`, on `qm_deploy_directory` and on `qm_win_applocal_deps`. It is what makes a copy happen where the destination already holds a file of the same name and no older, so a test wants two runs with something put in the way between them, and either function copies enough that doing it twice is the slowest thing in the suite.
- The scripts under `cmake/scripts`, called directly rather than through the function that wraps them. `copy.cmake` is reached through `qm_add_copy_command` and `configure_file.cmake` through `qm_future_configure_file`, both against a real build, so what a direct call would add is the refusal each makes when an argument is missing. `xxd.cmake` is reached only by `qm_add_binary_resource`, which is private.

## Unverified

- The standard library filter cannot be seen to work on macOS. Everything under `/usr/lib` now lives in the dyld shared cache rather than on disk, so `libSystem` is reported as not found whether or not `--standard` was asked for, and the deployment has nothing to leave behind. Checked on Windows and Linux, where the filter has files to act on.
- Nothing compiles what `qm_add_win_rc` and `qm_add_win_rc_enhanced` write. The tests read the generated `.rc` and check what is in it, and the icons they name are files with the right extension and nothing else in them, so that a resource compiler would accept the result is not checked. The same holds for `qm_add_win_manifest`, which nothing embeds.
- Nothing builds what `qm_add_mac_bundle` sets up. The properties it puts on the target are read back, but the `Info.plist` CMake writes out of them is not, so a property spelt wrongly would pass.
