#include <iostream>
#include <filesystem>

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

static bool removeEmptyDirectories(const fs::path &path) {
    bool cur_empty = true;
    for (const auto &entry : fs::directory_iterator(path)) {
        if (fs::is_directory(entry.path())) {
            bool sub_empty = removeEmptyDirectories(entry.path());
            cur_empty &= sub_empty;
            if (sub_empty) {
                fs::remove(entry.path());
            }
        } else {
            cur_empty = false;
        }
    }
    return cur_empty;
}

static void copyDirectory(const fs::path &sourceDir, const fs::path &destDir) {
    fs::create_directories(destDir); // Ensure destination directory exists

    for (const auto &dirEntry : fs::directory_iterator(sourceDir)) {
        const auto &sourcePath = dirEntry.path();
        auto destPath = destDir / sourcePath.filename(); // Construct destination path

        if (fs::is_regular_file(sourcePath)) {
            if (fs::exists(destPath)) {
                // Only copy if the source file is newer than the destination file
                if (fs::last_write_time(sourcePath) > fs::last_write_time(destPath)) {
                    fs::copy_file(sourcePath, destPath, fs::copy_options::overwrite_existing);
                }
            } else {
                fs::copy_file(sourcePath, destPath);

                // Sync time
                StdImpl::syncFileTime(destPath, sourcePath);
            }
        } else if (fs::is_directory(sourcePath)) {
            copyDirectory(sourcePath, destPath);
        } else if (fs::is_symlink(sourcePath)) {
            if (fs::exists(destPath)) {
                fs::remove(destPath);
            }

            // Check if symlink points inside the source directory
            if (sourceDir.compare(sourcePath.parent_path()) == 0) {
                fs::create_symlink(fs::read_symlink(sourcePath),
                                   destPath);   // Recreate symlink in the destination
            } else {
                fs::copy(sourcePath, destPath); // Directly copy the symlink
            }
        }
    }
}

static int cmd_cpdir(const SCL::ParseResult &result) {
    const auto &src = str2tstr(result.value(0).toString());
    const auto &dest = str2tstr(result.value(1).toString());

    try {
        copyDirectory(src, dest);
    } catch (const std::exception &e) {
        printf("Error: failed to copy directory: %s\n", e.what());
        return -1;
    }
    return 0;
}

static int cmd_rmdir(const SCL::ParseResult &result) {
    TStringList fileNames;
    for (const auto &item : result.values(0)) {
        fileNames.emplace_back(str2tstr(item.toString()));
    }

    for (const auto &item : std::as_const(fileNames)) {
        if (!fs::is_directory(item)) {
            continue;
        }
        try {
            removeEmptyDirectories(item);
        } catch (const std::exception &e) {
            printf("Error: failed to remove \"%s\": %s\n", fs::path(item).string().data(),
                   e.what());
            return -1;
        }
    }
    return 0;
}

static int cmd_touch(const SCL::ParseResult &result) {
    const auto &file = str2tstr(result.value(0).toString());
    const auto &refFile = str2tstr(result.value(1).toString());

    // Check existence
    if (!fs::is_regular_file(file)) {
        tprintf(_TSTR("Error: \"%s\" is not a regular file\n"), file.data());
        return -1;
    }

    if (!refFile.empty() && !fs::is_regular_file(refFile)) {
        tprintf(_TSTR("Error: \"%s\" is not a regular file\n"), refFile.data());
        return -1;
    }

    // Get time
    StdImpl::FileTime t;
    if (!refFile.empty()) {
        t = StdImpl::fileTime(refFile);
        if (t.modifyTime == std::chrono::system_clock::time_point()) {
            tprintf(_TSTR("Error: failed to get time of \"%s\"\n"), refFile.data());
            return -1;
        }
    } else {
        std::chrono::system_clock::time_point now = std::chrono::system_clock::now();
        t = {now, now, now};
    }

    // Set time
    if (!StdImpl::setFileTime(file, t)) {
        tprintf(_TSTR("Error: failed to sync time\n"));
        return -1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    SCL::Command cpdirCommand("cpdir", "Copy contents of a directory if different");
    cpdirCommand.addArguments({
        SCL::Argument("src", "Source directory"),
        SCL::Argument("dest", "Destination directory"),
    });
    cpdirCommand.setHandler(cmd_cpdir);

    SCL::Command rmdirCommand("rmdir", "Remove all empty directories");
    rmdirCommand.addArguments({
        SCL::Argument("dir", "Directories").multi(),
    });
    rmdirCommand.setHandler(cmd_rmdir);

    SCL::Command touchCommand("touch", "Update file timestamp");
    touchCommand.addArguments({
        SCL::Argument("file", "File to update time stamp"),
        SCL::Argument("ref file", "Reference file", false),
    });
    touchCommand.setHandler(cmd_touch);

    SCL::Command rootCommand(SCL::appName(), "Cross-platform core utility commands.");
    rootCommand.addCommands({
        cpdirCommand,
        rmdirCommand,
        touchCommand,
    });
    rootCommand.addVersionOption(TOOL_VERSION);
    rootCommand.addHelpOption(true, true);
    rootCommand.setHandler([](const SCL::ParseResult &result) -> int {
        result.showHelpText();
        return 0;
    });

    SCL::Parser parser(rootCommand);
    parser.setPrologue(TOOL_DESC);

#ifdef _WIN32
    std::ignore = argc;
    std::ignore = argv;
    return parser.invoke(SCL::commandLineArguments());
#else
    return parser.invoke(argc, argv);
#endif
}