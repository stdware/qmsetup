# Usage:
# cmake
# -D src=<dir>
# -D dest=<dir>
# [-D clean=TRUE]
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

if(NOT DEFINED clean)
    set(clean off)
endif()

if(NOT DEFINED copy)
    set(copy off)
endif()

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

# Clean if exists
if(clean AND EXISTS ${_dest_dir})
    if(IS_DIRECTORY ${_dest_dir})
        file(REMOVE_RECURSE ${_dest_dir})
    else()
        file(REMOVE ${_dest_dir})
    endif()
endif()

if(NOT IS_DIRECTORY ${_src_dir})
    message(FATAL_ERROR "Source directory \"${_src_dir}\" doesn't exist.")
endif()

file(GLOB_RECURSE header_files ${_src_dir}/*.h ${_src_dir}/*.hpp)

foreach(_file ${header_files})
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
    set(new_file ${_dir}/${file_name})

    if(copy)
        file(COPY ${_file} DESTINATION ${_dir})
    else()
        file(WRITE ${new_file} "#include \"${rel_path}\"\n")
    endif()
endforeach()