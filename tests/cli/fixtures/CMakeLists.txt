# The binaries the deploy tests run against.
#
# `qmcorecmd deploy` finds what shared libraries a binary needs and copies them
# somewhere. Testing that needs real binaries, so this builds nine of them.
# They do nothing at all. What matters is who links whom, and where each one
# sits, because that is what a deployment has to work out.
#
# The shape is the one a program has after it is installed alongside a
# framework it uses. Read `audio` as Qt and it is the familiar case: an
# application that links a framework has to carry the framework's libraries and
# its plugins, and the plugins are not linked by anything, so nothing finds
# them by following the graph. They are named on the command line instead.
#
# Mine, under myapp/:
#
#   bin/                qmtest_app          links core
#                       qmtest_core         links util and audio
#                       qmtest_util         a leaf
#   lib/app/plugins/    qmtest_plugin1      links core
#                       qmtest_plugin2      links audio, so a plugin of mine
#                                           reaches into the framework directly
#
# Theirs, under thirdparty/, which stands in for an installed framework:
#
#   bin/                qmtest_audio        links render
#                       qmtest_render       a leaf
#                       qmtest_codec        a leaf nothing of mine reaches
#   lib/audio/plugins/  qmtest_audioplugin1 links audio
#                       qmtest_audioplugin2 links codec
#
# So the application links core and nothing else. util, audio and render are
# reached only by following core, and then by following audio. A resolver that
# reads one level deep finds core and stops.
#
# codec is the one nothing links. No amount of following the graph from the
# application arrives at it, and it is there only because audioplugin2 wants
# it. That is the case plugin deployment exists for: naming the plugin has to
# bring a library along that nothing else asked for.
#
# What a build leaves behind is that tree, laid out under this file's build
# directory rather than flattened into one place:
#
#   myapp/bin/                    qmtest_app.exe qmtest_core.dll qmtest_util.dll
#   myapp/lib/app/plugins/        qmtest_plugin1.dll qmtest_plugin2.dll
#   thirdparty/bin/               qmtest_audio.dll qmtest_render.dll qmtest_codec.dll
#   thirdparty/lib/audio/plugins/ qmtest_audioplugin1.dll qmtest_audioplugin2.dll
#
# Those are the names Windows produces. Elsewhere the platform decorates them
# its own way, as qmtest_app and libqmtest_core.so, or libqmtest_core.dylib on
# macOS. That is why the tests name artifacts rather than files, and why
# nothing here carries a debug postfix. The qmtest_ prefix is there so that no
# fixture is ever named like something in C:\Windows\System32, which a
# deployment filters out on sight and would turn into a failure on one machine
# and not another.
#
# A test copies both trees into a sandbox of its own, keeping the structure. It
# does not rearrange them, because the arrangement is the point. Which command
# lines are run against it, and what each should leave behind, are declared in
# ../deploy_scenarios.json, and the directory names there have to agree with
# the ones set below.

# Symbols are exported by hand in fixture.h rather than wholesale, because
# CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS does not cover MODULE libraries, and a
# plugin entry point with no caller and no export is dropped by the linker,
# taking with it the very import that makes the plugin worth deploying.

set(_fixture_root ${CMAKE_CURRENT_BINARY_DIR})

# Where a binary goes, and what it has to be able to find from there.
#
# On Unix a binary carries its own search path, and CMake would write the build
# tree's absolute directories into it. That would let every fixture find every
# other one wherever it was copied to, which is exactly what these tests must
# not have. Each one is given a relative path instead, worked out from where it
# sits in the tree above, so that resolving depends on the layout rather than
# on where the build happened.
if(APPLE)
    set(_origin "@loader_path")
else()
    set(_origin "$ORIGIN")
endif()

set(_app_bin              myapp/bin)
set(_app_plugins          myapp/lib/app/plugins)
set(_third_bin            thirdparty/bin)
set(_third_plugins        thirdparty/lib/audio/plugins)

# myapp/bin reaches thirdparty/bin by going up two and across.
set(_app_bin_rpath        "${_origin};${_origin}/../../thirdparty/bin")
# myapp/lib/app/plugins goes up three to myapp, and four to the root.
set(_app_plugins_rpath    "${_origin};${_origin}/../../../bin;${_origin}/../../../../thirdparty/bin")
set(_third_bin_rpath      "${_origin}")
# thirdparty/lib/audio/plugins goes up three to thirdparty.
set(_third_plugins_rpath  "${_origin};${_origin}/../../../bin")

# name, kind, output directory, rpath
function(qmtest_fixture name kind directory rpath)
    if(kind STREQUAL "application")
        add_executable(qmtest_${name} ${name}.c)
    elseif(kind STREQUAL "plugin")
        add_library(qmtest_${name} MODULE ${name}.c)
    else()
        add_library(qmtest_${name} SHARED ${name}.c)
    endif()

    target_link_libraries(qmtest_${name} PRIVATE ${ARGN})

    set_target_properties(qmtest_${name} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${_fixture_root}/${directory}"
        LIBRARY_OUTPUT_DIRECTORY "${_fixture_root}/${directory}"
        # No configuration in the name. The tests look these up by what they
        # are, and a debug postfix would make that depend on how the project
        # was configured.
        DEBUG_POSTFIX ""
        SKIP_BUILD_RPATH ON
        BUILD_WITH_INSTALL_RPATH ON
        INSTALL_RPATH "${rpath}"
    )
    if(APPLE)
        set_target_properties(qmtest_${name} PROPERTIES INSTALL_NAME_DIR "@rpath")
    endif()
    if(MSVC)
        # A static runtime keeps the import tables down to what these actually
        # depend on, so that what a test sees does not turn on which C runtime
        # the machine happens to have.
        set_target_properties(qmtest_${name} PROPERTIES
            MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
        )
    endif()
endfunction()

# Theirs first, since mine link it.
qmtest_fixture(render       library     "${_third_bin}"      "${_third_bin_rpath}")
qmtest_fixture(codec        library     "${_third_bin}"      "${_third_bin_rpath}")
qmtest_fixture(audio        library     "${_third_bin}"      "${_third_bin_rpath}"     qmtest_render)
qmtest_fixture(audioplugin1 plugin      "${_third_plugins}"  "${_third_plugins_rpath}" qmtest_audio)
qmtest_fixture(audioplugin2 plugin      "${_third_plugins}"  "${_third_plugins_rpath}" qmtest_codec)

qmtest_fixture(util         library     "${_app_bin}"        "${_app_bin_rpath}")
qmtest_fixture(core         library     "${_app_bin}"        "${_app_bin_rpath}"       qmtest_util qmtest_audio)
qmtest_fixture(app          application "${_app_bin}"        "${_app_bin_rpath}"       qmtest_core)
qmtest_fixture(plugin1      plugin      "${_app_plugins}"    "${_app_plugins_rpath}"   qmtest_core)
qmtest_fixture(plugin2      plugin      "${_app_plugins}"    "${_app_plugins_rpath}"   qmtest_audio)

# A real framework bundle, which is a shape only macOS has.
#
# Deploying one is not deploying a file. The bundle is a directory, the library is inside it
# under Versions/A, and what a binary names is @rpath/Name.framework/Versions/A/Name. A whole
# body of code in the deployment exists for that, and nothing above reaches any of it, so this
# tree is here on its own rather than being worked into the graph above. Nothing links it but
# the one application beside it, and no declared scenario mentions it.
if(APPLE)
    set(_framework_dir "${_fixture_root}/frameworks")

    # A bundle takes a fair amount of saying, so it is said once.
    #
    # The header is a source as well as a PUBLIC_HEADER. Named only as the latter it is placed
    # when installing rather than when building, and the bundle comes out without a Headers
    # directory at all, which a deployment is meant to leave behind and cannot be seen to.
    function(qmtest_framework name)
        add_library(qmtest_${name} SHARED ${name}.c ${name}.h)
        target_link_libraries(qmtest_${name} PRIVATE ${ARGN})
        set_target_properties(qmtest_${name} PROPERTIES
            FRAMEWORK TRUE
            FRAMEWORK_VERSION A
            MACOSX_FRAMEWORK_IDENTIFIER org.stdware.qmtest.${name}
            PUBLIC_HEADER ${name}.h
            LIBRARY_OUTPUT_DIRECTORY "${_framework_dir}"
            DEBUG_POSTFIX ""
            SKIP_BUILD_RPATH ON
            BUILD_WITH_INSTALL_RPATH ON
            INSTALL_NAME_DIR "@rpath"
            INSTALL_RPATH "${_origin}/../../.."
        )
    endfunction()

    # An ordinary shared library that a framework needs, so that the walk leaves a bundle as well
    # as entering one.
    add_library(qmtest_plainlib SHARED plainlib.c)
    set_target_properties(qmtest_plainlib PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${_framework_dir}"
        DEBUG_POSTFIX ""
        SKIP_BUILD_RPATH ON
        BUILD_WITH_INSTALL_RPATH ON
        INSTALL_NAME_DIR "@rpath"
    )

    # bundleapp -> bundled.framework -> deeper.framework
    #                                -> plainlib
    #
    # Three levels, and the middle one is a bundle. Reaching deeper or plainlib means going into
    # bundled for the library inside it, reading what that names, and coming back out to a bundle
    # again. One level of framework never asks for any of that.
    qmtest_framework(deeper)
    qmtest_framework(bundled qmtest_deeper qmtest_plainlib)

    # Linked by nothing. It is the framework equivalent of codec above: no amount of following
    # the graph arrives at it, so the only way it is ever deployed is by being named with -c,
    # and that is a different path through the deployment.
    qmtest_framework(named)

    add_executable(qmtest_bundleapp bundleapp.c)
    target_link_libraries(qmtest_bundleapp PRIVATE qmtest_bundled)
    set_target_properties(qmtest_bundleapp PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY "${_framework_dir}"
        DEBUG_POSTFIX ""
        SKIP_BUILD_RPATH ON
        BUILD_WITH_INSTALL_RPATH ON
        INSTALL_RPATH "${_origin}"
    )

    set(QMSETUP_TEST_FRAMEWORK_DIR "${_framework_dir}" PARENT_SCOPE)
endif()

# The tests are told where the tree ended up, whatever the generator decided.
set(QMSETUP_TEST_FIXTURE_DIR "${_fixture_root}" PARENT_SCOPE)
