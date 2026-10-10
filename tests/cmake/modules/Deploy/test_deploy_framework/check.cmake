# What qm_deploy_directory did with a framework in the install tree.
#
# Included by testing/build.cmake once the tree exists. `_prefix` is where it
# was installed, and `_build` is the build directory of the project.

set(_frameworks "${_prefix}/Frameworks")
set(_binary "${_frameworks}/QmTestFw.framework/Versions/A/QmTestFw")

qmtest_exists("the dependency of the framework is deployed beside the framework"
    "${_frameworks}/libqmtest_fw_dep.dylib")

# ------------------------------------------------------------------
# Rpaths of the framework
# ------------------------------------------------------------------

execute_process(COMMAND otool -l "${_binary}" OUTPUT_VARIABLE _load_commands)
string(REGEX MATCHALL "path [^\n]+ \\(offset [0-9]+\\)" _matches "${_load_commands}")
set(_rpaths)

foreach(_match IN LISTS _matches)
    string(REGEX REPLACE "^path (.+) \\(offset [0-9]+\\)$" "\\1" _rpath "${_match}")
    list(APPEND _rpaths "${_rpath}")
endforeach()

# The binary lies three levels below the directory of the framework. This rpath
# reaches the libraries deployed beside the framework. A deployment that passes
# the files inside the framework instead of the framework sets an rpath relative
# to each of those paths, one of which is a symbolic link at the top of the
# framework.
qmtest_contains("the framework receives the rpaths of a framework" "${_rpaths}"
    "@loader_path/../../..")

# ------------------------------------------------------------------
# Loading
# ------------------------------------------------------------------

execute_process(COMMAND "${_prefix}/bin/qmtest_fw_app"
    RESULT_VARIABLE _app_result
    OUTPUT_VARIABLE _app_output
    ERROR_VARIABLE _app_output
)
qmtest_equal("the application runs from the install tree" "${_app_result}" "0")

execute_process(COMMAND "${_build}/loader/qmtest_fw_loader" "${_binary}"
    RESULT_VARIABLE _loader_result
    OUTPUT_VARIABLE _loader_output
    ERROR_VARIABLE _loader_output
)
qmtest_equal("the framework loads its dependency through its own rpaths"
    "${_loader_result}" "0")
