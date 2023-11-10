#include <filesystem>
#include <iostream>
#include <map>
#include <set>
#include <regex>

#include <unixutils.h>
#include <stdimpl.h>

#include <syscmdline/parser.h>
#include <syscmdline/system.h>

namespace SCL = SysCmdLine;

namespace fs = std::filesystem;

static std::vector<std::string> getFilesDependencies(const std::vector<std::string> &fileNames,
                                                     std::string *err) {
    std::map<std::string, int> libs;
    for (const auto &fileName : std::as_const(fileNames)) {
        std::string errorMessage;
        std::vector<std::string> dependentLibrariesIn;
        unsigned short machineArchIn;
        if (!UnixUtils::readUnixExecutable(fileName, &dependentLibrariesIn, &errorMessage) && err) {
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

static int deployDependencies(const std::vector<std::string> &fileNames, const std::string &dest,
                              const std::vector<std::string> &excludes, bool force) {
    // Dry run
    {
        std::string errorMessage;
        auto libraries = getFilesDependencies(fileNames, &errorMessage);
        if (!errorMessage.empty()) {
            printf(_TSTR("Error: %s\n"), errorMessage.data());
            return -1;
        }

        for (const auto &item : std::as_const(libraries)) {
            std::cout << item << std::endl;
        }
    }

    // Deploy
    {
        std::set<std::string> visited;
        for (const auto &item : fileNames) {
            visited.insert(fs::path(item).filename());
        }

        std::vector<std::string> stack = fileNames;
        std::vector<std::string> dependencies;
        while (!stack.empty()) {
            auto libs = getFilesDependencies(stack, nullptr);
            stack.clear();
            for (const auto &lib : std::as_const(libs)) {
                std::string fileName = fs::path(lib);
                if (
                    // fileName.starts_with(_TSTR("vcruntime")) ||
                    // fileName.starts_with(_TSTR("msvc")) ||
                    // fileName.starts_with(_TSTR("api-ms-win-")) ||
                    // fileName.starts_with(_TSTR("ext-ms-win-")) ||
                    // fileName.starts_with(_TSTR("qt")) ||
                    // fs::exists(_TSTR("C:\\Windows\\") + fileName) ||
                    // fs::exists(_TSTR("C:\\Windows\\system32\\") + fileName) ||
                    // fs::exists(_TSTR("C:\\Windows\\SysWow64\\") + fileName) ||
                    visited.count(fileName)) {
                    continue;
                }
                visited.insert(fileName);

                const auto &path = lib;
                // no searching

                bool skip = false;
                for (const auto &pattern : std::as_const(excludes)) {
                    const std::string &pathString = path;
                    if (std::regex_search(pathString.begin(), pathString.end(),
                                          std::regex(pattern))) {
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

    // Fix input files' rpath and import table
    for (const auto &file : fileNames) {
        std::string errorMessage;
        std::string rpath =
#ifdef __APPLE__
            "@executable_path"
#else
            "$ORIGIN"
#endif
            "/" +
            fs::relative(dest, file).string();
        if (!UnixUtils::setFileRunPath(file, rpath, &errorMessage)) {
            printf(_TSTR("Error: %s\n"), errorMessage.data());
        }
        return -1;
    }

    return 0;
}

int main(int argc, char *argv[]) {
    SCL::Command command(SCL::appName(), "Resolve and deploy Unix "
#ifdef __APPLE__
                                         "Mach-O"
#else
                                         "ELF"
#endif

                                         " files' dependencies.");
    command.addArguments({
        SCL::Argument("file", "Binary file(s)"),
    });
    command.addOptions({
        SCL::Option({"-o", "--out"}, "Set the output directory, defult to current directory")
            .arg("dir"),
        SCL::Option({"-e", "--exclude"}, "Exclude a path pattern").arg("regex").multi(),
        SCL::Option({"-f", "--force"}, "Force overwrite existing files"),
    });
    command.addVersionOption(TOOL_VERSION);
    command.addHelpOption(true);
    command.setHandler([](const SCL::ParseResult &result) -> int {
        bool force = result.optionIsSet("-f");
        std::string dest = ".";
        if (result.optionIsSet("-o")) {
            dest = fs::absolute(result.valueForOption("-o").toString());
        }

        // Add file names
        std::vector<std::string> fileNames;
        {
            const auto &files = result.values(0);
            fileNames.reserve(files.size());
            for (const auto &item : files) {
                fileNames.emplace_back(fs::absolute(item.toString()));
            }
        }

        // Add excludes
        std::vector<std::string> excludes;
        {
            const auto &excludeResult = result.option("-e").allValues();
            excludes.reserve(excludeResult.size());
            for (const auto &item : excludeResult) {
                excludes.emplace_back(item.toString());
            }
        }

        return deployDependencies(fileNames, dest, excludes, force);
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