include_guard(DIRECTORY)

#[[
    Disable all possible warnings from the compiler.
]] #
macro(qm_compiler_no_warnings)
    if(NOT "x${CMAKE_C_FLAGS}" STREQUAL "x")
        if(MSVC)
            string(REGEX REPLACE "[/|-]W[0|1|2|3|4]" " " CMAKE_C_FLAGS ${CMAKE_C_FLAGS})
        else()
            string(REGEX REPLACE "-W[all|extra]" " " CMAKE_C_FLAGS ${CMAKE_C_FLAGS})
            string(REGEX REPLACE "-[W]?pedantic" " " CMAKE_C_FLAGS ${CMAKE_C_FLAGS})
        endif()
    endif()
    if(NOT "x${CMAKE_CXX_FLAGS}" STREQUAL "x")
        if(MSVC)
            string(REGEX REPLACE "[/|-]W[0|1|2|3|4]" " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
        else()
            string(REGEX REPLACE "-W[all|extra]" " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
            string(REGEX REPLACE "-[W]?pedantic" " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
        endif()
    endif()
    string(APPEND CMAKE_C_FLAGS " -w ")
    string(APPEND CMAKE_CXX_FLAGS " -w ")
    if(NOT MSVC)
        string(APPEND CMAKE_C_FLAGS " -fpermissive ")
        string(APPEND CMAKE_CXX_FLAGS " -fpermissive ")
    endif()
endmacro()

#[[
    Enable all possible warnings from the compiler.
]] #
function(qm_compiler_max_warnings)
    if(MSVC)
        add_compile_options(-W4)
    elseif("x${CMAKE_CXX_COMPILER_ID}" STREQUAL "xClang")
        add_compile_options(-Weverything)
    else()
        add_compile_options(-Wall -Wextra -Wpedantic)
    endif()
endfunction()

#[[
    Treat all warnings as errors.
]] #
function(qm_compiler_warnings_are_errors)
    if(MSVC)
        add_compile_options(-WX)
    else()
        add_compile_options(-Werror)
    endif()
endfunction()

#[[
    Prevent the compiler from receiving unknown parameters.
]] #
function(qm_compiler_no_unknown_options)
    if(MSVC)
        if(MSVC_VERSION GREATER_EQUAL 1930) # Visual Studio 2022 version 17.0
            add_compile_options(-options:strict)
        endif()
        add_link_options(-WX)
    endif()
endfunction()

#[[
    Remove all unused code from the final binary.
]] #
function(qm_compiler_eliminate_dead_code)
    if(MSVC)
        add_compile_options(-Gw -Gy -Zc:inline)
        add_link_options(-OPT:REF -OPT:ICF -OPT:LBR)
    else()
        add_compile_options(-ffunction-sections -fdata-sections)
        if(APPLE)
            add_link_options(-Wl,-dead_strip)
        else()
            add_link_options(-Wl,--strip-all -Wl,--gc-sections)
        endif()
    endif()
endfunction()

#[[
    Only export symbols which are marked to be exported, just like MSVC.
]] #
macro(qm_compiler_dont_export_by_default)
    set(CMAKE_C_VISIBILITY_PRESET "hidden")
    set(CMAKE_CXX_VISIBILITY_PRESET "hidden")
    set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
endmacro()