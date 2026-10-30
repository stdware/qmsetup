# qm_basic_install, which writes the package files a find_package needs.
#
# It works by adding install rules, and an install rule that is never run says
# nothing, so this project is built and installed for real by
# testing/build.cmake. What it left behind is asserted in check.cmake.

cmake_minimum_required(VERSION 3.19)
project(qmtest_basic_install VERSION 2.3.4 LANGUAGES C)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

include(${QMSETUP_API})

add_library(qmtest_package_lib SHARED src/lib.c)
target_include_directories(qmtest_package_lib PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

install(TARGETS qmtest_package_lib
    EXPORT qmtest_package_targets
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

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

# A template spelled in lower case, the other form that find_package searches for. The name is in
# mixed case, so that the package files show it lowered.
qm_basic_install(
    NAME QmTestLower
    VERSION 1.2.3
    CONFIG_TEMPLATE "${CMAKE_CURRENT_SOURCE_DIR}/qmtestlower-config.cmake.in"
)

# No template given, with the lower case template of the name in the current list directory.
qm_basic_install(
    NAME QmTestFound
    VERSION 4.5.6
)

# A version file configured from a template in place of the one that
# write_basic_package_version_file writes. The template reads a variable of the caller.
set(QMTEST_VERSIONED_VERSION 7.7.7.7)
qm_basic_install(
    NAME QmTestVersioned
    VERSION 7.7.7.7
    VERSION_TEMPLATE "${CMAKE_CURRENT_SOURCE_DIR}/QmTestVersionedConfigVersion.cmake.in"
)
