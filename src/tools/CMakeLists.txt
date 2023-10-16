function(configure_target _target)
    if(WIN32)
        string(TIMESTAMP _year "%Y")
        qtmediate_add_win_rc(${_target}
            COPYRIGHT "Copyright ${CK_DEV_START_YEAR}-${_year} SineStriker"
            DESCRIPTION "QtMediate CMake Modules Tool"
        )
    endif()

    install(TARGETS ${_target}
        EXPORT ${QTMEDIATE_MODULES_INSTALL_NAME}Targets
        RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL
        LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}" OPTIONAL
        ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}" OPTIONAL
    )
endfunction()

add_subdirectory(cfggen)

add_subdirectory(incsync)

if(WIN32)
    add_subdirectory(windeps)
endif()

add_subdirectory(corecmd)