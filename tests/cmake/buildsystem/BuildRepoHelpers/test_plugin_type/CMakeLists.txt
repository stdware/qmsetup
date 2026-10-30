# The library type of <proj>_add_plugin: SHARED by default, MODULE if <proj>_PLUGIN_TYPE says so,
# and the keyword of a call in either case.
#
# The type is a property of the target, which can be read as soon as the target exists, so this
# project is configured by testing/configure.cmake and not built.

cmake_minimum_required(VERSION 3.19)
project(qmtest_plugin_type VERSION 1.0 LANGUAGES C)

include(${QMTEST_HARNESS})
include(${QMSETUP_API})

if(DEFINED QMCORECMD)
    set(QMSETUP_CORECMD_EXECUTABLE "${QMCORECMD}")
endif()

qm_import(private/BuildSystem)

# A prefix of its own, because the harness reads variables that start with QMTEST_
set(QMSETUP_BUILD_DIR "${CMAKE_BINARY_DIR}/out")
qm_setup_build_repo_helpers(typetest)
typetest_init_buildsystem(TYPETEST)

function(plugin_type _var _target)
    get_target_property(_type ${_target} TYPE)
    set(${_var} "${_type}" PARENT_SCOPE)
endfunction()

typetest_add_plugin(qmtest_default_plugin SOURCES src/plugin.c)
plugin_type(_type qmtest_default_plugin)
qmtest_equal("a plugin is a shared library by default" "${_type}" "SHARED_LIBRARY")

typetest_add_plugin(qmtest_module_plugin MODULE SOURCES src/plugin.c)
plugin_type(_type qmtest_module_plugin)
qmtest_equal("MODULE makes one plugin a module" "${_type}" "MODULE_LIBRARY")

set(TYPETEST_PLUGIN_TYPE MODULE)

typetest_add_plugin(qmtest_repository_plugin SOURCES src/plugin.c)
plugin_type(_type qmtest_repository_plugin)
qmtest_equal("<proj>_PLUGIN_TYPE makes every plugin a module" "${_type}" "MODULE_LIBRARY")

typetest_add_plugin(qmtest_shared_plugin SHARED SOURCES src/plugin.c)
plugin_type(_type qmtest_shared_plugin)
qmtest_equal("and SHARED of a call takes precedence over it" "${_type}" "SHARED_LIBRARY")

qmtest_report()
