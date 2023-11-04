// Usage: incgen [-c] [-e <pattern> [-e ...]] <src dir> <dest dir>
// Copy or make reference for include directory

#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <regex>

#include <stdimpl.h>

#include <syscmdline/parser.h>
#include <syscmdline/system.h>

using StdImpl::TChar;
using StdImpl::tprintf;
using StdImpl::TString;
using StdImpl::TStringList;

namespace SCL = SysCmdLine;

namespace fs = std::filesystem;

static inline std::string tstr2str(const TString &str) {
#ifdef _WIN32
    return SCL::wideToUtf8(str);
#else
    return str;
#endif
}

static inline TString str2tstr(const std::string &str) {
#ifdef _WIN32
    return SCL::utf8ToWide(str);
#else
    return str;
#endif
}

static void processHeaders(const fs::path &src, const fs::path &dest,
                           const std::vector<std::pair<TString, TString>> &includes,
                           const TStringList &excludes, bool copy, bool all) {
    // Remove target directory
    if (fs::exists(dest)) {
        std::filesystem::remove_all(dest);
    }

    for (const auto &entry : fs::recursive_directory_iterator(src)) {
        if (entry.is_regular_file()) {
            const auto &path = entry.path();
            if (!(path.extension() == _TSTR(".h") || path.extension() == _TSTR(".hpp"))) {
                continue;
            }

            // Get subdirectory
            std::filesystem::path subdir;
            for (const auto &pair : includes) {
                const TString &pathString = path;
                if (std::regex_search(pathString.begin(), pathString.end(),
                                      std::basic_regex<TChar>(pair.first))) {
                    subdir = pair.second;
                }
            }

            if (!all && subdir.empty())
                continue;

            // Check if should exclude
            bool skip = false;
            for (const auto &pattern : excludes) {
                const TString &pathString = path;
                if (std::regex_search(pathString.begin(), pathString.end(),
                                      std::basic_regex<TChar>(pattern))) {
                    skip = true;
                    break;
                }
            }

            if (skip)
                continue;

            const fs::path &targetDir = (TString(path.stem())
                                             .substr(path.stem().string().length() - 2, 2)
                                             .ends_with(_TSTR("_p")) &&
                                         !subdir.empty())
                                            ? (dest / subdir)
                                            : (dest);

            // Create directory
            if (!fs::exists(targetDir)) {
                fs::create_directories(targetDir);
            }

            auto targetPath = targetDir / path.filename();
            if (copy) {
                // Copy
                try {
                    fs::copy(path, targetPath, fs::copy_options::overwrite_existing);
                } catch (const std::exception &e) {
                    printf("Warning: copy file \"%s\" failed: %s\n", path.string().data(),
                           e.what());
                    continue;
                }
            } else {
                // Make relative reference
                auto rel = fs::relative(path, targetDir).string();
                std::replace(rel.begin(), rel.end(), '\\', '/');

                // Create file
                std::ofstream outFile(targetPath);
                if (!outFile.is_open())
                    continue;
                outFile << "#include \"" << rel << "\"" << std::endl;
                outFile.close();
            }

            // Set the timestamp
            StdImpl::syncFileTime(targetPath, path);
        }
    }
}

int main(int argc, char *argv[]) {
    SCL::Command command(SCL::appName(), "Reorganize the header directory structure.");
    command.addArguments({
        SCL::Argument("src dir", "Source files directory"),
        SCL::Argument("dest dir", "Destination directory"),
    });
    command.addOptions({
        SCL::Option({"-i", "--include"}, "Add a path pattern and corresponding subdirectory")
            .arg("regex")
            .arg("subdir")
            .multi(),
        SCL::Option({"-e", "--exclude"}, "Exclude a path pattern").arg("regex").multi(),
        SCL::Option({"-s", "--standard"}, "Add standard public-private name pattern"),
        SCL::Option({"-n", "--not-all"}, "Ignore unclassified files"),
        SCL::Option({"-c", "--copy"}, "Copy files rather than indirect reference"),
    });
    command.addVersionOption(TOOL_VERSION);
    command.addHelpOption(true);
    command.setHandler([](const SCL::ParseResult &result) -> int {
        bool copy = result.optionIsSet("-c");
        bool all = !result.optionIsSet("-n");
        bool standard = result.optionIsSet("-s");

        const auto &src = str2tstr(result.value(0).toString());
        const auto &dest = str2tstr(result.value(1).toString());
        if (!fs::is_directory(src)) {
            tprintf(_TSTR("Error: \"%s\" is not a directory.\n"), src.data());
            return -1;
        }

        std::vector<std::pair<TString, TString>> includes;
        TStringList excludes;

        // Add standard
        if (standard) {
            includes.emplace_back(_TSTR(R"(.*?_p\..+$)"), _TSTR("private"));
        }

        // Add includes
        {
            const auto &includeResult = result.option("-i");
            int cnt = includeResult.count();
            for (int i = 0; i < cnt; ++i) {
                includes.emplace_back(str2tstr(includeResult.value(0, i).toString()),
                                      str2tstr(includeResult.value(1, i).toString()));
            }
        }

        // Add excludes
        {
            const auto &excludeResult = result.option("-e");
            for (const auto &item : excludeResult.allValues()) {
                excludes.emplace_back(str2tstr(item.toString()));
            }
        }

        try {
            processHeaders(src, dest, includes, excludes, copy, all);
        } catch (const std::exception &e) {
            printf("Error: %s\n", e.what());
            return -1;
        }

        return 0;
    });

    SCL::Parser parser(command);
    parser.setPrologue(TOOL_DESC);
    parser.setDisplayOptions(SCL::Parser::ShowOptionsHintFront);

#ifdef _WIN32
    std::ignore = argc;
    std::ignore = argv;
    return parser.invoke(SCL::commandLineArguments());
#else
    return parser.invoke(argc, argv);
#endif
}