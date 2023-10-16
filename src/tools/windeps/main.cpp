// Usage: windeps <PE files...>
// Output: Show and deploy shared libraries that specified EXEs depends

#include <map>
#include <iostream>
#include <filesystem>
#include <set>
#include <regex>

#include <stdimpl.h>
#include <winutils.h>

using namespace StdImpl;

namespace fs = std::filesystem;

int main(int argc, char *argv[]) {
    (void) argc;
    (void) argv;

    // Parse arguments
    TStringList args = commandLineArguments();
    TStringList fileNames;
    TStringList excludes;
    TStringList searchingPaths;
    TString dest = _TSTR(".");

    bool showHelp = false;
    bool force = false;
    for (int i = 1; i < args.size(); ++i) {
        if (!tstrcmp(args[i], _TSTR("--help")) || !tstrcmp(args[i], _TSTR("-h"))) {
            showHelp = true;
            break;
        }
        if (!tstrcmp(args[i], _TSTR("--force")) || !tstrcmp(args[i], _TSTR("-f"))) {
            force = true;
            continue;
        }
        if (!tstrcmp(args[i], _TSTR("--exclude")) || !tstrcmp(args[i], _TSTR("-e"))) {
            if (i + 1 < args.size()) {
                excludes.emplace_back(args[i + 1]);
                i++;
            }
            continue;
        }
        if (!tstrcmp(args[i], _TSTR("--libdir"))) {
            if (i + 1 < args.size()) {
                dest = args[i + 1];
                i++;
            }
            continue;
        }
        if (!tstrcmp(args[i], _TSTR("--linkdir")) || !tstrcmp(args[i], _TSTR("-L"))) {
            if (i + 1 < args.size()) {
                searchingPaths.emplace_back(args[i + 1]);
                i++;
            }
            continue;
        }
        if (args[i].starts_with(_TSTR("-L")) && args[i].size() > 2) {
            searchingPaths.emplace_back(args[i].substr(2));
            continue;
        }
        fileNames.push_back(args[i]);
    }

    if (fileNames.empty() || showHelp) {
        tprintf(_TSTR("Usage: %s <PE files ...>\n"), appName().data());
        tprintf(_TSTR("Options:\n"));
        tprintf(_TSTR("    %-20s    Set the output directory, defult to current directory\n"),
                _TSTR("-o/--out <dir>"));
        tprintf(_TSTR("    %-20s    Add a library searching path\n"), _TSTR("-L/--linkdir <dir>"));
        tprintf(_TSTR("    %-20s    Exclude a file name pattern\n"), _TSTR("-e/--exclude <regex>"));
        tprintf(_TSTR("    %-20s    Always overwrite\n"), _TSTR("-f/--force"));
        tprintf(_TSTR("    %-20s    Show help message\n"), _TSTR("-h/--help"));
        return 0;
    }

    // Remove duplications
    {
        TStringList tmp;
        std::set<std::wstring> visited;
        for (const auto &item: std::as_const(searchingPaths)) {
            if (!fs::is_directory(item))
                continue;

            auto canonical = fs::canonical(item);
            if (visited.count(canonical)) {
                continue;
            }
            visited.insert(canonical);
            tmp.push_back(canonical);
        }

        searchingPaths = std::move(tmp);
    }

    auto getDeps = [](const TStringList &fileNames, std::wstring *err) -> std::vector<std::string> {
        std::map<std::string, int> libs;
        for (const auto &fileName: std::as_const(fileNames)) {
            std::wstring errorMessage;
            std::vector<std::string> dependentLibrariesIn;
            unsigned wordSizeIn;
            bool isDebugIn;
            bool isMinGW = false;
            unsigned short machineArchIn;
            if (!WinUtils::readPeExecutable(fileName, &errorMessage, &dependentLibrariesIn,
                                            &wordSizeIn, &isDebugIn, isMinGW, &machineArchIn) &&
                err) {
                *err = errorMessage;
                return {};
            }

            for (const auto &item: std::as_const(dependentLibrariesIn)) {
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

    // Dry run
    {
        std::wstring errorMessage;
        auto libraries = getDeps(fileNames, &errorMessage);
        if (!errorMessage.empty()) {
            tprintf(_TSTR("Error: %s\n"), errorMessage.data());
            return -1;
        }

        for (const auto &item: std::as_const(libraries)) {
            std::cout << item << std::endl;
        }
    }

    // Deploy
    {
        std::set<std::wstring> visited;
        for (const auto &item: fileNames) {
            visited.insert(fs::path(item).filename());
        }

        TStringList stack = fileNames;
        TStringList dependencies;
        while (!stack.empty()) {
            auto libs = getDeps(stack, nullptr);
            stack.clear();
            for (const auto &lib: std::as_const(libs)) {
                std::wstring fileName = fs::path(lib);
                std::transform(fileName.begin(), fileName.end(), fileName.begin(), ::tolower);
                if (fileName.starts_with(_TSTR("vcruntime")) ||
                    fileName.starts_with(_TSTR("msvc")) ||
                    fileName.starts_with(_TSTR("api-ms-win-")) ||
                    fileName.starts_with(_TSTR("ext-ms-win-")) ||
                    fileName.starts_with(_TSTR("qt")) ||
                    fs::exists(_TSTR("C:\\Windows\\") + fileName) ||
                    fs::exists(_TSTR("C:\\Windows\\system32\\") + fileName) ||
                    fs::exists(_TSTR("C:\\Windows\\SysWow64\\") + fileName) || visited.count(fileName)) {
                    continue;
                }
                visited.insert(fileName);

                fs::path path;
                for (const auto &dir: std::as_const(searchingPaths)) {
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
                for (const auto &pattern: std::as_const(excludes)) {
                    const TString &pathString = path;
                    if (std::regex_search(pathString.begin(), pathString.end(),
                                          std::basic_regex<TChar>(pattern))) {
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

        for (const auto &file: std::as_const(dependencies)) {
            auto target = dest / fs::path(file).filename();
            if (!force && fs::exists(target) && fs::last_write_time(target) >= fs::last_write_time(file)) {
                continue; // Replace if different
            }

            try {
                fs::copy(file, dest, fs::copy_options::overwrite_existing);
            } catch (const std::exception &e) {
                std::cout << "Warning: copy file \"" << fs::path(file) << "\" failed: " << e.what()
                          << std::endl;
                continue;
            }
            fs::last_write_time(target, fs::last_write_time(file));
        }
    }

    return 0;
}