# qm_deploy_directory with a framework in the install tree, on macOS.
#
# The application links the framework, and the framework links a library that
# is not installed. The deployment passes the framework to qmcorecmd as one
# item, which copies the library beside the framework and gives the framework
# the rpaths of a framework. check.cmake reads the rpaths, runs the application
# from the install tree, and loads the framework with a loader outside the
# install tree.
#
# The application alone does not detect wrong rpaths in the framework, because
# dyld also searches the rpaths of the application when it resolves the
# dependencies of the framework. The loader has no rpaths of its own.

cmake_minimum_required(VERSION 3.19)
project(qmtest_deploy_framework VERSION 1.0.0 LANGUAGES C)

include(${QMSETUP_API})

if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

qm_import(Deploy)

add_library(qmtest_fw_dep SHARED src/dep.c)

add_library(QmTestFw SHARED src/fw.c)
target_link_libraries(QmTestFw PRIVATE qmtest_fw_dep)
set_target_properties(QmTestFw PROPERTIES FRAMEWORK TRUE)

add_executable(qmtest_fw_app src/app.c)
target_link_libraries(qmtest_fw_app PRIVATE QmTestFw)

set_target_properties(qmtest_fw_dep QmTestFw qmtest_fw_app PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
)

# Not installed, and kept apart from the built libraries.
add_executable(qmtest_fw_loader src/loader.c)
set_target_properties(qmtest_fw_loader PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/loader"
)

install(TARGETS qmtest_fw_app RUNTIME DESTINATION bin)
install(TARGETS QmTestFw FRAMEWORK DESTINATION Frameworks)

qm_deploy_directory("${CMAKE_INSTALL_PREFIX}"
    EXTRA_SEARCHING_PATHS "${CMAKE_BINARY_DIR}/built"
    LIBRARY_DIR "${CMAKE_INSTALL_PREFIX}/Frameworks"
    VERBOSE
)
