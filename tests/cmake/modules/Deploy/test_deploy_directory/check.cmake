# What qm_deploy_directory brought into the install tree.
#
# Included by testing/build.cmake once the tree exists. `_prefix` is
# where it was installed.
#
# The application was installed without the library it links, so a deployment
# that did nothing would leave it unable to start.

if(WIN32)
    set(_library_dir "${_prefix}/bin")
    set(_extra_name "qmtest_extra_lib.dll")
elseif(APPLE)
    set(_library_dir "${_prefix}/lib")
    set(_extra_name "libqmtest_extra_lib.dylib")
else()
    set(_library_dir "${_prefix}/lib")
    set(_extra_name "libqmtest_extra_lib.so")
endif()

qmtest_exists("the library the application needs was brought along" "${_library_dir}/${_extra_name}")

# And nothing of the system came with it, --standard having been asked for.
file(GLOB _deployed "${_library_dir}/*")
set(_runtime)

foreach(_item IN LISTS _deployed)
    get_filename_component(_name "${_item}" NAME)
    string(TOLOWER "${_name}" _lowered)

    if(_lowered MATCHES "^(libc\\.|libc-|libm\\.|libm-|libgcc|libstdc|libsystem|msvcp|vcruntime|ucrtbase|api-ms-win)")
        list(APPEND _runtime "${_name}")
    endif()
endforeach()

qmtest_equal("and nothing of the system came with it" "${_runtime}" "")
