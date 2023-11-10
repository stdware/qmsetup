project(corecmd VERSION ${QTMEDIATE_MODULES_VERSION})

set(RC_COPYRIGHT "Copyright ${CK_DEV_START_YEAR}-${_year} SineStriker")
set(RC_DESCRIPTION "QtMediate CMake Modules Tool")

set(_src
    main.cpp
    sha-256.h
    sha-256.cpp
    utils.h
    utils.cpp
)

if(WIN32)
    list(APPEND _src utils_win.cpp)
else()
    list(APPEND _src utils_unix.cpp)
endif()

add_executable(${PROJECT_NAME} ${_src})

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_20)
target_link_libraries(${PROJECT_NAME} PRIVATE stdimpl syscmdline::syscmdline)

if(WIN32)
    string(TIMESTAMP _year "%Y")
    qtmediate_add_win_rc(${PROJECT_NAME}
        COPYRIGHT ${RC_COPYRIGHT}
        DESCRIPTION ${RC_DESCRIPTION}
    )
endif()

if(WIN32)
    target_link_libraries(${PROJECT_NAME} PRIVATE shlwapi)
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE TOOL_DESC="${RC_DESCRIPTION}, Version ${QTMEDIATE_MODULES_VERSION}")
target_compile_definitions(${PROJECT_NAME} PRIVATE TOOL_VERSION="${QTMEDIATE_MODULES_VERSION}")

set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME qmcorecmd)

install(TARGETS ${PROJECT_NAME}
    EXPORT ${QTMEDIATE_MODULES_INSTALL_NAME}Targets
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}" OPTIONAL
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}" OPTIONAL
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}" OPTIONAL
)