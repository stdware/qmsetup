/* Third party. Their main library, the one my code links. */
#include "fixture.h"

int qmtest_render_value(void);

QMTEST_EXPORT int qmtest_audio_value(void) {
    return qmtest_render_value() + 1;
}
