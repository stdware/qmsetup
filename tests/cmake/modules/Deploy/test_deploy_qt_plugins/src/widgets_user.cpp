#include <QtWidgets/QApplication>

#ifdef _WIN32
#  define QMTEST_EXPORT __declspec(dllexport)
#else
#  define QMTEST_EXPORT __attribute__((visibility("default")))
#endif

// A library outside Qt that links QtWidgets. The call requires symbols that QtWidgets exports, so
// that the linker records the dependency.
QMTEST_EXPORT int qmtest_widgets_user_value() {
    return QApplication::startDragDistance();
}
