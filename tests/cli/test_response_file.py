"""Arguments may come from a file instead of the command line, which is how a
build system gets around the platform's limit on how long one may be.
"""

from harness import QmTestCase


class TestResponseFile(QmTestCase):
    def test_arguments_are_read_from_the_file(self):
        self.write("src/a.txt", "a")
        self.write("args.rsp", "copy\nsrc/a.txt\ndest\n")
        r = self.run_cmd("@args.rsp")
        self.assertOk(r)
        self.assertFile("dest/a.txt")

    def test_blank_lines_are_passed_over(self):
        self.write("src/a.txt", "a")
        self.write("args.rsp", "copy\n\n\nsrc/a.txt\n\ndest\n")
        r = self.run_cmd("@args.rsp")
        self.assertOk(r)
        self.assertFile("dest/a.txt")

    def test_surrounding_space_is_dropped(self):
        self.write("src/a.txt", "a")
        self.write("args.rsp", "  copy  \n\tsrc/a.txt\t\n   dest   \n")
        r = self.run_cmd("@args.rsp")
        self.assertOk(r)
        self.assertFile("dest/a.txt")

    def test_quotes_let_an_argument_keep_its_spaces(self):
        self.write("src dir/a.txt", "a")
        self.write("args.rsp", 'copy\n"src dir/"\n"dest dir"\n')
        r = self.run_cmd("@args.rsp")
        self.assertOk(r)
        self.assertFile("dest dir/a.txt")

    def test_options_may_come_from_the_file_too(self):
        self.write("src/a.txt", "a")
        self.write("args.rsp", "copy\nsrc/a.txt\ndest\n-V\n")
        r = self.run_cmd("@args.rsp")
        self.assertOk(r)
        self.assertOut(r, "Copy: from")

    def test_a_utf8_byte_order_mark_is_skipped(self):
        self.write("src/a.txt", "a")
        self.path("args.rsp").write_bytes(
            b"\xef\xbb\xbf" + b"copy\nsrc/a.txt\ndest\n"
        )
        r = self.run_cmd("@args.rsp")
        self.assertOk(r)
        self.assertFile("dest/a.txt")

    def test_a_response_file_that_is_not_there_is_refused(self):
        r = self.run_cmd("@no_such_file.rsp")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_a_response_file_carrying_a_bad_command_line_is_refused(self):
        self.write("args.rsp", "copy\nonlyone\n")
        r = self.run_cmd("@args.rsp")
        self.assertFails(r)
        self.assertOut(r, "Error:")

    def test_the_whole_command_may_come_from_the_file(self):
        self.write("args.rsp", "configure\nout.h\n-D\nFOO=1\n")
        r = self.run_cmd("@args.rsp")
        self.assertOk(r)
        self.assertFileContains("out.h", "#define FOO 1")
