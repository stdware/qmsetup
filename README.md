# QtMediate CMake Modules

**QMSetup**: CMake Modules for QtMediate and other projects.

**This project is independent from Qt and other 3rdparty libraries.** Due to the fact that it encompasses some tools that need to be compiled, it's not suggested to be included as a subproject.

---

## Features

+ Helpful CMake utilities
+ Deploy project dependencies and fix rpaths
+ Re-organize header files
+ Generate configuration header files

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

## Thanks

+ RigoLigoRLC
+ CrSjimo
+ wangwenx190