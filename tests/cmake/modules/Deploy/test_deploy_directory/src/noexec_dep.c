#include "lib.h"

// Linked only by qmtest_noexec_lib, and not installed.
QMTEST_EXPORT int qmtest_noexec_dep_value(void) { return 3; }
