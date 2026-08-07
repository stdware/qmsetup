/* Mine. A plugin that reaches past my own code into the third party. */
#include "fixture.h"

int qmtest_audio_value(void);

QMTEST_EXPORT int qmtest_plugin2_entry(void) {
    return qmtest_audio_value();
}
