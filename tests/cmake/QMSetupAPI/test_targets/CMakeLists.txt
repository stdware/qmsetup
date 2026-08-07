# The QMSetupAPI functions that work on targets.
#
# A target needs a project to live in, so this is a project, configured by
# testing/configure.cmake. Nothing is built. What these functions do is set
# target properties, and a property can be read back as soon as it is set.
#
# Compiler and linker flags below are made up. They are never handed to a
# compiler, since nothing here is built, and what is being checked is that the
# function put them where it said it would.

cmake_minimum_required(VERSION 3.19)
project(qmtest_targets C)

include(${QMTEST_HARNESS})

set(_here ${CMAKE_CURRENT_SOURCE_DIR})

# ------------------------------------------------------------------
# qm_configure_target, on a library of the ordinary kind
# ------------------------------------------------------------------

add_library(mylib STATIC src/lib.c)
qm_configure_target(mylib
    DEFINES BOTH_WAYS
    DEFINES_PRIVATE MINE_ALONE
    DEFINES_INTERFACE THEIRS_ALONE
    INCLUDE ${_here}/include
    INCLUDE_PRIVATE ${_here}/src
    CCFLAGS -qmtest-private-flag
    CCFLAGS_PUBLIC -qmtest-public-flag
    LDFLAGS -qmtest-link-flag
)

get_target_property(_defs mylib COMPILE_DEFINITIONS)
get_target_property(_idefs mylib INTERFACE_COMPILE_DEFINITIONS)

qmtest_contains("DEFINES reaches the target itself" "${_defs}" "BOTH_WAYS")
qmtest_contains("and whatever links it" "${_idefs}" "BOTH_WAYS")
qmtest_contains("DEFINES_PRIVATE reaches the target" "${_defs}" "MINE_ALONE")
qmtest_lacks("and stops there" "${_idefs}" "MINE_ALONE")
qmtest_contains("DEFINES_INTERFACE reaches whatever links it" "${_idefs}" "THEIRS_ALONE")
qmtest_lacks("and not the target itself" "${_defs}" "THEIRS_ALONE")

get_target_property(_inc mylib INCLUDE_DIRECTORIES)
get_target_property(_iinc mylib INTERFACE_INCLUDE_DIRECTORIES)

qmtest_contains("INCLUDE is on the target" "${_inc}" "${_here}/include")
qmtest_contains("and on its interface" "${_iinc}" "${_here}/include")
qmtest_contains("INCLUDE_PRIVATE is on the target" "${_inc}" "${_here}/src")
qmtest_lacks("and not on its interface" "${_iinc}" "${_here}/src")

get_target_property(_ccflags mylib COMPILE_OPTIONS)
get_target_property(_iccflags mylib INTERFACE_COMPILE_OPTIONS)
qmtest_contains("CCFLAGS is private" "${_ccflags}" "-qmtest-private-flag")
qmtest_lacks("and does not reach the interface" "${_iccflags}" "-qmtest-private-flag")
qmtest_contains("CCFLAGS_PUBLIC reaches the interface" "${_iccflags}" "-qmtest-public-flag")

get_target_property(_ldflags mylib LINK_OPTIONS)
qmtest_contains("LDFLAGS is on the target" "${_ldflags}" "-qmtest-link-flag")

# ------------------------------------------------------------------
# The directories a pattern stands for
#
# include/ has a and b under it, so `include/*` is the three of them.
# ------------------------------------------------------------------

add_library(globlib STATIC src/lib.c)
qm_configure_target(globlib INCLUDE "${_here}/include/*")

get_target_property(_inc globlib INCLUDE_DIRECTORIES)
qmtest_contains("a pattern brings the directory itself" "${_inc}" "${_here}/include")
qmtest_contains("and what is under it" "${_inc}" "${_here}/include/a")
qmtest_contains("all of it" "${_inc}" "${_here}/include/b")

# A file under one of them is a file, not a directory to include.
qmtest_lacks("and nothing that is not a directory" "${_inc}" "${_here}/include/root.h")

# ------------------------------------------------------------------
# Link directories
# ------------------------------------------------------------------

add_library(linklib STATIC src/lib.c)
qm_configure_target(linklib
    LINKDIR ${_here}/include
    LINKDIR_PRIVATE ${_here}/src
)

get_target_property(_dirs linklib LINK_DIRECTORIES)
get_target_property(_idirs linklib INTERFACE_LINK_DIRECTORIES)
qmtest_contains("LINKDIR is on the target" "${_dirs}" "${_here}/include")
qmtest_contains("and on its interface" "${_idirs}" "${_here}/include")
qmtest_contains("LINKDIR_PRIVATE is on the target" "${_dirs}" "${_here}/src")
qmtest_lacks("and not on its interface" "${_idirs}" "${_here}/src")

# On its own, so that it cannot be answered by what another argument put there.
add_library(ilinklib STATIC src/lib.c)
qm_configure_target(ilinklib LINKDIR_INTERFACE ${_here}/include)

get_target_property(_idirs ilinklib INTERFACE_LINK_DIRECTORIES)
get_target_property(_dirs ilinklib LINK_DIRECTORIES)
qmtest_contains("LINKDIR_INTERFACE reaches the interface" "${_idirs}" "${_here}/include")
qmtest_lacks("and not the target itself" "${_dirs}" "${_here}/include")

# ------------------------------------------------------------------
# Language features
#
# The standard is set as a property as well as a feature, so that a language
# server sees the -std flag rather than having to guess the default.
# ------------------------------------------------------------------

add_library(featlib STATIC src/lib.c)
qm_configure_target(featlib FEATURES c_std_11)

get_target_property(_features featlib INTERFACE_COMPILE_FEATURES)
qmtest_contains("FEATURES reaches the interface" "${_features}" "c_std_11")

get_target_property(_std featlib C_STANDARD)
qmtest_equal("and the standard is set as a property too" "${_std}" "11")

# ------------------------------------------------------------------
# An interface library, which has nothing but an interface
# ------------------------------------------------------------------

add_library(ifacelib INTERFACE)
qm_configure_target(ifacelib
    DEFINES NOTHING_BUT_INTERFACE
    INCLUDE ${_here}/include
)

get_target_property(_idefs ifacelib INTERFACE_COMPILE_DEFINITIONS)
get_target_property(_iinc ifacelib INTERFACE_INCLUDE_DIRECTORIES)
qmtest_contains("what would be public becomes interface" "${_idefs}" "NOTHING_BUT_INTERFACE")
qmtest_contains("and so do the include directories" "${_iinc}" "${_here}/include")

# ------------------------------------------------------------------
# qm_export_defines
# ------------------------------------------------------------------

add_library(exportstatic STATIC src/lib.c)
qm_export_defines(exportstatic)

get_target_property(_defs exportstatic COMPILE_DEFINITIONS)
get_target_property(_idefs exportstatic INTERFACE_COMPILE_DEFINITIONS)
qmtest_contains("a static library says so to whatever links it" "${_idefs}" "EXPORTSTATIC_STATIC")
qmtest_contains("and knows it is the library being built" "${_defs}" "EXPORTSTATIC_LIBRARY")

add_library(exportshared SHARED src/lib.c)
qm_export_defines(exportshared)

get_target_property(_defs exportshared COMPILE_DEFINITIONS)
get_target_property(_idefs exportshared INTERFACE_COMPILE_DEFINITIONS)
qmtest_contains("a shared library knows it is the one being built" "${_defs}" "EXPORTSHARED_LIBRARY")
qmtest_lacks("and says nothing about being static" "${_idefs}" "EXPORTSHARED_STATIC")

# The name becomes a macro, so what cannot be in one is replaced.
add_library(export-with-dashes STATIC src/lib.c)
qm_export_defines(export-with-dashes)

get_target_property(_idefs export-with-dashes INTERFACE_COMPILE_DEFINITIONS)
qmtest_contains("a name that is not an identifier is made into one" "${_idefs}" "EXPORT_WITH_DASHES_STATIC")

add_library(exportnamed STATIC src/lib.c)
qm_export_defines(exportnamed PREFIX MYPREFIX)

get_target_property(_idefs exportnamed INTERFACE_COMPILE_DEFINITIONS)
qmtest_contains("PREFIX names them instead" "${_idefs}" "MYPREFIX_STATIC")

add_library(exporttokens STATIC src/lib.c)
qm_export_defines(exporttokens STATIC IS_STATIC LIBRARY IS_BUILDING)

get_target_property(_defs exporttokens COMPILE_DEFINITIONS)
get_target_property(_idefs exporttokens INTERFACE_COMPILE_DEFINITIONS)
qmtest_contains("STATIC names the whole macro" "${_idefs}" "IS_STATIC")
qmtest_contains("and LIBRARY the other" "${_defs}" "IS_BUILDING")

# ------------------------------------------------------------------
# qm_include_recursive
# ------------------------------------------------------------------

add_library(reclib STATIC src/lib.c)
qm_include_recursive(reclib PRIVATE ${_here}/include)

get_target_property(_inc reclib INCLUDE_DIRECTORIES)
qmtest_contains("the directory named" "${_inc}" "${_here}/include")
qmtest_contains("and everything under it" "${_inc}" "${_here}/include/a")
qmtest_contains("all of it" "${_inc}" "${_here}/include/b")

# ------------------------------------------------------------------
# qm_collect_targets
#
# Last, so that it sees everything defined above.
# ------------------------------------------------------------------

add_subdirectory(sub)

add_executable(plainapp src/app.c)

qm_collect_targets(_all)
qmtest_contains("everything in this directory" "${_all}" "mylib")
qmtest_contains("and everything in the ones below it" "${_all}" "qmtest_sub_static")

qm_collect_targets(_executables EXECUTABLE)
qmtest_contains("EXECUTABLE asks for the executables" "${_executables}" "plainapp")
qmtest_lacks("and leaves the libraries" "${_executables}" "mylib")

qm_collect_targets(_shared SHARED)
qmtest_contains("SHARED asks for the shared ones" "${_shared}" "exportshared")
qmtest_contains("wherever they are" "${_shared}" "qmtest_sub_shared")
qmtest_lacks("and leaves the static ones" "${_shared}" "mylib")

qm_collect_targets(_static STATIC)
qmtest_contains("STATIC asks for the static ones" "${_static}" "mylib")
qmtest_lacks("and leaves the shared ones" "${_static}" "exportshared")

qm_collect_targets(_interface INTERFACE)
qmtest_contains("INTERFACE asks for the interface ones" "${_interface}" "ifacelib")
qmtest_lacks("and leaves the rest" "${_interface}" "mylib")

qm_collect_targets(_both SHARED STATIC)
qmtest_contains("two kinds asked for at once" "${_both}" "mylib")
qmtest_contains("gives both" "${_both}" "exportshared")
qmtest_lacks("and still leaves the rest" "${_both}" "ifacelib")

# DIRECTORY says where to start, so a subdirectory answers with its own.
qm_collect_targets(_sub DIRECTORY ${_here}/sub)
qmtest_contains("DIRECTORY starts somewhere else" "${_sub}" "qmtest_sub_static")
qmtest_lacks("and does not climb back out" "${_sub}" "mylib")

qmtest_report()
