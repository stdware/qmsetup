// copy, which puts files and directories where they are asked for and passes over what is
// already there and no older.

#include "commands.h"

#include "utils/utils.h"

#include <stdexcept>
#include <utility>

#include <stdcorelib/path.h>

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
        stdc::path::clean_path(fs::absolute(str2tstr(argumentValue(result, 1))));

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
