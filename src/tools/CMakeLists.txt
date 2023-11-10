add_subdirectory(cfggen)

add_subdirectory(incsync)

if(WIN32)
    add_subdirectory(windeps)
else()
    add_subdirectory(unixdeps)
endif()

add_subdirectory(corecmd)