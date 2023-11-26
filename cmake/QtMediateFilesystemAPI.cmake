include_guard(DIRECTORY)

#[[
    Add a resources copying command for whole project.

    qtmediate_add_copy_command(<target>
        [CUSTOM_TARGET <target>]
        [FORCE] [VERBOSE]

        SOURCES <file/dir...>
        DESTINATION <dir>
    )
]] #
function(qtmediate_add_copy_command _target)
    set(options FORCE VERBOSE)
    set(oneValueArgs CUSTOM_TARGET DESTINATION)
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool)
    _qtmediate_get_core_tool(_tool "qtmediate_add_copy_command")

    if(NOT FUNC_SOURCES)
        message(FATAL_ERROR "qtmediate_add_copy_command: SOURCES not specified.")
    endif()

    set(_dest)

    if(NOT TARGET ${_target})
        add_custom_target(${_target})
    endif()

    get_target_property(_type ${_target} TYPE)

    if(FUNC_DESTINATION)
        # Determine destination
        qtmediate_has_genex(_has_genex ${FUNC_DESTINATION})

        if(NOT _has_genex)
            if(IS_ABSOLUTE ${FUNC_DESTINATION})
                set(_dest ${FUNC_DESTINATION})
            elseif(NOT ${_type} STREQUAL "UTILITY")
                set(_dest "$<TARGET_FILE_DIR:${_target}>/${FUNC_DESTINATION}")
            endif()
        endif()
    else()
        if(NOT ${_type} STREQUAL "UTILITY")
            set(_dest "$<TARGET_FILE_DIR:${_target}>")
        endif()
    endif()

    if(NOT _dest)
        message(FATAL_ERROR "qtmediate_add_copy_command: destination cannot be determined.")
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
        COMMAND ${_tool} copy ${_extra_args} ${FUNC_SOURCES} ${_dest}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )
endfunction()
