#include "lib.h"

QMTEST_EXPORT int qmtest_noexec_dep_value(void);

// Installed without execute permission. qmtest_noexec_dep is deployed only if
// the deployment processes this library.
QMTEST_EXPORT int qmtest_noexec_value(void) { return qmtest_noexec_dep_value() + 1; }
