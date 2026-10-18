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

# The first image format plugin is left out, and the first icon engine plugin
# is named by hand, both chosen here because the plugins differ between builds.
qm_get_qt_plugins(_imageformats MODULES Gui)
list(FILTER _imageformats INCLUDE REGEX "^imageformats/")
list(GET _imageformats 0 _excluded)
qm_get_qt_plugins(_iconengines MODULES Gui)
list(FILTER _iconengines INCLUDE REGEX "^iconengines/")
list(GET _iconengines 0 _named)

# check.cmake reads which plugins were chosen
file(WRITE "${CMAKE_BINARY_DIR}/chosen.cmake"
    "set(_excluded [==[${_excluded}]==])\nset(_named [==[${_named}]==])\n")

qm_deploy_directory("${CMAKE_INSTALL_PREFIX}"
    LIBRARY_DIR "${CMAKE_INSTALL_PREFIX}/qmtest_libs"
    PLUGIN_DIR "${CMAKE_INSTALL_PREFIX}/qmtest_plugins"
    PLUGINS "${_named}"
    QT_PLUGINS
    QT_PLUGINS_EXCLUDE "${_excluded}"
    QT_PLUGINS_EXCLUDE_MODULES Qml Quick
    STANDARD
    VERBOSE
    COMMENT "Deploying the Qt plugins the installed binaries need"
)
