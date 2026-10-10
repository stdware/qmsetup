#include "lib.h"

// Linked only by qmtest_excl_lib, not installed, and excluded from the deployment.
QMTEST_EXPORT int qmtest_excl_dep_value(void) { return 4; }
