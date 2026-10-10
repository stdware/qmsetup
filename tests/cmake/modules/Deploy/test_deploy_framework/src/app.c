int qmtest_fw_value(void);

// Exits with 0 only if the framework and its dependency both load.
int main(void) { return qmtest_fw_value() == 6 ? 0 : 1; }
