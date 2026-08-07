# Tests for the CMake layer, the qm_* functions in cmake/.
#
# Each module is a script run with `cmake -P`. Nothing they check needs a
# project to exist, so nothing configures or builds, and a failure names the
# check rather than leaving a configure log to read through.
#
# What that leaves out is the target, source and directory property scopes, and
# everything that wants Qt, protobuf or doxygen to be installed.

set(_modules
    test_version
    test_values
    test_definitions
    test_generate_config
)

foreach(_module IN LISTS _modules)
    add_test(NAME cmake.${_module}
        COMMAND ${CMAKE_COMMAND}
            -DQMSETUP_API=${QMSETUP_PROJECT_ROOT}/cmake/QMSetupAPI.cmake
            -DQMCORECMD=$<TARGET_FILE:qmcorecmd>
            -DQMTEST_WORK_DIR=${CMAKE_CURRENT_BINARY_DIR}/${_module}
            -P ${CMAKE_CURRENT_SOURCE_DIR}/${_module}.cmake
    )
    set_tests_properties(cmake.${_module} PROPERTIES
        LABELS cmake
        TIMEOUT 120
    )
endforeach()
