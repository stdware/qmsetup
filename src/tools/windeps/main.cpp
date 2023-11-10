#include <filesystem>
#include <iostream>
#include <map>
#include <regex>
#include <set>

#include <winutils.h>
#include <stdimpl.h>

#include <syscmdline/parser.h>
#include <syscmdline/system.h>

namespace SCL = SysCmdLine;

namespace fs = std::filesystem;

static std::vector<std::string> getFilesDependencies(const std::vector<std::wstring> &fileNames,
                                                     std::wstring *err) {
    std::map<std::string, int> libs;
    for (const auto &fileName : std::as_const(fileNames)) {
        std::wstring errorMessage;
        std::vector<std::string> dependentLibrariesIn;
        unsigned wordSizeIn;
        bool isDebugIn;
        bool isMinGW = false;
        unsigned short machineArchIn;
        if (!WinUtils::readPeExecutable(fileName, &errorMessage, &dependentLibrariesIn, &wordSizeIn,
                                        &isDebugIn, isMinGW, &machineArchIn) &&
            err) {
            *err = errorMessage;
            return {};
        }

        for (const auto &item : std::as_const(dependentLibrariesIn)) {
            libs[item]++;
        }
    }

    std::vector<std::string> res;
    res.reserve(libs.size());
    for (auto it = libs.begin(); it != libs.end(); ++it) {
        res.emplace_back(it->first);
    }
    return res;
};

static int deployDependencies(const std::vector<std::wstring> &searchingPaths,
                              const std::vector<std::wstring> &fileNames, const std::wstring &dest,
                              const std::vector<std::wstring> &excludes, bool force) {
    // Dry run
    {
        std::wstring errorMessage;
        auto libraries = getFilesDependencies(fileNames, &errorMessage);
        if (!errorMessage.empty()) {
            wprintf(_TSTR("Error: %s\n"), errorMessage.data());
            return -1;
        }

        for (const auto &item : std::as_const(libraries)) {
            std::cout << item << std::endl;
        }
    }

    // Deploy
    {
        std::set<std::wstring> visited;
        for (const auto &item : fileNames) {
            visited.insert(fs::path(item).filename());
        }

        std::vector<std::wstring> stack = fileNames;
        std::vector<std::wstring> dependencies;
        while (!stack.empty()) {
            auto libs = getFilesDependencies(stack, nullptr);
            stack.clear();
            for (const auto &lib : std::as_const(libs)) {
                std::wstring fileName = fs::path(lib);
                std::transform(fileName.begin(), fileName.end(), fileName.begin(), ::tolower);
                if (fileName.starts_with(_TSTR("vcruntime")) ||
                    fileName.starts_with(_TSTR("msvc")) ||
                    fileName.starts_with(_TSTR("api-ms-win-")) ||
                    fileName.starts_with(_TSTR("ext-ms-win-")) ||
                    fileName.starts_with(_TSTR("qt")) ||
                    fs::exists(_TSTR("C:\\Windows\\") + fileName) ||
                    fs::exists(_TSTR("C:\\Windows\\system32\\") + fileName) ||
                    fs::exists(_TSTR("C:\\Windows\\SysWow64\\") + fileName) ||
                    visited.count(fileName)) {
                    continue;
                }
                visited.insert(fileName);

                fs::path path;
                for (const auto &dir : std::as_const(searchingPaths)) {
                    fs::path targetPath = dir / fs::path(fileName);
                    if (fs::exists(targetPath)) {
                        path = targetPath;
                        break;
                    }
                }
                if (path.empty()) {
                    continue;
                }

                bool skip = false;
                for (const auto &pattern : std::as_const(excludes)) {
                    const std::wstring &pathString = path;
                    if (std::regex_search(pathString.begin(), pathString.end(),
                                          std::wregex(pattern))) {
                        skip = true;
                        break;
                    }
                }

                if (skip)
                    continue;

                dependencies.push_back(path);
                stack.push_back(path);
            }
        }

        for (const auto &file : std::as_const(dependencies)) {
            auto target = dest / fs::path(file).filename();
            if (!force && fs::exists(target) &&
                fs::last_write_time(target) >= fs::last_write_time(file)) {
                continue; // Replace if different
            }

            try {
                fs::copy(file, dest, fs::copy_options::overwrite_existing);
            } catch (const std::exception &e) {
                printf("Warning: copy file \"%s\" failed: %s\n", fs::path(file).string().data(),
                       e.what());
                continue;
            }
            StdImpl::syncFileTime(target, file);
        }
    }
    return 0;
}

int main(int argc, char *argv[]) {
    SCL::Command command(SCL::appName(), "Resolve and deploy Windows PE files' dependencies.");
    command.addArguments({
        SCL::Argument("file", "Windows PE file(s)"),
    });
    command.addOptions({
        SCL::Option({"-o", "--out"}, "Set the output directory, defult to current directory")
            .arg("dir"),
        SCL::Option({"-L", "--linkdir"}, "Add a library searching path")
            .arg("dir")
            .multi()
            .short_match(SCL::Option::ShortMatchSingleChar),
        SCL::Option({"-e", "--exclude"}, "Exclude a path pattern").arg("regex").multi(),
        SCL::Option({"-f", "--force"}, "Force overwrite existing files"),
    });
    command.addVersionOption(TOOL_VERSION);
    command.addHelpOption(true);
    command.setHandler([](const SCL::ParseResult &result) -> int {
        bool force = result.optionIsSet("-f");
        std::wstring dest = _TSTR(".");
        if (result.optionIsSet("-o")) {
            dest = fs::absolute(SCL::utf8ToWide(result.valueForOption("-o").toString())).wstring();
        }

        // Add file names
        std::vector<std::wstring> fileNames;
        {
            const auto &files = result.values(0);
            fileNames.reserve(files.size());
            for (const auto &item : files) {
                fileNames.emplace_back(fs::absolute(SCL::utf8ToWide(item.toString())));
            }
        }

        // Add searching paths
        std::vector<std::wstring> searchingPaths;
        {
            const auto &linkResult = result.option("-L").allValues();
            searchingPaths.reserve(linkResult.size());
            for (const auto &item : linkResult) {
                searchingPaths.emplace_back(fs::absolute(SCL::utf8ToWide(item.toString())));
            }

            // Remove duplications
            std::vector<std::wstring> tmp;
            std::set<std::wstring> visited;
            for (const auto &item : std::as_const(searchingPaths)) {
                if (!fs::is_directory(item))
                    continue;

                auto canonical = fs::canonical(item);
                if (visited.count(canonical)) {
                    continue;
                }
                visited.insert(canonical);
                tmp.emplace_back(canonical);
            }
            searchingPaths = std::move(tmp);
        }

        // Add excludes
        std::vector<std::wstring> excludes;
        {
            const auto &excludeResult = result.option("-e").allValues();
            excludes.reserve(excludeResult.size());
            for (const auto &item : excludeResult) {
                excludes.emplace_back(SCL::utf8ToWide(item.toString()));
            }
        }

        return deployDependencies(searchingPaths, fileNames, dest, excludes, force);
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
    return 0;
}