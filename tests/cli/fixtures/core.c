/* Mine. Links my own util and the third party's audio, which is what drags the
   third party into my deployment. */
#include "fixture.h"

int qmtest_util_value(void);
int qmtest_audio_value(void);

QMTEST_EXPORT int qmtest_core_value(void) {
    return qmtest_util_value() + qmtest_audio_value();
}
