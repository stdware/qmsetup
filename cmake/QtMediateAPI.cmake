include_guard(DIRECTORY)

if(NOT DEFINED QTMEDIATE_MODULES_DIR)
    set(QTMEDIATE_MODULES_DIR ${CMAKE_CURRENT_LIST_DIR})
endif()

#[[
    Skip CMAKE_AUTOMOC for all source files in directory.

    qtmediate_dir_skip_automoc()
]] #
macro(qtmediate_dir_skip_automoc)
    foreach(_item ${ARGN})
        file(GLOB _src ${_item}/*.h ${_item}/*.cpp ${_item}/*.cc)
        set_source_files_properties(
            ${_src} PROPERTIES SKIP_AUTOMOC ON
        )
    endforeach()
endmacro()

#[[
    Find Qt libraries.

    qtmediate_find_qt_libraries(<modules...>)
#]]
macro(qtmediate_find_qt_libraries)
    foreach(_module ${ARGN})
        find_package(QT NAMES Qt6 Qt5 COMPONENTS ${_module} REQUIRED)
        find_package(Qt${QT_VERSION_MAJOR} COMPONENTS ${_module} REQUIRED)
    endforeach()
endmacro()

#[[
    Link Qt libraries.

    qtmediate_link_qt_libraries(<target> <scope> <modules...>)
#]]
macro(qtmediate_link_qt_libraries _target _scope)
    foreach(_module ${ARGN})
        # Find
        if(NOT QT_VERSION_MAJOR OR NOT TARGET Qt${QT_VERSION_MAJOR}::${_module})
            qtmediate_find_qt_libraries(${_module})
        endif()

        # Link
        target_link_libraries(${_target} ${_scope} Qt${QT_VERSION_MAJOR}::${_module})
    endforeach()
endmacro()

#[[
    Include Qt private header directories.

    qtmediate_include_qt_private(<target> <scope> <modules...>)
#]]
macro(qtmediate_include_qt_private _target _scope)
    foreach(_module ${ARGN})
        # Find
        if(NOT QT_VERSION_MAJOR OR NOT TARGET Qt${QT_VERSION_MAJOR}::${_module})
            qtmediate_find_qt_libraries(${_module})
        endif()

        # Include
        target_include_directories(${_target} ${_scope} ${Qt${QT_VERSION_MAJOR}${_module}_PRIVATE_INCLUDE_DIRS})
    endforeach()
endmacro()

#[[
    Attach windows RC file to a target.

    qtmediate_add_win_rc(<target>
        [NAME           name] 
        [VERSION        version] 
        [DESCRIPTION    desc]
        [COPYRIGHT      copyright]
        [ICON           ico]
        [OUTPUT         output]
    )
]] #
function(qtmediate_add_win_rc _target)
    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION COPYRIGHT ICON OUTPUT)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    qtmediate_set_value(_version_temp PROJECT_VERSION "0.0.0.0")
    qtmediate_set_value(_out_path FUNC_OUTOUT "${CMAKE_CURRENT_BINARY_DIR}/${_name}_res.rc")

    qtmediate_set_value(_name FUNC_NAME ${_target})
    qtmediate_set_value(_version FUNC_VERSION ${_version_temp})
    qtmediate_set_value(_desc FUNC_DESCRIPTION ${_name})
    qtmediate_set_value(_copyright FUNC_COPYRIGHT ${_name})

    qtmediate_parse_version(_ver ${_version})
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

    configure_file("${QTMEDIATE_MODULES_DIR}/windows/WinResource.rc.in" ${_out_path} @ONLY)
    target_sources(${_target} PRIVATE ${_out_path})
endfunction()

#[[
    Attach windows manifest file to a target.

    qtmediate_add_win_manifest(<target>
        [NAME           name] 
        [VERSION        version] 
        [DESCRIPTION    desc]
        [OUTPUT         output]
    )
]] #
function(qtmediate_add_win_manifest _target)
    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION OUTPUT)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    qtmediate_set_value(_version_temp PROJECT_VERSION "0.0.0.0")
    qtmediate_set_value(_out_path FUNC_OUTOUT "${CMAKE_CURRENT_BINARY_DIR}/${RC_PROJECT_NAME}_manifest.manifest")

    qtmediate_set_value(_name FUNC_NAME ${_target})
    qtmediate_set_value(_version FUNC_VERSION ${_version_temp})
    qtmediate_set_value(_desc FUNC_DESCRIPTION ${_name})

    set(MANIFEST_IDENTIFIER ${_name})
    set(MANIFEST_VERSION ${_version})
    set(MANIFEST_DESCRIPTION ${_desc})

    configure_file("${QTMEDIATE_MODULES_DIR}/windows/WinManifest.manifest.in" ${_out_path} @ONLY)
    target_sources(${_target} PRIVATE ${_out_path})
endfunction()

#[[
    Add Mac bundle info.

    qtmediate_add_mac_bundle(<target>
        [NAME           <name>]
        [VERSION        <version>]
        [DESCRIPTION    <desc>]
        [COPYRIGHT      <copyright>]
        [ICON           <file>]
    )
]] #
function(qtmediate_add_mac_bundle _target)
    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION COPYRIGHT ICON)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    qtmediate_set_value(_version_temp PROJECT_VERSION "0.0.0.0")

    qtmediate_set_value(_app_name FUNC_NAME ${_target})
    qtmediate_set_value(_app_version FUNC_VERSION ${_version_temp})
    qtmediate_set_value(_app_desc FUNC_DESCRIPTION ${_app_name})
    qtmediate_set_value(_app_copyright FUNC_COPYRIGHT ${_app_name})

    qtmediate_parse_version(_app_version ${_app_version})

    # configure mac plist
    set_target_properties(${_target} PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME ${_app_name}
        MACOSX_BUNDLE_EXECUTABLE_NAME ${_app_name}
        MACOSX_BUNDLE_INFO_STRING ${_app_desc}
        MACOSX_BUNDLE_GUI_IDENTIFIER ${_app_name}
        MACOSX_BUNDLE_BUNDLE_VERSION ${_app_version}
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${_app_version_1}.${_app_version_2}
        MACOSX_BUNDLE_COPYRIGHT ${_app_copyright}
    )

    if(FUNC_ICON)
        # And this part tells CMake where to find and install the file itself
        set_source_files_properties(${FUNC_ICON} PROPERTIES
            MACOSX_PACKAGE_LOCATION "Resources"
        )

        # NOTE: Don't include the path in MACOSX_BUNDLE_ICON_FILE -- this is
        # the property added to Info.plist
        get_filename_component(_icns_name ${FUNC_ICON} NAME)

        # configure mac plist
        set_target_properties(${_target} PROPERTIES
            MACOSX_BUNDLE_ICON_FILE ${_icns_name}
        )

        # ICNS icon MUST be added to executable's sources list, for some reason
        # Only apple can do
        target_sources(${_target} PRIVATE ${FUNC_ICON})
    endif()
endfunction()

#[[
    Generate Windows shortcut after building target.

    qtmediate_create_win_shortcut(<target> <dir>
        [OUTPUT_NAME <name]
    )
]] #
function(qtmediate_create_win_shortcut _target _dir)
    set(options)
    set(oneValueArgs OUTPUT_NAME)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    qtmediate_set_value(_output_name FUNC_OUTPUT_NAME $<TARGET_FILE_BASE_NAME:${_target}>)

    set(_vbs_name ${CMAKE_CURRENT_BINARY_DIR}/${_target}_shortcut.vbs)
    set(_vbs_temp ${_vbs_name}.in)

    set(_lnk_path "${_dir}/${_output_name}.lnk")

    set(SHORTCUT_PATH ${_lnk_path})
    set(SHORTCUT_TARGET_PATH $<TARGET_FILE:${_target}>)
    set(SHORTCUT_WORKING_DIRECOTRY $<TARGET_FILE_DIR:${_target}>)
    set(SHORTCUT_DESCRIPTION $<TARGET_FILE_BASE_NAME:${_target}>)
    set(SHORTCUT_ICON_LOCATION $<TARGET_FILE:${_target}>)

    configure_file(
        "${QTMEDIATE_MODULES_DIR}/windows/WinCreateShortcut.vbs.in"
        ${_vbs_temp}
        @ONLY
    )
    file(GENERATE OUTPUT ${_vbs_name} INPUT ${_vbs_temp})

    add_custom_command(
        TARGET ${_target} POST_BUILD
        COMMAND cscript ${_vbs_name}
        BYPRODUCTS ${_lnk_path}
    )
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

    set(DOXYGEN_FILE_DIR ${QTMEDIATE_MODULES_DIR}/doxygen)

    qtmediate_set_value(_name FUNC_NAME "${PROJECT_NAME}")
    qtmediate_set_value(_version FUNC_VERSION "${PROJECT_VERSION}")
    qtmediate_set_value(_desc FUNC_DESCRIPTION "${PROJECT_DESCRIPTION}")
    qtmediate_set_value(_logo FUNC_LOGO "")
    qtmediate_set_value(_mdfile FUNC_MDFILE "")
    qtmediate_set_value(_tagfile FUNC_GENERATE_TAGFILE "")

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
        COMMENT "Building HTML documentation"
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
                OUTPUT_QUIET
            )
        ")
    endif()
endfunction()

#[[
    Generate indirect reference files for header files to make the include statements more orderly.
    The generated file has the same timestamp as the source file.

    qtmediate_sync_include(<src> <dest>
        [INSTALL_DIR]
    )
#]]
function(qtmediate_sync_include _src_dir _dest_dir)
    set(options COPY)
    set(oneValueArgs INSTALL_DIR)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get petool
    set(_tool_target qtmediate-cmake-modules::incsync)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_sync_include: tool \"incsync\" not found.")
    else()
        get_target_property(_tool ${_tool_target} LOCATION)
    endif()

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

        execute_process(
            COMMAND ${_tool} ${_src_dir} ${_dest_dir}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMAND_ERROR_IS_FATAL ANY
            OUTPUT_QUIET
        )

        if(FUNC_INSTALL_DIR)
            get_filename_component(_install_dir ${FUNC_INSTALL_DIR} ABSOLUTE BASE_DIR ${CMAKE_INSTALL_PREFIX})

            install(CODE "
                execute_process(
                    COMMAND \"${_tool}\" -c \"${_src_dir}\" \"${_install_dir}\"
                    WORKING_DIRECTORY \"${CMAKE_CURRENT_SOURCE_DIR}\"
                    COMMAND_ERROR_IS_FATAL ANY
                    OUTPUT_QUIET
                )
            ")
        endif()
    else()
        message(FATAL_ERROR "qtmediate_sync_include: Source directory doesn't exist.")
    endif()
endfunction()

#[[
    Parse version and create seq vars with specified prefix.

    qtmediate_parse_version(<prefix> <version>)
]] #
function(qtmediate_parse_version _prefix _version)
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

#[[
    Helper to link libraries and include directories of a target.

    qtmediate_configure_target(<target>
        [SOURCES          <files>]
        [LINKS            <libs>]
        [LINKS_PRIVATE    <libs>]
        [INCLUDE_PRIVATE  <dirs>]

        [DEFINES          <defs>]
        [DEFINES_PRIVATE  <defs>]

        [CCFLAGS          <flags>]
        [CCFLAGS_PRIVATE  <flags>]

        [QT_LINKS            <modules>]
        [QT_LINKS_PRIVATE    <modules>]
        [QT_INCLUDE_PRIVATE  <modules>]

        [SKIP_AUTOMOC_DIRS   <dirs>]
        [SKIP_AUTOMOC_FILES  <files]
    )
]] #
function(qtmediate_configure_target _target)
    set(options)
    set(oneValueArgs)
    set(multiValueArgs
        SOURCES LINKS LINKS_PRIVATE
        QT_LINKS QT_LINKS_PRIVATE QT_INCLUDE_PRIVATE
        INCLUDE_PRIVATE
        DEFINES DEFINES_PRIVATE
        CCFLAGS CCFLAGS_PUBLIC
        SKIP_AUTOMOC_DIRS SKIP_AUTOMOC_FILES
    )
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    target_sources(${_target} PRIVATE ${FUNC_SOURCES})
    target_link_libraries(${_target} PUBLIC ${FUNC_LINKS})
    target_link_libraries(${_target} PRIVATE ${FUNC_LINKS_PRIVATE})
    target_compile_definitions(${_target} PUBLIC ${FUNC_DEFINES})
    target_compile_definitions(${_target} PRIVATE ${FUNC_DEFINES_PRIVATE})
    target_compile_options(${_target} PUBLIC ${FUNC_CCFLAGS_PUBLIC})
    target_compile_options(${_target} PRIVATE ${FUNC_CCFLAGS})
    qtmediate_link_qt_libraries(${_target} PUBLIC ${FUNC_QT_LINKS})
    qtmediate_link_qt_libraries(${_target} PRIVATE ${FUNC_QT_LINKS_PRIVATE})
    target_include_directories(${_target} PRIVATE ${FUNC_INCLUDE_PRIVATE})
    qtmediate_include_qt_private(${_target} PRIVATE ${FUNC_QT_INCLUDE_PRIVATE})
    qtmediate_dir_skip_automoc(${FUNC_SKIP_AUTOMOC_DIRS})

    if(FUNC_SKIP_AUTOMOC_FILES)
        set_source_files_properties(
            ${FUNC_SKIP_AUTOMOC_FILES} PROPERTIES SKIP_AUTOMOC ON
        )
    endif()

    # Add library searching paths
    if(WIN32)
        get_target_property(_paths ${_target} LIBRARY_SEARCHING_PATHS)

        if(NOT _paths)
            set(_paths)
        endif()

        if(NOT CMAKE_BUILD_TYPE OR CMAKE_BUILD_TYPE STREQUAL Debug)
            set(_config_upper DEBUG)
        else()
            string(TOUPPER ${CMAKE_BUILD_TYPE} _config_upper)
        endif()

        foreach(_item ${FUNC_LINKS} ${FUNC_LINKS_PRIVATE})
            if(TARGET ${_item})
                # Resolve location
                get_target_property(_imported ${_item} IMPORTED)

                if(_imported)
                    get_target_property(_path ${_item} LOCATION_${_config_upper})

                    if(NOT _path OR ${_path} IN_LIST _result)
                        continue()
                    endif()

                    get_filename_component(_path ${_path} DIRECTORY)
                else()
                    get_target_property(_type ${_item} TYPE)

                    if(NOT ${_type} MATCHES "SHARED_LIBRARY")
                        continue()
                    endif()

                    set(_path $<TARGET_FILE_DIR:${_item}>)
                endif()
            endif()

            if(${_path} IN_LIST _paths)
                continue()
            endif()

            list(APPEND _paths ${_path})
        endforeach()

        set_target_properties(${_target} PROPERTIES LIBRARY_SEARCHING_PATHS "${_paths}")
    endif()
endfunction()

#[[
    Helper to define export macros.

    qtmediate_export_defines(<target>
        [PREFIX     <prefix>]
        [STATIC     <token>]
        [LIBRARY    <token>]
    )
]] #
function(qtmediate_export_defines _target)
    set(options)
    set(oneValueArgs PREFIX STATIC LIBRARY)
    set(multiValueArgs)

    if(NOT FUNC_PREFIX)
        string(TOUPPER ${_target} _prefix)
    else()
        set(_prefix ${FUNC_PREFIX})
    endif()

    qtmediate_set_value(_static_macro FUNC_STATIC ${_prefix}_STATIC)
    qtmediate_set_value(_library_macro FUNC_LIBRARY ${_prefix}_LIBRARY)

    get_target_property(_type ${_target} TYPE)

    if(${_type} STREQUAL STATIC_LIBRARY)
        target_compile_definitions(${_target} PUBLIC ${_static_macro})
    endif()

    target_compile_definitions(${_target} PRIVATE ${_library_macro})
endfunction()

#[[
    Set value if valid, otherwise use default.

    qtmediate_set_value(<key> <maybe_value> <default>)
]] #
macro(qtmediate_set_value _key _maybe_value _default)
    if(${_maybe_value})
        set(${_key} ${${_maybe_value}})
    else()
        set(${_key} ${_default})
    endif()
endmacro()

#[[
    Add a definition to global scope or a given target.

    qtmediate_add_definition(<key|key=value>
        [TARGET <target>]
        [PROPERTY <prop>]
        [NUMERICAL]
        [CONDITION <cond>]
    )
]] #
macro(qtmediate_add_definition)
    set(options GLOBAL NUMERICAL)
    set(oneValueArgs TARGET PROPERTY CONDITION)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(_result)
    set(_is_pair off)
    set(_defined off)

    set(_list ${FUNC_UNPARSED_ARGUMENTS})
    list(LENGTH _list _len)

    set(_cond on)

    if(FUNC_CONDITION)
        if(NOT ${FUNC_CONDITION})
            set(_cond off)
        endif()
    elseif(DEFINED FUNC_CONDITION)
        set(_cond off)
    endif()

    if(${_len} EQUAL 1)
        set(_result ${_list})
        set(_defined on)

        if(NOT _cond)
            set(_defined off)
        endif()
    elseif(${_len} EQUAL 2)
        # Get key
        list(POP_FRONT _list _key)
        list(POP_FRONT _list _val)

        # Boolean
        string(TOLOWER ${_val} _val_lower)

        if(${_val_lower} STREQUAL "off" OR ${_val_lower} STREQUAL "false")
            set(_result ${_key})
            set(_defined off)

            if(NOT _cond)
                set(_defined on)
            endif()
        elseif(${_val_lower} STREQUAL "on" OR ${_val_lower} STREQUAL "true")
            set(_result ${_key})
            set(_defined on)

            if(NOT _cond)
                set(_defined off)
            endif()
        else()
            set(_result "${_key}=${_val}")
            set(_is_pair on)
            set(_defined on)

            if(NOT _cond)
                set(_defined off)
            endif()
        endif()
    else()
        message(FATAL_ERROR "qtmediate_add_definition: called with incorrect number of arguments")
    endif()

    if(FUNC_NUMERICAL AND NOT _is_pair)
        if(_defined)
            set(_result "${_result}=1")
        else()
            set(_result "${_result}=-1")
        endif()
    elseif(NOT _defined)
        return()
    endif()

    qtmediate_set_value(_prop FUNC_PROPERTY CONFIG_DEFINITIONS)

    if(FUNC_TARGET)
        set_property(TARGET ${FUNC_TARGET} APPEND PROPERTY ${_prop} "${_result}")
    else()
        set_property(GLOBAL APPEND PROPERTY ${_prop} "${_result}")
    endif()
endmacro()

#[[
    Generate a configuration header. If the configuration has not changed, the generated file's
    timestemp will not be updated when you reconfigure it.

    qtmediate_generate_config(<file>
        [TARGET <target>]
        [PROPERTY prop]
    )
]] #
function(qtmediate_generate_config _file)
    set(options GLOBAL)
    set(oneValueArgs TARGET PROPERTY)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get petool
    set(_tool_target qtmediate-cmake-modules::cfggen)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_generate_config: tool \"cfggen\" not found.")
    else()
        get_target_property(_tool ${_tool_target} LOCATION)
    endif()

    qtmediate_set_value(_prop FUNC_PROPERTY CONFIG_DEFINITIONS)

    if(FUNC_TARGET)
        get_target_property(_def_list ${FUNC_TARGET} ${_prop})
    else()
        get_property(_def_list GLOBAL PROPERTY ${_prop})
    endif()

    if(_def_list)
        set(_args)

        foreach(_item ${_def_list})
            list(APPEND _args "-D${_item}")
        endforeach()

        execute_process(COMMAND ${_tool} ${_args} ${_file}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMAND_ERROR_IS_FATAL ANY
            OUTPUT_QUIET
        )
    endif()
endfunction()

#[[
    Helper to define export macros.

    qtmediate_win_applocal_deps(<target>
        [TARGET <name>]
        [EXTRA_SEARCHING_PATHS <paths...>]
    )
]] #
function(qtmediate_win_applocal_deps _target)
    set(options)
    set(oneValueArgs TARGET)
    set(multiValueArgs EXTRA_SEARCHING_PATHS)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get petool
    set(_tool_target qtmediate-cmake-modules::windeps)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_win_applocal_deps: tool \"windeps\" not found.")
    else()
        get_target_property(_tool ${_tool_target} LOCATION)
    endif()

    if(FUNC_TARGET)
        set(_deploy_target ${FUNC_TARGET})
        add_custom_target(${_deploy_target})
    else()
        set(_deploy_target ${_target})
    endif()

    get_target_property(_paths ${_target} LIBRARY_SEARCHING_PATHS)

    if(NOT _paths)
        set(_paths)
    endif()

    if(FUNC_EXTRA_SEARCHING_PATHS)
        list(APPEND _paths ${FUNC_EXTRA_SEARCHING_PATHS})
    endif()

    if(NOT _paths)
        return()
    endif()

    set(_args)

    foreach(_item ${_paths})
        list(APPEND _args "-L${_item}")
    endforeach()

    add_custom_command(TARGET ${_deploy_target} POST_BUILD
        COMMENT # COMMAND ${CMAKE_COMMAND} -E echo
        "Deploying shared libraries for $<TARGET_FILE_NAME:${_target}>"
        COMMAND ${_tool} ${_args} $<TARGET_FILE:${_target}> 1>NUL
        WORKING_DIRECTORY $<TARGET_FILE_DIR:${_target}>
    )
endfunction()