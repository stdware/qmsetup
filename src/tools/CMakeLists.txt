set(RC_COPYRIGHT "Copyright ${CK_DEV_START_YEAR}-${_year} SineStriker")
set(RC_DESCRIPTION "QtMediate CMake Modules Tool")

function(configure_target _target)
    if(WIN32)
        string(TIMESTAMP _year "%Y")
        qtmediate_add_win_rc(${_target}
            COPYRIGHT ${RC_COPYRIGHT}
            DESCRIPTION ${RC_DESCRIPTION}
        )
    endif()

    target_compile_definitions(${PROJECT_NAME} PRIVATE TOOL_DESC="${RC_DESCRIPTION}, Version ${QTMEDIATE_MODULES_VERSION}")
    target_compile_definitions(${PROJECT_NAME} PRIVATE TOOL_VERSION="${QTMEDIATE_MODULES_VERSION}")

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
else()
    add_subdirectory(unixdeps)
endif()

add_subdirectory(corecmd)