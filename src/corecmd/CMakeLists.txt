project(corecmd VERSION ${QTMEDIATE_MODULES_VERSION})

string(TIMESTAMP _year "%Y")
set(RC_COPYRIGHT "Copyright ${_year} SineStriker")
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
target_link_libraries(${PROJECT_NAME} PRIVATE syscmdline::syscmdline)

# Add features
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_20)
set_target_properties(${PROJECT_NAME} PROPERTIES
    CXX_EXTENSIONS OFF
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
)

if(WIN32)
    target_link_libraries(${PROJECT_NAME} PRIVATE shlwapi)
    target_compile_definitions(${PROJECT_NAME} PRIVATE _CRT_SECURE_NO_WARNINGS)
endif()

if(WIN32)
    qtmediate_add_win_rc(${PROJECT_NAME}
        COPYRIGHT ${RC_COPYRIGHT}
        DESCRIPTION ${RC_DESCRIPTION}
    )
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE TOOL_DESC="${RC_DESCRIPTION}, Version ${QTMEDIATE_MODULES_VERSION}")
target_compile_definitions(${PROJECT_NAME} PRIVATE TOOL_VERSION="${QTMEDIATE_MODULES_VERSION}")

set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME qmcorecmd)

# Vcpkg requires the binary to be installed in "tools/${PORT}" directory
if(QTMEDIATE_MODULES_VCPKG_TOOLS_HINT)
    set(_tools_dir tools/${QTMEDIATE_MODULES_INSTALL_NAME})
else()
    set(_tools_dir ${CMAKE_INSTALL_BINDIR})
endif()

install(TARGETS ${PROJECT_NAME}
    EXPORT ${QTMEDIATE_MODULES_INSTALL_NAME}Targets
    RUNTIME DESTINATION "${_tools_dir}" OPTIONAL
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}" OPTIONAL
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}" OPTIONAL
)
