# QtMediate CMake Modules

CMake Modules for QtMediate and other projects.

This project is independent from Qt and other 3rdparty libraries. Due to the fact that it encompasses some tools that need to be compiled, it cannot be included as a subproject.

## Functions

+ Windows & MacOS platform resources
    + `qtmediate_add_win_rc`
    + `qtmediate_add_win_manifest`
    + `qtmediate_add_mac_bundle`
    + `qtmediate_create_win_shortcut`
    + `qtmediate_win_applocal_deps`
+ Doxygen
    + `qtmediate_setup_doxygen`
+ Preprocess
    + `qtmediate_sync_include`
    + `qtmediate_add_definition`
    + `qtmediate_generate_config`
+ Qt related functions
    + `qtmediate_dir_skip_automoc`
    + `qtmediate_find_qt_libraries`
    + `qtmediate_link_qt_libraries`
    + `qtmediate_include_qt_private`
+ CMake Utilities
    + `qtmediate_parse_version`
    + `qtmediate_set_value`
    + `qtmediate_configure_target`
    + `qtmediate_export_defines`

## Integrate

+ Build & Install
    ```sh
    cmake -B build -DCMAKE_INSTALL_PREFIX=/path/to
    cmake -B build --target all
    cmake -B build --target install
    ```

+ Integrate
    ```sh
    cmake -Dqtmediate-cmake-modules_DIR=/path/to/lib/cmake/qtmediate-cmake-modules ...
    ```
    ```cmake
    # CMakeLists.txt
    find_package(qtmediate-cmake-modules REQUIRED)
    ```

## Thanks

+ RigoLigoRLC
+ CrSjimo
+ wangwenx190