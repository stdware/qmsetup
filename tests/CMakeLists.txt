# Where the project itself is, for the tests that read what it ships rather
# than what it built.
set(QMSETUP_PROJECT_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/..)

add_subdirectory(cli)
add_subdirectory(cmake)
