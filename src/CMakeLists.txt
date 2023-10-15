include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

add_subdirectory(shared)
add_subdirectory(tools)

if(TRUE)
    # Add install target
    set(_install_dir ${CMAKE_INSTALL_LIBDIR}/cmake/${QTMEDIATE_MODULES_INSTALL_NAME})

    # Add version file
    write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}-config-version.cmake"
        VERSION ${QTMEDIATE_MODULES_VERSION}
        COMPATIBILITY AnyNewerVersion
    )

    # Add configuration file
    configure_package_config_file(
        ${CMAKE_CURRENT_LIST_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}-config.cmake.in
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}-config.cmake"
        INSTALL_DESTINATION ${_install_dir}
        NO_CHECK_REQUIRED_COMPONENTS_MACRO
    )

    # Install cmake files
    install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}-config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${QTMEDIATE_MODULES_INSTALL_NAME}-config-version.cmake"
        DESTINATION ${_install_dir}
    )

    # Install cmake targets files
    install(EXPORT ${QTMEDIATE_MODULES_INSTALL_NAME}Targets
        FILE "${QTMEDIATE_MODULES_INSTALL_NAME}-targets.cmake"
        NAMESPACE qtmediate-cmake-modules::
        DESTINATION ${_install_dir}
    )

    # Install cmake modules
    install(DIRECTORY ../cmake/
        DESTINATION ${_install_dir}/cmake
        PATTERN "__pycache__" EXCLUDE
    )
endif()