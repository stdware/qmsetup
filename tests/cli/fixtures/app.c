/* Mine. Links core alone, so util, audio and render are reached only by
   following it. */

int qmtest_core_value(void);

int main(void) {
    return qmtest_core_value() > 0 ? 0 : 1;
}
