# What qm_basic_install left in the install tree.
#
# Included by testing/build.cmake once the tree exists. `_prefix` is
# where it was installed.
#
# Where the package files land depends on what GNUInstallDirs decided the
# library directory is called, which is not the same everywhere, so they are
# looked for rather than named.

function(the_one_file _var _pattern)
    file(GLOB_RECURSE _found "${_prefix}/${_pattern}")
    list(LENGTH _found _count)

    if(_count EQUAL 1)
        set(${_var} "${_found}" PARENT_SCOPE)
        return()
    endif()

    set(${_var} "" PARENT_SCOPE)
endfunction()

the_one_file(_config "QmTestPackageConfig.cmake")
the_one_file(_version_file "QmTestPackageConfigVersion.cmake")
the_one_file(_targets "qmtest_package_targets.cmake")

qmtest_true("a package configuration is installed" "${_config}")
qmtest_true("with a version file beside it" "${_version_file}")
qmtest_true("and the targets file for the export set" "${_targets}")

if(_config)
    # With no template of its own, the configuration written is one that pulls
    # in the targets file, which is the whole point of the default.
    qmtest_file_contains("the configuration includes the targets" "${_config}" "qmtest_package_targets\\.cmake")
    qmtest_file_contains("and was expanded from a package template" "${_config}" "PACKAGE_PREFIX_DIR")
endif()

if(_version_file)
    qmtest_file_contains("the version file carries the version" "${_version_file}" "2\\.3\\.4")
endif()

if(_targets)
    qmtest_file_contains("NAMESPACE reaches the exported name" "${_targets}" "QmTest::qmtest_package_lib")
endif()

# The three files sit together, since that is the one directory a caller has to
# point find_package at.
if(_config AND _targets)
    get_filename_component(_config_dir "${_config}" DIRECTORY)
    get_filename_component(_targets_dir "${_targets}" DIRECTORY)
    qmtest_equal("they are installed together" "${_targets_dir}" "${_config_dir}")

    get_filename_component(_config_dir_name "${_config_dir}" NAME)
    qmtest_equal("in a directory named after the package" "${_config_dir_name}" "QmTestPackage")
endif()

# The one given a template of its own
the_one_file(_templated "QmTestTemplatedConfig.cmake")
qmtest_true("a second package is installed alongside the first" "${_templated}")

if(_templated)
    qmtest_file_contains("CONFIG_TEMPLATE is what was expanded" "${_templated}" "QMTEST_CAME_FROM_A_TEMPLATE")
    qmtest_file_lacks("rather than the one that would have been written" "${_templated}" "qmtest_package_targets\\.cmake")
endif()

the_one_file(_templated_version "QmTestTemplatedConfigVersion.cmake")

if(_templated_version)
    qmtest_file_contains("VERSION is the one asked for" "${_templated_version}" "9\\.8\\.7")
    # The compatibility is not named in the file, only carried out, so what says
    # SameMajorVersion was used is that the major is what gets compared. The
    # other package took the default and does no such thing.
    qmtest_file_contains("COMPATIBILITY decides how it is compared"
        "${_templated_version}" "PACKAGE_FIND_VERSION_MAJOR")
endif()

if(_version_file)
    qmtest_file_lacks("and the default compares differently"
        "${_version_file}" "PACKAGE_FIND_VERSION_MAJOR")
endif()

# The one given a template spelled in lower case
the_one_file(_lower "qmtestlower-config.cmake")
the_one_file(_lower_version "qmtestlower-config-version.cmake")
the_one_file(_lower_pascal "QmTestLowerConfig.cmake")
qmtest_true("a lower case template gives a lower case configuration" "${_lower}")
qmtest_true("and a lower case version file" "${_lower_version}")
qmtest_false("and no PascalCase configuration" "${_lower_pascal}")

if(_lower)
    qmtest_file_contains("the lower case template is what was expanded" "${_lower}" "QMTEST_LOWER_TEMPLATE")
endif()

if(_lower_version)
    qmtest_file_contains("the lower case version file carries the version" "${_lower_version}" "1\\.2\\.3")
endif()

# The one whose lower case template lies in the list directory
the_one_file(_found "qmtestfound-config.cmake")
qmtest_true("without CONFIG_TEMPLATE the lower case template of the name is taken" "${_found}")

if(_found)
    qmtest_file_contains("and expanded" "${_found}" "QMTEST_FOUND_TEMPLATE")
endif()

# The one given a version template
the_one_file(_versioned "QmTestVersionedConfigVersion.cmake")
qmtest_true("a package with a version template is installed" "${_versioned}")

if(_versioned)
    qmtest_file_contains("VERSION_TEMPLATE is what was configured" "${_versioned}" "QMTEST_VERSION_FROM_A_TEMPLATE")
    qmtest_file_contains("with its variables replaced" "${_versioned}" "7\\.7\\.7\\.7")
    qmtest_file_lacks("rather than the file that would have been written" "${_versioned}" "PACKAGE_VERSION_COMPATIBLE")
endif()
