# qm_deploy_directory, which gathers what an installed tree needs to run.
#
# It works by adding an install rule that runs windeps.bat or unixdeps.sh, which
# runs qmcorecmd, so nothing short of a real install exercises any of it. The
# project is built and installed by testing/build.cmake and what it left
# behind is asserted in check.cmake.
#
# The application is installed. The library it links is deliberately not, which
# is the only reason the deployment has anything to do.

cmake_minimum_required(VERSION 3.19)
project(qmtest_deploy_directory VERSION 1.0.0 LANGUAGES C)

include(GNUInstallDirs)

include(${QMSETUP_API})

if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

qm_import(Deploy)

add_library(qmtest_extra_lib SHARED src/extra.c)
target_include_directories(qmtest_extra_lib PUBLIC src)

add_executable(qmtest_deploy_app src/app.c)
target_link_libraries(qmtest_deploy_app PRIVATE qmtest_extra_lib)

# Both in one place, so that the deployment has one directory to be told about
# rather than several.
set_target_properties(qmtest_extra_lib qmtest_deploy_app PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
)

install(TARGETS qmtest_deploy_app
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Linked by nothing, so following the graph from the application never arrives
# at it and only EXTRA_LIBRARIES brings it.
add_library(qmtest_loose_lib SHARED src/loose.c)
target_include_directories(qmtest_loose_lib PUBLIC src)
set_target_properties(qmtest_loose_lib PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
)

# A plugin, in the shape the scripts underneath look for: a category directory
# with the library inside it, named `lib<name>.*` on Unix and `<name>.dll` on
# Windows. The prefix is dropped on Windows for that reason, which is also what
# Qt does with its own plugins, MinGW otherwise writing libqmtest_svgicon.dll
# where windeps.bat asks for qmtest_svgicon.dll and finds nothing.
add_library(qmtest_svgicon SHARED src/plugin.c)
target_include_directories(qmtest_svgicon PUBLIC src)
set_target_properties(qmtest_svgicon PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qmtest_plugins/iconengines"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qmtest_plugins/iconengines"
)

if(WIN32)
    set_target_properties(qmtest_svgicon PROPERTIES PREFIX "")
endif()

# EXTRA_LIBRARIES is matched against what is on disk while the project is being
# read, so it cannot name anything this build has yet to make. What it is for is
# a binary that was already there, and a real one is needed rather than a file
# with the right name, the deployment reading each thing it copies. qmcorecmd
# is one, and the test is handed its path anyway.
get_filename_component(_prebuilt_name "${QMSETUP_CORECMD_EXECUTABLE}" NAME)

# The copy has no execute permission. The deployed copy receives it only through
# QMSETUP_FORCE_EXECUTABLE_PERMISSIONS.
file(COPY "${QMSETUP_CORECMD_EXECUTABLE}" DESTINATION "${CMAKE_BINARY_DIR}/prebuilt"
    FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
)

# A library installed without execute permission, as CMake installs shared
# libraries on Debian and the distributions derived from it. Its dependency is
# not installed and is deployed only through the library.
add_library(qmtest_noexec_dep SHARED src/noexec_dep.c)
target_include_directories(qmtest_noexec_dep PUBLIC src)

add_library(qmtest_noexec_lib SHARED src/noexec.c)
target_link_libraries(qmtest_noexec_lib PRIVATE qmtest_noexec_dep)

set_target_properties(qmtest_noexec_dep qmtest_noexec_lib PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
)

install(TARGETS qmtest_noexec_lib
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
)

# A separate debug file in the library directory, as _repo_install_pdb writes
# one beside each binary on Linux. The file is written without execute
# permission before the deployment runs, and keeps none if the deployment does
# not treat it as a binary. The step requires the objcopy of the toolchain, and
# check.cmake skips the check if the file was not written.
if(CMAKE_OBJCOPY)
    install(CODE "
        set(_debug \"\${CMAKE_INSTALL_PREFIX}/qmtest_libs/$<TARGET_FILE_NAME:qmtest_noexec_lib>.debug\")
        file(MAKE_DIRECTORY \"\${CMAKE_INSTALL_PREFIX}/qmtest_libs\")
        execute_process(
            COMMAND \"${CMAKE_OBJCOPY}\" --only-keep-debug \"$<TARGET_FILE:qmtest_noexec_lib>\" \"\${_debug}\"
            RESULT_VARIABLE _result
        )
        if(\"\${_result}\" STREQUAL \"0\" AND EXISTS \"\${_debug}\")
            file(CHMOD \"\${_debug}\" PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
        endif()
    ")
endif()

# A library in the install tree whose dependency matches EXCLUDE.
add_library(qmtest_excl_dep SHARED src/excl_dep.c)
target_include_directories(qmtest_excl_dep PUBLIC src)

add_library(qmtest_excl_lib SHARED src/excl.c)
target_link_libraries(qmtest_excl_lib PRIVATE qmtest_excl_dep)

set_target_properties(qmtest_excl_dep qmtest_excl_lib PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
)

install(TARGETS qmtest_excl_lib
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# The expression contains characters that bash and cmd interpret: ^ | ( ) ? ! $
# and a backslash. The deployment receives the expression unchanged only if the
# expression does not pass through the command line of either script.
set(_exclude "(^|/)(lib)?qmtest_excl_dep(?!_never)[^/]*\\.(so|dylib|dll)$")

set(QMSETUP_FORCE_EXECUTABLE_PERMISSIONS on)

# PLUGINS with EXTRA_PLUGIN_PATHS asks for no qmake, which is what lets the
# plugin half of this run without a Qt. QML is the part that cannot.
qm_deploy_directory("${CMAKE_INSTALL_PREFIX}"
    EXTRA_SEARCHING_PATHS "${CMAKE_BINARY_DIR}/built" "${CMAKE_BINARY_DIR}/prebuilt"
    LIBRARY_DIR "${CMAKE_INSTALL_PREFIX}/qmtest_libs"
    EXTRA_LIBRARIES "${_prebuilt_name}"
    PLUGINS "iconengines/qmtest_svgicon"
    PLUGIN_DIR "${CMAKE_INSTALL_PREFIX}/qmtest_plugins"
    EXTRA_PLUGIN_PATHS "${CMAKE_BINARY_DIR}/qmtest_plugins"
    EXCLUDE "${_exclude}"
    STANDARD
    VERBOSE
    COMMENT "Deploying what the installed binaries need"
)

# What the platform decided to call these, for check.cmake to read rather than
# guess at. Windows is not one naming scheme: MSVC writes qmtest_extra_lib.dll
# and MinGW writes libqmtest_extra_lib.dll, so a name spelt out in the checks
# was right for whichever compiler happened to be at hand.
#
# A quoted string rather than a bracket one, since the last of these is settled
# while the project is being read and the others only when it is generated.
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/built_names.cmake" CONTENT
"set(_extra_name \"$<TARGET_FILE_NAME:qmtest_extra_lib>\")
set(_loose_name \"$<TARGET_FILE_NAME:qmtest_loose_lib>\")
set(_plugin_name \"$<TARGET_FILE_NAME:qmtest_svgicon>\")
set(_prebuilt_name \"${_prebuilt_name}\")
set(_noexec_name \"$<TARGET_FILE_NAME:qmtest_noexec_lib>\")
set(_noexec_dep_name \"$<TARGET_FILE_NAME:qmtest_noexec_dep>\")
set(_excl_dep_name \"$<TARGET_FILE_NAME:qmtest_excl_dep>\")
")
