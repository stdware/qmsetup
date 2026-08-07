# A small application with a dependency graph worth resolving.
#
#   base                     a leaf, depended on from two directions
#   util     -> base
#   render   -> util         so render reaches base only through util
#   audio    -> base
#   app      -> render       the app names render alone, so util and base are
#                            reached only by following render
#   plugin_a -> render       a plugin over what the app already has
#   plugin_b -> audio        a plugin that brings a branch of its own
#
# Everything is built into one directory. The tests copy the pieces out of it
# and scatter them, so that nothing sits beside anything it depends on and the
# tool has to be told where to look:
#
#   app/
#       qmtest_app                the executable, on its own
#   libs/core/
#       qmtest_base
#       qmtest_util
#   libs/media/
#       qmtest_render
#       qmtest_audio              wanted by plugin_b alone
#   plugins/
#       qmtest_plugin_a
#       qmtest_plugin_b
#
# Deploying the application together with plugin_b --
#
#   qmcorecmd deploy app/qmtest_app -c plugins/qmtest_plugin_b out/plugins \
#             -L libs/core -L libs/media -o out
#
# should leave everything above where it was and add this:
#
#   out/
#       qmtest_render             app     -> render
#       qmtest_util               render  -> util
#       qmtest_base               util    -> base
#       qmtest_audio              plugin_b -> audio
#       plugins/
#           qmtest_plugin_b       brought by --copy, to the directory it named
#
# plugin_a is not in it, because it was not named. Audio would not be either,
# had plugin_b not been. Deploying the application alone gives out/ exactly
# render, util and base.
#
# The names above are what Windows produces. Elsewhere the platform decorates
# them its own way, as libqmtest_render.so or libqmtest_render.dylib, which is
# why the tests name artifacts rather than files.
#
# The layout, and what each command line should leave behind, are declared in
# ../deploy_scenarios.json. This file only builds the pieces.

# Symbols are exported by hand in fixture.h rather than wholesale, because
# CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS does not cover MODULE libraries, and a
# plugin entry point with no caller and no export is dropped by the linker --
# taking with it the very import that makes the plugin worth deploying.

function(qmtest_fixture_library name)
    add_library(qmtest_${name} SHARED ${name}.c)
    target_link_libraries(qmtest_${name} PRIVATE ${ARGN})
    list(APPEND _fixtures qmtest_${name})
    set(_fixtures ${_fixtures} PARENT_SCOPE)
endfunction()

function(qmtest_fixture_plugin name)
    add_library(qmtest_${name} MODULE ${name}.c)
    target_link_libraries(qmtest_${name} PRIVATE ${ARGN})
    list(APPEND _fixtures qmtest_${name})
    set(_fixtures ${_fixtures} PARENT_SCOPE)
endfunction()

qmtest_fixture_library(base)
qmtest_fixture_library(util qmtest_base)
qmtest_fixture_library(render qmtest_util)
qmtest_fixture_library(audio qmtest_base)

qmtest_fixture_plugin(plugin_a qmtest_render)
qmtest_fixture_plugin(plugin_b qmtest_audio)

add_executable(qmtest_app app.c)
target_link_libraries(qmtest_app PRIVATE qmtest_render)
list(APPEND _fixtures qmtest_app)

set(_fixture_dir ${CMAKE_CURRENT_BINARY_DIR}/artifacts)

foreach(_target IN LISTS _fixtures)
    set_target_properties(${_target} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${_fixture_dir}
        LIBRARY_OUTPUT_DIRECTORY ${_fixture_dir}
        # Import libraries and the like stay out of the way, so that the
        # directory holds the binaries and nothing else.
        ARCHIVE_OUTPUT_DIRECTORY ${_fixture_dir}/link
        # No versioned names, so that one file answers to one name.
        PREFIX "${CMAKE_SHARED_LIBRARY_PREFIX}"
        # The tests move these around, so a build-tree rpath would be a lie.
        SKIP_BUILD_RPATH ON
        BUILD_WITH_INSTALL_RPATH ON
        INSTALL_RPATH "$ORIGIN"
    )
    if(APPLE)
        set_target_properties(${_target} PROPERTIES
            INSTALL_RPATH "@loader_path"
            INSTALL_NAME_DIR "@rpath"
        )
    endif()
    if(MSVC)
        # A static runtime keeps the import tables down to what these actually
        # depend on, so that what a test sees does not turn on which C runtime
        # the machine happens to have.
        set_target_properties(${_target} PROPERTIES
            MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>"
        )
    endif()
endforeach()

# The tests are told where these ended up, whatever the generator decided.
set(QMSETUP_TEST_FIXTURE_DIR "$<TARGET_FILE_DIR:qmtest_app>" PARENT_SCOPE)
