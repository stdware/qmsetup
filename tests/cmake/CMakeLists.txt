# Tests for the CMake layer, the qm_* functions in cmake/.
#
# The layout under here follows the one it tests, so that the tests for a module
# are where you would look for them:
#
#   cmake/QMSetupAPI.cmake          QMSetupAPI/test_*.cmake
#   cmake/modules/Preprocess.cmake  modules/Preprocess/test_*.cmake
#
# Each module is a script run with `cmake -P`. Nothing they check needs a
# project to exist, so nothing configures or builds, and a failure names the
# check rather than leaving a configure log to read through.
#
# What that leaves out is the target and directory property scopes, and
# everything that wants Qt, protobuf or doxygen to be installed.

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

# The functions that work on targets, which need a project to live in. This one
# configures a project of its own rather than running a script, so it costs more
# than all the others together and is kept apart from them.
add_test(NAME cmake.project
    COMMAND ${CMAKE_COMMAND}
        -DQMSETUP_API=${QMSETUP_PROJECT_ROOT}/cmake/QMSetupAPI.cmake
        -DQMCORECMD=$<TARGET_FILE:qmcorecmd>
        -DQMTEST_HARNESS=${CMAKE_CURRENT_SOURCE_DIR}/harness.cmake
        -DQMTEST_PROJECT=${CMAKE_CURRENT_SOURCE_DIR}/project
        -DQMTEST_PROJECT_BUILD=${CMAKE_CURRENT_BINARY_DIR}/project-build
        -DQMTEST_GENERATOR=${CMAKE_GENERATOR}
        -DQMTEST_C_COMPILER=${CMAKE_C_COMPILER}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/configure_project.cmake
)
set_tests_properties(cmake.project PROPERTIES
    LABELS cmake
    TIMEOUT 300
)
