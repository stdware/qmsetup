#include "fixture.h"

/* Inside a real macOS framework bundle, so that a deployment has to carry the
   bundle across rather than a file. */
QMTEST_EXPORT int qmtest_bundled_value(void) { return 7; }
