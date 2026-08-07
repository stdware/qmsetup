/* Depends on util, and so on base only through it. */
#include "fixture.h"

int qmtest_util_value(void);

QMTEST_EXPORT int qmtest_render_value(void) {
    return qmtest_util_value() + 1;
}
