project(winutils)

file(GLOB_RECURSE _src *.h *.cpp)
add_library(${PROJECT_NAME} STATIC ${_src})

target_link_libraries(${PROJECT_NAME} PRIVATE shlwapi)
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_20)
target_include_directories(${PROJECT_NAME} PUBLIC .)