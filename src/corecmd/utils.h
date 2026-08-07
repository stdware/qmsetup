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
    //
    // Splitting, joining, trimming, case folding and the rest come from stdcorelib. What is
    // left here is the one thing it does not have.
    template <class T>
    void replaceString(std::basic_string<T> &s, const std::basic_string<T> &pattern,
                       const std::basic_string<T> &text) {
        size_t idx = 0;
        while ((idx = s.find(pattern, idx)) != std::basic_string<T>::npos) {
            s.replace(idx, pattern.size(), text);
            idx += text.size();
        }
    }

    // OS Utils
#ifdef _WIN32
    std::vector<std::wstring>
        resolveWinBinaryDependencies(const std::filesystem::path &path,
                                     const std::vector<std::filesystem::path> &searchingPaths,
                                     std::vector<std::string> *unparsed);
#else
    // Runs a program and answers with what it wrote, with its standard error folded in. Throws
    // on anything other than a nought exit, carrying what the program said.
    //
    // Windows has no counterpart because nothing there needs one. Its dependencies are read out
    // of the import table rather than by asking a tool.
    std::string executeCommand(const std::string &command, const std::vector<std::string> &args);

    void setFileRPaths(const std::string &file, const std::vector<std::string> &paths);

    std::vector<std::string>
        resolveUnixBinaryDependencies(const std::filesystem::path &path,
                                      const std::vector<std::filesystem::path> &searchingPaths,
                                      std::vector<std::string> *unparsed = nullptr);
#endif

#ifdef __APPLE__
    std::vector<std::string> getMacAbsoluteDependencies(const std::string &file);

    void replaceMacFileDependencies(
        const std::string &file, const std::vector<std::pair<std::string, std::string>> &depPairs);
#elif defined(__linux__)
    std::string getInterpreter(const std::string &file);

    bool setFileInterpreter(const std::string &file, const std::string &interpreter);
#endif
}


#endif // UTILS_H
