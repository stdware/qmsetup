/* Depends on base. */
#include "fixture.h"

int qmtest_base_value(void);

QMTEST_EXPORT int qmtest_util_value(void) {
    return qmtest_base_value() + 1;
}
