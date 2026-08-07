/* Third party. One of their plugins, which a deployment has to bring along
   even though nothing links it. */
#include "fixture.h"

int qmtest_audio_value(void);

QMTEST_EXPORT int qmtest_audioplugin1_entry(void) {
    return qmtest_audio_value();
}
