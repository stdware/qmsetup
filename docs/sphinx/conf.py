# Sphinx, for the reference pages built out of the comments in cmake/.
#
# The comments are written the way CMake writes its own: a bracket comment whose
# first line is `.rst:`, which sphinxcontrib.moderncmakedomain extracts with the
# `cmake-module` directive. Every .rst under here is a stub naming one module,
# so a module is documented in the module and nothing here has to be kept in
# step with it.
#
# In a directory of its own, the rest of docs/ being written by hand and read
# where it sits rather than built into anything.
#
# A module with no `.rst:` comment in it renders as an empty page rather than as
# an error, and a command whose comment nobody converted is simply absent, so
# neither shows up as a failure here. What catches that is the count, which the
# CI documentation job asserts.
#
#   pip install sphinx sphinxcontrib-moderncmakedomain
#   sphinx-build -b html -W docs/sphinx docs/sphinx/_build

import os
from pathlib import Path

from sphinxcontrib.moderncmakedomain.cmake import CMakeModule

project = "qmsetup"
copyright = "Stdware Collections"

extensions = ["sphinxcontrib.moderncmakedomain"]

# So that :cmake:command:`qm_foo` can be written as :command:`qm_foo`, and a bare
# code block is CMake unless it says otherwise.
primary_domain = "cmake"
highlight_language = "cmake"

html_theme = "alabaster"
exclude_patterns = ["_build"]

# No "page source" link and no copy of the sources beside the pages. Every source
# under here is a one line stub, so what the link offers a reader is the name of
# a file rather than the text they are looking at.
html_copy_source = False
html_show_sourcelink = False


# Where the repository is, said once.
#
# The stubs name their module from here, as `cmake/modules/Deploy.cmake`, so that
# none of them counts how deep it was filed and moving one changes nothing in it.
_source_dir = Path(__file__).resolve().parent
_repo_root = _source_dir.parents[1]

# A leading slash is how the directive underneath spells "from the Sphinx source
# directory", and this is the way back out of it. Worked out rather than written,
# so that it is right wherever this file is moved to.
_root_from_source = os.path.relpath(_repo_root, _source_dir).replace(os.sep, "/")


class QmModule(CMakeModule):
    """`cmake-module`, given a path from the top of the repository.

    An absolute path cannot be handed to the directive underneath, which reads
    one as relative to the Sphinx source directory whatever the platform calls a
    root, so the way out is worked out above and put on the front here.
    """

    def run(self):
        self.arguments[0] = f"/{_root_from_source}/{self.arguments[0]}"
        return super().run()


def setup(app):
    app.add_directive("qm-module", QmModule)
