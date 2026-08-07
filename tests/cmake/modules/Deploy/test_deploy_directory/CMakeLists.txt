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

qm_deploy_directory("${CMAKE_INSTALL_PREFIX}"
    EXTRA_SEARCHING_PATHS "${CMAKE_BINARY_DIR}/built"
    STANDARD
    VERBOSE
    COMMENT "Deploying what the installed binaries need"
)

# What the platform decided to call these, for check.cmake to read rather than
# guess at. Windows is not one naming scheme: MSVC writes qmtest_extra_lib.dll
# and MinGW writes libqmtest_extra_lib.dll, so a name spelt out in the checks
# was right for whichever compiler happened to be at hand.
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/built_names.cmake" CONTENT
[[set(_extra_name "$<TARGET_FILE_NAME:qmtest_extra_lib>")
]])
