#include "utils.h"

#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <utime.h>

#include <filesystem>
#include <regex>
#include <sstream>

namespace fs = std::filesystem;

namespace Utils {

    static std::string executeCommand(const std::string &command,
                                      const std::vector<std::string> &args) {
        // printf("Executing command: %s", command.data());
        // for (const auto &arg : args) {
        //     printf(" %s", arg.data());
        // }
        // printf("\n");

        // Create pipe
        int pipefd[2];
        if (pipe(pipefd) == -1) {
            throw std::runtime_error("failed to call \"pipe\"");
        }

        pid_t pid = fork();
        if (pid < 0) {
            close(pipefd[0]);
            close(pipefd[1]);
            throw std::runtime_error("failed to call \"fork\"");
        }

        if (pid == 0) {
            // --------
            // Child process
            // --------

            close(pipefd[0]); // Close read pipe

            // Redirect "stdout" to write pipe
            dup2(pipefd[1], STDOUT_FILENO);
            close(pipefd[1]);

            // Prepare arguments
            auto argv = new char *[args.size() + 2]; // +2 for command and nullptr
            argv[0] = new char[command.size() + 1];  // +1 for null terminator
            memcpy(argv[0], command.data(), command.size());
            for (size_t i = 0; i < args.size(); ++i) {
                argv[i + 1] = new char[args[i].size() + 1]; // +1 for null terminator
                memcpy(argv[i + 1], args[i].data(), args[i].size());
                argv[i + 1][args[i].size()] = '\0'; // null
            }
            argv[args.size() + 1] = nullptr;

            // Call "exec"
            execvp(argv[0], argv);

            // Clean allocated memory
            for (size_t i = 0; i < args.size() + 2; ++i) {
                delete[] argv[i];
            }
            delete[] argv;

            // Fail
            printf("execve failed: %s\n", strerror(errno));
            exit(EXIT_FAILURE);
        }

        // --------
        // Parent process
        // --------

        close(pipefd[1]); // Close write pipe

        // Read child process output
        std::string output;

        char buffer[256];
        ssize_t bytes_read;
        while ((bytes_read = read(pipefd[0], buffer, sizeof(buffer) - 1)) > 0) {
            buffer[bytes_read] = '\0';
            output += buffer;
        }
        close(pipefd[0]);

        // Wait for child process to terminate
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status)) {
            auto exitCode = WEXITSTATUS(status);
            if (exitCode == 0)
                return output;

            // Throw error
            while (!output.empty() && output.back() == '\n') {
                output.pop_back();
            }
            throw std::runtime_error(output);
        }

        if (WIFSIGNALED(status)) {
            auto sig = WTERMSIG(status);
            throw std::runtime_error("command \"" + command + "\" was terminated by signal " +
                                     std::to_string(sig));
        }

        throw std::runtime_error("command \"" + command + "\" terminated abnormally");
    }

    FileTime fileTime(const fs::path &path) {
        struct stat sb;
        if (stat(path.c_str(), &sb) == -1) {
            throw std::runtime_error("failed to get file time: \"" + path.string() + "\"");
        }

        FileTime times;
        times.accessTime = std::chrono::system_clock::from_time_t(sb.st_atime);
        times.modifyTime = std::chrono::system_clock::from_time_t(sb.st_mtime);
        times.statusChangeTime = std::chrono::system_clock::from_time_t(sb.st_ctime);
        return times;
    }

    void setFileTime(const fs::path &path, const FileTime &times) {
        struct utimbuf new_times;
        new_times.actime = std::chrono::system_clock::to_time_t(times.accessTime);
        new_times.modtime = std::chrono::system_clock::to_time_t(times.modifyTime);
        if (utime(path.c_str(), &new_times) != 0) {
            throw std::runtime_error("failed to set file time: \"" + path.string() + "\"");
        }
    }

#ifdef __APPLE__
    // Mac
    // Use `otool` and `install_name_tool`

    std::vector<std::string> readMacExecutable(const std::string &path) {
        const auto &replace = [](std::string &s, const std::string &pattern,
                                 const std::string &text) {
            size_t idx;
            while ((idx = s.find(pattern)) != std::string::npos) {
                s.replace(idx, pattern.size(), text);
            }
        };

        std::vector<std::string> rpaths;
        std::vector<std::string> dependencies;
        std::string output;

        // Get RPATHs
        try {
            output = executeCommand("otool", {"-l", path});
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to get RPATHs: " + std::string(e.what()));
        }

        {
            static const std::regex rpathRegex(R"(\s*path\s+(.*)\s+\(offset.*)");
            std::istringstream iss(output);
            std::string line;
            std::smatch match;

            while (std::getline(iss, line)) {
                if (line.find("cmd LC_RPATH") != std::string::npos) {
                    // skip 2 lines
                    std::getline(iss, line);
                    std::getline(iss, line);
                    if (std::regex_match(line, match, rpathRegex) && match.size() >= 2) {
                        rpaths.emplace_back(match[1].str());
                    }
                }
            }
        }


        // Get dependencies
        try {
            output = executeCommand("otool", {"-L", path});
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to get dependencies: " + std::string(e.what()));
        }

        {
            static const std::regex depRegex(
                R"(^\t(.+) \(compatibility version (\d+\.\d+\.\d+), current version (\d+\.\d+\.\d+)(, weak)?\)$)");
            std::istringstream iss(output);
            std::string line;
            std::smatch match;

            // skip first line
            std::getline(iss, line);

            const std::string &loaderPath = path;
            while (std::getline(iss, line)) {
                if (std::regex_search(line, match, depRegex) && match.size() >= 2) {
                    std::string dep = match[1].str();

                    // Replace @executable_path and @loader_path
                    replace(dep, "@executable_path", loaderPath);
                    replace(dep, "@loader_path", loaderPath);

                    // Find dependency
                    for (const auto &rpath : rpaths) {
                        std::string fullPath = dep;
                        replace(fullPath, "@rpath", rpath);
                        if (fs::exists(fullPath) && fullPath != path) {
                            dependencies.push_back(fullPath);
                            break;
                        }
                    }
                }
            }
        }

        return dependencies;
    }

    std::vector<std::string> resolveExecutableDependencies(const std::filesystem::path &path) {
        return readMacExecutable(path);
    }

#else
    // Linux
    // Use `ldd` and `patchelf`

    static std::vector<std::string> readLinuxExecutable(const std::string &fileName) {
        std::string output;

        try {
            output = executeCommand("ldd", {fileName});
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to get dependencies: " + std::string(e.what()));
        }

        std::istringstream iss(output);
        std::string line;

        static const std::regex regexp("^\\s*.+ => (.+) \\(.*");

        std::vector<std::string> dependencies;
        while (std::getline(iss, line)) {
            std::smatch match;
            if (std::regex_match(line, match, regexp) && match.size() >= 2) {
                dependencies.push_back(match[1].str());
            }
        }

        return dependencies;
    }

    std::vector<std::string> resolveExecutableDependencies(const std::filesystem::path &path) {
        return readLinuxExecutable(path);
    }

#endif

}