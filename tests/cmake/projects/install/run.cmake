# Builds and installs a project, then looks at what it installed.
#
# The two functions this is about, qm_basic_install and qm_deploy_directory,
# both work by adding install rules, and an install rule that is never run says
# nothing at all. So unlike every other test here this one builds and installs
# for real, which is why it is the slowest of them by a long way.

include(${QMTEST_HARNESS})

foreach(_required QMTEST_PROJECT QMTEST_PROJECT_BUILD QMTEST_INSTALL_PREFIX)
    if(NOT DEFINED ${_required})
        message(FATAL_ERROR "${_required} is not set. Run this through CTest, which passes it.")
    endif()
endforeach()

file(REMOVE_RECURSE "${QMTEST_PROJECT_BUILD}")
file(REMOVE_RECURSE "${QMTEST_INSTALL_PREFIX}")

# Runs a step, and stops here rather than letting the checks below report on a
# tree that was never finished.
function(step _what)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE _code OUTPUT_VARIABLE _out ERROR_VARIABLE _out)

    if(NOT _code EQUAL 0)
        message(FATAL_ERROR "${_what} failed:\n${_out}")
    endif()
endfunction()

set(_configure_args
    -S "${QMTEST_PROJECT}"
    -B "${QMTEST_PROJECT_BUILD}"
    "-DCMAKE_INSTALL_PREFIX=${QMTEST_INSTALL_PREFIX}"
    "-DQMSETUP_API=${QMSETUP_API}"
    "-DQMCORECMD=${QMCORECMD}"
    -DCMAKE_BUILD_TYPE=Release
)

if(QMTEST_GENERATOR)
    list(APPEND _configure_args -G "${QMTEST_GENERATOR}")
endif()

if(QMTEST_C_COMPILER)
    list(APPEND _configure_args "-DCMAKE_C_COMPILER=${QMTEST_C_COMPILER}")
endif()

step("configuring" ${CMAKE_COMMAND} ${_configure_args})
step("building" ${CMAKE_COMMAND} --build "${QMTEST_PROJECT_BUILD}" --config Release)
step("installing" ${CMAKE_COMMAND} --install "${QMTEST_PROJECT_BUILD}" --config Release)

set(_prefix "${QMTEST_INSTALL_PREFIX}")

# ------------------------------------------------------------------
# qm_basic_install
#
# Where the package files land depends on what GNUInstallDirs decided the
# library directory is called, which is not the same everywhere, so they are
# looked for rather than named.
# ------------------------------------------------------------------

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

# ------------------------------------------------------------------
# qm_deploy_directory
#
# The application was installed without the library it links, so a deployment
# that did nothing would leave it unable to start.
# ------------------------------------------------------------------

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

qmtest_report()
