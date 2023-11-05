# QtMediate CMake Modules

CMake Modules for QtMediate and other projects.

This project is independent from Qt and other 3rdparty libraries. Due to the fact that it encompasses some tools that need to be compiled, it cannot be included as a subproject.

## Support Platforms

+ Microsoft Windows
+ Apple Macintosh
+ GNU/Linux

## Preprocess Tools

+ cfggen
+ incsync
+ corecmd
+ windeps (Windows Only)
+ unixdeps (Unix Only)

## Dependencies

### Required Packages

`windeps` acquires the shared library paths by reading the PE files and searching the specified paths so that it doesn't depend on `dumpbin` tool.

`unixdeps` acquires the shared library paths by running `ldd`/`otool` command and fixes the *rpath*s by runing the `patchelf`/`install_name_tool` command, make sure you have installed them.

```sh
sudo apt install patchelf
```

### Open-Source Libraries
+ https://github.com/SineStriker/syscmdline
+ https://github.com/jothepro/doxygen-awesome-css

<!-- ## Functions

### Basic
+ Windows & MacOS platform resources
    + `qtmediate_add_win_rc`
    + `qtmediate_add_win_manifest`
    + `qtmediate_add_mac_bundle`
    + `qtmediate_create_win_shortcut`
+ Deploy shared libraries
    + `qtmediate_win_applocal_deps`
+ Qt related functions
    + `qtmediate_dir_skip_automoc`
    + `qtmediate_find_qt_libraries`
    + `qtmediate_link_qt_libraries`
    + `qtmediate_include_qt_private`
+ CMake Utilities
    + `qtmediate_parse_version`
    + `qtmediate_crop_version`
    + `qtmediate_get_shared_library_path`
    + `qtmediate_set_value`
    + `qtmediate_configure_target`
    + `qtmediate_export_defines`
    + `qtmediate_collect_targets`
    + `qtmediate_get_subdirs`
    + `qtmediate_has_genex`

### Extra
+ Filesystem
    + TODO

+ Preprocess
    + `qtmediate_sync_include`
    + `qtmediate_add_definition`
    + `qtmediate_generate_config`
    + `qtmediate_generate_build_info`

+ Doxygen
    + `qtmediate_setup_doxygen`

+ Qt linguist functions
    + `qtmediate_add_translation` -->

## Integrate

### Clone

Via Https
```sh
git clone --recursive https://github.com/SineStriker/qtmediate-cmake-modules.git
```
Via SSH
```sh
git clone --recursive git@github.com:SineStriker/qtmediate-cmake-modules.git
```

### Build & Install
```sh
cmake -B build -DCMAKE_INSTALL_PREFIX=/path/to
cmake -B build --target all
cmake -B build --target install
```

### Import
```sh
cmake -DqtmediateCM_DIR=/path/to/lib/cmake/qtmediateCM ...
```
```cmake
# CMakeLists.txt
find_package(qtmediateCM REQUIRED)
```

## Thanks

+ RigoLigoRLC
+ CrSjimo
+ wangwenx190