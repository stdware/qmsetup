include_guard(DIRECTORY)

#[[
Add a resources copying command for whole project.

    qtmediate_add_copy_command(<target>
        [CUSTOM_TARGET <target>]

        SOURCES <file/dir...>
        DESTINATION <dir>
    )
]] #
function(qtmediate_add_copy_command _target)
    set(options)
    set(oneValueArgs CUSTOM_TARGET DESTINATION)
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool_target qtmediateCM::corecmd)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_add_copy_command: tool \"corecmd\" not found.")
    endif()

    get_target_property(_tool ${_tool_target} LOCATION)

    if(NOT FUNC_SOURCES)
        message(FATAL_ERROR "qtmediate_add_copy_command: SOURCES not specified.")
    endif()

    set(_dest)

    if(NOT TARGET ${_target})
        add_custom_target(${_target})
    endif()

    get_target_property(_type ${_target} TYPE)

    if(FUNC_DESTINATION)
        if(IS_ABSOLUTE ${FUNC_DESTINATION})
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

    foreach(_item ${FUNC_SOURCES})
        get_filename_component(_full_path ${_item} ABSOLUTE)

        # if(NOT EXISTS ${_full_path})
        # message(FATAL_ERROR "qtmediate_add_copy_command: \"${_item}\" doesn't exist.")
        # endif()
        set(_args ${_tool} cpdir ${_full_path} ${_dest})

        if(${_item} MATCHES ".+[/|\\\\]")
            list(APPEND _args "-c")
        endif()

        # Add a post target to handle unexpected delete
        add_custom_command(TARGET ${_deploy_target} POST_BUILD
            COMMAND ${_args}
        )
    endforeach()
endfunction()

#[[
Add a resources copying command for whole project.

    qtmediate_parse_copy_args(<args> <RESULT> <ERROR>)

    args:   SRC <files...> DEST <dir1>
            SRC <files...> DEST <dir2> ...
]] #
function(qtmediate_parse_copy_args _args _result _error)
    # State Machine
    set(_src)
    set(_dest)
    set(_status NONE) # NONE, SRC, DEST
    set(_count 0)

    set(_list)

    foreach(_item ${_args})
        if(${_item} STREQUAL SRC)
            if(${_status} STREQUAL NONE)
                set(_src)
                set(_status SRC)
            elseif(${_status} STREQUAL DEST)
                set(${_error} "missing directory name after DEST!" PARENT_SCOPE)
                return()
            else()
                set(${_error} "missing source files after SRC!" PARENT_SCOPE)
                return()
            endif()
        elseif(${_item} STREQUAL DEST)
            if(${_status} STREQUAL SRC)
                set(_status DEST)
            elseif(${_status} STREQUAL DEST)
                set(${_error} "missing directory name after DEST!" PARENT_SCOPE)
                return()
            else()
                set(${_error} "no source files specified for DEST!" PARENT_SCOPE)
                return()
            endif()
        else()
            if(${_status} STREQUAL NONE)
                set(${_error} "missing SRC or DEST token!" PARENT_SCOPE)
                return()
            elseif(${_status} STREQUAL DEST)
                if(NOT _src)
                    set(${_error} "no source files specified for DEST!" PARENT_SCOPE)
                    return()
                endif()

                set(_status NONE)
                math(EXPR _count "${_count} + 1")

                string(JOIN "\\;" _src_str ${_src})
                list(APPEND _list "${_src_str}\\;${_item}")
            else()
                get_filename_component(_path ${_item} ABSOLUTE)
                list(APPEND _src ${_path})
            endif()
        endif()
    endforeach()

    if(${_status} STREQUAL SRC)
        set(${_error} "missing DEST after source files!" PARENT_SCOPE)
        return()
    elseif(${_status} STREQUAL DEST)
        set(${_error} "missing directory name after DEST!" PARENT_SCOPE)
        return()
    elseif(${_count} STREQUAL 0)
        set(${_error} "no files specified!" PARENT_SCOPE)
        return()
    endif()

    set(${_result} "${_list}" PARENT_SCOPE)
endfunction()