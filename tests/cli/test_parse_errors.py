"""A command line that does not mean anything must say so and exit non-zero,
rather than doing part of the job or falling over."""

from harness import QmTestCase


class TestUnknownNames(QmTestCase):
    def test_an_unknown_command_is_refused(self):
        r = self.run_cmd("nosuchcommand")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_a_near_miss_is_offered_as_a_suggestion(self):
        r = self.run_cmd("deploi")
        self.assertFails(r)
        self.assertOut(r, "deploy")

    def test_an_unknown_option_is_refused(self):
        r = self.run_cmd("copy", "--nosuchoption", "a", "b")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_an_option_belonging_to_another_command_is_unknown_here(self):
        r = self.run_cmd("configure", "out.h", "--linkdir", "somewhere", "-d")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_a_multi_value_argument_takes_an_unknown_option_as_a_value(self):
        """A command whose last argument takes any number of values has no way to
        tell an unknown option from a value, so the token becomes one. It is the
        command's own check that then refuses it, if it has one."""
        r = self.run_cmd("copy", "--notanoption", "a", "b")
        self.assertFails(r)
        self.assertOut(r, "not a file or directory")
        self.assertOut(r, "--notanoption")


class TestNothingOnTheLine(QmTestCase):
    """The root command asks for help to be shown when a line carries nothing at
    all, and its help option is global, so this holds for a subcommand too."""

    def test_a_subcommand_with_nothing_on_its_line_shows_its_help(self):
        for command in ("copy", "touch", "configure", "rmdir", "incsync", "deploy"):
            with self.subTest(command=command):
                r = self.run_cmd(command)
                self.assertOk(r)
                self.assertOut(r, f"qmcorecmd {command}")
                self.assertNotOut(r, "Error:")


class TestMissingArguments(QmTestCase):
    """Once a line carries anything at all, what is missing from it is an error."""

    def test_copy_with_a_source_but_no_destination_is_refused(self):
        r = self.run_cmd("copy", "onlyone")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_incsync_with_only_a_source_is_refused(self):
        r = self.run_cmd("incsync", "src")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_configure_with_only_an_option_is_refused(self):
        r = self.run_cmd("configure", "-d")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_touch_with_only_an_option_is_refused(self):
        r = self.run_cmd("touch", "-V")
        self.assertFails(r)
        self.assertOut(r, "Error:")


class TestArgumentCounts(QmTestCase):
    def test_touch_takes_two_arguments_and_no_more(self):
        for name in ("a.txt", "b.txt", "c.txt"):
            self.write(name, name)
        r = self.run_cmd("touch", "a.txt", "b.txt", "c.txt")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_an_option_needing_a_value_and_not_given_one_is_refused(self):
        r = self.run_cmd("configure", "out.h", "--project")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_a_two_argument_option_given_only_one_is_refused(self):
        self.mkdir("src")
        r = self.run_cmd("incsync", "src", "dest", "-i", "onlyregex")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_an_option_given_more_often_than_it_may_be_is_refused(self):
        r = self.run_cmd("configure", "out.h", "-p", "one", "-p", "two", "-d")
        self.assertFails(r)
        self.assertOut(r, "Error:")


class TestFailuresFromTheWork(QmTestCase):
    """Not the parse, but what the command found once it started."""

    def test_copying_something_that_is_not_there_is_refused(self):
        r = self.run_cmd("copy", "no_such_file.txt", "dest")
        self.assertFails(r)
        self.assertOut(r, "not a file or directory")

    def test_touching_a_directory_is_refused(self):
        self.mkdir("adir")
        r = self.run_cmd("touch", "adir")
        self.assertFails(r)
        self.assertOut(r, "not a regular file")

    def test_touching_against_a_reference_that_is_not_there_is_refused(self):
        self.write("a.txt", "a")
        r = self.run_cmd("touch", "a.txt", "no_such_reference.txt")
        self.assertFails(r)
        self.assertOut(r, "not a regular file")

    def test_syncing_from_something_that_is_not_a_directory_is_refused(self):
        self.write("notadir.txt", "x")
        r = self.run_cmd("incsync", "notadir.txt", "dest")
        self.assertFails(r)
        self.assertOut(r, "not a directory")


class TestNothingIsLeftBehind(QmTestCase):
    def test_a_refused_copy_writes_nothing(self):
        r = self.run_cmd("copy", "no_such_file.txt", "dest")
        self.assertFails(r)
        self.assertNoDir("dest")

    def test_a_refused_configure_writes_no_header(self):
        r = self.run_cmd("configure", "out.h", "--project")
        self.assertFails(r)
        self.assertNoFile("out.h")

    def test_a_refused_incsync_writes_nothing(self):
        self.write("notadir.txt", "x")
        r = self.run_cmd("incsync", "notadir.txt", "dest")
        self.assertFails(r)
        self.assertNoDir("dest")
