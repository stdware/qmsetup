# <proj>_install of a module whose config template is spelled in lower case, the other form that
# find_package searches for. <proj>_init_buildsystem takes that template from the current list
# directory and names the export set in the same spelling, and qm_basic_install names the package
# files after the template. VERSION_TEMPLATE checks that <proj>_install forwards the arguments it
# does not parse.
#
# The project is built and installed by testing/build.cmake, and check.cmake asserts the installed
# package files.

cmake_minimum_required(VERSION 3.19)
project(qmtest_install_names VERSION 3.1.4 LANGUAGES C)

include(${QMSETUP_API})

if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

qm_import(private/BuildSystem)

# A prefix of its own, because the harness reads variables that start with QMTEST_
set(QMSETUP_BUILD_DIR "${CMAKE_BINARY_DIR}/out")
set(NAMETEST_INSTALL on)
set(NAMETEST_DEVEL on)
set(NAMETEST_INSTALL_NAME QmTestNames)
qm_setup_build_repo_helpers(nametest)
nametest_init_buildsystem(NAMETEST)

# The init function is a macro, so a variable that it does not unset stays in this scope.
foreach(_var _default_config_template _default_config_file _default_version_file
        _default_lower_name)
    if(DEFINED ${_var})
        message(FATAL_ERROR "nametest_init_buildsystem leaves ${_var} in the scope of the caller")
    endif()
endforeach()

nametest_add_library(qmtest_names_lib STATIC SOURCES src/lib.c)
nametest_install(NO_INCLUDE
    VERSION_TEMPLATE "${CMAKE_CURRENT_SOURCE_DIR}/qmtestnames-config-version.cmake.in"
)
