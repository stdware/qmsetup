/* A plugin over what the application already carries. */
#include "fixture.h"

int qmtest_render_value(void);

QMTEST_EXPORT int qmtest_plugin_a_entry(void) {
    return qmtest_render_value();
}
