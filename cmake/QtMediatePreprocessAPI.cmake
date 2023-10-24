include_guard(DIRECTORY)

#[[
    Generate indirect reference files for header files to make the include statements more orderly.
    The generated file has the same timestamp as the source file.

    qtmediate_sync_include(<src> <dest>
        [INSTALL_DIR]
    )
#]]
function(qtmediate_sync_include _src_dir _dest_dir)
    set(options COPY)
    set(oneValueArgs INSTALL_DIR)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool_target qtmediate-cmake-modules::incsync)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_sync_include: tool \"incsync\" not found.")
    else()
        get_target_property(_tool ${_tool_target} LOCATION)
    endif()

    if(NOT IS_ABSOLUTE ${_src_dir})
        get_filename_component(_src_dir ${_src_dir} ABSOLUTE)
    else()
        string(REPLACE "\\" "/" _src_dir ${_src_dir})
    endif()

    if(NOT IS_ABSOLUTE ${_dest_dir})
        get_filename_component(_dest_dir ${_dest_dir} ABSOLUTE)
    else()
        string(REPLACE "\\" "/" _dest_dir ${_dest_dir})
    endif()

    if(IS_DIRECTORY ${_src_dir})
        file(GLOB_RECURSE header_files ${_src_dir}/*.h ${_src_dir}/*.hpp)

        execute_process(
            COMMAND ${_tool} -s ${_src_dir} ${_dest_dir}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMAND_ERROR_IS_FATAL ANY
            OUTPUT_QUIET
        )

        if(FUNC_INSTALL_DIR)
            get_filename_component(_install_dir ${FUNC_INSTALL_DIR} ABSOLUTE BASE_DIR ${CMAKE_INSTALL_PREFIX})

            install(CODE "
                execute_process(
                    COMMAND \"${_tool}\" -c -s \"${_src_dir}\" \"${_install_dir}\"
                    WORKING_DIRECTORY \"${CMAKE_CURRENT_SOURCE_DIR}\"
                    COMMAND_ERROR_IS_FATAL ANY
                    OUTPUT_QUIET
                )
            ")
        endif()
    else()
        message(FATAL_ERROR "qtmediate_sync_include: Source directory doesn't exist.")
    endif()
endfunction()

#[[
    Add a definition to global scope or a given target.

    qtmediate_add_definition( <key | key=value> | <key> <value>
        [STRING_LITERAL]
        [TARGET <target>]
        [PROPERTY <prop>]
        [NUMERICAL]
        [CONDITION <cond>]
    )
]] #
macro(qtmediate_add_definition)
    set(options GLOBAL NUMERICAL STRING_LITERAL)
    set(oneValueArgs TARGET PROPERTY CONDITION)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(_result)
    set(_is_pair off)
    set(_defined off)

    set(_list ${FUNC_UNPARSED_ARGUMENTS})
    list(LENGTH _list _len)

    set(_cond on)

    if(FUNC_CONDITION)
        if(NOT ${FUNC_CONDITION})
            set(_cond off)
        endif()
    elseif(DEFINED FUNC_CONDITION)
        set(_cond off)
    endif()

    if(${_len} EQUAL 1)
        set(_result ${_list})
        set(_defined on)

        if(NOT _cond)
            set(_defined off)
        endif()
    elseif(${_len} EQUAL 2)
        # Get key
        list(POP_FRONT _list _key)
        list(POP_FRONT _list _val)

        if(FUNC_STRING_LITERAL AND NOT ${_val} MATCHES "\".+\"")
            set(_val "\"${_val}\"")
        endif()

        # Boolean
        string(TOLOWER ${_val} _val_lower)

        if(${_val_lower} STREQUAL "off" OR ${_val_lower} STREQUAL "false")
            set(_result ${_key})
            set(_defined off)

            if(NOT _cond)
                set(_defined on)
            endif()
        elseif(${_val_lower} STREQUAL "on" OR ${_val_lower} STREQUAL "true")
            set(_result ${_key})
            set(_defined on)

            if(NOT _cond)
                set(_defined off)
            endif()
        else()
            set(_result "${_key}=${_val}")
            set(_is_pair on)
            set(_defined on)

            if(NOT _cond)
                set(_defined off)
            endif()
        endif()
    else()
        message(FATAL_ERROR "qtmediate_add_definition: called with incorrect number of arguments")
    endif()

    if(FUNC_NUMERICAL AND NOT _is_pair)
        if(_defined)
            set(_result "${_result}=1")
        else()
            set(_result "${_result}=-1")
        endif()
    elseif(NOT _defined)
        return()
    endif()

    qtmediate_set_value(_prop FUNC_PROPERTY CONFIG_DEFINITIONS)

    if(FUNC_TARGET)
        set_property(TARGET ${FUNC_TARGET} APPEND PROPERTY ${_prop} "${_result}")
    else()
        set_property(GLOBAL APPEND PROPERTY ${_prop} "${_result}")
    endif()
endmacro()

#[[
    Generate a configuration header. If the configuration has not changed, the generated file's
    timestemp will not be updated when you reconfigure it.

    qtmediate_generate_config(<file>
        [TARGET <target>]
        [PROPERTY <prop>]
    )
]] #
function(qtmediate_generate_config _file)
    set(options GLOBAL)
    set(oneValueArgs TARGET PROPERTY)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool_target qtmediate-cmake-modules::cfggen)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_generate_config: tool \"cfggen\" not found.")
    else()
        get_target_property(_tool ${_tool_target} LOCATION)
    endif()

    qtmediate_set_value(_prop FUNC_PROPERTY CONFIG_DEFINITIONS)

    if(FUNC_TARGET)
        get_target_property(_def_list ${FUNC_TARGET} ${_prop})
    else()
        get_property(_def_list GLOBAL PROPERTY ${_prop})
    endif()

    if(_def_list)
        set(_args)

        foreach(_item ${_def_list})
            list(APPEND _args "-D${_item}")
        endforeach()

        execute_process(COMMAND ${_tool} ${_args} ${_file}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMAND_ERROR_IS_FATAL ANY
            OUTPUT_QUIET
        )
    endif()
endfunction()

#[[
    Generate build info information header.

    qtmediate_generate_build_info(<dir> <prefix> <file>)

    dir: Repository root directory (CMake will try to run `git` at this directory)
    prefix: Macros prefix
    file: Output file
]] #
function(qtmediate_generate_build_info _dir _prefix _file)
    # Get tool
    set(_tool_target qtmediate-cmake-modules::cfggen)

    if(NOT TARGET ${_tool_target})
        message(FATAL_ERROR "qtmediate_generate_config: tool \"cfggen\" not found.")
    else()
        get_target_property(_tool ${_tool_target} LOCATION)
    endif()

    set(_git_branch "unknown")
    set(_git_hash "unknown")
    set(_git_commit_time "unknown")
    set(_git_commit_author "unknown")
    set(_git_commit_email "unknown")

    find_package(Git QUIET)

    if(Git_FOUND)
        # message(STATUS "Git found: ${GIT_EXECUTABLE} (version ${GIT_VERSION_STRING})")

        # Branch
        execute_process(
            COMMAND ${GIT_EXECUTABLE} symbolic-ref --short -q HEAD
            OUTPUT_VARIABLE _temp
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            WORKING_DIRECTORY ${_dir}
            RESULT_VARIABLE _code
        )

        if(${_code} EQUAL 0)
            set(_git_branch ${_temp})
        endif()

        # Hash
        execute_process(
            COMMAND ${GIT_EXECUTABLE} log -1 "--pretty=format:%H\n%aI\n%aN\n%aE"
            OUTPUT_VARIABLE _temp
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            WORKING_DIRECTORY ${_dir}
            RESULT_VARIABLE _code
        )

        if(${_code} EQUAL 0)
            string(REPLACE "\n" ";" _temp_list "${_temp}")
            list(GET _temp_list 0 _git_hash)
            list(GET _temp_list 1 _git_commit_time)
            list(GET _temp_list 2 _git_commit_author)
            list(GET _temp_list 3 _git_commit_email)
        endif()
    else()
        # message(WARNING "Git not found")
    endif()

    set(_compiler_name unknown)

    if("${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang")
        set(_compiler_name "Clang")
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
        set(_compiler_name "GCC")
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "MSVC")
        set(_compiler_name "MSVC")
    elseif(CMAKE_CXX_COMPILER_ID)
        set(_compiler_name ${CMAKE_CXX_COMPILER_ID})
    endif()

    set(_compiler_arch ${CMAKE_CXX_COMPILER_ARCHITECTURE_ID})

    if(NOT _compiler_arch)
        string(TOLOWER ${CMAKE_HOST_SYSTEM_PROCESSOR} _compiler_arch)
    endif()

    set(_compiler_version ${CMAKE_CXX_COMPILER_VERSION})

    if(NOT _compiler_version)
        set(_compiler_version 0)
    endif()

    # string(TIMESTAMP _build_time "%Y/%m/%d %H:%M:%S")
    # string(TIMESTAMP _build_year "%Y")

    set(_def_list)
    list(APPEND _def_list ${_prefix}_BUILD_COMPILER_ID=\"${_compiler_name}\")
    list(APPEND _def_list ${_prefix}_BUILD_COMPILER_VERSION=\"${_compiler_version}\")
    list(APPEND _def_list ${_prefix}_BUILD_COMPILER_ARCH=\"${_compiler_arch}\")
    # list(APPEND _def_list ${_prefix}_BUILD_DATE_TIME=\"${_build_time}\")
    # list(APPEND _def_list ${_prefix}_BUILD_YEAR=\"${_build_year}\")
    list(APPEND _def_list ${_prefix}_GIT_BRANCH=\"${_git_branch}\")
    list(APPEND _def_list ${_prefix}_GIT_LAST_COMMIT_HASH=\"${_git_hash}\")
    list(APPEND _def_list ${_prefix}_GIT_LAST_COMMIT_TIME=\"${_git_commit_time}\")
    list(APPEND _def_list ${_prefix}_GIT_LAST_COMMIT_AUTHOR=\"${_git_commit_author}\")
    list(APPEND _def_list ${_prefix}_GIT_LAST_COMMIT_EMAIL=\"${_git_commit_email}\")

    set(_args)

    foreach(_item ${_def_list})
        list(APPEND _args "-D${_item}")
    endforeach()

    execute_process(COMMAND ${_tool} ${_args} ${_file}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND_ERROR_IS_FATAL ANY
        OUTPUT_QUIET
    )
endfunction()