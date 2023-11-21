include_guard(DIRECTORY)

#[[
    Record searching paths for Windows Executables.

    qtmediate_win_record_deps(_target)
]] #
function(qtmediate_win_record_deps _target)
    set(_paths)
    get_target_property(_link_libraries ${_target} LINK_LIBRARIES)

    foreach(_item ${_link_libraries})
        if(NOT TARGET ${_item})
            continue()
        endif()

        get_target_property(_imported ${_item} IMPORTED)

        if(_imported)
            get_target_property(_path ${_item} LOCATION)

            if(NOT _path OR NOT ${_path} MATCHES "\\.dll$")
                continue()
            endif()

            set(_path "$<TARGET_PROPERTY:${_item},LOCATION_$<CONFIG>>")
        else()
            get_target_property(_type ${_item} TYPE)

            if(NOT ${_type} MATCHES "SHARED_LIBRARY")
                continue()
            endif()

            set(_path "$<TARGET_FILE:${_item}>")
        endif()

        list(APPEND _paths ${_path})
    endforeach()

    if(NOT _paths)
        return()
    endif()

    set(_deps_file "${CMAKE_CURRENT_BINARY_DIR}/${_target}_deps_$<CONFIG>.txt")
    file(GENERATE OUTPUT ${_deps_file} CONTENT "$<JOIN:${_paths},\n>")
    set_target_properties(${_target} PROPERTIES DEPENDENCIES_RECORD_FILE ${_deps_file})
endfunction()

#[[
    Automatically copy dependencies for Windows Executables after build.

    qtmediate_win_applocal_deps(_target
        [DEPLOY_TARGET <target>]
        [EXTRA_SEARCHING_PATHS <paths...>]
        [OUTPUT_DIR <dir>]
    )
]] #
function(qtmediate_win_applocal_deps _target)
    if(NOT WIN32)
        return()
    endif()

    set(options)
    set(oneValueArgs TARGET DEPLOY_TARGET OUTPUT_DIR)
    set(multiValueArgs EXTRA_SEARCHING_PATHS)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool_target qtmediateCM::corecmd)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_win_applocal_deps: tool \"corecmd\" not found.")
    endif()

    get_target_property(_tool ${_tool_target} LOCATION)

    # Get output directory and deploy target
    set(_out_dir)
    set(_deploy_target)

    if(FUNC_DEPLOY_TARGET)
        set(_deploy_target ${FUNC_DEPLOY_TARGET})

        if(NOT TARGET ${_deploy_target})
            add_custom_target(${_deploy_target})
        endif()
    else()
        set(_deploy_target ${_target})
    endif()

    if(FUNC_OUTPUT_DIR)
        set(_out_dir ${FUNC_OUTPUT_DIR})
    else()
        set(_out_dir "$<TARGET_FILE_DIR:${_target}>")
    endif()

    if(NOT _out_dir)
        message(FATAL_ERROR "qtmediate_win_applocal_deps: cannot determine output directory.")
    endif()

    # Get record files
    set(_path_files)
    _qtmeidate_win_get_all_record_files(_path_files ${_target})

    # Prepare command
    set(_args)

    foreach(_item ${FUNC_EXTRA_SEARCHING_PATHS})
        list(APPEND _args "-L${_item}")
    endforeach()

    foreach(_item ${_path_files})
        list(APPEND _args "-@${_item}")
    endforeach()

    list(APPEND _args "$<TARGET_FILE:${_target}>")

    add_custom_command(TARGET ${_deploy_target} POST_BUILD
        COMMAND ${_tool} deploy ${_args}
        WORKING_DIRECTORY ${_out_dir}
    )
endfunction()

#[[
    Add deploy command when install project.

    qtmediate_deploy_directory(_install_dir
        [FORCE] [STANDARD] [VERBOSE]
        [LIBRARY_DIR <dir>]
        [EXTRA_PLUGIN_PATHS <path>...]
        
        [PLUGINS <plugin>...]
        [PLUGIN_DIR <dir>]

        [QML <qml>...]
        [QML_DIR <dir>]

        [WIN_TARGETS <target>...]
        [WIN_SEARCHING_PATHS <path>...]

        [COMMENT <comment]
    )
]] #
function(qtmediate_deploy_directory _install_dir)
    set(options FORCE STANDARD VERBOSE)
    set(oneValueArgs LIBRARY_DIR PLUGIN_DIR QML_DIR COMMENT)
    set(multiValueArgs EXTRA_PLUGIN_PATHS PLUGINS QML WIN_TARGETS WIN_SEARCHING_PATHS)

    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool_target qtmediateCM::corecmd)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_deploy_directory: tool \"corecmd\" not found.")
    endif()

    get_target_property(_tool ${_tool_target} LOCATION)

    # Get qmake
    if((FUNC_PLUGINS OR FUNC_QML) AND NOT DEFINED QT_QMAKE_EXECUTABLE)
        if(TARGET Qt${QT_VERSION_MAJOR}::qmake)
            get_target_property(QT_QMAKE_EXECUTABLE Qt${QT_VERSION_MAJOR}::qmake IMPORTED_LOCATION)
        elseif((FUNC_PLUGINS AND NOT FUNC_EXTRA_PLUGIN_PATHS) OR FUNC_QML)
            message(FATAL_ERROR "qtmediate_deploy_directory: qmake not defined. Add find_package(Qt5 COMPONENTS Core) to CMake to enable.")
        endif()
    endif()

    if(WIN32)
        set(_default_lib_dir bin)
    else()
        set(_default_lib_dir lib)
    endif()

    # Set values
    qtmediate_set_value(_lib_dir FUNC_LIBRARY_DIR "${_install_dir}/${_default_lib_dir}")
    qtmediate_set_value(_plugin_dir FUNC_PLUGIN_DIR "${_install_dir}/plugins")
    qtmediate_set_value(_qml_dir FUNC_QML_DIR "${_install_dir}/qml")

    get_filename_component(_lib_dir ${_lib_dir} ABSOLUTE BASE_DIR ${_install_dir})
    get_filename_component(_plugin_dir ${_plugin_dir} ABSOLUTE BASE_DIR ${_install_dir})

    # Prepare commands
    set(_args
        -i "${_install_dir}"
        -p "${_plugin_dir}"
        -l "${_lib_dir}"
        -o "${_qml_dir}"
        -m "${_tool}"
    )

    if(QT_QMAKE_EXECUTABLE)
        list(APPEND _args -q "${QT_QMAKE_EXECUTABLE}")
    endif()

    # Add Qt plugins
    foreach(_item IN LISTS FUNC_PLUGINS)
        list(APPEND _args "-t" "${_item}")
    endforeach()

    # Add QML modules
    foreach(_item IN LISTS FUNC_QML)
        list(APPEND _args "-Q" "${_item}")
    endforeach()

    # Add extra plugin paths
    foreach(_item IN LISTS FUNC_EXTRA_PLUGIN_PATHS)
        list(APPEND _args "-P" "${_item}")
    endforeach()

    if(WIN32)
        set(_path_files)

        if(FUNC_WIN_TARGETS)
            _qtmeidate_win_get_all_record_files(_path_files ${FUNC_WIN_TARGETS})
        endif()

        foreach(_item ${FUNC_WIN_SEARCHING_PATHS})
            list(APPEND _args -L "${_item}")
        endforeach()

        foreach(_item ${_path_files})
            list(APPEND _args -@ "${_item}")
        endforeach()

        set(_script_quoted "cmd /c \"${QTMEDIATE_MODULES_DIR}/scripts/windeps.bat\"")
    else()
        set(_script_quoted "bash \"${QTMEDIATE_MODULES_DIR}/scripts/unixdeps.sh\"")
    endif()

    # Add options
    if(FUNC_FORCE)
        list(APPEND _args "-f")
    endif()

    if(FUNC_STANDARD)
        list(APPEND _args "-s")
    endif()

    if(FUNC_VERBOSE)
        list(APPEND _args "-V")
    endif()

    set(_args_quoted)

    foreach(_item ${_args})
        set(_args_quoted "${_args_quoted}\"${_item}\" ")
    endforeach()

    set(_comment_code)

    if(FUNC_COMMENT)
        set(_comment_code "message(STATUS \"${FUNC_COMMENT}\")")
    endif()

    # Add install command
    install(CODE "
        ${_comment_code}
        execute_process(
            COMMAND ${_script_quoted} ${_args_quoted}
            WORKING_DIRECTORY \"${_install_dir}\"
            COMMAND_ERROR_IS_FATAL ANY
        )
    ")
endfunction()

function(_qtmeidate_win_get_all_record_files _out)
    # Get searching paths
    macro(get_recursive_dynamic_dependencies _current_target _result)
        get_target_property(_deps ${_current_target} LINK_LIBRARIES)

        if(_deps)
            foreach(_dep ${_deps})
                get_target_property(_type ${_dep} TYPE)

                if(${_type} STREQUAL "SHARED_LIBRARY")
                    list(APPEND ${_result} ${_dep})
                endif()

                get_recursive_dynamic_dependencies(${_dep} ${_result})
            endforeach()
        endif()
    endmacro()

    set(_visited_targets ${ARGN})

    foreach(_target ${ARGN})
        set(_all_deps)
        get_recursive_dynamic_dependencies(${_target} _all_deps)

        foreach(_cur_dep ${_all_deps})
            if(${_cur_dep} IN_LIST _visited_targets)
                continue()
            endif()

            list(APPEND _visited_targets ${_cur_dep})
        endforeach()
    endforeach()

    set(_path_files)

    foreach(_target ${_visited_targets})
        # Add file
        get_target_property(_file ${_target} DEPENDENCIES_RECORD_FILE)

        if(NOT _file)
            continue()
        endif()

        list(APPEND _path_files ${_file})
    endforeach()

    set(${_out} ${_path_files} PARENT_SCOPE)
endfunction()