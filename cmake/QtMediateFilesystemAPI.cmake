include_guard(DIRECTORY)

#[[
Add a resources copying command for whole project.

    qtmediate_add_copy_command(<target>
        SOURCES <file/dir...>
        DESTINATION <dir>
    )
]] #
function(qtmediate_add_copy_command _target)
    set(options)
    set(oneValueArgs DESTINATION)
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT FUNC_SOURCES)
        message(FATAL_ERROR "qtmediate_deploy_directory: SOURCES not specified.")
    endif()

    set(_dest)

    if(NOT TARGET ${_target})
        add_custom_target(${_target})
    endif()

    if(FUNC_DESTINATION)
        set(_dest ${FUNC_DESTINATION})
    else()
        get_target_property(_type ${_target} TYPE)

        if(NOT ${_type} STREQUAL "UTILITY")
            set(_dest "$<TARGET_FILE_DIR:${_target}>")
        endif()
    endif()

    if(NOT ${_dest})
        message(FATAL_ERROR "qtmediate_deploy_directory: destination cannot be determined.")
    endif()

    foreach(_item ${FUNC_SOURCES})
        get_filename_component(_full_path ${_item} ABSOLUTE)

        set(_args ${_tool} cpdir ${_item} ${_dest})

        if(${_item} MATCHES ".+[/|\\\\]")
            list(APPEND _args "-c")
        endif()

        # Add a post target to handle unexpected delete
        add_custom_command(TARGET ${_target} POST_BUILD
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