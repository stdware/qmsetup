# qm_import and qm_import_all, which bring the modules in, and qm_find_package,
# which brings in a find script.
#
# All three work out a file name from what they are given and include it, so
# what there is to check is which file that turns out to be and what happens
# when it is not there.

include(${QMTEST_HARNESS})

# ------------------------------------------------------------------
# qm_import
# ------------------------------------------------------------------

# The suffix may be left off or written out.
qm_import(Preprocess)
qmtest_command("a module named without its suffix" qm_add_definition)

qm_import(Filesystem.cmake)
qmtest_command("and one named with it" qm_add_copy_command)

# Several at once.
qm_import(CompilerOptions Translate)
qmtest_command("several named at once" qm_compiler_max_warnings)
qmtest_command("all of them" qm_add_translation)

# Bringing one in twice is what an include guard is for, and is not an error.
qm_import(Preprocess)
qmtest_equal("a module brought in twice is not an error" "reached here" "reached here")

qmtest_script_fails("a module that is not there is refused"
    "not found"
    "qm_import(NoSuchModule)")

# ------------------------------------------------------------------
# qm_import_all
#
# Every module in the directory, for a project that would rather not name them
# one at a time.
# ------------------------------------------------------------------

qm_import_all()

qmtest_command("everything is brought in" qm_deploy_directory)
qmtest_command("all of it" qm_setup_doxygen)
qmtest_command("the whole of it" qm_install_qml_modules)

# ------------------------------------------------------------------
# qm_find_package
#
# The scripts under find-modules, which are named with or without the Find
# prefix the file itself may carry.
# ------------------------------------------------------------------

# Nothing of VC-LTL happens away from MSVC, which a script run is, so this is
# the name being placed rather than the script doing anything.
qm_find_package(VC-LTL)
qmtest_equal("a find script is brought in by its name" "reached here" "reached here")

qm_find_package(VC-LTL.cmake)
qmtest_equal("named with its suffix as well" "reached here" "reached here")

qmtest_script_fails("a find script that is not there is refused"
    "not found"
    "qm_find_package(NoSuchPackage)")

qmtest_report()
