project(incsync VERSION ${QTMEDIATE_MODULES_VERSION})

file(GLOB_RECURSE _src *.h *.cpp)
add_executable(${PROJECT_NAME} ${_src})

configure_target(${PROJECT_NAME})

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_20)
target_link_libraries(${PROJECT_NAME} PRIVATE stdimpl syscmdline::syscmdline)