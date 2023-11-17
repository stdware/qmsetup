#include <iostream>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <regex>
#include <set>
#include <stdexcept>
#include <iomanip>

#include <syscmdline/parser.h>
#include <syscmdline/system.h>

#include "sha-256.h"
#include "utils.h"

namespace SCL = SysCmdLine;

namespace fs = std::filesystem;

using SCL::u8printf;

static constexpr const char STR_WARNING[] =
    R"(// Caution: This file is generated by CMake automatically during configure.
// WARNING!!! DO NOT EDIT THIS FILE MANUALLY!!!
// ALL YOUR MODIFICATIONS HERE WILL GET LOST AFTER RE-CONFIGURING!!!)";

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

static std::string time2str(const std::chrono::system_clock::time_point &t) {
    std::time_t t2 = std::chrono::system_clock::to_time_t(t);
    std::string s(30, '\0');
    std::strftime(s.data(), s.size(), "%Y-%m-%d %H:%M:%S", std::localtime(&t2));
    return s;
}

static bool removeEmptyDirectories(const fs::path &path, bool verbose) {
    bool isEmpty = true;
    for (const auto &entry : fs::directory_iterator(path)) {
        if (fs::is_directory(entry.path()) && removeEmptyDirectories(entry.path(), verbose)) {
            if (verbose) {
                u8printf("Remove %s\n", tstr2str(path).data());
            }

            // Empty directory
            fs::remove(entry.path());
        }

        // File or non-empty directory
        isEmpty = false;
    }
    return isEmpty;
}

static void copyDirectoryImpl(const fs::path &rootSourceDir, const fs::path &sourceDir,
                              const fs::path &destDir, bool verbose) {
    fs::create_directories(destDir); // Ensure destination directory exists

    for (const auto &dirEntry : fs::directory_iterator(sourceDir)) {
        const auto &sourcePath = dirEntry.path();
        auto destPath = destDir / sourcePath.filename(); // Construct destination path

        if (fs::is_regular_file(sourcePath)) {
            if (fs::exists(destPath)) {
                // Only copy if the source file is newer than the destination file
                if (fs::last_write_time(sourcePath) > fs::last_write_time(destPath)) {
                    if (verbose) {
                        u8printf("Copy %s\n", tstr2str(sourcePath).data());
                    }
                    fs::copy_file(sourcePath, destPath, fs::copy_options::overwrite_existing);
                }
            } else {
                if (verbose) {
                    u8printf("Copy %s\n", tstr2str(sourcePath).data());
                }
                fs::copy_file(sourcePath, destPath);

                // Sync time
                Utils::syncFileTime(destPath, sourcePath);
            }
        } else if (fs::is_directory(sourcePath)) {
            copyDirectoryImpl(rootSourceDir, sourcePath, destPath, verbose);
        } else if (fs::is_symlink(sourcePath)) {
            if (fs::exists(destPath)) {
                fs::remove(destPath);
            }

            // Check if symlink points inside the source directory
            if (rootSourceDir.compare(sourcePath.parent_path()) == 0) {
                // Recreate symlink in the destination
                if (verbose) {
                    u8printf("Symlink %s\n", tstr2str(sourcePath).data());
                }
                fs::create_symlink(fs::read_symlink(sourcePath), destPath);
            } else {
                // Directly copy the symlink
                if (verbose) {
                    u8printf("Copy %s\n", tstr2str(sourcePath).data());
                }
                fs::copy(sourcePath, destPath);
            }
        }
    }
}

static std::string standardError(int code = errno) {
    return std::error_code(code, std::generic_category()).message();
}

// ---------------------------------------- Commands ----------------------------------------

static int cmd_cpdir(const SCL::ParseResult &result) {
    bool verbose = result.optionIsSet("--verbose");
    const auto &src = fs::absolute(str2tstr(result.value(0).toString()));
    const auto &dest = fs::absolute(str2tstr(result.value(1).toString()));
    copyDirectoryImpl(src, src, dest, verbose);
    return 0;
}

static int cmd_rmdir(const SCL::ParseResult &result) {
    bool verbose = result.optionIsSet("--verbose");
    TStringList fileNames;
    {
        const auto &dirsResult = result.values(0);
        fileNames.reserve(dirsResult.size());
        for (const auto &item : dirsResult) {
            fileNames.emplace_back(fs::absolute(str2tstr(item.toString())));
        }
    }

    for (const auto &item : std::as_const(fileNames)) {
        if (!fs::is_directory(item)) {
            continue;
        }
        removeEmptyDirectories(item, verbose);
    }
    return 0;
}

static int cmd_touch(const SCL::ParseResult &result) {
    bool verbose = result.optionIsSet("--verbose");

    const auto &file = str2tstr(result.value(0).toString());
    const auto &refFile = str2tstr(result.value(1).toString());

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

static int cmd_configure(const SCL::ParseResult &result) {
    bool verbose = result.optionIsSet("--verbose");
    const auto &fileName = str2tstr(result.value(0).toString());

    // Add defines
    std::vector<std::string> defines;
    {
        const auto &definesResult = result.option("-D").allValues();
        defines.reserve(definesResult.size());
        for (const auto &item : definesResult) {
            defines.emplace_back(item.toString());
        }
    }

    // Generate definitions content
    std::string definitions;
    {
        std::stringstream ss;
        for (const auto &def : std::as_const(defines)) {
            size_t pos = def.find('=');
            if (pos != std::string::npos) {
                ss << "#define " << def.substr(0, pos) << " " << def.substr(pos + 1) << "\n";
            } else {
                ss << "#define " << def << "\n";
            }
        }
        definitions = ss.str();
    }

    // Calculate hash
    std::string hash;
    {
        uint8_t buf[32];
        calc_sha_256(buf, definitions.data(), definitions.size());

        std::stringstream ss;
        ss << std::hex << std::setfill('0');
        for (auto byte : buf) {
            ss << std::setw(2) << static_cast<int>(byte);
        }
        hash = ss.str();
    }

    // Read file
    do {
        // Check if file exists and has the same hash
        std::ifstream inFile(fileName);
        if (!inFile.is_open()) {
            break;
        }

        std::regex hashPattern(R"(^// SHA256: (\w+)$)");
        std::smatch match;
        std::string line;
        bool matched = false;

        int pp_cnt = 0;
        while (std::getline(inFile, line)) {
            if (line.empty())
                continue;

            if (line.starts_with('#')) {
                pp_cnt++; // Skip header guard
                if (pp_cnt > 2) {
                    break;
                }
                continue;
            }

            if (!line.starts_with("//"))
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
                SCL::u8debug(SCL::MessageType::MT_Warning, true, "Content matched. (%s)\n",
                             hash.data());
            }
            return 0; // Same hash found, no need to overwrite the file
        }

    } while (false);

    // Create file
    {
        // Create directory if needed
        if (auto dir = fs::path(fileName).parent_path(); !fs::is_directory(dir)) {
            fs::create_directories(dir);
        }

        std::ofstream outFile(fileName);
        if (!outFile.is_open()) {
            throw std::runtime_error("failed to open file \"" + tstr2str(fileName) +
                                     "\": " + standardError());
        }

        // Header guard
        std::string guard = tstr2str(fs::path(fileName).filename());
        std::replace(guard.begin(), guard.end(), '.', '_');
        for (char &c : guard) {
            c = char(std::toupper(c));
        }

        outFile << "#ifndef " << guard << "\n";
        outFile << "#define " << guard << "\n\n";

        outFile << STR_WARNING << "\n\n";           // Warning
        outFile << "// SHA256: " << hash << "\n\n"; // Hash
        outFile << definitions << "\n";             // Definitions
        outFile << "#endif // " << guard << "\n";   // Header guard end

        outFile.close();
    }

    if (verbose) {
        u8printf("SHA256: %s\n", hash.data());
    }

    return 0;
}

static int cmd_incsync(const SCL::ParseResult &result) {
    bool verbose = result.optionIsSet("--verbose");

    bool copy = result.optionIsSet("-c");
    bool all = !result.optionIsSet("-n");
    bool standard = result.optionIsSet("-s");

    const fs::path &src = str2tstr(result.value(0).toString());
    const fs::path &dest = str2tstr(result.value(1).toString());
    if (!fs::is_directory(src)) {
        throw std::runtime_error("not a directory: \"" + tstr2str(src) + "\"");
    }

    // Add includes
    std::vector<std::pair<TString, TString>> includes;
    {
        const auto &includeResult = result.option("-i");
        int cnt = includeResult.count();
        includes.reserve(cnt + 1);

        // Add standard
        if (standard) {
            includes.emplace_back(_TSTR(R"(.*?_p\..+$)"), _TSTR("private"));
        }

        for (int i = 0; i < cnt; ++i) {
            includes.emplace_back(str2tstr(includeResult.value(0, i).toString()),
                                  str2tstr(includeResult.value(1, i).toString()));
        }
    }

    // Add excludes
    TStringList excludes;
    {
        const auto &excludeResult = result.option("-e").allValues();
        excludes.reserve(excludeResult.size());
        for (const auto &item : excludeResult) {
            excludes.emplace_back(str2tstr(item.toString()));
        }
    }

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

            const fs::path &targetDir = subdir.empty() ? dest : (dest / subdir);

            // Create directory
            if (!fs::exists(targetDir)) {
                fs::create_directories(targetDir);
            }

            auto targetPath = targetDir / path.filename();
            if (verbose) {
                u8printf("Create %s\n", tstr2str(targetPath).data());
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
                if (!outFile.is_open())
                    continue;
                outFile << "#include \"" << rel << "\"" << std::endl;
                outFile.close();
            }

            // Set timestamp
            Utils::syncFileTime(targetPath, path);
        }
    }

    return 0;
}

static int cmd_deploy(const SCL::ParseResult &result) {
    bool verbose = result.optionIsSet("--verbose");
    bool force = result.optionIsSet("-f");
    TString dest = fs::current_path(); // Default to current path
    if (result.optionIsSet("-o")) {
        dest = fs::absolute(str2tstr(result.valueForOption("-o").toString()));
    }

    // Add file names
    TStringList fileNames;
    {
        const auto &files = result.values(0);
        fileNames.reserve(files.size());
        for (const auto &item : files) {
            fileNames.emplace_back(fs::absolute(str2tstr(item.toString())));
        }
    }

#ifdef _WIN32
    // Add searching paths
    TStringList searchingPaths;
    {
        const auto &linkResult = result.option("-L").allValues();

        TStringList tmp;
        tmp.reserve(linkResult.size() + fileNames.size());

        // Add file paths
        for (const auto &item : std::as_const(fileNames)) {
            tmp.emplace_back(fs::path(item).parent_path());
        }

        // Add searching paths
        for (const auto &item : linkResult) {
            tmp.emplace_back(fs::absolute(str2tstr(item.toString())));
        }

        // Remove duplications
        TStringSet visited;
        for (const auto &item : std::as_const(tmp)) {
            if (!fs::is_directory(item))
                continue;

            TString canonical = fs::canonical(item);
            if (visited.count(canonical)) {
                continue;
            }
            visited.insert(canonical);
            searchingPaths.emplace_back(canonical);
        }
    }
#endif

    // Add excludes
    TStringList excludes;
    {
        const auto &excludeResult = result.option("-e").allValues();

        excludes.reserve(excludeResult.size());
        for (const auto &item : excludeResult) {
            excludes.emplace_back(str2tstr(item.toString()));
        }
    }

    // Deploy
    TStringSet visited;
    for (const auto &item : fileNames) {
        visited.insert(fs::path(item).filename());
    }

    TStringList stack = fileNames;
    TStringList dependencies;

    // Search for dependencies recursively
    while (!stack.empty()) {
        // Resolve dependencies
        auto libs = [](const TStringList &fileNames) -> std::vector<std::string> {
            std::set<std::string> libs;
            for (const auto &fileName : std::as_const(fileNames)) {
                const auto &deps = Utils::resolveExecutableDependencies(fileName);
                for (const auto &item : std::as_const(deps)) {
                    libs.insert(item);
                }
            }
            return {libs.begin(), libs.end()};
        }(stack);
        stack.clear();

        // Search dependencies
        for (const auto &lib : std::as_const(libs)) {
            TString fileName = fs::path(lib);
            std::transform(fileName.begin(), fileName.end(), fileName.begin(), ::tolower);

            if (
#ifdef _WIN32
                // Ignore API-Set, MSVC libraries, system libraries and Qt libraries
                fileName.starts_with(_TSTR("vcruntime")) || fileName.starts_with(_TSTR("msvcp")) ||
                fileName.starts_with(_TSTR("concrt")) || fileName.starts_with(_TSTR("vccorlib")) ||
                fileName.starts_with(_TSTR("ucrtbase")) || fileName.starts_with(_TSTR("api-ms-win-")) ||
                fileName.starts_with(_TSTR("ext-ms-win-")) || fileName.starts_with(_TSTR("qt")) ||
                fs::exists(_TSTR("C:\\Windows\\") + fileName) ||
                fs::exists(_TSTR("C:\\Windows\\system32\\") + fileName) ||
                fs::exists(_TSTR("C:\\Windows\\SysWow64\\") + fileName) ||
#endif
                visited.count(fileName)) {
                continue;
            }
            visited.insert(fileName);

#ifdef _WIN32
            // Search in specified searching paths
            fs::path path;
            for (const auto &dir : std::as_const(searchingPaths)) {
                fs::path targetPath = dir / fs::path(lib);
                if (fs::exists(targetPath)) {
                    path = targetPath;
                    break;
                }
            }

            if (path.empty()) {
                continue;
            }
#else
            path = lib;
#endif

            bool skip = false;
            for (const auto &pattern : std::as_const(excludes)) {
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

    // Deploy
    for (const auto &file : std::as_const(dependencies)) {
        auto target = dest / fs::path(file).filename();

        if (fs::exists(target) && fs::exists(file) && fs::canonical(target) == fs::canonical(file))
            continue; // Same file

        if (!force && fs::exists(target) &&
            Utils::fileTime(target).modifyTime >= Utils::fileTime(file).modifyTime) {
            continue; // Replace if different
        }

        if (verbose) {
            u8printf("Deploy %s\n", tstr2str(target).data());
        }

        if (!fs::is_directory(dest)) {
            fs::create_directories(dest);
        }

        fs::copy(file, dest, fs::copy_options::overwrite_existing);
        Utils::syncFileTime(target, file);
    }

    return 0;
}

int main(int argc, char *argv[]) {
    // Shared option
    static SCL::Option verbose({"-V", "--verbose"}, "Show verbose");

    SCL::Command cpdirCommand = []() {
        SCL::Command command("cpdir", "Copy contents of a directory if different");
        command.addArguments({
            SCL::Argument("src", "Source directory"),
            SCL::Argument("dest", "Destination directory"),
        });
        command.addOption(verbose);
        command.setHandler(cmd_cpdir);
        return command;
    }();

    SCL::Command rmdirCommand = []() {
        SCL::Command command("rmdir", "Remove all empty directories");
        command.addArguments({
            SCL::Argument("dir", "Directories").multi(),
        });
        command.addOption(verbose);
        command.setHandler(cmd_rmdir);
        return command;
    }();

    SCL::Command touchCommand = []() {
        SCL::Command command("touch", "Update file timestamp");
        command.addArguments({
            SCL::Argument("file", "File to update time stamp"),
            SCL::Argument("ref file", "Reference file", false),
        });
        command.addOption(verbose);
        command.setHandler(cmd_touch);
        return command;
    }();

    SCL::Command configureCommand = []() {
        SCL::Command command("configure", "Generate configuration header");
        command.addArgument(SCL::Argument("output file", "Output header path"));
        command.addOptions({
            SCL::Option({"-D", "--define"}, R"(Define a variable, format: "key" or "key=value")")
                .arg("expr")
                .multi()
                .short_match(SCL::Option::ShortMatchSingleChar),
        });
        command.addOption(verbose);
        command.setHandler(cmd_configure);
        return command;
    }();

    SCL::Command incsyncCommand = []() {
        SCL::Command command("incsync", "Reorganize the header directory structure");
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
        command.addOption(verbose);
        command.setHandler(cmd_incsync);
        return command;
    }();

    SCL::Command deployCommand = []() {
        SCL::Command command("deploy", "Resolve and deploy " OS_EXECUTABLE " files' dependencies");
        command.addArguments({
            SCL::Argument("file", OS_EXECUTABLE "(s)"),
        });
        command.addOptions({
            SCL::Option({"-o", "--out"}, "Set the output directory, defult to current directory")
                .arg("dir"),
#ifdef _WIN32
            SCL::Option({"-L", "--linkdir"}, "Add a library searching path")
                .arg("dir")
                .multi()
                .short_match(SCL::Option::ShortMatchSingleChar),
#endif
            SCL::Option({"-e", "--exclude"}, "Exclude a path pattern").arg("regex").multi(),
            SCL::Option({"-f", "--force"}, "Force overwrite existing files"),
        });
        command.addOption(verbose);
        command.setHandler(cmd_deploy);
        return command;
    }();

    SCL::Command rootCommand(SCL::appName(), "Cross-platform core utility commands.");
    rootCommand.addCommands({
        cpdirCommand,
        rmdirCommand,
        touchCommand,
        configureCommand,
        incsyncCommand,
        deployCommand,
    });
    rootCommand.addVersionOption(TOOL_VERSION);
    rootCommand.addHelpOption(true, true);
    rootCommand.setHandler([](const SCL::ParseResult &result) -> int {
        result.showHelpText();
        return 0;
    });

    SCL::CommandCatalogue cc;
    cc.addCommands("Filesystem Commands", {"cpdir", "rmdir", "touch"});
    cc.addCommands("Developer Commands", {"configure", "incsync", "deploy"});
    rootCommand.setCatalogue(cc);

    SCL::Parser parser(rootCommand);
    parser.setPrologue(TOOL_DESC);
    parser.setDisplayOptions(SCL::Parser::AlignAllCatalogues);

    int ret;
    try {
#ifdef _WIN32
        std::ignore = argc;
        std::ignore = argv;
        ret = parser.invoke(SCL::commandLineArguments());
#else
        ret = parser.invoke(argc, argv);
#endif
    } catch (const std::exception &e) {
        std::string msg = e.what();

#ifdef _WIN32
        if (typeid(e) == typeid(std::filesystem::filesystem_error)) {
            auto err = static_cast<const std::filesystem::filesystem_error &>(e);
            // msg = "\"" + tstr2str(err.path1()) + "\": " + standardError();
            msg = Utils::local8bit_to_utf8(err.what());
        }
#endif

        SCL::u8debug(SCL::MT_Critical, true, "Error: %s\n", msg.data());
        ret = -1;
    }
    return ret;
}
