#include "stdimpl.h"

#include <fstream>
#include <cstdarg>
#include <cstring>
#include <iomanip>
#include <sstream>

#ifdef _WIN32
#  include <Windows.h>

#  include <fcntl.h>
#  include <io.h>
#else
#  include <limits.h>
#  include <sys/stat.h>
#  include <utime.h>
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
        while (std::getline(file, s, '\0')) {
            res.push_back(s);
        }
        file.close();
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
        if (_NSGetExecutablePath(buf, &size) != 0) {
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

    int tstrcmp(const TChar *s, const TChar *p) {
#ifdef _WIN32
        return wcscmp(s, p);
#else
        return strcmp(s, p);
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

#ifdef _WIN32

    // Helper functions to convert between FILETIME and std::chrono::system_clock::time_point
    static std::chrono::system_clock::time_point filetime_to_timepoint(const FILETIME &ft) {
        // Windows file time starts from January 1, 1601
        // std::chrono::system_clock starts from January 1, 1970
        const long long WIN_EPOCH = 116444736000000000LL; // in hundreds of nanoseconds
        long long duration = (static_cast<long long>(ft.dwHighDateTime) << 32) + ft.dwLowDateTime;
        duration -= WIN_EPOCH;                            // convert to Unix epoch
        return std::chrono::system_clock::from_time_t(duration / 10000000LL);
    }

    static FILETIME timepoint_to_filetime(const std::chrono::system_clock::time_point &tp) {
        FILETIME ft;
        const long long WIN_EPOCH = 116444736000000000LL; // in hundreds of nanoseconds
        long long duration =
            std::chrono::duration_cast<std::chrono::microseconds>(tp.time_since_epoch()).count();
        duration = duration * 10 + WIN_EPOCH;
        ft.dwLowDateTime = static_cast<DWORD>(duration & 0xFFFFFFFF);
        ft.dwHighDateTime = static_cast<DWORD>((duration >> 32) & 0xFFFFFFFF);
        return ft;
    }

#endif

#ifdef _WIN32

    FileTime fileTime(const TString &path) {
        HANDLE hFile = CreateFileW(path.data(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                                   OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile == INVALID_HANDLE_VALUE) {
            return {};
        }

        FILETIME creationTime, lastAccessTime, lastWriteTime;
        if (!GetFileTime(hFile, &creationTime, &lastAccessTime, &lastWriteTime)) {
            CloseHandle(hFile);
            return {};
        }
        CloseHandle(hFile);

        FileTime times;
        // ... (convert FILETIMEs to std::chrono::system_clock::time_point and store in times)
        times.accessTime = filetime_to_timepoint(lastAccessTime);
        times.modifyTime = filetime_to_timepoint(lastWriteTime);
        times.statusChangeTime = filetime_to_timepoint(creationTime);

        return times;
    }

    bool setFileTime(const TString &path, const FileTime &times) {
        HANDLE hFile = CreateFileW(path.data(), FILE_WRITE_ATTRIBUTES, FILE_SHARE_WRITE, nullptr,
                                   OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile == INVALID_HANDLE_VALUE) {
            return false;
        }

        FILETIME creationTime, lastAccessTime, lastWriteTime;
        // ... (convert times.accessTime and times.modifyTime to FILETIMEs)
        lastAccessTime = timepoint_to_filetime(times.accessTime);
        lastWriteTime = timepoint_to_filetime(times.modifyTime);
        creationTime = timepoint_to_filetime(times.statusChangeTime);

        if (!SetFileTime(hFile, &creationTime, &lastAccessTime, &lastWriteTime)) {
            CloseHandle(hFile);
            return false;
        }
        CloseHandle(hFile);
        return true;
    }

#else // For POSIX systems like Linux/Mac

    FileTime fileTime(const std::filesystem::path &path) {
        struct stat sb;
        if (stat(path.c_str(), &sb) == -1) {
            return {};
        }

        FileTime times;
        times.accessTime = std::chrono::system_clock::from_time_t(sb.st_atime);
        times.modifyTime = std::chrono::system_clock::from_time_t(sb.st_mtime);
        times.statusChangeTime = std::chrono::system_clock::from_time_t(sb.st_ctime);
        return times;
    }

    bool setFileTime(const std::filesystem::path &path, const FileTime &times) {
        struct utimbuf new_times;
        new_times.actime = std::chrono::system_clock::to_time_t(times.accessTime);
        new_times.modtime = std::chrono::system_clock::to_time_t(times.modifyTime);
        if (utime(path.c_str(), &new_times) != 0) {
            return false;
        }
        return true;
    }

#endif

}