#include <QtXml/QDomDocument>

#ifdef _WIN32
#  define QMTEST_EXPORT __declspec(dllexport)
#else
#  define QMTEST_EXPORT __attribute__((visibility("default")))
#endif

// A library outside Qt that links QtXml. The call requires symbols that QtXml exports, so that the
// linker records the dependency.
QMTEST_EXPORT int qmtest_qt_user_value() {
    QDomDocument document;
    return document.isNull() ? 0 : 1;
}
