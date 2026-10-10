int qmtest_fw_dep_value(void);

// The library inside the framework. It loads qmtest_fw_dep through its rpaths.
int qmtest_fw_value(void) { return qmtest_fw_dep_value() + 1; }
