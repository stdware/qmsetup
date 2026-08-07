# The qm_* functions that work on targets.
#
# A target needs a project to live in, so unlike the rest of the tests this one
# is a project, configured by the run.cmake beside it. Nothing is built. What
# these functions do is set target properties, and a property can be read back
# as soon as it is set.
#
# Compiler and linker flags are made up. They are never handed to a compiler,
# since nothing here is built, and what is being checked is that the function
# put them where it said it would.

cmake_minimum_required(VERSION 3.19)
project(qmtest_cmake_project C)

include(${QMTEST_HARNESS})

qm_import(Preprocess)

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
# Definitions on a target, and on a directory
#
# Only the global and source scopes can be reached without a project, so these
# two are checked here.
# ------------------------------------------------------------------

set_property(GLOBAL PROPERTY CONFIG_DEFINITIONS "")

qm_add_definition(ON_THE_TARGET TARGET mylib)
qm_add_definition(WITH_A_VALUE 7 TARGET mylib)

get_property(_d TARGET mylib PROPERTY CONFIG_DEFINITIONS)
qmtest_equal("a definition put on a target" "${_d}" "ON_THE_TARGET;WITH_A_VALUE=7")

get_property(_g GLOBAL PROPERTY CONFIG_DEFINITIONS)
qmtest_equal("and nowhere else" "${_g}" "")

qm_remove_definition(ON_THE_TARGET TARGET mylib)
get_property(_d TARGET mylib PROPERTY CONFIG_DEFINITIONS)
qmtest_equal("and taken off it again" "${_d}" "WITH_A_VALUE=7")

qm_add_definition(ON_THE_DIRECTORY DIRECTORY ${_here})
get_property(_d DIRECTORY ${_here} PROPERTY CONFIG_DEFINITIONS)
qmtest_contains("a definition put on a directory" "${_d}" "ON_THE_DIRECTORY")

qm_remove_definition(ON_THE_DIRECTORY DIRECTORY ${_here})
get_property(_d DIRECTORY ${_here} PROPERTY CONFIG_DEFINITIONS)
qmtest_lacks("and taken off it again" "${_d}" "ON_THE_DIRECTORY")

# ------------------------------------------------------------------
# What Windows binaries carry
#
# The resource and the manifest are configured at once rather than built, so
# what they say can be read straight off the file. Nowhere else runs this.
# ------------------------------------------------------------------

if(WIN32)
    set(_res_dir "${CMAKE_CURRENT_BINARY_DIR}/resources")

    # Icons that no resource compiler will ever see, since nothing here is
    # built. What is checked is that the path reaches the resource file.
    set(_icon_dir "${CMAKE_CURRENT_BINARY_DIR}/icons")
    file(WRITE "${_icon_dir}/main.ico" "not really an icon")
    file(WRITE "${_icon_dir}/second.ico" "nor is this one")

    add_executable(winapp src/app.c)
    qm_add_win_rc(winapp
        NAME "A Test Application"
        VERSION 1.2.3.4
        DESCRIPTION "Something to read the resource of"
        COPYRIGHT "Copyright nobody"
        OUTPUT_DIR "${_res_dir}"
    )

    set(_rc "${_res_dir}/winapp_res.rc")
    qmtest_exists("OUTPUT_DIR is where the resource goes" "${_rc}")
    qmtest_file_contains("the name is in it" "${_rc}" "A Test Application")
    qmtest_file_contains("the description too" "${_rc}" "Something to read the resource of")
    qmtest_file_contains("and the copyright" "${_rc}" "Copyright nobody")
    # A version resource wants four numbers with commas, not the string form.
    qmtest_file_contains("the version is four numbers" "${_rc}" "1,2,3,4")
    qmtest_file_contains("and the string form is there as well" "${_rc}" "1\\.2\\.3\\.4")

    get_target_property(_sources winapp SOURCES)
    qmtest_contains("the resource is compiled into the target" "${_sources}" "${_rc}")

    # A version with fewer components is filled out, the same as anywhere else.
    add_executable(winshort src/app.c)
    qm_add_win_rc(winshort VERSION 2.0 OUTPUT_DIR "${_res_dir}")
    qmtest_file_contains("a short version is filled out" "${_res_dir}/winshort_res.rc" "2,0,0,0")

    # Nothing given, so the target names itself.
    add_executable(winbare src/app.c)
    qm_add_win_rc(winbare OUTPUT_DIR "${_res_dir}")
    qmtest_file_contains("the target names itself" "${_res_dir}/winbare_res.rc" "winbare")

    # An icon is a line in the resource, and no icon is that line commented out
    # rather than left half written.
    qmtest_file_lacks("with no icon nothing points at one" "${_res_dir}/winbare_res.rc" "\n[^/\n]*IDI_ICON1")

    add_executable(winicon src/app.c)
    qm_add_win_rc(winicon ICON "${_icon_dir}/main.ico" OUTPUT_DIR "${_res_dir}")
    qmtest_file_contains("ICON reaches the resource" "${_res_dir}/winicon_res.rc" "main\\.ico")

    # A library takes a resource as readily as an executable does.
    add_library(winrclib SHARED src/lib.c)
    qm_add_win_rc(winrclib NAME "A Test Library" VERSION 3.4.5.6 OUTPUT_DIR "${_res_dir}")
    qmtest_file_contains("a library takes one too" "${_res_dir}/winrclib_res.rc" "A Test Library")

    get_target_property(_sources winrclib SOURCES)
    qmtest_contains("and compiles it in" "${_sources}" "${_res_dir}/winrclib_res.rc")

    add_executable(winrich src/app.c)
    qm_add_win_rc_enhanced(winrich
        NAME "A Richer Application"
        VERSION 5.6.7.8
        COMPANY "Nobody Ltd"
        INTERNAL_NAME "richer"
        TRADEMARK "None at all"
        ORIGINAL_FILENAME "winrich.exe"
        COMMENTS "Nothing to add"
        OUTPUT_DIR "${_res_dir}"
    )

    set(_rc2 "${_res_dir}/winrich_res.rc")
    qmtest_file_contains("the company is in it" "${_rc2}" "Nobody Ltd")
    qmtest_file_contains("the internal name too" "${_rc2}" "richer")
    qmtest_file_contains("the trademark" "${_rc2}" "None at all")
    qmtest_file_contains("the original file name" "${_rc2}" "winrich\\.exe")
    qmtest_file_contains("and the comments" "${_rc2}" "Nothing to add")
    # An executable and a library are different kinds of file to Windows.
    qmtest_file_contains("an executable says it is one" "${_rc2}" "VFT_APP")

    add_library(winrichlib SHARED src/lib.c)
    qm_add_win_rc_enhanced(winrichlib VERSION 1.0.0.0 OUTPUT_DIR "${_res_dir}")
    qmtest_file_contains("and a library says it is one" "${_res_dir}/winrichlib_res.rc" "VFT_DLL")

    # This one takes any number of icons, numbered in the order they were given,
    # the first being the one Windows shows for the file.
    add_executable(winicons src/app.c)
    qm_add_win_rc_enhanced(winicons
        VERSION 1.0.0.0
        ICONS "${_icon_dir}/main.ico" "${_icon_dir}/second.ico"
        OUTPUT_DIR "${_res_dir}"
    )

    set(_rc3 "${_res_dir}/winicons_res.rc")
    qmtest_file_contains("the first icon is the first" "${_rc3}" "IDI_ICON1[ \t]+ICON[ \t]+\"[^\"]*main\\.ico\"")
    qmtest_file_contains("and the second the second" "${_rc3}" "IDI_ICON2[ \t]+ICON[ \t]+\"[^\"]*second\\.ico\"")

    # The manifest
    add_executable(winplain src/app.c)
    qm_add_win_manifest(winplain NAME "Plain" VERSION 1.2.3.4 OUTPUT_DIR "${_res_dir}")

    set(_manifest "${_res_dir}/winplain_manifest.exe.manifest")
    qmtest_exists("the manifest is written" "${_manifest}")
    qmtest_file_contains("it names the application" "${_manifest}" "Plain")
    qmtest_file_contains("it asks for no more than it was started with" "${_manifest}" "asInvoker")
    qmtest_file_lacks("and says nothing about the code page" "${_manifest}" "activeCodePage")

    add_executable(winadmin src/app.c)
    qm_add_win_manifest(winadmin NAME "Admin" VERSION 1.0.0.0 UTF8 ADMIN OUTPUT_DIR "${_res_dir}")

    set(_manifest2 "${_res_dir}/winadmin_manifest.exe.manifest")
    qmtest_file_contains("ADMIN asks to be run as one" "${_manifest2}" "requireAdministrator")
    qmtest_file_contains("UTF8 asks for that code page" "${_manifest2}" "UTF-8")
endif()

# ------------------------------------------------------------------
# What a Mac bundle carries
# ------------------------------------------------------------------

if(APPLE)
    add_executable(macapp src/app.c)
    qm_add_mac_bundle(macapp
        NAME "MyMacApp"
        VERSION 1.2.3.4
        DESCRIPTION "Something to read the bundle of"
        COPYRIGHT "Copyright nobody"
    )

    get_target_property(_bundle macapp MACOSX_BUNDLE)
    qmtest_true("it is made a bundle" "${_bundle}")

    get_target_property(_output macapp OUTPUT_NAME)
    qmtest_equal("NAME is what the binary is called" "${_output}" "MyMacApp")

    get_target_property(_name macapp MACOSX_BUNDLE_BUNDLE_NAME)
    qmtest_equal("and what the bundle is called" "${_name}" "MyMacApp")

    get_target_property(_version macapp MACOSX_BUNDLE_BUNDLE_VERSION)
    qmtest_equal("the version is carried whole" "${_version}" "1.2.3.4")

    # The short one is what a user is shown, so it is only the first two.
    get_target_property(_short macapp MACOSX_BUNDLE_SHORT_VERSION_STRING)
    qmtest_equal("and the short one is the first two of it" "${_short}" "1.2")

    get_target_property(_copyright macapp MACOSX_BUNDLE_COPYRIGHT)
    qmtest_equal("the copyright is carried" "${_copyright}" "Copyright nobody")

    get_target_property(_info macapp MACOSX_BUNDLE_INFO_STRING)
    qmtest_equal("and the description" "${_info}" "Something to read the bundle of")

    # Nothing given, so the target names itself.
    add_executable(macbare src/app.c)
    qm_add_mac_bundle(macbare)

    get_target_property(_name macbare MACOSX_BUNDLE_BUNDLE_NAME)
    qmtest_equal("the target names itself" "${_name}" "macbare")

    # An icon is named in the plist without its path, and goes into the bundle
    # by being one of the target's sources.
    set(_icon "${CMAKE_CURRENT_BINARY_DIR}/icons/app.icns")
    file(WRITE "${_icon}" "not really an icon")

    add_executable(maciconapp src/app.c)
    qm_add_mac_bundle(maciconapp NAME "IconApp" ICON "${_icon}")

    get_target_property(_icon_file maciconapp MACOSX_BUNDLE_ICON_FILE)
    qmtest_equal("the plist names the icon without its path" "${_icon_file}" "app.icns")

    get_target_property(_sources maciconapp SOURCES)
    qmtest_contains("and the icon is one of the sources" "${_sources}" "${_icon}")

    get_source_file_property(_where "${_icon}" MACOSX_PACKAGE_LOCATION)
    qmtest_equal("which is put under Resources" "${_where}" "Resources")
endif()

# ------------------------------------------------------------------
# qm_collect_targets
#
# Last, so that it sees everything defined above.
# ------------------------------------------------------------------

add_subdirectory(sub)

# One that is not behind a platform check, so that there is an executable to
# find wherever this runs.
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
