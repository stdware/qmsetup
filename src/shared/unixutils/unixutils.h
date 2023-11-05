#ifndef UNIXUTILS_H
#define UNIXUTILS_H

#include <string>
#include <vector>

namespace UnixUtils {

    bool readUnixExecutable(const std::string &fileName, std::vector<std::string> *libs,
                            std::string *errorMessage);

}

#endif // UNIXUTILS_H
