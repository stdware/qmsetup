# What the installation of a module laid out in a bundle holds without <proj>_DEVEL.
#
# Included by testing/build.cmake once the tree exists. `_prefix` is where it was installed and
# `_build` is the build of the project.

set(_frameworks "QmTestBundle.app/Contents/Frameworks")

# The case occurs: the build puts the archive into the bundle, which the copy carries along.
qmtest_exists("the build puts the archive into the bundle"
    "${_build}/out/${_frameworks}/libqmtest_archive.a")

qmtest_exists("the bundle is installed" "${_prefix}/QmTestBundle.app/Contents/MacOS/QmTestBundle")
qmtest_not_exists("the archive is removed from the installed bundle"
    "${_prefix}/${_frameworks}/libqmtest_archive.a")
qmtest_exists("a shared library stays" "${_prefix}/${_frameworks}/libqmtest_shared.dylib")
qmtest_exists("and a file named .a that is no archive"
    "${_prefix}/QmTestBundle.app/Contents/Resources/notes.a")
