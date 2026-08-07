#include "fixture.h"

/* Inside a real macOS framework bundle, so that a deployment has to carry the
   bundle across rather than a file.

   It needs another framework and an ordinary library, so that resolving it is
   not the end of the walk. Reaching either of them means going into this bundle
   for the library, reading what that names, and coming back out. */
QMTEST_EXPORT int qmtest_deeper_value(void);
QMTEST_EXPORT int qmtest_plainlib_value(void);

QMTEST_EXPORT int qmtest_bundled_value(void) {
    return qmtest_deeper_value() + qmtest_plainlib_value();
}
