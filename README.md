# QtMediate CMake Modules

CMake modules for QtMediate and other projects.

## Modules

+ Windows & MacOS platform resources
    + `qtmediate_add_win_rc`
    + `qtmediate_add_win_manifest`
    + `qtmediate_create_win_shortcut`
    + `qtmediate_add_mac_bundle`
+ Doxygen
    + `qtmediate_setup_doxygen`
+ Source file processing
    + `qtmediate_gen_include`
+ Qt related functions
    + `qtmediate_dir_skip_automoc`
    + `qtmediate_find_qt_libraries`
    + `qtmediate_link_qt_libraries`
    + `qtmediate_include_qt_private`
+ CMake Utils
    + `qtmediate_parse_version`
    + `qtmediate_set_value`
    + `qtmediate_configure_target`
    + `qtmediate_export_defines`

## Integrate

+ CMake Sub-project
    + Edit `CMakeLists.txt`
        ```cmake
        include("${QTMEDIATE_MODULES_DIR}/QtMediateAPI.cmake")
        ```
    + CMake Configure
        ```sh
        cmake -DQTMEDIATE_MODULES_DIR=<dir> ...
        ```