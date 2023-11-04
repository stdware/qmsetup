add_subdirectory(stdimpl)

if(WIN32)
    add_subdirectory(winutils)
else()
    add_subdirectory(unixutils)
endif()