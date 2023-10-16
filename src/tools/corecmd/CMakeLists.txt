project(corecmd VERSION ${QTMEDIATE_MODULES_VERSION})

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED on)

file(GLOB_RECURSE _src *.h *.cpp)

add_executable(${PROJECT_NAME} ${_src})

configure_target(${PROJECT_NAME})

target_link_libraries(${PROJECT_NAME} PRIVATE stdimpl)