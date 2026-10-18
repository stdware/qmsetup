# qm_get_qt_plugins, against a real Qt 6.
#
# Registered only where tests/cmake/CMakeLists.txt found a Qt 6, which older
# than 6.9 is given what it does not describe. Nothing is
# built: the function reads the module descriptions and the plugin directories
# of the installation, and what it returns is a list to read back.
#
# The plugins differ between the platforms and between the builds of Qt, so the
# checks name what every build has: one platform plugin, which is not one of the
# platform plugins that only tests use, no debug plugin, and the plugins of a
# type that Gui declares.

cmake_minimum_required(VERSION 3.19)
project(qmtest_get_qt_plugins CXX)

include(${QMTEST_HARNESS})

qm_import(private/QtPlugins)
qm_find_qt(Core)

# Qt 6.9 is the first to set the directory of the module descriptions and to
# name its platforms in them. An older Qt is told both, as its caller would.
set(_platform_args)

if(Qt6_VERSION VERSION_LESS 6.9)
    set(QT6_INSTALL_DESCRIPTIONSDIR modules)

    if(WIN32)
        set(_platform_args PLATFORMS windows)
    elseif(APPLE)
        set(_platform_args PLATFORMS cocoa)
    else()
        set(_platform_args PLATFORMS xcb)
    endif()
endif()

qm_get_qt_plugins(_plugins MODULES Gui Widgets ${_platform_args})

set(_platforms ${_plugins})
list(FILTER _platforms INCLUDE REGEX "^platforms/")
list(LENGTH _platforms _count)
qmtest_equal("one platform plugin is selected, the one Qt names for the platform"
    "${_count}" "1")
qmtest_lacks("and not the minimal platform" "${_plugins}" "platforms/qminimal")
qmtest_lacks("nor the offscreen platform" "${_plugins}" "platforms/qoffscreen")

set(_imageformats ${_plugins})
list(FILTER _imageformats INCLUDE REGEX "^imageformats/")
qmtest_true("the plugins of a type that Gui declares are selected" "${_imageformats}")

# A debug plugin is named after its release plugin with d on Windows and with
# _debug on macOS. Neither is selected beside the release plugin.
set(_debug)

foreach(_plugin IN LISTS _plugins)
    if("${_plugin}d" IN_LIST _plugins OR "${_plugin}_debug" IN_LIST _plugins)
        list(APPEND _debug "${_plugin}")
    endif()
endforeach()

qmtest_equal("no debug plugin is selected" "${_debug}" "")

qm_get_qt_plugins(_core MODULES Core)
qmtest_equal("Core declares no plugin type" "${_core}" "")

list(GET _imageformats 0 _excluded)
qm_get_qt_plugins(_without MODULES Gui Widgets EXCLUDE ${_excluded} ${_platform_args})
qmtest_lacks("EXCLUDE leaves a plugin out" "${_without}" "${_excluded}")
list(LENGTH _plugins _all)
list(LENGTH _without _rest)
math(EXPR _all "${_all} - 1")
qmtest_equal("and only that plugin" "${_rest}" "${_all}")

qmtest_report()
