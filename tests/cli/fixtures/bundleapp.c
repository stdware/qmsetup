#include "fixture.h"

QMTEST_EXPORT int qmtest_bundled_value(void);

/* Links the framework, and is what a deployment is pointed at. */
int main(void) { return qmtest_bundled_value() - 7; }
