# What QT_PLUGINS of qm_deploy_directory brought in.
#
# Included by testing/build.cmake once the tree exists. `_prefix` is where it
# was installed and `_build` where it was built, which holds the plugins that
# the project chose to name and to leave out.

include("${_build}/chosen.cmake")

set(_library_dir "${_prefix}/qmtest_libs")
set(_plugin_dir "${_prefix}/qmtest_plugins")

# Every deployed plugin, as <type>/<file name>
file(GLOB_RECURSE _files RELATIVE "${_plugin_dir}" "${_plugin_dir}/*")
set(_names)

foreach(_file IN LISTS _files)
    get_filename_component(_type "${_file}" DIRECTORY)
    get_filename_component(_name "${_file}" NAME_WE)
    string(REGEX REPLACE "^lib" "" _name "${_name}")
    list(APPEND _names "${_type}/${_name}")
endforeach()

# ------------------------------------------------------------------
# The modules worked out from the binaries
# ------------------------------------------------------------------

# QtWidgets is required by the library, and QtGui and QtCore by QtWidgets, so
# all three are deployed. Named by a pattern, a library being called something
# different on every platform.
file(GLOB _deployed RELATIVE "${_library_dir}" "${_library_dir}/*")

foreach(_module Core Gui Widgets)
    set(_found)

    foreach(_item IN LISTS _deployed)
        if(_item MATCHES "Qt6?${_module}")
            set(_found on)
        endif()
    endforeach()

    qmtest_true("Qt${_module} is deployed" "${_found}")
endforeach()

# ------------------------------------------------------------------
# The libraries of the system on Linux
# ------------------------------------------------------------------

# With STANDARD a library under a library directory of the system, such as libGL of the
# graphics driver and libxcb, which QtGui and the platform plugin require, is left to the
# machine. The ICU that Qt installs beside its libraries is deployed, because other systems
# lack its version.
if(CMAKE_HOST_UNIX AND NOT CMAKE_HOST_APPLE)
    set(_system)
    set(_icu)

    foreach(_item IN LISTS _deployed)
        if(_item MATCHES "^lib(GL|EGL|GLX|OpenGL|xcb)[.-]")
            list(APPEND _system "${_item}")
        elseif(_item MATCHES "^libicuuc[.]so")
            set(_icu on)
        endif()
    endforeach()

    qmtest_false("no library of the system is deployed" "${_system}")

    file(GLOB _qt_icu "${_qt_library_dir}/libicuuc.so*")

    if(_qt_icu)
        qmtest_true("the ICU of Qt is deployed" "${_icu}")
    endif()
endif()

# ------------------------------------------------------------------
# The plugins of those modules
# ------------------------------------------------------------------

set(_platforms ${_names})
list(FILTER _platforms INCLUDE REGEX "^platforms/")
list(LENGTH _platforms _count)
qmtest_equal("the one platform plugin of the platform is deployed, which Gui requires"
    "${_count}" "1")
qmtest_lacks("and not the minimal platform" "${_names}" "platforms/qminimal")

set(_imageformats ${_names})
list(FILTER _imageformats INCLUDE REGEX "^imageformats/")
qmtest_true("the image format plugins of Gui are deployed" "${_imageformats}")

# QT_PLUGINS_EXCLUDE_MODULES names Qml and Quick, so a plugin that requires Qt
# Quick, such as the input context of the virtual keyboard, is left out with
# what it requires. Without it, Qt Quick and the plugins of QML debugging came
# along. A Qt without the virtual keyboard passes these checks without
# exercising them.
set(_quick)

foreach(_item IN LISTS _deployed)
    if(_item MATCHES "Qt6?Quick")
        set(_quick on)
    endif()
endforeach()

qmtest_false("Qt Quick is not deployed if QT_PLUGINS_EXCLUDE_MODULES names it" "${_quick}")

set(_qmltooling ${_names})
list(FILTER _qmltooling INCLUDE REGEX "^qmltooling/")
qmtest_equal("nor a plugin of QML debugging" "${_qmltooling}" "")

# ------------------------------------------------------------------
# QT_PLUGINS_EXCLUDE and PLUGINS
# ------------------------------------------------------------------

qmtest_lacks("QT_PLUGINS_EXCLUDE leaves a plugin out" "${_names}" "${_excluded}")
qmtest_contains("a plugin of PLUGINS is deployed beside them" "${_names}" "${_named}")

# ------------------------------------------------------------------
# The release flavour only
# ------------------------------------------------------------------

if(WIN32)
    set(_debug ${_names})
    list(FILTER _debug INCLUDE REGEX "d$")
    set(_debug_beside)

    foreach(_name IN LISTS _debug)
        string(REGEX REPLACE "d$" "" _release "${_name}")

        if(_release IN_LIST _names)
            list(APPEND _debug_beside "${_name}")
        endif()
    endforeach()

    qmtest_equal("no debug plugin is deployed beside its release plugin" "${_debug_beside}" "")
endif()
