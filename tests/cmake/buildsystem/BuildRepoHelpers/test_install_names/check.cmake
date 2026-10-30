# What <proj>_install left in the install tree.
#
# Included by testing/build.cmake once the tree exists. `_prefix` is where it
# was installed. The package directory depends on the library directory that
# GNUInstallDirs chose, so the files are looked for rather than named.

function(the_one_file _var _pattern)
    file(GLOB_RECURSE _found "${_prefix}/${_pattern}")
    list(LENGTH _found _count)

    if(_count EQUAL 1)
        set(${_var} "${_found}" PARENT_SCOPE)
        return()
    endif()

    set(${_var} "" PARENT_SCOPE)
endfunction()

the_one_file(_config "qmtestnames-config.cmake")
the_one_file(_version "qmtestnames-config-version.cmake")
the_one_file(_targets "qmtestnames-targets.cmake")
the_one_file(_pascal "QmTestNamesConfig.cmake")
the_one_file(_pascal_targets "QmTestNamesTargets.cmake")

qmtest_true("the configuration follows the lower case template" "${_config}")
qmtest_true("and so does the version file" "${_version}")
qmtest_true("and the export set is named in the same spelling" "${_targets}")
qmtest_false("no PascalCase configuration is installed" "${_pascal}")
qmtest_false("and no PascalCase targets file" "${_pascal_targets}")

if(_config)
    qmtest_file_contains("the template of the list directory is what was expanded" "${_config}" "QMTEST_NAMES_TEMPLATE")
endif()

if(_version)
    qmtest_file_contains("VERSION_TEMPLATE reaches qm_basic_install" "${_version}" "QMTEST_NAMES_VERSION_TEMPLATE")
    qmtest_file_contains("with the version of the project" "${_version}" "3\\.1\\.4")
endif()

if(_targets)
    qmtest_file_contains("the targets file exports the library" "${_targets}" "qmtest_names_lib")
endif()
