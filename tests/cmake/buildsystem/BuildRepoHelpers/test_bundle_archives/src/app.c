int qmtest_archive_value(void);
int qmtest_shared_value(void);

int main(void) { return qmtest_archive_value() + qmtest_shared_value() == 3 ? 0 : 1; }
