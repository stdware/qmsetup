/* A plugin that brings a branch of its own along. */
#include "fixture.h"

int qmtest_audio_value(void);

QMTEST_EXPORT int qmtest_plugin_b_entry(void) {
    return qmtest_audio_value();
}
