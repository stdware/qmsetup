#ifndef UTILS_H
#define UTILS_H

#include <string>
#include <vector>
#include <filesystem>
#include <chrono>

namespace Utils {

    // Filesystem Utils
    struct FileTime {
        std::chrono::system_clock::time_point accessTime;
        std::chrono::system_clock::time_point modifyTime;
        std::chrono::system_clock::time_point statusChangeTime; // Creation time on Windows
    };

    FileTime fileTime(const std::filesystem::path &path);

    void setFileTime(const std::filesystem::path &path, const FileTime &times);

    inline void syncFileTime(const std::filesystem::path &dest, const std::filesystem::path &src) {
        setFileTime(dest, fileTime(src));
    }

    // String Utils
    template <class T>
    std::vector<std::basic_string<T>> split(const std::basic_string<T> &s,
                                            const std::basic_string<T> &delimiter) {
        std::vector<std::basic_string<T>> tokens;
        typename std::basic_string<T>::size_type start = 0;
        typename std::basic_string<T>::size_type end = s.find(delimiter);
        while (end != std::basic_string<T>::npos) {
            tokens.push_back(s.substr(start, end - start));
            start = end + delimiter.size();
            end = s.find(delimiter, start);
        }
        tokens.push_back(s.substr(start));
        return tokens;
    }

    // OS Utils
    std::vector<std::string> resolveExecutableDependencies(const std::filesystem::path &path);

    std::string trim(const std::string &str) {
        auto start = str.begin();
        while (start != str.end() && std::isspace(*start)) {
            start++;
        }

        auto end = str.end();
        do {
            end--;
        } while (std::distance(start, end) > 0 && std::isspace(*end));

        return std::string(start, end + 1);
    }

#ifdef _WIN32
    std::string local8bit_to_utf8(const std::string &s);
#else
    void setFileRunPaths(const std::string &file, const std::vector<std::string> &paths);
#endif

}


#endif // UTILS_H
