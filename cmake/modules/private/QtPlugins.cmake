#[[
    Warning: This module is private, may be modified or removed in the future, please use with caution.

    The Qt plugins of Qt modules, worked out from the metadata of a Qt 6 installation:
    modules/<module>.json lists the plugin types of each module, and the plugins of a type are the
    plugins in the directory of that type. Qt's own deployment reads the same files.

    Deploy.cmake includes this file for QT_PLUGINS of qm_deploy_directory, whose install rule
    includes it as well, because an install rule runs as a script of its own. The directories of
    Qt default to those of the Qt 6 that the project found. The install rule passes every one of
    them, since it runs without the project.
]] #

include_guard(GLOBAL)

#[[
    Sets <out> to the directory of the module descriptions, the directory of the plugins, the
    suffix and the prefix of the file name of a plugin, and the binary and the library
    directories, of the Qt 6 that the project found, for the platform of the project. Stops with
    an error naming <caller> if no Qt 6 was found.

    _qm_qt_plugin_dirs(<out> <caller>)
]] #
function(_qm_qt_plugin_dirs _out _caller)
    if(NOT QT6_INSTALL_PREFIX OR NOT QT6_INSTALL_DESCRIPTIONSDIR OR NOT QT6_INSTALL_PLUGINS)
        message(FATAL_ERROR "${_caller}: the Qt plugins require Qt 6, found before the call.")
    endif()

    if(WIN32)
        set(_suffix ".dll")
        set(_prefix "")
    elseif(APPLE)
        set(_suffix ".dylib")
        set(_prefix "lib")
    else()
        set(_suffix ".so")
        set(_prefix "lib")
    endif()

    set(${_out}
        "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_DESCRIPTIONSDIR}"
        "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_PLUGINS}"
        "${_suffix}"
        "${_prefix}"
        "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS}"
        "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_LIBS}"
        PARENT_SCOPE
    )
endfunction()

#[[
    Sets the values that the caller was not given, in the variables of the caller named
    FUNC_<keyword>, from _qm_qt_plugin_dirs(): DESCRIPTIONS, PLUGINS_DIR, and SUFFIX and PREFIX.
    The last two are taken together, because the prefix of Windows is empty and therefore cannot
    be told from a prefix that was not given.

    _qm_qt_plugin_defaults(<caller>)
]] #
macro(_qm_qt_plugin_defaults _caller)
    if(NOT FUNC_DESCRIPTIONS OR NOT FUNC_PLUGINS_DIR OR NOT FUNC_SUFFIX)
        _qm_qt_plugin_dirs(_qm_qt_plugin_dirs_found ${_caller})

        if(NOT FUNC_DESCRIPTIONS)
            list(GET _qm_qt_plugin_dirs_found 0 FUNC_DESCRIPTIONS)
        endif()

        if(NOT FUNC_PLUGINS_DIR)
            list(GET _qm_qt_plugin_dirs_found 1 FUNC_PLUGINS_DIR)
        endif()

        if(NOT FUNC_SUFFIX)
            list(GET _qm_qt_plugin_dirs_found 2 FUNC_SUFFIX)
            list(GET _qm_qt_plugin_dirs_found 3 FUNC_PREFIX)
        endif()
    endif()
endmacro()

#[[
    Get the Qt modules of the Qt libraries in a listing.

    qm_get_qt_modules(<output_var> <listing>
        [DESCRIPTIONS <dir>]
    )

    <listing>
        Paths, one per line, such as the output of qmcorecmd deploy --list source. A path that
        holds a semicolon is read whole.
    DESCRIPTIONS
        The module descriptions, modules/ of the Qt 6 found by default

    A library is recognized by its file name: Qt6Widgets.dll, Qt6Widgetsd.dll, libQt6Widgets.so.6
    and QtWidgets.framework are all the module Widgets. A name is a module if the descriptions
    hold its description, which separates the d of a debug library from a module whose name
    ends with d. A path that names no Qt library is passed over.
]] #
function(qm_get_qt_modules _out _listing)
    set(options)
    set(oneValueArgs DESCRIPTIONS)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT FUNC_DESCRIPTIONS)
        _qm_qt_plugin_dirs(_dirs qm_get_qt_modules)
        list(GET _dirs 0 FUNC_DESCRIPTIONS)
    endif()

    set(_modules)

    # Line by line rather than as a CMake list, which would split a path at a semicolon
    while(NOT "${_listing}" STREQUAL "")
        string(FIND "${_listing}" "\n" _end)

        if(_end EQUAL -1)
            set(_file "${_listing}")
            set(_listing "")
        else()
            string(SUBSTRING "${_listing}" 0 ${_end} _file)
            math(EXPR _end "${_end} + 1")
            string(SUBSTRING "${_listing}" ${_end} -1 _listing)
        endif()

        get_filename_component(_name "${_file}" NAME)

        if(_name MATCHES "^(lib)?Qt6([A-Za-z0-9]+)(\\.|$)")
            set(_module "${CMAKE_MATCH_2}")
        elseif(_name MATCHES "^Qt([A-Za-z0-9]+)\\.framework$")
            set(_module "${CMAKE_MATCH_1}")
        else()
            continue()
        endif()

        # The match runs in a condition of its own, see qm_get_qt_plugins()
        if(NOT EXISTS "${FUNC_DESCRIPTIONS}/${_module}.json")
            if(NOT _module MATCHES "^(.+)d$")
                continue()
            endif()

            set(_module "${CMAKE_MATCH_1}")

            if(NOT EXISTS "${FUNC_DESCRIPTIONS}/${_module}.json")
                continue()
            endif()
        endif()

        list(APPEND _modules "${_module}")
    endwhile()

    list(REMOVE_DUPLICATES _modules)
    set(${_out} ${_modules} PARENT_SCOPE)
endfunction()

#[=[
    Get the Qt plugins of Qt modules, as Qt's own deployment selects them.

    qm_get_qt_plugins(<output_var>
        MODULES <module>...
        [EXCLUDE <plugin>...]
        [DESCRIPTIONS <dir>]
        [PLUGINS_DIR <dir>]
        [SUFFIX <suffix> [PREFIX <prefix>]]
    )

    <output_var>
        Set to the plugins, sorted, each in the format <category>/<name> that PLUGINS of
        qm_deploy_directory takes
    MODULES
        Qt modules without the prefix, such as Gui and Widgets
    EXCLUDE
        Plugins, as <category>/<name>, to leave out
    DESCRIPTIONS
        The module descriptions, modules/ of the Qt 6 found by default
    PLUGINS_DIR
        The plugins, plugins/ of the Qt 6 found by default
    SUFFIX, PREFIX
        The suffix and the prefix of the file name of a plugin: .dll and nothing on Windows, and
        lib with .dylib or .so elsewhere, of the platform of the project by default

    Every plugin of each plugin type of the modules is selected, except the platform plugins, of
    which only those that the description of Gui names for the platform are selected, such as
    platforms/qwindows. A debug plugin beside its release plugin is not selected: <name>d on
    Windows and <name>_debug on macOS. A type without a directory has no plugins. The
    dependencies of a plugin are not examined. QT_PLUGINS of qm_deploy_directory examines them.
]=] #
function(qm_get_qt_plugins _out)
    set(options)
    set(oneValueArgs DESCRIPTIONS PLUGINS_DIR SUFFIX PREFIX)
    set(multiValueArgs MODULES EXCLUDE)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    _qm_qt_plugin_defaults(qm_get_qt_plugins)
    set(_types)
    set(_platforms)

    foreach(_module IN LISTS FUNC_MODULES)
        set(_file "${FUNC_DESCRIPTIONS}/${_module}.json")

        if(NOT EXISTS "${_file}")
            continue()
        endif()

        file(READ "${_file}" _json)

        # ERROR_VARIABLE holds NOTFOUND if there is no error.
        string(JSON _count ERROR_VARIABLE _error LENGTH "${_json}" plugin_types)

        if(_error STREQUAL "NOTFOUND" AND _count GREATER 0)
            math(EXPR _last "${_count} - 1")

            foreach(_index RANGE ${_last})
                string(JSON _type GET "${_json}" plugin_types ${_index})
                list(APPEND _types "${_type}")
            endforeach()
        endif()

        string(JSON _count ERROR_VARIABLE _error LENGTH "${_json}" qpa platforms)

        if(_error STREQUAL "NOTFOUND" AND _count GREATER 0)
            math(EXPR _last "${_count} - 1")

            foreach(_index RANGE ${_last})
                string(JSON _platform GET "${_json}" qpa platforms ${_index})
                list(APPEND _platforms "q${_platform}")
            endforeach()
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _types)
    set(_plugins)

    foreach(_type IN LISTS _types)
        file(GLOB _files LIST_DIRECTORIES false
            "${FUNC_PLUGINS_DIR}/${_type}/${FUNC_PREFIX}*${FUNC_SUFFIX}")

        foreach(_file IN LISTS _files)
            get_filename_component(_name "${_file}" NAME)
            string(LENGTH "${FUNC_PREFIX}" _prefix_length)
            string(LENGTH "${FUNC_SUFFIX}" _suffix_length)
            string(LENGTH "${_name}" _length)
            math(EXPR _length "${_length} - ${_prefix_length} - ${_suffix_length}")
            string(SUBSTRING "${_name}" ${_prefix_length} ${_length} _name)

            # Matched first, because ${CMAKE_MATCH_1} in the same condition is expanded before the
            # match runs and holds the previous match.
            if(FUNC_SUFFIX STREQUAL ".dll" AND _name MATCHES "^(.+)d$")
                if(EXISTS "${FUNC_PLUGINS_DIR}/${_type}/${CMAKE_MATCH_1}.dll")
                    continue()
                endif()
            endif()

            if(_name MATCHES "_debug$")
                continue()
            endif()

            if(_type STREQUAL "platforms" AND NOT _name IN_LIST _platforms)
                continue()
            endif()

            if("${_type}/${_name}" IN_LIST FUNC_EXCLUDE)
                continue()
            endif()

            list(APPEND _plugins "${_type}/${_name}")
        endforeach()
    endforeach()

    list(SORT _plugins)
    set(${_out} ${_plugins} PARENT_SCOPE)
endfunction()

#[=[
    Select the Qt plugins that a deployment requires.

    qm_select_qt_plugins(<output_var>
        COMMAND <command>...
        WORKING_DIRECTORY <dir>
        CORECMD <path>
        SEARCHING_PATHS <dir>...
        [EXCLUDE <plugin>...]
        [EXCLUDE_MODULES <module>...]
        [DESCRIPTIONS <dir>]
        [PLUGINS_DIR <dir>]
        [SUFFIX <suffix> [PREFIX <prefix>]]
    )

    <output_var>
        Set to the plugins, sorted, as <category>/<name>. <output_var>_MODULES is set to the Qt
        modules that the deployment requires with them.
    COMMAND
        The deployment script of qm_deploy_directory, which --list-sources makes print the
        libraries that the deployment would copy
    WORKING_DIRECTORY
        The directory that the deployment deploys, whose Qt libraries count as required
    CORECMD
        qmcorecmd, which resolves each plugin
    SEARCHING_PATHS
        The directories of the Qt libraries that a plugin requires
    EXCLUDE_MODULES
        Qt modules without the prefix. A plugin that requires one of them is left out.
    EXCLUDE, DESCRIPTIONS, PLUGINS_DIR, SUFFIX, PREFIX
        As for qm_get_qt_plugins()

    The modules that the binaries require come from the listing of the script and from the Qt
    libraries in the working directory. The plugins of these modules are then resolved one by
    one, as windeployqt resolves them. A plugin that requires a module of EXCLUDE_MODULES is left
    out. A plugin that requires a further module adds that module, whose plugins are examined in
    turn. Which plugins and modules to leave out is the decision of the caller: windeployqt, for
    instance, leaves out the plugins that require Qml or Quick for a program without QML, and
    tls/qopensslbackend and generic/qinsighttracker unless asked for.
]=] #
function(qm_select_qt_plugins _out)
    set(options)
    set(oneValueArgs WORKING_DIRECTORY CORECMD DESCRIPTIONS PLUGINS_DIR SUFFIX PREFIX)
    set(multiValueArgs COMMAND SEARCHING_PATHS EXCLUDE EXCLUDE_MODULES)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    _qm_qt_plugin_defaults(qm_select_qt_plugins)
    set(_where DESCRIPTIONS "${FUNC_DESCRIPTIONS}")
    set(_plugin_where ${_where} PLUGINS_DIR "${FUNC_PLUGINS_DIR}" SUFFIX "${FUNC_SUFFIX}"
        PREFIX "${FUNC_PREFIX}")

    execute_process(
        COMMAND ${FUNC_COMMAND} --list-sources
        WORKING_DIRECTORY "${FUNC_WORKING_DIRECTORY}"
        OUTPUT_VARIABLE _listing
        COMMAND_ERROR_IS_FATAL ANY
    )
    qm_get_qt_modules(_used "${_listing}" ${_where})

    # A Qt library in the install tree, such as one of an earlier deployment, is a binary that the
    # script names rather than a dependency that it lists. Frameworks are directories.
    file(GLOB_RECURSE _installed LIST_DIRECTORIES true "${FUNC_WORKING_DIRECTORY}/*")
    string(JOIN "\n" _installed ${_installed})
    qm_get_qt_modules(_installed_modules "${_installed}" ${_where})
    list(APPEND _used ${_installed_modules})
    list(REMOVE_DUPLICATES _used)

    set(_search)

    foreach(_dir IN LISTS FUNC_SEARCHING_PATHS)
        list(APPEND _search -L "${_dir}")
    endforeach()

    set(_examined ${FUNC_EXCLUDE})
    set(_selected)

    while(TRUE)
        qm_get_qt_plugins(_candidates MODULES ${_used} EXCLUDE ${_examined} ${_plugin_where})

        if(NOT _candidates)
            break()
        endif()

        foreach(_plugin IN LISTS _candidates)
            list(APPEND _examined "${_plugin}")
            string(FIND "${_plugin}" "/" _slash)
            string(SUBSTRING "${_plugin}" 0 ${_slash} _type)
            math(EXPR _slash "${_slash} + 1")
            string(SUBSTRING "${_plugin}" ${_slash} -1 _name)
            set(_file "${FUNC_PLUGINS_DIR}/${_type}/${FUNC_PREFIX}${_name}${FUNC_SUFFIX}")

            execute_process(
                COMMAND "${FUNC_CORECMD}" deploy "${_file}" ${_search} -s -n --list source
                OUTPUT_VARIABLE _plugin_listing
                ERROR_VARIABLE _plugin_error
                RESULT_VARIABLE _result
            )

            if(NOT _result EQUAL 0)
                message(WARNING "The dependencies of the Qt plugin ${_plugin} are unknown, and "
                    "the plugin is not deployed: ${_plugin_error}")
                continue()
            endif()

            qm_get_qt_modules(_needed "${_plugin_listing}" ${_where})
            set(_blocked)

            foreach(_module IN LISTS _needed)
                if(_module IN_LIST FUNC_EXCLUDE_MODULES)
                    set(_blocked on)
                endif()
            endforeach()

            if(_blocked)
                continue()
            endif()

            list(APPEND _selected "${_plugin}")
            list(APPEND _used ${_needed})
            list(REMOVE_DUPLICATES _used)
        endforeach()
    endwhile()

    list(SORT _selected)
    list(SORT _used)
    set(${_out} ${_selected} PARENT_SCOPE)
    set(${_out}_MODULES ${_used} PARENT_SCOPE)
endfunction()
