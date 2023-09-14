if(NOT DEFINED QTMEDIATE_CMAKE_MODULES_DIR)
    set(QTMEDIATE_CMAKE_MODULES_DIR ${CMAKE_CURRENT_LIST_DIR})
endif()

#[[
Attach windows RC file to a target.

    qtmediate_add_winrc(<target>
        [NAME           name] 
        [VERSION        version] 
        [DESCRIPTION    desc]
        [COPYRIGHT      copyright]
        [ICON           ico]
        [OUTPUT         output]
    )
]] #
function(qtmediate_add_winrc _target)
    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION COPYRIGHT ICON OUTPUT)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    _qtmediate_set_value(_version_temp PROJECT_VERSION "0.0.0.0")
    _qtmediate_set_value(_out_path FUNC_OUTOUT "${CMAKE_CURRENT_BINARY_DIR}/${_name}_res.rc")

    _qtmediate_set_value(_name FUNC_NAME ${PROJECT_NAME})
    _qtmediate_set_value(_version FUNC_VERSION ${_version_temp})
    _qtmediate_set_value(_desc FUNC_DESCRIPTION ${_name})
    _qtmediate_set_value(_copyright FUNC_COPYRIGHT ${_name})

    _qtmediate_parse_version(_ver ${_version})
    set(RC_VERSION ${_ver_1},${_ver_2},${_ver_3},${_ver_4})

    set(RC_APPLICATION_NAME ${_name})
    set(RC_VERSION_STRING ${_version})
    set(RC_DESCRIPTION ${_desc})
    set(RC_COPYRIGHT ${_copyright})

    if(NOT FUNC_ICON)
        set(RC_ICON_COMMENT "//")
        set(RC_ICON_PATH)
    else()
        set(RC_ICON_PATH ${FUNC_ICON})
    endif()

    configure_file("${QTMEDIATE_CMAKE_MODULES_DIR}/win/WinResource.rc.in" ${_out_path} @ONLY)
    target_sources(${RC_PROJECT_NAME} PRIVATE ${_out_path})
endfunction()

#[[
Attach windows manifest file to a target.

    qtmediate_add_winrc(<target>
        [NAME           name] 
        [VERSION        version] 
        [DESCRIPTION    desc]
        [OUTPUT         output]
    )
]] #
function(qtmediate_add_manifest _target)
    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION OUTPUT)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    _qtmediate_set_value(_version_temp PROJECT_VERSION "0.0.0.0")
    _qtmediate_set_value(_out_path FUNC_OUTOUT "${CMAKE_CURRENT_BINARY_DIR}/${RC_PROJECT_NAME}_manifest.manifest")

    _qtmediate_set_value(_name FUNC_NAME ${PROJECT_NAME})
    _qtmediate_set_value(_version FUNC_VERSION ${_version_temp})
    _qtmediate_set_value(_desc FUNC_DESCRIPTION ${_name})

    set(MANIFEST_IDENTIFIER ${_name})
    set(MANIFEST_VERSION ${_version})
    set(MANIFEST_DESCRIPTION ${_desc})

    configure_file("${QTMEDIATE_CMAKE_MODULES_DIR}/win/WinManifest.nanifest.in" ${_out_path} @ONLY)
    target_sources(${RC_PROJECT_NAME} PRIVATE ${_out_path})
endfunction()

#[[
Add Doxygen generate target.

    qtmediate_setup_doxygen(<target>
        [NAME           <name>]
        [VERSION        <version>]
        [DESCRIPTION    <desc>]
        [LOGO           <file>]
        [MDFILE         <file>]
        [OUTPUT_DIR     <dir>]
        [INSTALL_DIR    <dir>]

        [TAGFILES           <file> ...]
        [GENERATE_TAGFILE   <file>]
        
        [INPUT                  <file> ...]
        [INCLUDE_DIRECTORIES    <dir> ...]
        [COMPILE_DEFINITIONS    <NAME=VALUE> ...]
        [TARGETS                <target> ...]
        [ENVIRONMENT_EXPORTS    <key> ...]
        [NO_EXPAND_MACROS       <macro> ...]
        [DEPENDS                <dependency> ...]
    )
]] #
function(qtmediate_setup_doxygen _target)
    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION LOGO MDFILE OUTPUT_DIR INSTALL_DIR GENERATE_TAGFILE)
    set(multiValueArgs INPUT TAGFILES INCLUDE_DIRECTORIES COMPILE_DEFINITIONS TARGETS ENVIRONMENT_EXPORTS
        NO_EXPAND_MACROS DEPENDS
    )
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT DOXYGEN_EXECUTABLE)
        message(FATAL_ERROR "qtmediate_setup_doxygen: doxygen executable not defined!")
    endif()

    set(DOXYGEN_FILE_DIR ${QTMEDIATE_CMAKE_MODULES_DIR}/doxygen)

    _qtmediate_set_value(_name FUNC_NAME "${PROJECT_NAME}")
    _qtmediate_set_value(_version FUNC_VERSION "${PROJECT_VERSION}")
    _qtmediate_set_value(_desc FUNC_DESCRIPTION "${PROJECT_DESCRIPTION}")
    _qtmediate_set_value(_logo FUNC_LOGO "")
    _qtmediate_set_value(_mdfile FUNC_MDFILE "")
    _qtmediate_set_value(_tagfile FUNC_GENERATE_TAGFILE "")

    if(_desc STREQUAL "")
        set(${_desc} "${_name}")
    endif()

    set(_sep " \\\n    ")

    # Generate include file
    set(_doxy_includes "${CMAKE_CURRENT_BINARY_DIR}/cmake/doxygen_${_target}.inc")
    set(_doxy_output_dir "${CMAKE_CURRENT_BINARY_DIR}/doxygen_${_target}")

    set(_input "")
    set(_tagfiles "")
    set(_includes "")
    set(_defines "")
    set(_no_expand "")

    if(FUNC_INPUT)
        set(_input "INPUT = $<JOIN:${FUNC_INPUT},${_sep}>\n\n")
    else()
        set(_input "INPUT = \n\n")
    endif()

    if(FUNC_TAGFILES)
        set(_tagfiles "TAGFILES = $<JOIN:${FUNC_TAGFILES},${_sep}>\n\n")
    else()
        set(_tagfiles "TAGFILES = \n\n")
    endif()

    if(FUNC_INCLUDE_DIRECTORIES)
        set(_includes "INCLUDE_PATH = $<JOIN:${FUNC_INCLUDE_DIRECTORIES},${_sep}>\n\n")
    else()
        set(_includes "INCLUDE_PATH = \n\n")
    endif()

    if(FUNC_COMPILE_DEFINITIONS)
        set(_defines "PREDEFINED = $<JOIN:${FUNC_COMPILE_DEFINITIONS},${_sep}>\n\n")
    else()
        set(_defines "PREDEFINED = \n\n")
    endif()

    if(FUNC_NO_EXPAND_MACROS)
        set(_temp_list)

        foreach(_item ${FUNC_NO_EXPAND_MACROS})
            list(APPEND _temp_list "${_item}=")
        endforeach()

        set(_no_expand "PREDEFINED += $<JOIN:${_temp_list},${_sep}>\n\n")
        unset(_temp_list)
    endif()

    # Extra
    set(_extra_arguments)

    if(FUNC_TARGETS)
        foreach(item ${FUNC_TARGETS})
            set(_extra_arguments
                "${_extra_arguments}INCLUDE_PATH += $<JOIN:$<TARGET_PROPERTY:${item},INCLUDE_DIRECTORIES>,${_sep}>\n\n")
            set(_extra_arguments
                "${_extra_arguments}PREDEFINED += $<JOIN:$<TARGET_PROPERTY:${item},COMPILE_DEFINITIONS>,${_sep}>\n\n")
        endforeach()
    endif()

    if(FUNC_OUTPUT_DIR)
        set(_doxy_output_dir ${FUNC_OUTPUT_DIR})
    endif()

    if(_mdfile)
        set(_extra_arguments "${_extra_arguments}INPUT += ${_mdfile}\n\n")
    endif()

    file(GENERATE
        OUTPUT "${_doxy_includes}"
        CONTENT "${_input}${_tagfiles}${_includes}${_defines}${_extra_arguments}${_no_expand}"
    )

    set(_env)

    foreach(_export ${FUNC_ENVIRONMENT_EXPORTS})
        if(NOT DEFINED "${_export}")
            message(FATAL_ERROR "qtmediate_setup_doxygen: ${_export} is not known when trying to export it.")
        endif()

        list(APPEND _env "${_export}=${${_export}}")
    endforeach()

    list(APPEND _env "DOXY_FILE_DIR=${DOXYGEN_FILE_DIR}")
    list(APPEND _env "DOXY_INCLUDE_FILE=${_doxy_includes}")

    list(APPEND _env "DOXY_PROJECT_NAME=${_name}")
    list(APPEND _env "DOXY_PROJECT_VERSION=${_version}")
    list(APPEND _env "DOXY_PROJECT_BRIEF=${_desc}")
    list(APPEND _env "DOXY_PROJECT_LOGO=${_logo}")
    list(APPEND _env "DOXY_MAINPAGE_MD_FILE=${_mdfile}")

    set(_build_command "${CMAKE_COMMAND}" "-E" "env"
        ${_env}
        "DOXY_OUTPUT_DIR=${_doxy_output_dir}"
        "DOXY_GENERATE_TAGFILE=${_tagfile}"
        "${DOXYGEN_EXECUTABLE}"
        "${DOXYGEN_FILE_DIR}/Doxyfile"
    )

    if(FUNC_DEPENDS)
        set(_dependencies DEPENDS ${FUNC_DEPENDS})
    endif()

    if(_tagfile)
        get_filename_component(_tagfile_dir ${_tagfile} ABSOLUTE)
        get_filename_component(_tagfile_dir ${_tagfile_dir} DIRECTORY)
        set(_make_tagfile_dir_cmd COMMAND ${CMAKE_COMMAND} -E make_directory ${_tagfile_dir})
    else()
        set(_make_tagfile_dir_cmd)
    endif()

    add_custom_target(${_target}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${_doxy_output_dir}
        ${_make_tagfile_dir_cmd}
        COMMAND ${_build_command}
        COMMENT "Build HTML documentation"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        VERBATIM
        ${_dependencies}
    )

    if(FUNC_INSTALL_DIR AND CMAKE_INSTALL_PREFIX)
        get_filename_component(_install_dir ${FUNC_INSTALL_DIR} ABSOLUTE BASE_DIR ${CMAKE_INSTALL_PREFIX})

        if(_tagfile)
            get_filename_component(_name ${_tagfile} NAME)
            set(_install_tagfile ${_install_dir}/${_name})
        else()
            set(_install_tagfile)
        endif()

        set(_install_command "${CMAKE_COMMAND}" "-E" "env"
            ${_env}
            "DOXY_OUTPUT_DIR=${_install_dir}"
            "DOXY_GENERATE_TAGFILE=${_install_tagfile}"
            "${DOXYGEN_EXECUTABLE}"
            "${DOXYGEN_FILE_DIR}/Doxyfile"
        )

        set(_install_command_quoted)

        foreach(_item ${_install_command})
            set(_install_command_quoted "${_install_command_quoted}\"${_item}\" ")
        endforeach()

        install(CODE "
            message(STATUS \"Install HTML documentation\")
            file(MAKE_DIRECTORY \"${_install_dir}\")
            execute_process(
                COMMAND ${_install_command_quoted}
                WORKING_DIRECTORY \"${CMAKE_CURRENT_SOURCE_DIR}\"
            )
        ")
    endif()
endfunction()

#[[
    Generate reference include directories.

    qtmediate_gen_include(<src> <dest>
        [CLEAN] [INSTALL_DIR]
    )
#]]
function(qtmediate_gen_include _src_dir _dest_dir)
    set(options COPY CLEAN)
    set(oneValueArgs INSTALL_DIR)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT IS_ABSOLUTE ${_src_dir})
        get_filename_component(_src_dir ${_src_dir} ABSOLUTE)
    else()
        string(REPLACE "\\" "/" _src_dir ${_src_dir})
    endif()

    if(NOT IS_ABSOLUTE ${_dest_dir})
        get_filename_component(_dest_dir ${_dest_dir} ABSOLUTE)
    else()
        string(REPLACE "\\" "/" _dest_dir ${_dest_dir})
    endif()

    if(IS_DIRECTORY ${_src_dir})
        file(GLOB_RECURSE header_files ${_src_dir}/*.h ${_src_dir}/*.hpp)

        if(FUNC_CLEAN)
            if(EXISTS ${_dest_dir})
                if(IS_DIRECTORY ${_dest_dir})
                    file(REMOVE_RECURSE ${_dest_dir})
                else()
                    file(REMOVE ${_dest_dir})
                endif()
            else()
                return()
            endif()
        endif()

        execute_process(
            COMMAND ${CMAKE_COMMAND}
            -D "src=${_src_dir}"
            -D "dest=${_dest_dir}"
            -P "${QTMEDIATE_CMAKE_MODULES_DIR}/commands/GenInclude.cmake"
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        )

        if(FUNC_INSTALL_DIR)
            get_filename_component(_install_dir ${FUNC_INSTALL_DIR} ABSOLUTE BASE_DIR ${CMAKE_INSTALL_PREFIX})

            install(CODE "
                execute_process(
                    COMMAND \"${CMAKE_COMMAND}\"
                    -D \"src=${_src_dir}\"
                    -D \"dest=${_install_dir}\"
                    -D \"clean=TRUE\"
                    -P \"${QTMEDIATE_CMAKE_MODULES_DIR}/commands/GenInclude.cmake\"
                    WORKING_DIRECTORY \"${CMAKE_CURRENT_SOURCE_DIR}\"
                )
            ")
        endif()
    else()
        message(FATAL_ERROR "qtmediate_gen_include_files: Source directory doesn't exist.")
    endif()
endfunction()

# ----------------------------------
# QtMediate Private API
# ----------------------------------
macro(_qtmediate_set_value _key _maybe_value _default)
    if(${_maybe_value})
        set(${_key} ${${_maybe_value}})
    else()
        set(${_key} ${_default})
    endif()
endmacro()

function(_qtmediate_parse_version _prefix _version)
    string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ ${_version})

    foreach(_i RANGE 1 4)
        if(${CMAKE_MATCH_COUNT} GREATER_EQUAL ${_i})
            set(_tmp ${CMAKE_MATCH_${_i}})
        else()
            set(_tmp 0)
        endif()

        set(${_prefix}_${_i} ${_tmp} PARENT_SCOPE)
    endforeach()
endfunction()