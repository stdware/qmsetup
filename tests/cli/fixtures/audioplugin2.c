/* Third party. The plugin that drags in a library the application never
   linked. */
#include "fixture.h"

int qmtest_codec_value(void);

QMTEST_EXPORT int qmtest_audioplugin2_entry(void) {
    return qmtest_codec_value();
}
