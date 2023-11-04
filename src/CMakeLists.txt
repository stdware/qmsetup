include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Get syscmdline
find_package(syscmdline QUIET)

if(NOT TARGET syscmdline::syscmdline)
    set(SYSCMDLINE_INSTALL off)
    add_subdirectory(syscmdline)
endif()

# Add subdirectories
add_subdirectory(shared)
add_subdirectory(tools)

# Add headers
set(_corelib_name library)
add_library(${_corelib_name} INTERFACE)
target_include_directories(${_corelib_name} INTERFACE
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>"
    "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${QTMEDIATE_MODULES_INSTALL_NAME}>"
)

install(TARGETS ${_corelib_name}
    EXPORT ${QTMEDIATE_MODULES_INSTALL_NAME}Targets
)

if(TRUE)
    # Add install target
    set(_install_dir ${CMAKE_INSTALL_LIBDIR}/cmake/${QTMEDIATE_MODULES_INSTALL_NAME})

    # Add version file
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}Config-version.cmake"
        VERSION ${QTMEDIATE_MODULES_VERSION}
        COMPATIBILITY AnyNewerVersion
    )

    # Add configuration file
    configure_package_config_file(
        ${CMAKE_CURRENT_LIST_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}Config.cmake.in
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}Config.cmake"
        INSTALL_DESTINATION ${_install_dir}
        NO_CHECK_REQUIRED_COMPONENTS_MACRO
    )

    # Install cmake files
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}Config-version.cmake"
        DESTINATION ${_install_dir}
    )

    # Install cmake targets files
    install(EXPORT ${QTMEDIATE_MODULES_INSTALL_NAME}Targets
        FILE "${QTMEDIATE_MODULES_INSTALL_NAME}-targets.cmake"
        NAMESPACE qtmediateCM::
        DESTINATION ${_install_dir}
    )

    # Install headers
    install(DIRECTORY ../include/
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    # Install cmake modules
    install(DIRECTORY ../cmake/
        DESTINATION ${_install_dir}/cmake
    )
endif()