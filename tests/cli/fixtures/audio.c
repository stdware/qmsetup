/* Depends on base, and on nothing else. Deploying the application alone must
   not bring this one along. */
#include "fixture.h"

int qmtest_base_value(void);

QMTEST_EXPORT int qmtest_audio_value(void) {
    return qmtest_base_value() + 10;
}
