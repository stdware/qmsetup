project(winutils)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED on)

file(GLOB_RECURSE _src *.h *.cpp)

add_library(${PROJECT_NAME} STATIC ${_src})

target_link_libraries(${PROJECT_NAME} PRIVATE shlwapi)

target_include_directories(${PROJECT_NAME} PUBLIC .)