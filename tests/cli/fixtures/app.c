/* Names render alone. util and base are reached only by following it. */

int qmtest_render_value(void);

int main(void) {
    return qmtest_render_value() == 3 ? 0 : 1;
}
