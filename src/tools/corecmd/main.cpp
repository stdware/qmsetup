#include <iostream>
#include <filesystem>

#include <stdimpl.h>

using namespace StdImpl;

namespace fs = std::filesystem;

static int cmd_cpdir(const TStringList &args);
static int cmd_rmdir(const TStringList &args);
static int cmd_touch(const TStringList &args);

static void printHelp();

static bool removeEmptyDirectories(const fs::path &path) {
    bool isCurrentDirEmpty = true;
    for (const auto &entry : fs::directory_iterator(path)) {
        if (fs::is_directory(entry.path())) {
            bool isSubDirEmpty = removeEmptyDirectories(entry.path());
            isCurrentDirEmpty &= isSubDirEmpty;
            if (isSubDirEmpty) {
                fs::remove(entry.path());
            }
        } else {
            isCurrentDirEmpty = false;
        }
    }
    return isCurrentDirEmpty;
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
                syncFileTime(destPath, sourcePath);
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

static struct {
    const TChar *cmd;
    const TChar *desc;
    int (*entry)(const TStringList &);
} commandEntries[] = {
    {_TSTR("cpdir <src> <dest>"),      _TSTR("Copy directory if different"),  cmd_cpdir},
    {_TSTR("rmdir <dir> [<dir> ...]"), _TSTR("Remove all empty directories"), cmd_rmdir},
    {_TSTR("touch <file> [ref file]"), _TSTR("Update timestamp"),             cmd_touch},
};

static struct {
    const TChar *opt;
    const TChar *desc;
    void (*entry)();
} optionEntries[] = {
    {_TSTR("-h/--help"), _TSTR("Show help message"), printHelp},
};

int cmd_cpdir(const TStringList &args) {
    TStringList fileNames(args.begin() + 2, args.end());
    if (fileNames.size() != 2) {
        tprintf(_TSTR("Error: invalid number of arguments\n"));
        return -1;
    }

    try {
        copyDirectory(fileNames.at(0), fileNames.at(1));
    } catch (const std::exception &e) {
        printf("Error: failed to copy directory: %s\n", e.what());
        return -1;
    }
    return 0;
}

int cmd_rmdir(const TStringList &args) {
    TStringList fileNames(args.begin() + 2, args.end());
    if (fileNames.size() == 0) {
        tprintf(_TSTR("Error: invalid number of arguments\n"));
        return -1;
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

int cmd_touch(const TStringList &args) {
    TStringList fileNames(args.begin() + 2, args.end());
    if (fileNames.size() == 0 || fileNames.size() > 2) {
        tprintf(_TSTR("Error: invalid number of arguments\n"));
        return -1;
    }

    const auto &src = fileNames.size() > 1 ? fileNames.at(1) : TString();
    const auto &dest = fileNames.at(0);

    // Check existence
    if (!src.empty() && !fs::is_regular_file(src)) {
        tprintf(_TSTR("Error: \"%s\" is not a regular file\n"), src.data());
        return -1;
    }

    if (!fs::is_regular_file(dest)) {
        tprintf(_TSTR("Error: \"%s\" is not a regular file\n"), dest.data());
        return -1;
    }

    // Get time
    FileTime t;
    if (!src.empty()) {
        t = fileTime(src);
        if (t.modifyTime == std::chrono::system_clock::time_point()) {
            tprintf(_TSTR("Error: failed to get time of \"%s\"\n"), src.data());
            return -1;
        }
    } else {
        std::chrono::system_clock::time_point now = std::chrono::system_clock::now();
        t = {now, now, now};
    }

    // Set time
    if (!setFileTime(dest, t)) {
        tprintf(_TSTR("Error: failed to sync time\n"));
        return -1;
    }
    return 0;
}

void printHelp() {
    tprintf(_TSTR("Usage: %s [cmd] [options]\n"), appName().data());
    tprintf(_TSTR("Commands:\n"));
    for (const auto &item : std::as_const(commandEntries)) {
        tprintf(_TSTR("    %-30s    %s\n"), item.cmd, item.desc);
    }
    tprintf(_TSTR("Options:\n"));
    for (const auto &item : std::as_const(optionEntries)) {
        tprintf(_TSTR("    %-30s    %s\n"), item.opt, item.desc);
    }
}

int main(int argc, char *argv[]) {
    (void) argc;
    (void) argv;

    TStringList args = commandLineArguments();
    if (args.size() < 2) {
        printHelp();
        return 0;
    }

    const auto &first = args[1];
    if (first.starts_with(_TSTR("-"))) {
        for (const auto &item : std::as_const(optionEntries)) {
            auto opts = split<TChar>(item.opt, _TSTR("/"));
            for (const auto &opt : std::as_const(opts)) {
                if (opt == first) {
                    item.entry();
                    return 0;
                }
            }
        }
        tprintf(_TSTR("Error: unknown option \"%s\"\n"), first.data());
        return -1;
    }
    for (const auto &item : std::as_const(commandEntries)) {
        auto cmd = TString(item.cmd);
        if (first == cmd.substr(0, cmd.find(_TSTR(' ')))) {
            return item.entry(args);
        }
    }
    tprintf(_TSTR("Error: unknown command \"%s\"\n"), first.data());
    return -1;
}