#ifdef _WIN32
#  include <stdcorelib/platform/windows/stdc_windows.h>
#endif

#include <iostream>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <regex>
#include <set>
#include <stdexcept>
#include <iomanip>
#include <map>

#include <stdcorelib/console.h>
#include <stdcorelib/path.h>
#include <stdcorelib/str.h>
#include <stdcorelib/system.h>
#include <stdcorelib/stlextra/algorithms.h>
#include <stdcorelib/support/commandline.h>

#include "sha-256.h"
#include "utils.h"

namespace cli = stdc::cli;

namespace fs = std::filesystem;

using stdc::u8printf;

// ---------------------------------------- Definitions ----------------------------------------

#ifdef _WIN32
#  define OS_EXECUTABLE "Windows PE"
#elif defined(__APPLE__)
#  define OS_EXECUTABLE "Mach-O"
#else
#  define OS_EXECUTABLE "ELF"
#endif

#ifdef _WIN32
using TChar = wchar_t;
using TString = std::wstring;
#else
using TChar = char;
using TString = std::string;
#endif

using TStringList = std::vector<TString>;
using TStringSet = std::set<TString>;

#ifdef _WIN32
#  define _TSTR(X) L##X
#  define tstrcmp  wcscmp
#else
#  define _TSTR(X) X
#  define tstrcmp  strcmp
#endif

// ---------------------------------------- Functions ----------------------------------------

static inline std::string tstr2str(const TString &str) {
    return stdc::path::to_utf8(str);
}

static inline TString str2tstr(const std::string &str) {
    return stdc::path::from_utf8(str);
}

static std::string time2str(const std::chrono::system_clock::time_point &t) {
    std::time_t t2 = std::chrono::system_clock::to_time_t(t);
    std::string s(32, '\0');
    // Cut to what was written. Without this the string keeps the nulls it was made with and
    // carries them wherever it is printed.
    s.resize(std::strftime(s.data(), s.size(), "%Y-%m-%d %H:%M:%S", std::localtime(&t2)));
    return s;
}

template <class T>
static bool searchInRegexList(std::basic_string<T> s,
                              const std::vector<std::basic_string<T>> &regexList) {
    // Replace separator
    std::replace(s.begin(), s.end(), _TSTR('\\'), _TSTR('/'));

    bool found = false;
    for (const auto &pattern : regexList) {
        if (std::regex_search(s.begin(), s.end(), std::basic_regex<T>(pattern))) {
            found = true;
            break;
        }
    }
    return found;
}

static bool removeEmptyDirectories(const fs::path &path, bool verbose) {
    bool isEmpty = true;
    for (const auto &entry : fs::directory_iterator(path)) {
        if (fs::is_directory(entry.path()) && removeEmptyDirectories(entry.path(), verbose)) {
            continue;
        }

        // File or non-empty directory
        isEmpty = false;
    }

    // Remove self if empty
    if (isEmpty) {
        if (verbose) {
            u8printf("Remove: \"%s\"\n", tstr2str(path).data());
        }
        fs::remove(path);
    }

    // Notify the caller the directory is empty or not
    return isEmpty;
}

static bool copyFile(const fs::path &file, const fs::path &dest, const fs::path &symlinkContent,
                     bool force, bool verbose) {
    auto target = dest / file.filename();
    if (fs::exists(target)) {
        if (stdc::path::clean_path(target) == stdc::path::clean_path(file))
            return false; // Same file

        if (!force && Utils::fileTime(target).modifyTime >= Utils::fileTime(file).modifyTime)
            return false; // Not updated
    } else if (!fs::is_directory(dest)) {
        fs::create_directories(dest);
    }

    if (!symlinkContent.empty()) {
        if (verbose) {
            u8printf("Link: from \"%s\" to \"%s\"\n", tstr2str(file).data(),
                   tstr2str(symlinkContent).data());
        }

        if (fs::exists(target))
            fs::remove(target);
        fs::create_symlink(symlinkContent, target);
    } else {
        if (verbose) {
            u8printf("Copy: from \"%s\" to \"%s\"\n", tstr2str(file).data(), tstr2str(target).data());
        }
        fs::copy(file, dest, fs::copy_options::overwrite_existing);
        Utils::syncFileTime(target, file); // Sync time for each file
    }

    return true;
}

static void copyDirectory(const fs::path &srcRootDir, const fs::path &srcDir,
                          const fs::path &destDir, bool force, bool verbose,
                          const std::function<bool(const fs::path &)> &ignore = {}) {
    fs::create_directories(destDir); // Ensure the destination directory exists

    for (const auto &entry : fs::directory_iterator(srcDir)) {
        const auto &entryPath = entry.path();
        if (ignore && ignore(entryPath))
            continue;

#ifndef _WIN32
        if (fs::is_symlink(entryPath)) {
            fs::path linkPath;
            try {
                linkPath = fs::canonical(entryPath);
            } catch (...) {
                // The symlink is invalid
                copyFile(entryPath, destDir, {}, force, verbose);
                continue;
            }

            // Copy if symlink points inside the source directory
            copyFile(entryPath, destDir,
                     stdc::str::starts_with(linkPath.string(), srcRootDir.string())
                         ? fs::relative(linkPath, fs::canonical(entryPath.parent_path())).string()
                         : std::string(),
                     force, verbose);
            continue;
        }
#endif

        if (fs::is_regular_file(entryPath)) {
            copyFile(entryPath, destDir, {}, force, verbose);
        } else if (fs::is_directory(entryPath)) {
            copyDirectory(srcRootDir, entryPath, destDir / entryPath.filename(), force, verbose,
                          ignore);
        }
    }
}

static std::string standardError(int code = errno) {
    return std::error_code(code, std::generic_category()).message();
}

#ifdef __APPLE__
static inline bool isFramework(const fs::path &path) {
    return stdc::str::to_lower(path.extension().string()) == ".framework";
}

static fs::path lib2framework(fs::path path, const fs::path &fallback = {}) {
    // Ensure the path has at least three ancestors (including root)
    for (int i = 0; i < 3; ++i) {
        if (!path.has_parent_path())
            return fallback;
        path = path.parent_path();
    }
    // Check if the ancestor's extension is ".framework"
    if (isFramework(path))
        return path;
    return fallback;
}

static fs::path framework2lib(fs::path path, const fs::path &fallback = {}) {
    try {
        return fs::canonical(path / path.stem());
    } catch (...) {
    }
    return fallback;
}

static fs::path framework2lib_debug(fs::path path, const fs::path &fallback = {}) {
    try {
        return fs::canonical(path / (path.stem().string() + "_debug"));
    } catch (...) {
    }
    return fallback;
}
#endif

#ifdef _WIN32
static inline bool isMSVCLibrary(const TString &fileName) {
    return stdc::str::starts_with(fileName, _TSTR("vcruntime")) ||
           stdc::str::starts_with(fileName, _TSTR("msvcp")) ||
           stdc::str::starts_with(fileName, _TSTR("concrt")) ||
           stdc::str::starts_with(fileName, _TSTR("vccorlib")) ||
           stdc::str::starts_with(fileName, _TSTR("ucrtbase"));
}

static inline fs::path searchWindowsSystemPaths(const TString &fileName) {
    // Asked for rather than spelled out. Windows is not always on C:, and a 32 bit process on a
    // 64 bit system is handed SysWOW64 here without anyone having to work out that it should be.
    static const std::vector<fs::path> searchPaths = []() -> std::vector<fs::path> {
        std::vector<fs::path> paths;
        wchar_t buf[MAX_PATH];
        if (UINT len = ::GetWindowsDirectoryW(buf, MAX_PATH); len > 0 && len < MAX_PATH) {
            paths.emplace_back(std::wstring(buf, len));
        }
        if (UINT len = ::GetSystemDirectoryW(buf, MAX_PATH); len > 0 && len < MAX_PATH) {
            paths.emplace_back(std::wstring(buf, len));
        }
        return paths;
    }();

    for (const auto &path : std::as_const(searchPaths)) {
        auto fullPath = path / fileName;
        if (fs::exists(fullPath)) {
            return fullPath;
        }
    }
    return {};
}
#else
static fs::path copyCanonical(const fs::path &path, const fs::path &dest, bool force,
                              bool verbose) {
    // Copy library files and symlinks, returns the real library file
    fs::path target;
    if (fs::is_symlink(path)) {
        auto linkPath = fs::canonical(path);
        copyFile(linkPath, dest, {}, force, verbose);              // Copy real file
        copyFile(path, dest, linkPath.filename(), force, verbose); // Copy link file
        target = dest / linkPath.filename();
    } else {
        copyFile(path, dest, {}, force, verbose); // Copy file
        target = dest / path.filename();
    }
    return target;
};
#endif

static inline fs::path toFramework(const fs::path &path) {
    return
#ifdef __APPLE__
        lib2framework(path, path)
#else
        path
#endif
            ;
}

static inline fs::path fromFramework(const fs::path &path) {
#ifdef __APPLE__
    auto res = framework2lib(path);
    if (res.empty()) {
        res = framework2lib_debug(path);
        if (res.empty()) {
            res = path;
        }
    }
    return res;
#else
    return path;
#endif
}

// ---------------------------------------- Commands ----------------------------------------

static inline bool isForceSet(const cli::ParseResult &result) {
    return result.option("-f").has_value();
}

static inline bool isDryRunSet(const cli::ParseResult &result) {
    return result.option("-d").has_value();
}

static inline bool isVerboseSet(const cli::ParseResult &result) {
    return result.isRoleSet(cli::Option::Verbose);
}

static inline bool isStandardSet(const cli::ParseResult &result) {
    return result.option("-s").has_value();
}

// The values of one argument of an option, across every time the option was given.
static std::vector<std::string> optionValues(const cli::ParseResult &result,
                                             std::string_view token, int index = 0) {
    auto given = result.option(token);
    if (!given) {
        return {};
    }
    return given->values<std::string>(index).value_or(std::vector<std::string>{});
}

// The values of one positional argument of the command that was reached.
static std::vector<std::string> argumentValues(const cli::ParseResult &result, int index) {
    return result.values<std::string>(index).value_or(std::vector<std::string>{});
}

static int cmd_copy(const cli::ParseResult &result) {
    bool force = isForceSet(result);
    bool verbose = isVerboseSet(result);

    std::set<fs::path> files;
    std::set<fs::path> directories;
    std::set<fs::path> directoryContents;
    {
        for (const auto &rawString : argumentValues(result, 0)) {
            bool contents = false;
            if (auto last = rawString.back(); last == '/' || last == '\\') {
                contents = true;
            }

            const auto &path = stdc::path::clean_path(fs::absolute(str2tstr(rawString)));
            if (fs::is_directory(path)) {
                (contents ? directoryContents : directories).insert(path);
            } else if (fs::exists(path)) {
                files.insert(path);
            } else {
                throw std::runtime_error("not a file or directory: \"" + rawString + "\"");
            }
        }
    }

    const auto &dest =
        stdc::path::clean_path(fs::absolute(str2tstr(result.value<std::string>(1).value_or(std::string()))));

    // Add excludes
    TStringList excludes;
    {
        const auto &excludeResult = optionValues(result, "-e");
        excludes.reserve(excludeResult.size());
        for (const auto &item : excludeResult) {
            excludes.emplace_back(str2tstr(item));
        }
    }

    // Copy
    const auto &excludeFunc = [&excludes](const fs::path &path) {
        return searchInRegexList(TString(path), excludes);
    };

    for (const auto &item : std::as_const(files)) {
        copyFile(item, dest, {}, force, verbose);
    }
    for (const auto &item : std::as_const(directories)) {
        copyDirectory(item, item, dest / item.filename(), force, verbose, excludeFunc);
    }
    for (const auto &item : std::as_const(directoryContents)) {
        copyDirectory(item, item, dest, force, verbose, excludeFunc);
    }

    return 0;
}

static int cmd_rmdir(const cli::ParseResult &result) {
    bool verbose = isVerboseSet(result);

    std::vector<fs::path> dirs;
    {
        const auto &dirsResult = argumentValues(result, 0);
        dirs.reserve(dirsResult.size());
        for (const auto &item : dirsResult) {
            dirs.emplace_back(fs::absolute(str2tstr(item)));
        }
    }

    for (const auto &item : std::as_const(dirs)) {
        if (!fs::is_directory(item)) {
            continue;
        }
        removeEmptyDirectories(item, verbose);
    }
    return 0;
}

static int cmd_touch(const cli::ParseResult &result) {
    bool verbose = isVerboseSet(result);

    const auto &file = str2tstr(result.value<std::string>(0).value_or(std::string()));
    const auto &refFile = str2tstr(result.value<std::string>(1).value_or(std::string()));

    // Check existence
    if (!fs::is_regular_file(file)) {
        throw std::runtime_error("not a regular file: \"" + tstr2str(file) + "\"");
    }

    if (!refFile.empty() && !fs::is_regular_file(refFile)) {
        throw std::runtime_error("not a regular file: \"" + tstr2str(refFile) + "\"");
    }

    // Get time
    Utils::FileTime t;
    if (!refFile.empty()) {
        t = Utils::fileTime(refFile);
    } else {
        auto now = std::chrono::system_clock::now();
        t = {now, now, now};
    }

    // Set time
    if (verbose) {
        u8printf("Set A-Time: %s\n", time2str(t.accessTime).data());
        u8printf("Set M-Time: %s\n", time2str(t.modifyTime).data());
        u8printf("Set C-Time: %s\n", time2str(t.statusChangeTime).data());
    }
    Utils::setFileTime(file, t);
    return 0;
}

static int cmd_configure(const cli::ParseResult &result) {
    bool dryrun = isDryRunSet(result);
    bool force = isForceSet(result);
    bool verbose = dryrun || isVerboseSet(result);

    const auto &projectName = result.valueForOption<std::string>("-p").value_or(std::string());
    const auto &fileName = fs::absolute(str2tstr(result.value<std::string>(0).value_or(std::string())));

    // Warning file
    std::vector<std::string> warningLines;
    if (const auto &warningResult = result.option("-w"); warningResult) {
        do {
            const auto &warningFileString =
                warningResult->value<std::string>(0).value_or(std::string());
            if (warningFileString.empty())
                break;

            const auto &warningFile = str2tstr(warningFileString);
            std::ifstream inFile((fs::path(warningFile)));
            if (!inFile.is_open()) {
                break;
            }

            std::string line;
            while (std::getline(inFile, line)) {
                line = stdc::str::trim(std::move(line));
                if (line.empty())
                    continue;
                warningLines.push_back(line);
            }

            inFile.close();
        } while (false);

        if (warningLines.empty()) {
            warningLines = {
                "Caution: This file is generated by CMake automatically during configure.",
                "WARNING!!! DO NOT EDIT THIS FILE MANUALLY!!!",
                "ALL YOUR MODIFICATIONS HERE WILL GET LOST AFTER RE-CONFIGURING!!!",
            };
        }
    }

    // Add defines
    const std::vector<std::string> defines = optionValues(result, "-D");

    // Generate definitions content
    std::string definitions;
    {
        std::map<std::string, size_t> definitionMap;
        std::vector<std::pair<std::string, std::string>> definitionSequence; // Preserve order
        for (const auto &def : std::as_const(defines)) {
            // Raw line
            if (def.front() == '%') {
                definitionSequence.push_back(std::make_pair("%", def.substr(1)));
                continue;
            }

            std::string key;
            std::string val;
            size_t pos = def.find('=');
            if (pos == std::string::npos) {
                key = def;
            } else {
                key = def.substr(0, pos);
                val = def.substr(pos + 1);
            }

            auto it = definitionMap.find(key);
            if (it == definitionMap.end()) {
                definitionMap[key] = definitionSequence.size();
                definitionSequence.push_back(std::make_pair(key, val));
            } else {
                definitionSequence[it->second].second = val;
            }
        }

        std::stringstream ss;
        for (const auto &pair : std::as_const(definitionSequence)) {
            if (pair.first == "%") {
                ss << pair.second << "\n";
            } else if (pair.second.empty()) {
                ss << "#define " << pair.first << "\n";
            } else {
                ss << "#define " << pair.first << " " << pair.second << "\n";
            }
        }
        definitions = ss.str();
    }

    // Calculate hash
    std::string hash;
    if (!force) {
        uint8_t buf[32];
        calc_sha_256(buf, definitions.data(), definitions.size());

        std::stringstream ss;
        ss << std::hex << std::setfill('0');
        for (auto byte : buf) {
            ss << std::setw(2) << static_cast<int>(byte);
        }
        hash = ss.str();
    }

    // Generate content
    std::string content;
    {
        std::string guard = tstr2str(fileName.filename());
        {
            // Prepend project name
            if (!projectName.empty()) {
                guard = projectName + "_" + guard;
            }

            // Replace punctuation signs
            std::replace_if(
                guard.begin(), guard.end(), [](const char &c) { return !isalnum(c) && c != '_'; },
                '_');

            // Macro token can not start with a number, fix it
            if (std::isdigit(guard.front())) {
                guard = "_" + guard;
            }

            // To upper case
            guard = stdc::str::to_upper(guard);
        }

        std::stringstream ss;

        // Header guard
        ss << "#ifndef " << guard << "\n";
        ss << "#define " << guard << "\n\n";

        // Warning
        if (!warningLines.empty()) {
            for (const auto &item : std::as_const(warningLines)) {
                ss << "// " << item << "\n";
            }
            ss << "\n";
        }

        // Hash
        if (!hash.empty()) {
            ss << "// SHA256: " << hash << "\n\n";
        }

        // Definitions
        ss << definitions << "\n";

        // Header guard end
        ss << "#endif // " << guard << "\n";

        content = ss.str();
    }

    if (dryrun) {
        u8printf("%s", content.data());
        return 0;
    }

    // Read file
    do {
        if (force)
            break;

        // Check if file exists and has the same hash
        std::ifstream inFile(fileName);
        if (!inFile.is_open()) {
            break;
        }

        bool matched = false;

        static std::regex hashPattern(R"(^// SHA256: (\w+)$)");
        std::smatch match;
        std::string line;

        int pp_cnt = 0;
        while (std::getline(inFile, line)) {
            if (line.empty())
                continue;

            if (line.front() == '#') {
                pp_cnt++; // Skip header guard
                if (pp_cnt > 2) {
                    break;
                }
                continue;
            }

            if (!stdc::str::starts_with(line, "//"))
                break;

            if (std::regex_match(line, match, hashPattern)) {
                if (match[1] == hash) {
                    matched = true;
                }
                break;
            }
        }
        inFile.close();

        if (matched) {
            if (verbose) {
                stdc::console::printf(stdc::console::bold, stdc::console::yellow,
                                      stdc::console::nocolor, "Content matched. (%s)\n",
                                      hash.data());
            }
            // Same hash found, no need to overwrite the file
            return 0;
        }
    } while (false);

    // Create file
    {
        // Create directory if needed
        if (auto dir = fileName.parent_path(); !fs::is_directory(dir)) {
            fs::create_directories(dir);
        }

        std::ofstream outFile(fileName);
        if (!outFile.is_open()) {
            throw std::runtime_error("failed to open file \"" + tstr2str(fileName) +
                                     "\": " + standardError());
        }

        outFile << content;
        outFile.close();

        if (verbose) {
            if (!hash.empty()) {
                u8printf("SHA256: %s\n", hash.data());
            }
        }
    }

    return 0;
}

static int cmd_incsync(const cli::ParseResult &result) {
    bool dryrun = isDryRunSet(result);
    bool verbose = dryrun || isVerboseSet(result);
    bool force = isForceSet(result);
    bool standard = isStandardSet(result);
    bool copy = result.option("-c").has_value();
    bool all = !result.option("-n").has_value();

    const fs::path &src =
        stdc::path::clean_path(fs::absolute(str2tstr(result.value<std::string>(0).value_or(std::string()))));
    const fs::path &dest =
        stdc::path::clean_path(fs::absolute(str2tstr(result.value<std::string>(1).value_or(std::string()))));
    if (!fs::is_directory(src)) {
        throw std::runtime_error("not a directory: \"" + tstr2str(src) + "\"");
    }

    // Add includes
    std::vector<std::pair<TString, TString>> includes;
    {
        const auto &includeResult = result.option("-i");
        int cnt = includeResult ? includeResult->count() : 0;
        includes.reserve(cnt + 1);

        // Add standard
        if (standard) {
            includes.emplace_back(_TSTR(R"(.*?_p\..+$)"), _TSTR("private"));
        }

        for (int i = 0; i < cnt; ++i) {
            includes.emplace_back(
                str2tstr(includeResult->value<std::string>(0, i).value_or(std::string())),
                str2tstr(includeResult->value<std::string>(1, i).value_or(std::string())));
        }
    }

    // Add excludes
    TStringList excludes;
    {
        const auto &excludeResult = optionValues(result, "-e");
        excludes.reserve(excludeResult.size());
        for (const auto &item : excludeResult) {
            excludes.emplace_back(str2tstr(item));
        }
    }

    // Remove target directory if needed
    if (!dryrun && fs::exists(dest) && force) {
        fs::remove_all(dest);
    }

    for (const auto &entry : fs::recursive_directory_iterator(src)) {
        if (entry.is_regular_file()) {
            const auto &path = entry.path();
            const auto &ext = stdc::str::to_lower(TString(path.extension()));
            if (!(ext == _TSTR(".h") || ext == _TSTR(".hh") || ext == _TSTR(".hpp") ||
                  ext == _TSTR(".hxx"))) {
                continue;
            }

            // Get subdirectory
            fs::path subdir;
            for (const auto &pair : includes) {
                TString pathString = path;
                // Replace separator
                std::replace(pathString.begin(), pathString.end(), _TSTR('\\'), _TSTR('/'));

                if (std::regex_search(pathString.begin(), pathString.end(),
                                      std::basic_regex<TChar>(pair.first))) {
                    subdir = pair.second;
                }
            }

            if (!all && subdir.empty())
                continue;

            // Check if it should be excluded
            if (searchInRegexList(TString(path), excludes))
                continue;

            const fs::path &targetDir = subdir.empty() ? dest : (dest / subdir);

            auto targetPath = targetDir / path.filename();
            if (verbose) {
                u8printf("Sync: from \"%s\" to \"%s\"\n", tstr2str(path).data(),
                       tstr2str(targetPath).data());
            }

            if (dryrun)
                continue;

            if (fs::exists(targetPath) &&
                Utils::fileTime(targetPath).modifyTime >= Utils::fileTime(path).modifyTime) {
                continue;
            }

            // Create directory
            if (!fs::exists(targetDir)) {
                fs::create_directories(targetDir);
            }

            if (copy) {
                // Copy
                fs::copy(path, targetPath, fs::copy_options::overwrite_existing);
            } else {
                // Make relative reference
                std::string rel = tstr2str(fs::relative(path, targetDir));

#ifdef _WIN32
                // Replace separator
                std::replace(rel.begin(), rel.end(), '\\', '/');
#endif

                // Create file
                std::ofstream outFile(targetPath);
                if (!outFile.is_open()) {
                    throw std::runtime_error("failed to open file \"" + tstr2str(targetPath) +
                                             "\": " + standardError());
                }
                outFile << "#include \"" << rel << "\"" << std::endl;
                outFile.close();
            }

            // Set timestamp
            Utils::syncFileTime(targetPath, path);
        }
    }

    return 0;
}

static int cmd_deploy(const cli::ParseResult &result) {
    bool dryrun = isDryRunSet(result);
    bool verbose = dryrun || isVerboseSet(result);
    bool force = isForceSet(result);
    bool standard = isStandardSet(result);

    fs::path dest = fs::current_path(); // Default to current path
    if (auto destResult = result.option("-o"); destResult) {
        dest = stdc::path::clean_path(fs::absolute(
            str2tstr(destResult->value<std::string>().value_or(std::string()))));
    }

    // Add file names
    std::set<fs::path> orgFiles;
    {
        for (const auto &item : argumentValues(result, 0)) {
            orgFiles.insert(toFramework(stdc::path::clean_path(fs::absolute(str2tstr(item)))));
        }
    }

    // Add extra org files
    std::vector<std::pair<fs::path, fs::path>> extraOrgFiles;
    {
        const auto &copiesResult = result.option("-c");
        int cnt = copiesResult ? copiesResult->count() : 0;
        extraOrgFiles.reserve(cnt);
        for (int i = 0; i < cnt; ++i) {
            extraOrgFiles.emplace_back(
                toFramework(stdc::path::clean_path(fs::absolute(str2tstr(
                    copiesResult->value<std::string>(0, i).value_or(std::string()))))),
                stdc::path::clean_path(fs::absolute(str2tstr(
                    copiesResult->value<std::string>(1, i).value_or(std::string())))));
        }
    }

#if 1
    // Add searching paths
    std::vector<fs::path> searchingPaths;
    {
        const auto &linkResult = optionValues(result, "-L");

        std::vector<fs::path> tmp;
        tmp.reserve(linkResult.size() + orgFiles.size());

        // Add file paths
        for (const auto &item : std::as_const(orgFiles)) {
            tmp.emplace_back(fs::path(item).parent_path());
        }

        // Add searching paths
        for (const auto &item : linkResult) {
            tmp.emplace_back(stdc::path::clean_path(fs::absolute(str2tstr(item))));
        }

        // Read configuration
        const auto &configFiles = optionValues(result, "--linkdirs-file");
        for (const auto &item : configFiles) {
            std::ifstream file(fs::path(str2tstr(item)), std::ios::binary);
            if (!file.is_open()) {
                continue;
            }

            // Skip BOM
            char bom[3];
            file.read(bom, 3);
            if (file.gcount() != 3 ||
                !(bom[0] == (char) 0xEF && bom[1] == (char) 0xBB && bom[2] == (char) 0xBF)) {
                file.seekg(0);
            }

            std::string line;
            while (std::getline(file, line)) {
                if (line.empty())
                    continue;
                if (line.size() >= 2 && line.front() == '\"' && line.back() == '\"')
                    line = line.substr(1, line.size() - 2);
                tmp.emplace_back(stdc::path::clean_path(fs::absolute(str2tstr(stdc::str::trim(std::move(line))))));
            }
        }

        // Add dest
        tmp.push_back(dest);

        // Remove duplications
        std::set<fs::path> visited;
        for (auto item : std::as_const(tmp)) {
            if (fs::is_regular_file(item))
                item = item.parent_path();
            else if (!fs::is_directory(item))
                continue;

            if (stdc::contains(visited, item)) {
                continue;
            }
            visited.insert(item);
            searchingPaths.emplace_back(item);
        }
    }
#endif

    // Add excludes
    TStringList excludes;
    {
        const auto &excludeResult = optionValues(result, "-e");
        excludes.reserve(excludeResult.size());
        for (const auto &item : excludeResult) {
            excludes.emplace_back(str2tstr(item));
        }
    }

    // Deploy
    std::vector<fs::path> dependencies;
#ifdef __APPLE__
    enum FrameworkType {
        NoFramework = 0,
        Release = 1,
        Debug = 2,
    };
    std::map<std::string, int> depFrameworkTypes;
#endif
    {
        std::set<fs::path> allOrgFileNames;
        for (const auto &item : std::as_const(orgFiles)) {
            allOrgFileNames.insert(item.filename());
        }
        for (const auto &pair : std::as_const(extraOrgFiles)) {
            allOrgFileNames.insert(pair.first.filename());
        }

        const auto &getFilesDeps =
            [&](const std::vector<fs::path> &paths) -> std::vector<fs::path> {
            std::set<TString> result;
            for (const auto &path : std::as_const(paths)) {
                if (verbose) {
                    u8printf("Resolve: \"%s\"\n", tstr2str(path).data());
                }

                std::vector<std::string> unparsed;
                const auto &deps =
#ifdef _WIN32
                    Utils::resolveWinBinaryDependencies(path, searchingPaths, &unparsed)
#else
                    Utils::resolveUnixBinaryDependencies(fromFramework(path), searchingPaths,
                                                         &unparsed)
#endif
                    ;
                for (const auto &item : deps) {
                    if (verbose) {
                        u8printf("    %s\n", tstr2str(item).data());
                    }
                    result.insert(item);
                }

                if (verbose) {
                    size_t maxSize = 0;
                    for (const auto &item : std::as_const(unparsed)) {
                        maxSize = std::max(maxSize, item.size());
                    }
                    for (const auto &item : std::as_const(unparsed)) {
                        u8printf("    %s%s[Not Found]\n", item.data(),
                               std::string(maxSize + 4 - item.size(), ' ').data());
                    }
                }
            }
            return {result.begin(), result.end()};
        };

        std::set<fs::path> visited;
        std::vector<fs::path> stack = {orgFiles.begin(), orgFiles.end()};

        // Mark original files as visited
        for (const auto &item : std::as_const(orgFiles)) {
            visited.insert(item.filename());
        }
        for (const auto &pair : std::as_const(extraOrgFiles)) {
            visited.insert(pair.first.filename());
            stack.push_back(pair.first);
        }

        // Search for dependencies recursively
        while (!stack.empty()) {
            auto libs = getFilesDeps(stack);
            stack.clear();

            // Search dependencies
            for (const auto &lib : std::as_const(libs)) {
                const auto &path = toFramework(lib);
                // Ignore orginal file
                if (stdc::contains(allOrgFileNames, path.filename()))
                    continue;

                // Ignore files in standard mode
                // Lower cased, so every name matched against it below has to be lower case
                // too. A pattern with a capital in it never matches anything.
                TString fileName = stdc::str::to_lower(TString(path.filename()));
                if ((standard && (
#ifdef _WIN32
                                     isMSVCLibrary(fileName)
#elif defined(__APPLE__)
                                     stdc::str::starts_with(fileName, "libc++") ||
                                     stdc::str::starts_with(fileName, "libsystem")
#else
                                     stdc::str::starts_with(fileName, "libstdc++") ||
                                     stdc::str::starts_with(fileName, "libgcc") ||
                                     stdc::str::starts_with(fileName, "libglib") ||
                                     stdc::str::starts_with(fileName, "libpthread") ||
                                     stdc::str::starts_with(fileName, "libgthread") ||
                                     stdc::str::starts_with(fileName, "libicu") ||
                                     stdc::str::starts_with(fileName, "libc.so") ||
                                     stdc::str::starts_with(fileName, "libc-") ||
                                     stdc::str::starts_with(fileName, "libdl.so") ||
                                     stdc::str::starts_with(fileName, "libdl-") ||
                                     // Spelled out rather than as "libm", which would take
                                     // libmagic and libmount with it.
                                     stdc::str::starts_with(fileName, "libm.so") ||
                                     stdc::str::starts_with(fileName, "libm-")
#endif
                                         )) ||
#ifdef _WIN32
                    (!searchWindowsSystemPaths(fileName).empty() ||
                     stdc::str::starts_with(fileName, _TSTR("api-ms-win-")) ||
                     stdc::str::starts_with(fileName, _TSTR("ext-ms-win-"))) ||
#endif
                    stdc::contains(visited, fileName)) {
                    continue;
                }
                visited.insert(fileName);

                // Check if it should be excluded
                if (searchInRegexList(TString(path), excludes))
                    continue;

#ifdef __APPLE__
                // Mark framework type
                if (fs::is_directory(path)) {
                    std::string name = lib.filename();
                    if (name.ends_with("_debug")) {
                        depFrameworkTypes[path.stem()] |= Debug;
                    } else {
                        depFrameworkTypes[path.stem()] |= Release;
                    }
                }
#endif

                dependencies.push_back(path);

                // Push to stack and resolve in next loop
                stack.push_back(path);
            }
        }
    }

    // Deploy
    if (dryrun) {
        return 0;
    }

#ifdef _WIN32
    // Windows
    // Only need to copy the libraries.

    // Copy original files
    for (const auto &pair : std::as_const(extraOrgFiles)) {
        copyFile(pair.first, pair.second, {}, force, verbose);
    }

    // Copy dependencies
    for (const auto &file : std::as_const(dependencies)) {
        copyFile(file, dest, {}, force, verbose);
    }
#else
    // Unix
    // Copy libraries and fix rpaths, and may need to deploy interpreter on Linux.

    const auto &fixRPaths = [verbose](const std::string &file,
                                      const std::vector<std::string> &paths) {
        if (verbose) {
            u8printf("Fix rpath: \"%s\"\n", file.data());
            for (const auto &path : paths) {
                u8printf("    %s\n", path.data());
            }
        }
        Utils::setFileRPaths(file, paths);
    };

#  if defined(__APPLE__)
    // Ignore Header files and unused library
    static const auto &frameworkIgnore = [](const fs::path &path, const fs::path &frameworkName,
                                            int type) -> bool {
        if (!(type & Release)) {
            if (path.filename() == frameworkName)
                return true;
        }
        if (!(type & Debug)) {
            if (path.filename() == frameworkName.string() + "_debug")
                return true;
        }
        return fs::is_directory(path) && path.filename() == "Headers" &&
               fs::is_directory(path.parent_path() / "Resources");
    };

    // The framework is supposed to place at the right place
    // We don't take care of the special rpaths
    const auto &fixFrameworkRPaths = [fixRPaths](const fs::path &path) {
        fixRPaths(path, {
                            "@executable_path/../Frameworks",
                            "@loader_path/Frameworks",
                            "@loader_path/../../..",
                        });
    };

    // Copy original files
    auto targetOrgFiles = orgFiles;
    for (const auto &pair : std::as_const(extraOrgFiles)) {
        const auto &file = pair.first;
        fs::path targetPath;
        if (fs::is_directory(file)) {
            const auto &name = file.stem();
            targetPath = pair.second / file.filename();

            copyDirectory(file, file, targetPath, force, verbose,
                          [&](const fs::path &path) -> bool {
                              return frameworkIgnore(path, name, Debug | Release); //
                          });
        } else {
            targetPath = copyCanonical(file, pair.second, force, verbose);
        }
        targetOrgFiles.insert(targetPath);
    }

    // Copy dependencies
    std::set<fs::path> targetDependencies;
    for (const auto &file : std::as_const(dependencies)) {
        fs::path targetPath;
        if (fs::is_directory(file)) {
            const auto &name = file.stem();
            targetPath = dest / file.filename();

            int type = Debug | Release;
            if (auto it = depFrameworkTypes.find(name); it != depFrameworkTypes.end()) {
                type = it->second;
            }
            copyDirectory(file, file, targetPath, force, verbose,
                          [&](const fs::path &path) -> bool {
                              return frameworkIgnore(path, name, type); //
                          });
        } else {
            targetPath = copyCanonical(file, dest, force, verbose);
        }
        targetDependencies.insert(targetPath);
    }

    // Extra step: strip non-native architectures from universal binaries
    {
        // Get current architecture
        std::string currentArch;
        try {
            currentArch = Utils::executeCommand("uname", {"-m"});
            currentArch = stdc::str::trim(std::move(currentArch));
        } catch (const std::exception &e) {
            if (verbose) {
                u8printf("Warning: Failed to get current architecture: %s\n", e.what());
            }
            currentArch = "unknown";
        }

        if (currentArch != "unknown") {
            const auto &stripUniversalBinary = [verbose, &currentArch](const fs::path &file) {
                if (!fs::is_regular_file(file)) {
                    return;
                }

                // Check if file is a universal binary using lipo
                std::string lipoInfo;
                try {
                    lipoInfo = Utils::executeCommand("lipo", {"-info", file.string()});
                } catch (const std::exception &) {
                    // Not a binary file or lipo failed, skip
                    return;
                }

                // Check if it's a universal binary (contains "Architectures")
                if (lipoInfo.find("Architectures") == std::string::npos) {
                    return; // Not a universal binary
                }

                // Check if current architecture is present
                if (lipoInfo.find(currentArch) == std::string::npos) {
                    if (verbose) {
                        u8printf(
                            "Warning: Universal binary \"%s\" does not contain %s architecture\n",
                            file.string().data(), currentArch.data());
                    }
                    return;
                }

                // Extract current architecture
                bool lipoPassed = false;
                try {
                    if (verbose) {
                        u8printf("Strip universal binary: \"%s\" (keep %s)\n", file.string().data(),
                               currentArch.data());
                    }
                    std::ignore = Utils::executeCommand(
                        "lipo", {file.string(), "-thin", currentArch, "-output", file.string()});
                    lipoPassed = true;
                } catch (const std::exception &e) {
                    if (verbose) {
                        u8printf("Warning: Failed to strip universal binary \"%s\": %s\n",
                               file.string().data(), e.what());
                    }
                }
            };

            // Process original files
            for (const auto &file : std::as_const(targetOrgFiles)) {
                if (isFramework(file)) {
                    fs::path lib = framework2lib(file);
                    if (!lib.empty()) {
                        stripUniversalBinary(lib);
                    }

                    fs::path libDebug = framework2lib_debug(file);
                    if (!libDebug.empty()) {
                        stripUniversalBinary(libDebug);
                    }
                } else {
                    stripUniversalBinary(file);
                }
            }

            // Process dependencies
            for (const auto &file : std::as_const(targetDependencies)) {
                if (isFramework(file)) {
                    fs::path lib = framework2lib(file);
                    if (!lib.empty()) {
                        stripUniversalBinary(lib);
                    }

                    fs::path libDebug = framework2lib_debug(file);
                    if (!libDebug.empty()) {
                        stripUniversalBinary(libDebug);
                    }
                } else {
                    stripUniversalBinary(file);
                }
            }
        }
    }

    // Extra step: normalize dependencies
    {
        // Build name indexes
        std::set<std::string> targetFileNames;
        for (const auto &file : std::as_const(targetOrgFiles)) {
            if (isFramework(file)) {
                targetFileNames.insert(file.stem());
            } else {
                targetFileNames.insert(file.filename());
            }
        }

        for (const auto &file : std::as_const(targetDependencies)) {
            if (isFramework(file)) {
                targetFileNames.insert(file.stem());
            } else {
                targetFileNames.insert(file.filename());
            }
        }

        static const auto &normalize = [verbose, &targetFileNames](const fs::path &file) {
            std::vector<std::pair<std::string, std::string>> normalized;
            for (const auto &dep : Utils::getMacAbsoluteDependencies(
                     isFramework(file) ? framework2lib(file) : file)) {
                fs::path depPath = dep;

                // Only collected dependencies will be normalized
                if (fs::exists(depPath) &&
                    stdc::contains(targetFileNames, fs::canonical(depPath).filename())) {
                    normalized.emplace_back(dep, "@rpath/" + depPath.filename().string());
                }
            }

            if (normalized.empty())
                return;

            if (verbose) {
                u8printf("Normalize dependencies: \"%s\"\n", file.string().data());
                for (const auto &item : std::as_const(normalized)) {
                    u8printf("    %s\n", item.first.data());
                }
            }

            Utils::replaceMacFileDependencies(file, normalized);
        };

        for (const auto &file : std::as_const(targetOrgFiles)) {
            normalize(file);
        }
        for (const auto &file : std::as_const(targetDependencies)) {
            normalize(file);
        }
    }

    // Fix rpath for original files (maybe executable)
    for (const auto &file : std::as_const(targetOrgFiles)) {
        if (isFramework(file)) {
            fs::path lib = framework2lib(file);
            if (!lib.empty()) {
                fixFrameworkRPaths(lib);
            }

            fs::path libDebug = framework2lib_debug(file);
            if (!libDebug.empty()) {
                fixFrameworkRPaths(libDebug);
            }
        } else {
            fixRPaths(file,
                      {
                          "@executable_path/../Frameworks",
                          "@loader_path/" +
                              stdc::path::clean_path(fs::relative(dest, file.parent_path())).string(),
                      });
        }
    }

    // Fix rpath for dependencies
    for (const auto &file : std::as_const(targetDependencies)) {
        if (isFramework(file)) {
            fs::path lib = framework2lib(file);
            if (!lib.empty()) {
                fixFrameworkRPaths(lib);
            }

            fs::path libDebug = framework2lib_debug(file);
            if (!libDebug.empty()) {
                fixFrameworkRPaths(libDebug);
            }
        } else {
            fixRPaths(file, {
                                "@executable_path/../Frameworks",
                                "@loader_path",
                            });
        }
    }

#  else
    // const auto &setInterpreter = [verbose](const std::string &file, const std::string &interp) {
    //     if (verbose) {
    //         u8printf("Set interpreter: \"%s\"\n", file.data());
    //         u8printf("    %s\n", interp.data());
    //     }
    //     Utils::setFileInterpreter(file, interp);
    // };

    // Copy original files
    auto targetOrgFiles = orgFiles;
    for (const auto &pair : std::as_const(extraOrgFiles)) {
        auto targetPath = copyCanonical(pair.first, pair.second, force, verbose);
        targetOrgFiles.insert(targetPath);
    }

    // Copy dependencies
    std::set<fs::path> targetDependencies;
    for (const auto &file : std::as_const(dependencies)) {
        auto targetPath = copyCanonical(file, dest, force, verbose);

        // libc.so is a shell script
        if (targetPath.filename() != "libc.so") {
            targetDependencies.insert(targetPath);
        }
    }

    // Fix rpath for original files
    for (const auto &file : std::as_const(targetOrgFiles)) {
        fixRPaths(file,
                  {"$ORIGIN/" + stdc::path::clean_path(fs::relative(dest, file.parent_path())).string()});
    }

    // Fix rpath for dependencies
    for (const auto &file : std::as_const(targetDependencies)) {
        fixRPaths(file, {"$ORIGIN"});
    }

    // Fix interpreter
    // do {
    //     if (standard) {
    //         break;
    //     }

    //     fs::path interpreter;
    //     for (const auto &file : std::as_const(targetOrgFiles)) {
    //         interpreter = Utils::getInterpreter(file);
    //         if (!interpreter.empty())
    //             break;
    //     }
    //     if (interpreter.empty()) {
    //         for (const auto &dep : std::as_const(targetDependencies)) {
    //             interpreter = Utils::getInterpreter(dep);
    //             if (!interpreter.empty())
    //                 break;
    //         }
    //     }
    //     if (interpreter.empty())
    //         break;

    //     // Copy interpreter
    //     copyCanonical(interpreter, dest, force, verbose);

    //     std::string interpreterName = interpreter.filename();
    //     interpreter = dest / interpreterName;

    //     if (verbose) {
    //         u8printf("Interpreter: \"%s\"\n", interpreter.string().data());
    //     }

    //     // Set interpreter for original files
    //     for (const auto &file : std::as_const(targetOrgFiles)) {
    //         setInterpreter(file,
    //                        "$ORIGIN/" + stdc::path::clean_path(fs::relative(dest, file.parent_path()) /
    //                                                      interpreter.filename())
    //                                         .string());
    //     }

    //     // Set interpreter for dependencies
    //     for (const auto &dep : std::as_const(targetDependencies)) {
    //         setInterpreter(dep, "$ORIGIN/" + interpreterName);
    //     }
    // } while (false);
#  endif
#endif
    return 0;
}

int main(int argc, char *argv[]) {
    cli::Command copyCommand = []() {
        cli::Command command("copy", "Copy files or directories if different");
        command.addArguments({
            cli::Argument("src", "Source files or directories").multi(),
            cli::Argument("dest", "Destination directory"),
        });
        command.addOptions({
            cli::Option({"-e", "--exclude"}, "Exclude a path pattern").arg("regex").multi(),
            cli::Option({"-f", "--force"}, "Force overwrite existing files"),
        });
        command.addOptions({cli::Option::Verbose});
        command.setHandler(cmd_copy);
        return command;
    }();

    cli::Command rmdirCommand = []() {
        cli::Command command("rmdir", "Remove empty directories recursively");
        command.addArguments({
            cli::Argument("dir", "Directories").multi(),
        });
        command.addOption({cli::Option::Verbose});
        command.setHandler(cmd_rmdir);
        return command;
    }();

    cli::Command touchCommand = []() {
        cli::Command command("touch", "Update file timestamp");
        command.addArguments({
            cli::Argument("file", "File to update time stamp"),
            cli::Argument("ref file", "Reference file", false),
        });
        command.addOption({cli::Option::Verbose});
        command.setHandler(cmd_touch);
        return command;
    }();

    cli::Command configureCommand = []() {
        cli::Command command("configure", "Generate configuration header");
        command.addArgument(cli::Argument("output file", "Output header path"));
        command.addOptions({
            cli::Option({"-D", "--define"},
                        R"(Define a variable, format: <key>, <key>=<value>, %<raw>)")
                .arg("expr")
                .multi()
                .shortMatch(cli::Option::ShortMatchSingleChar),
            cli::Option({"-p", "--project"}, "Set project name").arg("name"),
            cli::Option({"-w", "--warning"}, "Generate warning text").arg("file", false),
            cli::Option({"-f", "--force"}, "Skip calculating hash and overwrite always"),
            cli::Option({"-d", "--dryrun"}, "Print contents only"),
        });
        command.addOption({cli::Option::Verbose});
        command.setHandler(cmd_configure);
        return command;
    }();

    cli::Command incsyncCommand = []() {
        cli::Command command("incsync", "Reorganize header files of include directory");
        command.addArguments({
            cli::Argument("src", "Input directory containing source headers"),
            cli::Argument("dest", "Output directory of reorganized headers"),
        });
        command.addOptions({
            cli::Option({"-i", "--include"}, "Add a path pattern and corresponding subdirectory")
                .arg("regex")
                .arg("subdir")
                .multi(),
            cli::Option({"-e", "--exclude"}, "Exclude a path pattern").arg("regex").multi(),
            cli::Option({"-s", "--standard"}, "Add standard public-private name pattern"),
            cli::Option({"-n", "--not-all"}, "Ignore unclassified files"),
            cli::Option({"-c", "--copy"}, "Copy files rather than indirect reference"),
            cli::Option({"-d", "--dryrun"}, "Print reorganizing details only"),
            cli::Option({"-f", "--force"}, "Force deleting existing directory"),
        });
        command.addOption({cli::Option::Verbose});
        command.setHandler(cmd_incsync);
        return command;
    }();

    cli::Command deployCommand = []() {
        cli::Command command("deploy", "Resolve and deploy " OS_EXECUTABLE " files' dependencies");
        command.addArguments({
            cli::Argument("file", OS_EXECUTABLE " file(s)").multi(),
        });
        command.addOptions({
            cli::Option({"-c", "--copy"}, "Additional " OS_EXECUTABLE " file(s) to copy")
                .arg("src")
                .arg("dir")
                .multi()
                .prior(cli::Option::IgnoreMissingArguments),
            cli::Option({"-o", "--out"},
                        "Set output directory of dependencies, defult to current directory")
                .arg("dir"),
#if 1
            cli::Option({"-L", "--linkdir"}, "Add a library searching path")
                .arg("dir")
                .multi()
                .shortMatch(cli::Option::ShortMatchSingleChar),
            cli::Option({"--linkdirs-file"}, "Add library searching paths from a list file")
                .arg("file")
                .multi()
                .shortMatch(cli::Option::ShortMatchSingleChar),
#endif
            cli::Option({"-e", "--exclude"}, "Exclude a path pattern").arg("regex").multi(),
            cli::Option({"-s", "--standard"}, "Ignore C/C++ runtime and system libraries"),
            cli::Option({"-d", "--dryrun"}, "Print dependencies only"),
            cli::Option({"-f", "--force"}, "Force overwrite existing files"),
        });
        command.addOption({cli::Option::Verbose});
        command.setHandler(cmd_deploy);
        return command;
    }();

    cli::Command rootCommand(stdc::system::application_name(),
                             "Cross-platform utility commands for C/C++ build systems.");
    rootCommand.addCommands({
        copyCommand,
        rmdirCommand,
        touchCommand,
        configureCommand,
        incsyncCommand,
        deployCommand,
    });
    rootCommand.addVersionOption(TOOL_VERSION);
    rootCommand.addHelpOption(true, true);

    cli::CommandCatalogue cc;
    cc.addCommands("Filesystem Commands", {"copy", "rmdir", "touch"});
    cc.addCommands("Buildsystem Commands", {"configure", "incsync", "deploy"});
    rootCommand.setCatalogue(cc);

    cli::Parser parser(rootCommand);
    parser.setPrologue(TOOL_DESC);
    parser.setEpilogue(TOOL_COPYRIGHT);
    parser.setDisplayOptions(cli::Parser::AlignAllCatalogues);

    // The copyright line under the page is worth setting apart from the page.
    {
        auto layout = cli::HelpLayout::defaultLayout();
        layout.setBodyStyle(cli::HelpBlock::Epilogue,
                            {stdc::console::bold, stdc::console::yellow});
        parser.setHelpLayout(layout);
    }

    // On Windows the arguments that reach main() are in the machine's ANSI code page, so the
    // wide command line is read instead and converted. Everywhere else argv is already what
    // the user typed.
    std::vector<std::string> args;
#ifdef _WIN32
    std::ignore = argc;
    std::ignore = argv;
    {
        const auto &given = stdc::system::command_line_arguments();
        args.assign(given.begin(), given.end());
    }
#else
    args.assign(argv, argv + argc);
#endif

    int ret;
    try {
        ret = parser.invoke(args, -1, cli::Parser::EnableResponseFile);
    } catch (const std::exception &e) {
        std::string msg = e.what();

#ifdef _WIN32
        if (typeid(e) == typeid(fs::filesystem_error)) {
            // What the standard library puts in what() is in the ANSI code page too.
            msg = stdc::wstring_conv::to_utf8(stdc::wstring_conv::from_ansi(e.what()));
        }
#endif

        stdc::console::printf(stdc::console::bold, stdc::console::lightred,
                              stdc::console::nocolor, "Error: %s\n", msg.data());
        ret = -1;
    }
    return ret;
}
