# qm_get_qt_modules, which recognizes the Qt libraries in a listing by their
# file names.
#
# The module descriptions are made here rather than taken from a Qt, so that
# the answers are known and nothing needs Qt installed. A description is all
# that the function reads of an installation, and only whether it exists.

include(${QMTEST_HARNESS})

qm_import(private/QtPlugins)

set(_descriptions "${QMTEST_WORK_DIR}/modules")
file(REMOVE_RECURSE "${_descriptions}")

# Qmld is a module whose name ends with d, as no module of Qt does, so that the
# d of a debug library is seen to be told apart from it.
foreach(_module Core Gui Widgets Qmld)
    file(WRITE "${_descriptions}/${_module}.json" "{}")
endforeach()

function(_modules_of _out _listing)
    qm_get_qt_modules(_modules "${_listing}" DESCRIPTIONS "${_descriptions}")
    list(SORT _modules)
    set(${_out} "${_modules}" PARENT_SCOPE)
endfunction()

_modules_of(_found "C:/Qt/bin/Qt6Widgets.dll\nC:/Qt/bin/Qt6Cored.dll\n")
qmtest_equal("a release and a debug library on Windows" "${_found}" "Core;Widgets")

_modules_of(_found "/opt/qt/lib/libQt6Gui.so.6\n/Users/a/Qt/lib/QtCore.framework\n")
qmtest_equal("a library on Linux and a framework on macOS" "${_found}" "Core;Gui")

_modules_of(_found "/opt/qt/lib/libQt6Qmld.so.6\n")
qmtest_equal("a module whose name ends with d keeps the d" "${_found}" "Qmld")

_modules_of(_found "/opt/qt/lib/libQt6Network.so.6\n/usr/lib/libz.so.1\n/opt/QtCore\n")
qmtest_equal("what names no module with a description is passed over" "${_found}" "")

_modules_of(_found "D:/semi;colon/Qt6Gui.dll\nD:/other/Qt6Core.dll")
qmtest_equal("a path with a semicolon is read whole, as is a last line without a newline"
    "${_found}" "Core;Gui")

_modules_of(_found "")
qmtest_equal("an empty listing names no module" "${_found}" "")

qmtest_report()
