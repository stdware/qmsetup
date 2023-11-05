#include <filesystem>
#include <iostream>

#include <unixutils.h>
#include <stdimpl.h>

#include <syscmdline/parser.h>
#include <syscmdline/system.h>

int main(int argc, char *argv[]) {
    std::vector<std::string> libs;
    std::string errorMessage;
    if (!UnixUtils::readUnixExecutable(argv[1], &libs, &errorMessage)) {
        std::cout << errorMessage << std::endl;
        return -1;
    }
    for (const auto &lib : std::as_const(libs)) {
        std::cout << lib << std::endl;
    }
    return 0;
}