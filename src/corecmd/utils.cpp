#include "utils.h"

#include <stdexcept>

namespace fs = std::filesystem;

namespace Utils {

    bool removeEmptyDirectories(const fs::path &path) {
        bool isEmpty = true;
        for (const auto &entry : fs::directory_iterator(path)) {
            if (fs::is_directory(entry.path()) && removeEmptyDirectories(entry.path())) {
                // Empty directory
                fs::remove(entry.path());

                // Exception will be thrown if failed
                // ...
            }

            // File or non-empty directory
            isEmpty = false;
        }
        return isEmpty;
    }

    static void copyDirectoryImpl(const fs::path &rootSourceDir, const fs::path &sourceDir,
                                  const fs::path &destDir) {
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
                    Utils::syncFileTime(destPath, sourcePath);
                }
            } else if (fs::is_directory(sourcePath)) {
                copyDirectoryImpl(rootSourceDir, sourcePath, destPath);
            } else if (fs::is_symlink(sourcePath)) {
                if (fs::exists(destPath)) {
                    fs::remove(destPath);
                }

                // Check if symlink points inside the source directory
                if (rootSourceDir.compare(sourcePath.parent_path()) == 0) {
                    // Recreate symlink in the destination
                    fs::create_symlink(fs::read_symlink(sourcePath), destPath);
                } else {
                    // Directly copy the symlink
                    fs::copy(sourcePath, destPath);
                }
            }
        }
    }

    void copyDirectory(const fs::path &sourceDir, const fs::path &destDir) {
        copyDirectoryImpl(sourceDir, sourceDir, destDir);
    }

}