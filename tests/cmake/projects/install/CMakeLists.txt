# qm_basic_install and qm_deploy_directory, which only mean anything once a
# project has been built and installed.
#
# Unlike the other project under here this one is built and installed for real,
# because what both functions do is add install rules and an install rule that
# is never run says nothing. The assertions are in the run.cmake beside this
# file, which looks at the tree that was installed.
#
# Three targets, for three different jobs:
#
#   qmtest_package_lib  exported and installed, so there is something for
#                       qm_basic_install to write a package for
#   qmtest_extra_lib    never installed, and the only reason the deployment has
#                       anything to do
#   qmtest_install_app  installed, links the extra library, and is what the
#                       deployment is pointed at

cmake_minimum_required(VERSION 3.19)
project(qmtest_install_project VERSION 2.3.4 LANGUAGES C)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

include(${QMSETUP_API})

if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

qm_import(Deploy)

add_library(qmtest_package_lib SHARED src/package.c)
target_include_directories(qmtest_package_lib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

add_library(qmtest_extra_lib SHARED src/extra.c)
target_include_directories(qmtest_extra_lib PUBLIC src)

add_executable(qmtest_install_app src/app.c)
target_link_libraries(qmtest_install_app PRIVATE qmtest_extra_lib)

# Everything in one place, so that the deployment has one directory to be told
# about rather than several.
set_target_properties(qmtest_package_lib qmtest_extra_lib qmtest_install_app PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/built"
)

install(TARGETS qmtest_package_lib
    EXPORT qmtest_package_targets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Not in an export set. Its dependency is deliberately left uninstalled, which
# an exported target is not allowed to have.
install(TARGETS qmtest_install_app
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# ------------------------------------------------------------------
# qm_basic_install
# ------------------------------------------------------------------

# No template given, so one is written naming the targets file.
qm_basic_install(
    NAME QmTestPackage
    VERSION 2.3.4
    NAMESPACE QmTest::
    EXPORT qmtest_package_targets
)

# And one that is given a template of its own.
qm_basic_install(
    NAME QmTestTemplated
    VERSION 9.8.7
    COMPATIBILITY SameMajorVersion
    CONFIG_TEMPLATE "${CMAKE_CURRENT_SOURCE_DIR}/QmTestTemplatedConfig.cmake.in"
)

# ------------------------------------------------------------------
# qm_deploy_directory
#
# The application is installed without the library it needs. Finding that and
# bringing it along is the whole job.
# ------------------------------------------------------------------

qm_deploy_directory("${CMAKE_INSTALL_PREFIX}"
    EXTRA_SEARCHING_PATHS "${CMAKE_BINARY_DIR}/built"
    STANDARD
    VERBOSE
    COMMENT "Deploying what the installed binaries need"
)
