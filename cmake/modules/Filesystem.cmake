include_guard(DIRECTORY)

#[[
    Warning: This module depends on `QMSetupAPI.cmake`.
]] #
if(NOT DEFINED QMSETUP_MODULES_DIR)
    message(FATAL_ERROR "QMSETUP_MODULES_DIR not defined. Add find_package(qmsetup) to CMake first.")
endif()

#[[
    Add a resources copying command for whole project.

    qm_add_copy_command(<target>
        [CUSTOM_TARGET <target>]
        [FORCE] [VERBOSE]

        SOURCES <file/dir...>
        DESTINATION <dir>
    )
]] #
function(qm_add_copy_command _target)
    set(options FORCE VERBOSE)
    set(oneValueArgs CUSTOM_TARGET DESTINATION)
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Check tool
    if(NOT QMSETUP_CORECMD_EXECUTABLE)
        message(FATAL_ERROR "qm_add_copy_command: corecmd tool not found.")
    endif()

    if(NOT FUNC_SOURCES)
        message(FATAL_ERROR "qm_add_copy_command: SOURCES not specified.")
    endif()

    if(NOT TARGET ${_target})
        add_custom_target(${_target})
    endif()

    get_target_property(_type ${_target} TYPE)

    set(_dest)

    if(FUNC_DESTINATION)
        qm_has_genex(_has_genex ${FUNC_DESTINATION})

        if(_has_genex OR IS_ABSOLUTE ${FUNC_DESTINATION})
            set(_dest ${FUNC_DESTINATION})
        elseif(NOT ${_type} STREQUAL "UTILITY")
            set(_dest "$<TARGET_FILE_DIR:${_target}>/${FUNC_DESTINATION}")
        endif()
    else()
        if(NOT ${_type} STREQUAL "UTILITY")
            set(_dest "$<TARGET_FILE_DIR:${_target}>")
        endif()
    endif()

    if(NOT _dest)
        message(FATAL_ERROR "qm_add_copy_command: destination cannot be determined.")
    endif()

    set(_deploy_target)

    if(FUNC_CUSTOM_TARGET)
        set(_deploy_target ${FUNC_CUSTOM_TARGET})

        if(NOT TARGET ${_deploy_target})
            add_custom_target(${_deploy_target})
        endif()
    else()
        set(_deploy_target ${_target})
    endif()

    set(_extra_args)

    if(FUNC_FORCE)
        list(APPEND _extra_args -f)
    endif()

    if(FUNC_VERBOSE)
        list(APPEND _extra_args -V)
    endif()

    add_custom_command(TARGET ${_deploy_target} POST_BUILD
        COMMAND ${QMSETUP_CORECMD_EXECUTABLE} copy ${_extra_args} ${FUNC_SOURCES} ${_dest}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
endfunction()
