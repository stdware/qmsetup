# Usage:
# cmake
# -D src=<dir>
# -D dest=<dir>
# [-D copy=TRUE]
# -P GenInclude.cmake

# Generate include files from source directory into a new directory tiledly

# python: https://github.com/SineStriker/cpp-repo-scripts/blob/main/scripts/gen_include.py

# Check defined
if(NOT DEFINED src)
    message(FATAL_ERROR "Argument \"src\" not specified.")
endif()

if(NOT DEFINED dest)
    message(FATAL_ERROR "Argument \"dest\" not specified.")
endif()

if(NOT DEFINED copy)
    set(copy off)
endif()

# Enable "IN_LIST"
cmake_policy(SET CMP0057 NEW)

# Get absolute paths
if(NOT IS_ABSOLUTE ${src})
    get_filename_component(_src_dir ${src} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_BINARY_DIR})
else()
    set(_src_dir ${src})
endif()

if(NOT IS_ABSOLUTE ${dest})
    get_filename_component(_dest_dir ${dest} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_BINARY_DIR})
else()
    set(_dest_dir ${dest})
endif()

if(NOT IS_DIRECTORY ${_src_dir})
    message(FATAL_ERROR "Source directory \"${_src_dir}\" doesn't exist.")
endif()

# Collect files
file(GLOB_RECURSE _header_files ${_src_dir}/*.h ${_src_dir}/*.hpp)

set(_header_file_names)

foreach(_item ${_header_files})
    get_filename_component(_name ${_item} NAME)
    list(APPEND _header_file_names ${_name})
endforeach()

# Removed deprecated ones
file(GLOB_RECURSE _existing_files ${_dest_dir}/*.h ${_dest_dir}/*.hpp)

foreach(_item ${_existing_files})
    get_filename_component(_name ${_item} NAME)

    if(${_name} IN_LIST _header_file_names)
        continue()
    endif()

    file(REMOVE ${_item})
endforeach()

foreach(_file ${_header_files})
    get_filename_component(file_name ${_file} NAME)

    if(file_name MATCHES "_p\\.")
        set(_dir ${_dest_dir}/private)
    else()
        set(_dir ${_dest_dir})
    endif()

    if(NOT EXISTS ${_dir})
        file(MAKE_DIRECTORY ${_dir})
    endif()

    file(RELATIVE_PATH rel_path ${_dir} ${_file})
    string(REPLACE "\\" "/" rel_path ${rel_path})
    set(_new_file ${_dir}/${file_name})

    if(copy)
        file(COPY ${_file} DESTINATION ${_dir})
    else()
        set(_content "#include \"${rel_path}\"\n")

        # Compare
        if(EXISTS ${_new_file})
            file(READ ${_new_file} _file_content)

            if(${_file_content} STREQUAL ${_content})
                continue()
            endif()

            file(REMOVE ${_new_file})
        endif()

        file(WRITE ${_new_file} ${_content})
    endif()
endforeach()