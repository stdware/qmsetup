# Tests for the CMake layer, the qm_* functions in cmake/.
#
# There are two shapes of test here, and the layout says which is which.
#
# A script test is a `cmake -P` run. Nothing it checks needs a project to exist,
# so nothing configures or builds, and a failure names the check rather than
# leaving a configure log to read through. These mirror what they test:
#
#   cmake/QMSetupAPI.cmake          QMSetupAPI/test_*.cmake
#   cmake/modules/Preprocess.cmake  modules/Preprocess/test_*.cmake
#
# A project test is a whole project, under projects/, with a run.cmake beside it
# that drives it. These are for the functions that work on targets or on an
# installed tree, which no script can reach. They are not mirrored, because each
# of them covers functions from more than one of the files above.
#
# Not covered:
#
#   qm_compiler_* is left alone on purpose. Every one of them is a list of
#   compiler flags chosen per compiler, so a test could only repeat the list
#   back, which says nothing about whether the flags are the right ones. What
#   would catch a mistake there is compiling with them, which is a different
#   kind of test from any of these.
#
#   Anything wanting Qt, protobuf or doxygen installed, and the standalone
#   scripts under cmake/scripts.

set(_modules
    QMSetupAPI/test_version
    QMSetupAPI/test_values
    QMSetupAPI/test_subdirs
    modules/Filesystem/test_directories
    modules/Preprocess/test_definitions
    modules/Preprocess/test_generate_config
    modules/Preprocess/test_sync_include
    modules/Preprocess/test_build_info
)

foreach(_module IN LISTS _modules)
    # The path is the name, so a failure says which file to open.
    string(REPLACE "/" "." _name ${_module})

    add_test(NAME cmake.${_name}
        COMMAND ${CMAKE_COMMAND}
            -DQMSETUP_API=${QMSETUP_PROJECT_ROOT}/cmake/QMSetupAPI.cmake
            -DQMCORECMD=$<TARGET_FILE:qmcorecmd>
            # Passed in rather than found relative to the test, which would have
            # every file counting how deep it sits.
            -DQMTEST_HARNESS=${CMAKE_CURRENT_SOURCE_DIR}/harness.cmake
            -DQMTEST_WORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/${_module}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/${_module}.cmake
    )
    set_tests_properties(cmake.${_name} PROPERTIES
        LABELS cmake
        TIMEOUT 120
    )
endforeach()

# The functions that work on targets. This configures a project of its own
# rather than running a script, so it costs more than all the script tests
# together, and it is kept apart from them.
add_test(NAME cmake.projects.targets
    COMMAND ${CMAKE_COMMAND}
        -DQMSETUP_API=${QMSETUP_PROJECT_ROOT}/cmake/QMSetupAPI.cmake
        -DQMCORECMD=$<TARGET_FILE:qmcorecmd>
        -DQMTEST_HARNESS=${CMAKE_CURRENT_SOURCE_DIR}/harness.cmake
        -DQMTEST_PROJECT=${CMAKE_CURRENT_SOURCE_DIR}/projects/targets
        -DQMTEST_PROJECT_BUILD=${CMAKE_CURRENT_BINARY_DIR}/targets-build
        -DQMTEST_GENERATOR=${CMAKE_GENERATOR}
        -DQMTEST_C_COMPILER=${CMAKE_C_COMPILER}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/projects/targets/run.cmake
)
set_tests_properties(cmake.projects.targets PROPERTIES
    LABELS cmake
    TIMEOUT 300
)

# qm_basic_install and qm_deploy_directory both work by adding install rules,
# and an install rule that is never run says nothing, so this one is built and
# installed for real. It is the slowest test here by a long way.
add_test(NAME cmake.projects.install
    COMMAND ${CMAKE_COMMAND}
        -DQMSETUP_API=${QMSETUP_PROJECT_ROOT}/cmake/QMSetupAPI.cmake
        -DQMCORECMD=$<TARGET_FILE:qmcorecmd>
        -DQMTEST_HARNESS=${CMAKE_CURRENT_SOURCE_DIR}/harness.cmake
        -DQMTEST_PROJECT=${CMAKE_CURRENT_SOURCE_DIR}/projects/install
        -DQMTEST_PROJECT_BUILD=${CMAKE_CURRENT_BINARY_DIR}/install-build
        -DQMTEST_INSTALL_PREFIX=${CMAKE_CURRENT_BINARY_DIR}/install-prefix
        -DQMTEST_GENERATOR=${CMAKE_GENERATOR}
        -DQMTEST_C_COMPILER=${CMAKE_C_COMPILER}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/projects/install/run.cmake
)
set_tests_properties(cmake.projects.install PROPERTIES
    LABELS cmake
    TIMEOUT 600
)
