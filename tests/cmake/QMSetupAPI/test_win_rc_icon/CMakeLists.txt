# qm_add_win_rc with an icon that exists while configuring and with one that a custom command
# writes while building, as a project that keeps only the drawing of its icon writes the icon.
#
# Registered only on Windows. Built and installed by testing/build.cmake, and check.cmake writes
# both icons again in another color and builds again, so that each resource is seen to compile
# again at the next build, without a configure.

cmake_minimum_required(VERSION 3.19)
project(qmtest_win_rc_icon VERSION 1.0.0 LANGUAGES C)

include(${QMSETUP_API})

add_executable(qmtest_make_icon src/make_icon.c)

# An icon as a source file. src/plain.ico was written by qmtest_make_icon, and the copy is the
# file that check.cmake changes.
file(COPY src/plain.ico DESTINATION "${CMAKE_BINARY_DIR}")
set(_plain_icon "${CMAKE_BINARY_DIR}/plain.ico")

add_executable(qmtest_rc_plain src/app.c)
qm_add_win_rc(qmtest_rc_plain ICON "${_plain_icon}")

# An icon that does not exist while configuring
set(_icon "${CMAKE_BINARY_DIR}/app.ico")
add_custom_command(OUTPUT "${_icon}"
    COMMAND qmtest_make_icon "${_icon}" 1
    DEPENDS qmtest_make_icon
    VERBATIM
)

add_executable(qmtest_rc_app src/app.c)
qm_add_win_rc(qmtest_rc_app ICON "${_icon}")

# The paths that check.cmake reads
file(GENERATE OUTPUT "${CMAKE_BINARY_DIR}/built_names.cmake" CONTENT
"set(_plain \"$<TARGET_FILE:qmtest_rc_plain>\")
set(_plain_icon \"${_plain_icon}\")
set(_app \"$<TARGET_FILE:qmtest_rc_app>\")
set(_make_icon \"$<TARGET_FILE:qmtest_make_icon>\")
set(_icon \"${_icon}\")
")
