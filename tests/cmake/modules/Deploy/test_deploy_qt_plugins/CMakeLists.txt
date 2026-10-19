# QT_PLUGINS of qm_deploy_directory, against a real Qt 6.
#
# Registered only where tests/cmake/CMakeLists.txt found a Qt 6, and built and
# installed by testing/build.cmake. What is asserted is in check.cmake.
#
# The install tree holds one library that links QtWidgets and nothing else of
# Qt, and no plugin is named. The deployment has to work out from the installed
# binaries that QtWidgets, QtGui and QtCore are required, and deploy the
# plugins of those modules. One plugin is left out with QT_PLUGINS_EXCLUDE, and
# one is named with PLUGINS as well, so that the two lists are seen to combine.
# Qml and Quick are left out with QT_PLUGINS_EXCLUDE_MODULES, as windeployqt
# leaves them out for a program without QML.

cmake_minimum_required(VERSION 3.19)
project(qmtest_deploy_qt_plugins VERSION 1.0.0 LANGUAGES C CXX)

include(GNUInstallDirs)

include(${QMSETUP_API})

if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

qm_import(Deploy)
qm_find_qt(Widgets)

add_library(qmtest_widgets_user SHARED src/widgets_user.cpp)
target_link_libraries(qmtest_widgets_user PRIVATE Qt${QT_VERSION_MAJOR}::Widgets)

install(TARGETS qmtest_widgets_user
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Qt 6.9 is the first to set the directory of the module descriptions and to
# name its platforms in them. An older Qt is told both, as its caller would.
set(_platforms)

if(Qt6_VERSION VERSION_LESS 6.9)
    set(QT6_INSTALL_DESCRIPTIONSDIR modules)

    if(WIN32)
        set(_platforms windows)
    elseif(APPLE)
        set(_platforms cocoa)
    else()
        set(_platforms xcb)
    endif()
endif()

set(_platform_args)

if(_platforms)
    set(_platform_args PLATFORMS ${_platforms})
endif()

# The first image format plugin is left out, and the first icon engine plugin
# is named by hand, both chosen here because the plugins differ between builds.
qm_get_qt_plugins(_imageformats MODULES Gui ${_platform_args})
list(FILTER _imageformats INCLUDE REGEX "^imageformats/")
list(GET _imageformats 0 _excluded)
qm_get_qt_plugins(_iconengines MODULES Gui ${_platform_args})
list(FILTER _iconengines INCLUDE REGEX "^iconengines/")
list(GET _iconengines 0 _named)

# check.cmake reads which plugins were chosen, and the library directory of Qt
file(WRITE "${CMAKE_BINARY_DIR}/chosen.cmake"
    "set(_excluded [==[${_excluded}]==])\nset(_named [==[${_named}]==])\n"
    "set(_qt_library_dir [==[${QT6_INSTALL_PREFIX}/${QT6_INSTALL_LIBS}]==])\n")

# Without VERBOSE, unlike the other deployments here. windeps.bat once wrote
# "ECHO is off." in place of the absent -V, qmcorecmd failed on it, and the
# install went on as if nothing had been deployed.
qm_deploy_directory(.
    LIBRARY_DIR qmtest_libs
    PLUGIN_DIR qmtest_plugins
    PLUGINS "${_named}"
    QT_PLUGINS
    QT_PLUGINS_EXCLUDE "${_excluded}"
    QT_PLUGINS_EXCLUDE_MODULES Qml Quick
    QT_PLUGINS_PLATFORMS ${_platforms}
    STANDARD
    COMMENT "Deploying the Qt plugins the installed binaries need"
)
