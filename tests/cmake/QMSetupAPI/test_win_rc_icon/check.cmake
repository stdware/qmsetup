# The icons of the resources, written again after the first build, and the builds after it.
#
# Included by testing/build.cmake once the project is built. `_build` is its build tree.
#
# The icon that exists while configuring once configured the tree again after a change, as a
# CMAKE_CONFIGURE_DEPENDS of the directory, for the generators of Visual Studio, which do not
# honor OBJECT_DEPENDS. Ninja did the same, which the check of the configure below detects.

include("${_build}/built_names.cmake")

qmtest_exists("the build wrote the icon" "${_icon}")
file(SHA256 "${_plain}" _plain_first)
file(SHA256 "${_app}" _app_first)

# Runs a build of the project, and sets _out to what it printed
function(build_again _what)
    execute_process(COMMAND ${CMAKE_COMMAND} --build "${_build}" --config Release
        RESULT_VARIABLE _code
        OUTPUT_VARIABLE _output
        ERROR_VARIABLE _output
    )
    qmtest_equal("${_what} succeeds" "${_code}" "0")
    set(_out "${_output}" PARENT_SCOPE)
endfunction()

# Other colors, written over the icons as an editor saves them
execute_process(COMMAND "${_make_icon}" "${_plain_icon}" 0 RESULT_VARIABLE _code)
qmtest_equal("the plain icon is written again" "${_code}" "0")
execute_process(COMMAND "${_make_icon}" "${_icon}" 2 RESULT_VARIABLE _code)
qmtest_equal("the written icon is written again" "${_code}" "0")

build_again("the build after the change")
file(SHA256 "${_plain}" _plain_second)
file(SHA256 "${_app}" _app_second)
string(COMPARE NOTEQUAL "${_plain_first}" "${_plain_second}" _changed)
qmtest_true("the application of the plain icon has the new icon" "${_changed}")
string(COMPARE NOTEQUAL "${_app_first}" "${_app_second}" _changed)
qmtest_true("the application of the written icon has the new icon" "${_changed}")
string(REGEX MATCH "Re-running CMake|Configuring done" _configured "${_out}")
qmtest_false("and nothing configured again" "${_configured}")

# Nothing changed, so no script is written again and the applications stay as they were.
build_again("a build without a change")
file(SHA256 "${_plain}" _plain_third)
file(SHA256 "${_app}" _app_third)
qmtest_equal("the application of the plain icon is the same" "${_plain_third}" "${_plain_second}")
qmtest_equal("the application of the written icon is the same" "${_app_third}" "${_app_second}")
string(REGEX MATCH "_res\\.rc" _written "${_out}")
qmtest_false("and no script is written again" "${_written}")
