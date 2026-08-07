# Tests for the CMake layer, the qm_* functions in cmake/.
#
# Everything here sits where what it tests sits, so the tests for a module are
# where you would look for them:
#
#   cmake/QMSetupAPI.cmake          QMSetupAPI/
#   cmake/modules/Preprocess.cmake  modules/Preprocess/
#
# testing/ is the exception, being the only thing under here that is not a test:
# the assertions every test uses, and the two drivers that run the ones that are
# projects.
#
# There are three kinds, and each covers one group of functions:
#
#   test_*.cmake     a script, run with `cmake -P`. Nothing it checks needs a
#                    project to exist, so nothing configures or builds, and it
#                    finishes in hundredths of a second.
#
#   test_*/          a project, configured by testing/configure.cmake, for the
#                    functions that work on targets. The assertions are in its
#                    CMakeLists.txt, so a configure that stops is a test that
#                    failed. Nothing is built.
#
#   test_*/          with a check.cmake beside it, a project that is built and
#                    installed by testing/build.cmake, for the functions
#                    that work by adding install rules. The assertions are in
#                    check.cmake, which runs against the installed tree. These
#                    are the slowest here by a long way.
#
# Not covered:
#
#   qm_compiler_* is left alone on purpose. Every one of them is a list of
#   compiler flags chosen per compiler, so a test could only read the list back
#   to itself, which says nothing about whether the flags are the right ones.
#   What would catch a mistake there is compiling with them, which is a
#   different kind of test from any of these.
#
#   Anything wanting Qt, protobuf or doxygen installed, and the standalone
#   scripts under cmake/scripts.

# ------------------------------------------------------------------
# Scripts
# ------------------------------------------------------------------

set(_scripts
    QMSetupAPI/test_version
    QMSetupAPI/test_values
    QMSetupAPI/test_subdirs
    modules/Filesystem/test_directories
    modules/Preprocess/test_definitions
    modules/Preprocess/test_generate_config
    modules/Preprocess/test_sync_include
    modules/Preprocess/test_build_info
)

# ------------------------------------------------------------------
# Projects that are configured
# ------------------------------------------------------------------

set(_configured_projects
    QMSetupAPI/test_targets
    modules/Preprocess/test_definition_scopes
)

# Registered only where they do anything, rather than configuring a project
# whose every check is behind a platform test.
if(WIN32)
    list(APPEND _configured_projects QMSetupAPI/test_win_resources)
endif()

if(APPLE)
    list(APPEND _configured_projects QMSetupAPI/test_mac_bundle)
endif()

# ------------------------------------------------------------------
# Projects that are built and installed
# ------------------------------------------------------------------

set(_built_projects
    QMSetupAPI/test_basic_install
    modules/Deploy/test_deploy_directory
)

if(WIN32)
    list(APPEND _built_projects modules/Deploy/test_win_applocal_deps)
endif()

# ------------------------------------------------------------------
# Registration
# ------------------------------------------------------------------

# The path is the name, so a failure says which directory to open.
function(qmtest_cmake_add _module _driver)
    string(REPLACE "/" "." _name ${_module})

    add_test(NAME cmake.${_name}
        COMMAND ${CMAKE_COMMAND}
            -DQMSETUP_API=${QMSETUP_PROJECT_ROOT}/cmake/QMSetupAPI.cmake
            -DQMCORECMD=$<TARGET_FILE:qmcorecmd>
            # Passed in rather than found relative to the test, which would have
            # every file counting how deep it sits.
            -DQMTEST_HARNESS=${CMAKE_CURRENT_SOURCE_DIR}/testing/harness.cmake
            -DQMTEST_WORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/${_module}/work
            -DQMTEST_PROJECT=${CMAKE_CURRENT_SOURCE_DIR}/${_module}
            -DQMTEST_PROJECT_BUILD=${CMAKE_CURRENT_BINARY_DIR}/${_module}/build
            -DQMTEST_INSTALL_PREFIX=${CMAKE_CURRENT_BINARY_DIR}/${_module}/prefix
            -DQMTEST_GENERATOR=${CMAKE_GENERATOR}
            -DQMTEST_C_COMPILER=${CMAKE_C_COMPILER}
            -P ${_driver}
    )
    set_tests_properties(cmake.${_name} PROPERTIES
        LABELS cmake
        TIMEOUT 600
    )
endfunction()

foreach(_module IN LISTS _scripts)
    qmtest_cmake_add(${_module} ${CMAKE_CURRENT_SOURCE_DIR}/${_module}.cmake)
endforeach()

foreach(_module IN LISTS _configured_projects)
    qmtest_cmake_add(${_module} ${CMAKE_CURRENT_SOURCE_DIR}/testing/configure.cmake)
endforeach()

foreach(_module IN LISTS _built_projects)
    qmtest_cmake_add(${_module} ${CMAKE_CURRENT_SOURCE_DIR}/testing/build.cmake)
endforeach()
