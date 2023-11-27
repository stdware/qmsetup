# QMSetup: QtMediate CMake Modules

**QMSetup** is a set of CMake Modules for QtMediate and other projects.

**This project is independent from Qt and other 3rdparty libraries.** Due to the fact that it encompasses some tools that need to be compiled, it's not suggested to be included as a subproject.

---

## Features

+ Helpful CMake utilities
+ Generate configuration header files
+ Re-organize header files
+ Deploy project dependencies and fix rpaths

## Support Platforms

+ Microsoft Windows
+ Apple Macintosh
+ GNU/Linux

## Dependencies

### Required Packages

Windows deploy command acquires the shared library paths by reading the PE files and searching the specified paths so that it doesn't depend on `dumpbin` tool.

Unix deploy command acquires the shared library paths by running `ldd`/`otool` command and fixes the *rpath*s by runing the `patchelf`/`install_name_tool` command, make sure you have installed them.

```sh
sudo apt install patchelf
```

### Open-Source Libraries
+ https://github.com/SineStriker/syscmdline
+ https://github.com/jothepro/doxygen-awesome-css

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

### Preinstall (Suggested)

#### Build & Install
```sh
cmake -B build -DCMAKE_INSTALL_PREFIX=/path/to
cmake -B build --target all
cmake -B build --target install
```

#### Import
```sh
cmake -Dqmsetup_DIR=/path/to/lib/cmake/qmsetup ...
```
```cmake
find_package(qmsetup REQUIRED)
```

### Sub-project

It still needs to be installed, but the installation occurs during the CMake Configure phase and is executed only once.

```cmake
find_package(qmsetup QUIET)

if (NOT TARGET qmsetup::library)
    # Modify this variable according to your project structure
    set(_source_dir ${CMAKE_CURRENT_SOURCE_DIR}/qmsetup)

    # Import install function
    include("${_source_dir}/cmake/modules/InstallPackage.cmake")

    # Install package in place
    set(_package_path)
    qmsetup_install_package(qmsetup
        SOURCE_DIR ${_source_dir}
        BUILD_TYPE Release
        RESULT_PATH _package_path
    )

    # Find package again
    find_package(qmsetup REQUIRED PATHS ${_package_path})

    # Update import path
    set(qmsetup_DIR ${_package_path} CACHE PATH "" FORCE)
endif()
```

## Quick Start

### Examples

Here are some common use cases of CMake project, you can simplify many operations when using this library.

#### Generate Configuration Header
```cmake
qm_import(Preprocess)

qm_add_definition(FOO false)
qm_add_definition(BAR 114514)
qm_add_definition(BAZ "ABC" STRING_LITERAL)

qm_generate_config(${CMAKE_BINARY_DIR}/conf.h)
```

#### Sync Resource Files After Build
```cmake
qm_import(Filesystem)

qm_add_copy_command(${PROJECT_NAME}
    SOURCES
        file.txt
        dir_to_copy
        dir_contents_to_copy/
    DESTINATION .
)
```

#### Deploy Project And All Dependencies
```cmake
qm_import(Deploy)

qm_deploy_directory("${CMAKE_INSTALL_PREFIX}"
    COMMENT "Deploy project spectacularly"
    PLUGINS "iconengines/qsvgicon" "bearer/qgenericbearer"
    QML Qt QtQml
    PLUGIN_DIR share/plugins
    QML_DIR share/qml
)
```

## Thanks

+ RigoLigoRLC
+ CrSjimo
+ wangwenx190