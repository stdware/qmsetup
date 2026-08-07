"""The help page, the version, and the way both are reached."""

from harness import QmTestCase


class TestRootHelp(QmTestCase):
    def test_a_bare_command_line_prints_the_help(self):
        r = self.run_cmd()
        self.assertOk(r)
        self.assertOut(r, "Usage:")
        self.assertOut(r, "Cross-platform utility commands")

    def test_long_and_short_spellings_print_the_same_page(self):
        long_form = self.run_cmd("--help")
        short_form = self.run_cmd("-h")
        self.assertOk(long_form)
        self.assertOk(short_form)
        self.assertEqual(long_form.out, short_form.out)

    def test_every_command_is_listed(self):
        r = self.run_cmd("--help")
        self.assertOk(r)
        for command in ("copy", "rmdir", "touch", "configure", "incsync", "deploy"):
            self.assertOut(r, command)

    def test_the_catalogue_puts_commands_under_their_headings(self):
        r = self.run_cmd("--help")
        self.assertOk(r)
        self.assertOut(r, "Filesystem Commands:")
        self.assertOut(r, "Buildsystem Commands:")
        self.assertOutOrder(r, "Filesystem Commands:", "copy")
        self.assertOutOrder(r, "touch", "Buildsystem Commands:")
        self.assertOutOrder(r, "Buildsystem Commands:", "configure")

    def test_the_page_is_laid_out_in_a_fixed_order(self):
        r = self.run_cmd("--help")
        self.assertOk(r)
        self.assertOutOrder(r, "Description:", "Usage:")
        self.assertOutOrder(r, "Usage:", "Options:")
        self.assertOutOrder(r, "Options:", "Filesystem Commands:")

    def test_the_prologue_and_epilogue_frame_the_page(self):
        r = self.run_cmd("--help")
        self.assertOk(r)
        self.assertOut(r, "QMSetup Core Utility Command")
        self.assertOut(r, "Copyright")
        self.assertOutOrder(r, "QMSetup Core Utility Command", "Description:")
        self.assertOutOrder(r, "Filesystem Commands:", "Copyright")

    def test_the_help_option_is_listed_among_the_options(self):
        r = self.run_cmd("--help")
        self.assertOk(r)
        self.assertOut(r, "-h, --help")
        self.assertOut(r, "-v, --version")


class TestVersion(QmTestCase):
    def test_version_prints_a_version(self):
        r = self.run_cmd("--version")
        self.assertOk(r)
        self.assertRegex(r.out, r"\d+\.\d+\.\d+")

    def test_version_does_not_print_the_help(self):
        r = self.run_cmd("--version")
        self.assertOk(r)
        self.assertNotOut(r, "Usage:")

    def test_the_short_spelling_means_the_same(self):
        self.assertEqual(self.run_cmd("-v").out, self.run_cmd("--version").out)


class TestSubcommandHelp(QmTestCase):
    """--help is global, so it answers for a subcommand as well as for the root."""

    def test_copy_help_names_its_own_arguments_and_options(self):
        r = self.run_cmd("copy", "--help")
        self.assertOk(r)
        self.assertOut(r, "Copy files or directories if different")
        for token in ("src", "dest", "--exclude", "--force", "--verbose"):
            self.assertOut(r, token)

    def test_the_usage_line_names_the_path_down_to_the_subcommand(self):
        r = self.run_cmd("deploy", "--help")
        self.assertOk(r)
        self.assertOut(r, "qmcorecmd deploy")

    def test_a_multi_value_argument_is_marked_as_one(self):
        r = self.run_cmd("copy", "--help")
        self.assertOk(r)
        self.assertOut(r, "<src>...")

    def test_an_optional_argument_is_marked_as_one(self):
        r = self.run_cmd("touch", "--help")
        self.assertOk(r)
        self.assertOut(r, "[<ref file>]")

    def test_configure_help_names_its_options(self):
        r = self.run_cmd("configure", "--help")
        self.assertOk(r)
        self.assertOut(r, "Generate configuration header")
        for token in ("--define", "--project", "--warning", "--dryrun", "--force"):
            self.assertOut(r, token)

    def test_incsync_help_shows_the_two_arguments_of_its_include_option(self):
        r = self.run_cmd("incsync", "--help")
        self.assertOk(r)
        self.assertOut(r, "--include")
        self.assertOut(r, "regex")
        self.assertOut(r, "subdir")

    def test_deploy_help_names_its_options(self):
        r = self.run_cmd("deploy", "--help")
        self.assertOk(r)
        for token in ("--linkdir", "--linkdirs-file", "--standard", "--out"):
            self.assertOut(r, token)

    def test_a_subcommand_does_not_list_another_subcommands_options(self):
        r = self.run_cmd("rmdir", "--help")
        self.assertOk(r)
        self.assertOut(r, "Remove empty directories recursively")
        self.assertNotOut(r, "--linkdir")
        self.assertNotOut(r, "--define")

    def test_every_subcommand_answers_help(self):
        for command in ("copy", "rmdir", "touch", "configure", "incsync", "deploy"):
            with self.subTest(command=command):
                r = self.run_cmd(command, "--help")
                self.assertOk(r)
                self.assertOut(r, f"qmcorecmd {command}")
