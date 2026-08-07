// copy, rmdir and touch, which are here because Windows has no command of its own for any of
// them and because CMake's answers are either slower or do not exist.

#include "commands.h"

#include "utils/utils.h"

#include <iostream>

#include <stdcorelib/console.h>
#include <stdcorelib/path.h>

using stdc::u8printf;

int cmd_copy(const cli::ParseResult &result) {
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
        return Utils::searchInRegexList(TString(path), excludes);
    };

    for (const auto &item : std::as_const(files)) {
        Utils::copyFile(item, dest, {}, force, verbose);
    }
    for (const auto &item : std::as_const(directories)) {
        Utils::copyDirectory(item, item, dest / item.filename(), force, verbose, excludeFunc);
    }
    for (const auto &item : std::as_const(directoryContents)) {
        Utils::copyDirectory(item, item, dest, force, verbose, excludeFunc);
    }

    return 0;
}

int cmd_rmdir(const cli::ParseResult &result) {
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
        Utils::removeEmptyDirectories(item, verbose);
    }
    return 0;
}

int cmd_touch(const cli::ParseResult &result) {
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
        u8printf("Set A-Time: %s\n", Utils::time2str(t.accessTime).data());
        u8printf("Set M-Time: %s\n", Utils::time2str(t.modifyTime).data());
        u8printf("Set C-Time: %s\n", Utils::time2str(t.statusChangeTime).data());
    }
    Utils::setFileTime(file, t);
    return 0;
}

