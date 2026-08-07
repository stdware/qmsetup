/* Mine. A plugin over what the application already carries. */
#include "fixture.h"

int qmtest_core_value(void);

QMTEST_EXPORT int qmtest_plugin1_entry(void) {
    return qmtest_core_value();
}
