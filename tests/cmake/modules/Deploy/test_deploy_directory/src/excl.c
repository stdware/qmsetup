#include "lib.h"

QMTEST_EXPORT int qmtest_excl_dep_value(void);

// Installed. Its dependency matches EXCLUDE and is therefore not deployed.
QMTEST_EXPORT int qmtest_excl_value(void) { return qmtest_excl_dep_value() + 1; }
