include_guard(DIRECTORY)

#[[
    Warning: This module depends on `QMSetupAPI.cmake`.
]] #
if(NOT DEFINED QMSETUP_MODULES_DIR)
    message(FATAL_ERROR "QMSETUP_MODULES_DIR not defined. Add find_package(qmsetup) to CMake first.")
endif()

#[[
    Initialize the build output directories of targets and resources.

    qm_init_directories()
]] #
macro(qm_init_directories)
    if(NOT DEFINED QMSETUP_BUILD_TREE_DIR)
        set(QMSETUP_BUILD_TREE_DIR ${CMAKE_BINARY_DIR})
    endif()

    if(NOT DEFINED QMSETUP_BUILD_DIR)
        set(QMSETUP_BUILD_DIR "${QMSETUP_BUILD_TREE_DIR}/out-$<LOWER_CASE:${CMAKE_SYSTEM_PROCESSOR}>-$<CONFIG>")
    endif()

    if(NOT DEFINED CMAKE_RUNTIME_OUTPUT_DIRECTORY)
        set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${QMSETUP_BUILD_DIR}/bin)
    endif()

    if(NOT DEFINED CMAKE_LIBRARY_OUTPUT_DIRECTORY)
        set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${QMSETUP_BUILD_DIR}/lib)
    endif()

    if(NOT DEFINED CMAKE_ARCHIVE_OUTPUT_DIRECTORY)
        set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${QMSETUP_BUILD_DIR}/lib)
    endif()

    if(NOT DEFINED CMAKE_BUILD_SHARE_DIR)
        set(CMAKE_BUILD_SHARE_DIR ${QMSETUP_BUILD_DIR}/share)
    endif()
endmacro()

#[[
    Add a resources copying command for whole project.

    qm_add_copy_command(<target>
        [CUSTOM_TARGET <target>]
        [FORCE] [VERBOSE]

        SOURCES <file/dir...> [DESTINATION <dir>] [INSTALL_DIR <dir>]
    )

    SOURCES: Source files or directories, directories ending with "/" will have their contents copied
    DESTINATION: Copy the source file to the destination path. If the given value is a relative path, 
                 the base directory depends on the type of the target
                    - `$<TARGET_FILE_DIR>`: real target
                    - `QMSETUP_BUILD_TREE_DIR`: custom target
    INSTALL_DIR: Install the source files into a subdirectory of the given path. The subdirectory is the
                 relative path from the `QMSETUP_BUILD_DIR` to `DESTINATION`.
]] #
function(qm_add_copy_command _target)
    set(options FORCE VERBOSE)
    set(oneValueArgs CUSTOM_TARGET DESTINATION INSTALL_DIR)
    set(multiValueArgs SOURCES)
    cmake_parse_arguments(FUNC "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Check tool
    if(NOT QMSETUP_CORECMD_EXECUTABLE)
        message(FATAL_ERROR "qm_add_copy_command: corecmd tool not found.")
    endif()

    if(NOT FUNC_SOURCES)
        message(FATAL_ERROR "qm_add_copy_command: SOURCES not specified.")
    endif()

    if(NOT TARGET ${_target})
        add_custom_target(${_target})
    endif()

    get_target_property(_type ${_target} TYPE)

    set(_dest)

    if(FUNC_DESTINATION)
        qm_has_genex(_has_genex ${FUNC_DESTINATION})

        if(_has_genex OR IS_ABSOLUTE ${FUNC_DESTINATION})
            set(_dest ${FUNC_DESTINATION})
        elseif(NOT ${_type} STREQUAL "UTILITY")
            set(_dest "$<TARGET_FILE_DIR:${_target}>/${FUNC_DESTINATION}")
        endif()
    else()
        if(NOT ${_type} STREQUAL "UTILITY")
            set(_dest "$<TARGET_FILE_DIR:${_target}>")
        endif()
    endif()

    if(NOT _dest AND QMSETUP_BUILD_DIR)
        set(_dest "${QMSETUP_BUILD_DIR}/${FUNC_DESTINATION}")
    endif()

    if(NOT _dest)
        message(FATAL_ERROR "qm_add_copy_command: destination cannot be determined. Try specify `DESTINATION`.")
    endif()

    set(_deploy_target)

    if(FUNC_CUSTOM_TARGET)
        set(_deploy_target ${FUNC_CUSTOM_TARGET})

        if(NOT TARGET ${_deploy_target})
            add_custom_target(${_deploy_target})
        endif()
    else()
        set(_deploy_target ${_target})
    endif()

    set(_extra_args)

    if(FUNC_FORCE)
        list(APPEND _extra_args -f)
    endif()

    if(FUNC_VERBOSE)
        list(APPEND _extra_args -V)
    endif()

    add_custom_command(TARGET ${_deploy_target} POST_BUILD
        COMMAND ${QMSETUP_CORECMD_EXECUTABLE} copy ${_extra_args} ${FUNC_SOURCES} ${_dest}
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    )

    if(FUNC_INSTALL_DIR)
        if(NOT QMSETUP_BUILD_DIR)
            message(FATAL_ERROR "qm_add_copy_command: `QMSETUP_BUILD_DIR` not defined, the install directory cannot be determined.")
        endif()

        install(CODE "
            set(_src \"${FUNC_SOURCES}\")

            # Calculate the relative path from build phase destination to build directory
            file(RELATIVE_PATH _rel_path \"${QMSETUP_BUILD_DIR}\" \"${_dest}\")

            # Calculate real install directory
            get_filename_component(_dest \"${FUNC_INSTALL_DIR}/\${_rel_path}\" ABSOLUTE BASE_DIR \${CMAKE_INSTALL_PREFIX})
    
            foreach(_file \${_src})
                # Avoid using `get_filename_component` to keep the trailing slash
                set(_path \${_file})
                if (NOT IS_ABSOLUTE \${_path})
                    set(_path \"${CMAKE_CURRENT_SOURCE_DIR}/\${_path}\")
                endif()
    
                if(IS_DIRECTORY \${_path})
                    set(_type DIRECTORY)
                else()
                    set(_type FILE)
                endif()
    
                file(INSTALL DESTINATION \"\${_dest}\"
                    TYPE \${_type}
                    FILES \${_path}
                )
            endforeach()
        ")
    endif()
endfunction()
