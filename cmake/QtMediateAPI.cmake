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
    if(NOT WIN32)
        return()
    endif()

    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION COPYRIGHT ICON OUTPUT)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    qtmediate_set_value(_version_temp PROJECT_VERSION "0.0.0.0")

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

    qtmediate_set_value(_out_path FUNC_OUTOUT "${CMAKE_CURRENT_BINARY_DIR}/${_name}_res.rc")

    configure_file("${QTMEDIATE_MODULES_DIR}/windows/WinResource.rc.in" ${_out_path} @ONLY)
    target_sources(${_target} PRIVATE ${_out_path})
endfunction()

#[[
    Attach windows RC file to a target, enhanced edition.

    qtmediate_add_win_rc_enhanced(<target>
        [NAME              name]
        [VERSION           version]
        [DESCRIPTION       description]
        [COPYRIGHT         copyright]
        [COMMENTS          comments]
        [COMPANY           company]
        [INTERNAL_NAME     internal name]
        [TRADEMARK         trademark]
        [ORIGINAL_FILENAME original filename]
        [ICONS             icon file paths]
        [OUTPUT            output]
    )
]] #
function(qtmediate_add_win_rc_enhanced _target)
    if(NOT WIN32)
        return()
    endif()

    set(options)
    set(oneValueArgs NAME VERSION DESCRIPTION COPYRIGHT COMMENTS COMPANY INTERNAL_NAME TRADEMARK ORIGINAL_FILENAME OUTPUT)
    set(multiValueArgs ICONS)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    qtmediate_set_value(_version_temp PROJECT_VERSION "0.0.0.0")

    qtmediate_set_value(_name FUNC_NAME ${_target})
    qtmediate_set_value(_version FUNC_VERSION ${_version_temp})
    qtmediate_set_value(_desc FUNC_DESCRIPTION ${_name})
    qtmediate_set_value(_copyright FUNC_COPYRIGHT ${_name})
    qtmediate_set_value(_comments FUNC_COMMENTS "")
    qtmediate_set_value(_company FUNC_COMPANY "")
    qtmediate_set_value(_internal_name FUNC_INTERNAL_NAME "")
    qtmediate_set_value(_trademark FUNC_TRADEMARK "")
    qtmediate_set_value(_original_filename FUNC_ORIGINAL_FILENAME "")

    qtmediate_parse_version(_ver ${_version})
    set(RC_VERSION ${_ver_1},${_ver_2},${_ver_3},${_ver_4})

    set(RC_APPLICATION_NAME ${_name})
    set(RC_VERSION_STRING ${_version})
    set(RC_DESCRIPTION ${_desc})
    set(RC_COPYRIGHT ${_copyright})
    set(RC_COMMENTS ${_comments})
    set(RC_COMPANY ${_company})
    set(RC_INTERNAL_NAME ${_internal_name})
    set(RC_TRADEMARK ${_trademark})
    set(RC_ORIGINAL_FILENAME ${_original_filename})

    set(_file_type)
    set(_target_type)
    get_target_property(_target_type ${_target} TYPE)
    if("x${_target_type}" STREQUAL "xEXECUTABLE")
        set(_file_type "VFT_APP")
    else()
        set(_file_type "VFT_DLL")
    endif()
    set(RC_FILE_TYPE ${_file_type})

    set(_icons)
    if(FUNC_ICONS)
        set(_index 1)
        foreach(_icon IN LISTS FUNC_ICONS)
            string(APPEND _icons "IDI_ICON${_index}    ICON    \"${_icon}\"\n")
            math(EXPR _index "${_index} +1")
        endforeach()
    endif()
    set(RC_ICONS ${_icons})

    qtmediate_set_value(_out_path FUNC_OUTOUT "${CMAKE_CURRENT_BINARY_DIR}/${_name}_res.rc")

    configure_file("${QTMEDIATE_MODULES_DIR}/windows/WinResource2.rc.in" ${_out_path} @ONLY)
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
    if(NOT WIN32)
        return()
    endif()

    set(options UTF8)
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

    set(MANIFEST_UTF8)
    if(FUNC_UTF8)
        set(MANIFEST_UTF8 "<activeCodePage xmlns=\"http://schemas.microsoft.com/SMI/2019/WindowsSettings\">UTF-8</activeCodePage>")
    endif()

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
    if(NOT APPLE)
        return()
    endif()

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
    if(NOT WIN32)
        return()
    endif()

    set(options)
    set(oneValueArgs OUTPUT_NAME)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    qtmediate_set_value(_output_name FUNC_OUTPUT_NAME $<TARGET_FILE_BASE_NAME:${_target}>)

    set(_vbs_name ${CMAKE_CURRENT_BINARY_DIR}/${_target}_shortcut_$<CONFIG>.vbs)
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
    Get shorter version number.

    qtmediate_crop_version(<VAR> <version> <count>)
]] #
function(qtmediate_crop_version _var _version _count)
    qtmediate_parse_version(FUNC ${_version})

    set(_list)

    foreach(_i RANGE 1 ${_count})
        list(APPEND _list ${FUNC_${_i}})
    endforeach()

    string(JOIN "." _short_version ${_list})
    set(${_var} ${_short_version} PARENT_SCOPE)
endfunction()

#[[
    Tell if there are any generator expressions in the string.

    qtmediate_has_genex(<VAR> <string>)
]] #
function(qtmediate_has_genex _out _str)
    string(GENEX_STRIP "${_str}" _no_genex)

    if("${_str}" STREQUAL "${_no_genex}")
        set(_res off)
    else()
        set(_res on)
    endif()

    set(${_out} ${_res} PARENT_SCOPE)
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
    Collect targets of given types recursively in a directory.

    qtmediate_collect_targets(<list> [DIR directory]
                              [EXECUTABLE] [SHARED] [STATIC] [UTILITY])

    If one or more types are specified, return targets matching the types.
    If no type is specified, return all targets.
]] #
function(qtmediate_collect_targets _var)
    set(options EXECUTABLE SHARED STATIC UTILITY)
    set(oneValueArgs DIR)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(FUNC_DIR)
        set(_dir ${FUNC_DIR})
    else()
        set(_dir ${CMAKE_CURRENT_SOURCE_DIR})
    endif()

    set(_tmp_targets)

    macro(get_targets_recursive _targets _dir)
        get_property(_subdirs DIRECTORY ${_dir} PROPERTY SUBDIRECTORIES)

        foreach(_subdir ${_subdirs})
            get_targets_recursive(${_targets} ${_subdir})
        endforeach()

        get_property(_current_targets DIRECTORY ${_dir} PROPERTY BUILDSYSTEM_TARGETS)
        list(APPEND ${_targets} ${_current_targets})
    endmacro()

    # Get targets
    get_targets_recursive(_tmp_targets ${_dir})
    set(_targets)

    if(NOT FUNC_EXECUTABLE AND NOT FUNC_SHARED AND NOT FUNC_STATIC AND NOT FUNC_UTILITY)
        set(_targets ${_tmp_targets})
    else()
        # Filter targets
        foreach(_item ${_tmp_targets})
            get_target_property(_type ${_item} TYPE)

            if(${_type} STREQUAL "EXECUTABLE")
                if(FUNC_EXECUTABLE)
                    list(APPEND _targets ${_item})
                endif()
            elseif(${_type} STREQUAL "SHARED_LIBRARY")
                if(FUNC_SHARED)
                    list(APPEND _targets ${_item})
                endif()
            elseif(${_type} STREQUAL "STATIC_LIBRARY")
                if(FUNC_STATIC)
                    list(APPEND _targets ${_item})
                endif()
            elseif(${_type} STREQUAL "UTILITY")
                if(FUNC_UTILITY)
                    list(APPEND _targets ${_item})
                endif()
            endif()
        endforeach()
    endif()

    set(${_var} ${_targets} PARENT_SCOPE)
endfunction()

#[[
    Get subdirectories' names or paths.

    qtmediate_get_subdirs(<list>  
        [DIRECTORY dir]
        [EXCLUDE names...]
        [REGEX_INCLUDE exps...]
        [REGEX_EXLCUDE exps...]
        [RELATIVE path]
        [ABSOLUTE]
    )

    If `DIRECTORY` is not specified, consider `CMAKE_CURRENT_SOURCE_DIR`.
    If `RELATIVE` is specified, return paths evaluated as a relative path to it.
    If `ABSOLUTE` is specified, return absolute paths.
    If neither of them is specified, return names.
]] #
function(qtmediate_get_subdirs _var)
    set(options ABSOLUTE)
    set(oneValueArgs DIRECTORY RELATIVE)
    set(multiValueArgs EXCLUDE REGEX_EXLCUDE)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(FUNC_DIRECTORY)
        get_filename_component(_dir ${FUNC_DIRECTORY} ABSOLUTE)
    else()
        set(_dir ${CMAKE_CURRENT_SOURCE_DIR})
    endif()

    file(GLOB _subdirs LIST_DIRECTORIES true RELATIVE ${_dir} "${_dir}/*")

    if(FUNC_EXCLUDE)
        foreach(_exclude_dir ${FUNC_EXCLUDE})
            list(REMOVE_ITEM _subdirs ${_exclude_dir})
        endforeach()
    endif()

    if(FUNC_REGEX_INCLUDE)
        foreach(_exp ${FUNC_REGEX_INCLUDE})
            list(FILTER _subdirs INCLUDE REGEX ${_exp})
        endforeach()
    endif()

    if(FUNC_REGEX_EXCLUDE)
        foreach(_exp ${FUNC_REGEX_EXCLUDE})
            list(FILTER _subdirs EXCLUDE REGEX ${_exp})
        endforeach()
    endif()

    set(_res)

    if(FUNC_RELATIVE)
        get_filename_component(_relative ${FUNC_RELATIVE} ABSOLUTE)
    else()
        set(_relative)
    endif()

    foreach(_sub ${_subdirs})
        if(IS_DIRECTORY ${_dir}/${_sub})
            if(FUNC_ABSOLUTE)
                list(APPEND _res ${_dir}/${_sub})
            elseif(_relative)
                file(RELATIVE_PATH _rel_path ${_relative} ${_dir}/${_sub})
                list(APPEND _res ${_rel_path})
            else()
                list(APPEND _res ${_sub})
            endif()
        endif()
    endforeach()

    set(${_var} ${_res} PARENT_SCOPE)
endfunction()