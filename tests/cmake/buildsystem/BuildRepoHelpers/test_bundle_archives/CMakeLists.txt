# <proj>_add_application of a module laid out in a bundle, which removes the archives from the
# installed bundle unless <proj>_DEVEL is set.
#
# Registered only on macOS, where alone the layout is a bundle. cmake --install copies the bundle
# whole from the build, so the project is built and installed by testing/build.cmake, and
# check.cmake asserts what the installed bundle holds.

cmake_minimum_required(VERSION 3.19)
project(qmtest_bundle_archives VERSION 1.0 LANGUAGES C)

include(${QMSETUP_API})

if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

qm_import(private/BuildSystem)

# A prefix of its own, because the harness reads variables that start with QMTEST_
set(QMSETUP_BUILD_DIR "${CMAKE_BINARY_DIR}/out")
set(BUNDLETEST_INSTALL on)
set(BUNDLETEST_MACOSX_BUNDLE_NAME QmTestBundle)
qm_setup_build_repo_helpers(bundletest)
bundletest_init_buildsystem(BUNDLETEST)

bundletest_add_library(qmtest_archive STATIC SOURCES src/archive.c)
bundletest_add_library(qmtest_shared SHARED SOURCES src/shared.c)
bundletest_add_application(qmtest_app
    SOURCES src/app.c
    LINKS qmtest_archive qmtest_shared
)
qm_add_mac_bundle(qmtest_app NAME QmTestBundle)

# A file of the bundle whose name ends with .a and which is no archive
file(WRITE "${BUNDLETEST_BUILD_DATA_DIR}/notes.a" "not an archive\n")
