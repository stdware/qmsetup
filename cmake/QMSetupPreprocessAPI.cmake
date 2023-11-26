include_guard(DIRECTORY)

#[[
    Generate indirect reference files for header files to make the include statements more orderly.
    The generated file has the same timestamp as the source file.

    qmsetup_sync_include(<src> <dest>
        [NO_STANDARD] [NO_ALL]
        [INCLUDE <pair...>]
        [EXCLUDE <expr...>]
        [INSTALL_DIR <dir>]
        [FORCE] [VERBOSE]
    )
#]]
function(qmsetup_sync_include _src_dir _dest_dir)
    set(options FORCE VERBOSE NO_STANDARD NO_ALL)
    set(oneValueArgs INSTALL_DIR)
    set(multiValueArgs INCLUDE EXCLUDE)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool)
    _qmsetup_get_core_tool(_tool "qmsetup_sync_include")

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

        set(_args)

        if(NOT FUNC_NO_STANDARD)
            list(APPEND _args -s)
        endif()

        if(FUNC_NO_ALL)
            list(APPEND _args -n)
        endif()

        foreach(_item ${FUNC_INCLUDE})
            list(APPEND _args -i ${_item})
        endforeach()

        foreach(_item ${FUNC_EXCLUDE})
            list(APPEND _args -e ${_item})
        endforeach()

        if(FUNC_VERBOSE)
            list(APPEND _args -V)
        endif()

        if(NOT FUNC_FORCE OR NOT EXISTS ${_dest_dir})
            if(EXISTS ${_dest_dir})
                file(REMOVE_RECURSE ${_dest_dir})
            endif()

            execute_process(
                COMMAND ${_tool} incsync ${_args} ${_src_dir} ${_dest_dir}
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMAND_ERROR_IS_FATAL ANY
            )
        endif()

        if(FUNC_INSTALL_DIR)
            get_filename_component(_install_dir ${FUNC_INSTALL_DIR} ABSOLUTE BASE_DIR ${CMAKE_INSTALL_PREFIX})

            set(_args_quoted)

            foreach(_item ${_args})
                set(_args_quoted "${_args_quoted}\"${_item}\" ")
            endforeach()

            # Get command output only and use file(INSTALL) to install files
            install(CODE "
                execute_process(
                    COMMAND \"${_tool}\" incsync -d ${_args_quoted} \"${_src_dir}\" \"${_install_dir}\"
                    WORKING_DIRECTORY \"${CMAKE_CURRENT_SOURCE_DIR}\"
                    OUTPUT_VARIABLE _output_contents
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    COMMAND_ERROR_IS_FATAL ANY
                )
                string(REPLACE \"\\n\" \";\" _lines \"\${_output_contents}\")

                foreach(_line \${_lines})
                    string(REGEX MATCH \"from \\\"([^\\\"]*)\\\" to \\\"([^\\\"]*)\\\"\" _ \${_line})
                    get_filename_component(_target_path \${CMAKE_MATCH_2} DIRECTORY)
                    file(INSTALL \${CMAKE_MATCH_1} DESTINATION \${_target_path})
                endforeach()
            ")
        endif()
    else()
        message(FATAL_ERROR "qmsetup_sync_include: Source directory doesn't exist.")
    endif()
endfunction()

#[[
    Add a definition to global scope or a given target.

    qmsetup_add_definition( <key | key=value> | <key> <value>
        [STRING_LITERAL]
        [TARGET <target>]
        [PROPERTY <prop>]
        [NUMERICAL]
        [CONDITION <cond>]
    )
]] #
function(qmsetup_add_definition)
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
        message(FATAL_ERROR "qmsetup_add_definition: called with incorrect number of arguments")
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

    qmsetup_set_value(_prop FUNC_PROPERTY CONFIG_DEFINITIONS)

    if(FUNC_TARGET)
        set_property(TARGET ${FUNC_TARGET} APPEND PROPERTY ${_prop} "${_result}")
    else()
        set_property(GLOBAL APPEND PROPERTY ${_prop} "${_result}")
    endif()
endfunction()

#[[
    Generate a configuration header. If the configuration has not changed, the generated file's
    timestemp will not be updated when you reconfigure it.

    qmsetup_generate_config(<file>
        [TARGET <target>]
        [PROPERTY <prop>]
        [WARNING_FILE <file>]
        [NO_WARNING]
        [NO_HASH]
    )
]] #
function(qmsetup_generate_config _file)
    set(options NO_WARNING NO_HASH)
    set(oneValueArgs TARGET PROPERTY)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool)
    _qmsetup_get_core_tool(_tool "qmsetup_generate_config")

    qmsetup_set_value(_prop FUNC_PROPERTY CONFIG_DEFINITIONS)

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

        list(APPEND _args ${_file})

        if(NOT FUNC_NO_WARNING)
            list(APPEND _args "-w" ${FUNC_WARNING_FILE})
        endif()

        if(FUNC_NO_HASH)
            list(APPEND _args "-f")
        endif()

        execute_process(COMMAND ${_tool} configure ${_args}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMAND_ERROR_IS_FATAL ANY
        )
    endif()
endfunction()

#[[
    Generate build info information header.

    qmsetup_generate_build_info(<file>
        [ROOT_DIRECTORY <dir>]
        [PREFIX <prefix>]
        [WARNING_FILE <file>]
        [NO_WARNING]
        [NO_HASH]
        [REQUIRED]
    )

    file: Output file

    ROOT_DIRECTORY: Repository root directory (CMake will try to run `git` at this directory)
    PREFIX: Macros prefix, default to `PROJECT_NAME`
    REQUIRED: Abort if there's any error with git
]] #
function(qmsetup_generate_build_info _file)
    set(options NO_WARNING NO_HASH REQUIRED)
    set(oneValueArgs ROOT_DIRECTORY PREFIX)
    set(multiValueArgs)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Get tool
    set(_tool)
    _qmsetup_get_core_tool(_tool "qmsetup_generate_build_info")

    if(FUNC_PREFIX)
        set(_prefix ${FUNC_PREFIX})
    else()
        string(TOUPPER "${PROJECT_NAME}" _prefix)
    endif()

    set(_dir)
    qmsetup_set_value(_dir FUNC_ROOT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

    set(_git_branch "unknown")
    set(_git_hash "unknown")
    set(_git_commit_time "unknown")
    set(_git_commit_author "unknown")
    set(_git_commit_email "unknown")

    find_package(Git QUIET)

    if(Git_FOUND)
        # Branch
        execute_process(
            COMMAND ${GIT_EXECUTABLE} symbolic-ref --short -q HEAD
            OUTPUT_VARIABLE _temp
            ERROR_VARIABLE _err
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            WORKING_DIRECTORY ${_dir}
            RESULT_VARIABLE _code
        )

        if(${_code} EQUAL 0)
            set(_git_branch ${_temp})
        elseif(FUNC_REQUIRED)
            message(FATAL_ERROR "${_err}")
        endif()

        # Hash
        execute_process(
            COMMAND ${GIT_EXECUTABLE} log -1 "--pretty=format:%H\n%aI\n%aN\n%aE"
            OUTPUT_VARIABLE _temp
            ERROR_VARIABLE _err
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
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
        elseif(FUNC_REQUIRED)
            message(FATAL_ERROR "${_err}")
        endif()
    elseif(FUNC_REQUIRED)
        message(FATAL_ERROR "Git not found")
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

    list(APPEND _args ${_file})

    if(NOT FUNC_NO_WARNING)
        list(APPEND _args "-w" ${FUNC_WARNING_FILE})
    endif()

    if(FUNC_NO_HASH)
        list(APPEND _args "-f")
    endif()

    execute_process(COMMAND ${_tool} configure ${_args}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        COMMAND_ERROR_IS_FATAL ANY
    )
endfunction()