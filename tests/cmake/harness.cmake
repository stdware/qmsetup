# What every test in this directory loads first.
#
# The tests run in script mode, with `cmake -P`, because nothing they check
# needs a project to exist. That keeps them quick and keeps a failure readable:
# there is no configure log to read through, only the line that failed.
#
# Checks are collected rather than aborted on, so one run says everything that
# is wrong rather than the first thing. qmtest_report() at the end of a file is
# what turns that into an exit code.
#
# What is passed in:
#
#   QMSETUP_API     the QMSetupAPI.cmake to test
#   QMCORECMD       the executable the modules shell out to
#   QMTEST_WORK_DIR a directory of this test's own, emptied on the way in

if(NOT DEFINED QMSETUP_API)
    message(FATAL_ERROR "QMSETUP_API is not set. It has to name the QMSetupAPI.cmake under test. "
        "Run these through CTest, which passes it.")
endif()

if(NOT EXISTS "${QMSETUP_API}")
    message(FATAL_ERROR "QMSETUP_API points at nothing: ${QMSETUP_API}")
endif()

include("${QMSETUP_API}")

# After the include rather than before. QMSetupAPI.cmake clears this itself when
# the imported target is absent, which it always is in script mode.
if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

if(DEFINED QMTEST_WORK_DIR)
    file(REMOVE_RECURSE "${QMTEST_WORK_DIR}")
    file(MAKE_DIRECTORY "${QMTEST_WORK_DIR}")
endif()

set_property(GLOBAL PROPERTY QMTEST_CHECKS 0)
set_property(GLOBAL PROPERTY QMTEST_FAILURES "")

function(_qmtest_pass)
    get_property(_count GLOBAL PROPERTY QMTEST_CHECKS)
    math(EXPR _count "${_count} + 1")
    set_property(GLOBAL PROPERTY QMTEST_CHECKS ${_count})
endfunction()

function(_qmtest_fail _what _detail)
    _qmtest_pass()
    set_property(GLOBAL APPEND PROPERTY QMTEST_FAILURES "${_what}\n      ${_detail}")
endfunction()

#[[
    The value is what it should be, compared as a string. A list compares as a
    string too, since that is what a list is.

    qmtest_equal(<what> <actual> <expected>)
]] #
function(qmtest_equal _what _actual _expected)
    if("${_actual}" STREQUAL "${_expected}")
        _qmtest_pass()
        return()
    endif()

    _qmtest_fail("${_what}" "expected [${_expected}]\n      got      [${_actual}]")
endfunction()

#[[
    qmtest_true(<what> <value>)
]] #
function(qmtest_true _what _value)
    if(_value)
        _qmtest_pass()
        return()
    endif()

    _qmtest_fail("${_what}" "expected something true, got [${_value}]")
endfunction()

#[[
    qmtest_false(<what> <value>)
]] #
function(qmtest_false _what _value)
    if(_value)
        _qmtest_fail("${_what}" "expected something false, got [${_value}]")
        return()
    endif()

    _qmtest_pass()
endfunction()

#[[
    The file is there and holds the text.

    qmtest_file_contains(<what> <file> <text>)
]] #
function(qmtest_file_contains _what _file _text)
    if(NOT EXISTS "${_file}")
        _qmtest_fail("${_what}" "${_file} was not written")
        return()
    endif()

    file(READ "${_file}" _content)

    if("${_content}" MATCHES "${_text}")
        _qmtest_pass()
        return()
    endif()

    _qmtest_fail("${_what}" "${_file} does not match [${_text}]\n--- content ---\n${_content}")
endfunction()

#[[
    Says how it went, and fails the run if anything went wrong. Every test file
    ends with this.

    qmtest_report()
]] #
function(qmtest_report)
    get_property(_count GLOBAL PROPERTY QMTEST_CHECKS)
    get_property(_failures GLOBAL PROPERTY QMTEST_FAILURES)
    list(LENGTH _failures _failed)

    if(_failed EQUAL 0)
        message(STATUS "${_count} checks, all of them passed")
        return()
    endif()

    set(_text "${_failed} of ${_count} checks failed:")

    foreach(_failure IN LISTS _failures)
        string(APPEND _text "\n\n  * ${_failure}")
    endforeach()

    message(FATAL_ERROR "${_text}")
endfunction()
