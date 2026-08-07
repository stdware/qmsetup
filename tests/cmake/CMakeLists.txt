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
