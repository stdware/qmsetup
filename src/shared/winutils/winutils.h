#ifndef WINUTILS_H
#define WINUTILS_H

#include <string>
#include <vector>

namespace WinUtils {

    std::wstring winErrorMessage(uint32_t error, bool nativeLanguage = false);

    // Read a PE executable and determine dependent libraries, word size
    // and debug flags.
    bool readPeExecutable(const std::wstring &peExecutableFileName, std::wstring *errorMessage,
                          std::vector<std::string> *dependentLibrariesIn, unsigned *wordSizeIn,
                          bool *isDebugIn, bool isMinGW, unsigned short *machineArchIn);

}

#endif // WINUTILS_H
