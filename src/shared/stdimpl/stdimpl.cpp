#include "stdimpl.h"

#include <fstream>
#include <cstdarg>
#include <iomanip>
#include <sstream>

#ifdef _WIN32
#  include <Windows.h>

#  include <fcntl.h>
#  include <io.h>
#else
#  include <limits.h>
#  ifdef __APPLE__
#    include <crt_externs.h>
#    include <mach-o/dyld.h>
#  endif
#endif

namespace StdImpl {

#ifdef _WIN32
    struct LocaleGuard {
        LocaleGuard() {
            mode = _setmode(_fileno(stdout), _O_U16TEXT);
        }
        ~LocaleGuard() {
            _setmode(_fileno(stdout), mode);
        }
        int mode;
    };
#endif

    TStringList commandLineArguments() {
        TStringList res;
#ifdef _WIN32
        int argc;
        auto argvW = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
        if (argvW == nullptr)
            return {};
        res.reserve(argc);
        for (int i = 0; i != argc; ++i) {
            res.push_back(argvW[i]);
        }
        ::LocalFree(argvW);
#elif defined(__APPLE__)
        auto argv = *(_NSGetArgv());
        for (int i = 0; argv[i] != nullptr; ++i) {
            res.push_back(argv[i]);
        }
#else
        std::ifstream file("/proc/self/cmdline", std::ios::in);
        if (file.fail())
            return {};
        std::string s;
        char c;
        while (file.get(c)) {
            if (c == '\0') {
                if (!s.empty()) {
                    res.push_back(s);
                    s.clear();
                }
            } else {
                s.push_back(c);
            }
        }
#endif
        return res;
    }
    TString appPath() {
#ifdef _WIN32
        wchar_t buf[MAX_PATH];
        if (!::GetModuleFileNameW(nullptr, buf, MAX_PATH)) {
            return {};
        }
        return buf;
#elif defined(__APPLE__)
        char buf[PATH_MAX];
        uint32_t size = sizeof(buf);
        if (_NSGetExecutablePath(path, &size) != 0) {
            return {};
        }
        return buf;
#else
        char buf[PATH_MAX];
        if (!realpath("/proc/self/exe", buf)) {
            return {};
        }
        return buf;
#endif
    }

    TString appName() {
        auto appName = appPath();
        auto slashIdx = appName.find_last_of(
#ifdef _WIN32
            _TSTR("\\")
#else
            _TSTR("/")
#endif
        );
        if (slashIdx != TString::npos) {
            appName = appName.substr(slashIdx + 1);
        }
        return appName;
    }

    void tprintf(const TChar *format, ...) {
#ifdef _WIN32
        LocaleGuard g;

        va_list args;
        va_start(args, format);
        vwprintf(format, args);
        va_end(args);
#else
        va_list args;
        va_start(args, format);
        vprintf(format, args);
        va_end(args);
#endif
    }

    std::string toHexString(const std::vector<uint8_t> &data) {
        std::stringstream ss;
        ss << std::hex << std::setfill('0');
        for (auto byte : data) {
            ss << std::setw(2) << static_cast<int>(byte);
        }
        return ss.str();
    }

    std::vector<uint8_t> fromHexString(const std::string &str) {
        if (str.length() % 2 != 0) {
            throw std::invalid_argument("Invalid hex string length");
        }

        std::vector<uint8_t> data;
        for (size_t i = 0; i < str.length(); i += 2) {
            std::string byteString = str.substr(i, 2);
            uint8_t byte = static_cast<uint8_t>(std::stoi(byteString, nullptr, 16));
            data.push_back(byte);
        }
        return data;
    }

}