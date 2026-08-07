#include "utils.h"

#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
#include <utime.h>

#include <cstring>
#include <filesystem>
#include <map>
#include <regex>
#include <set>
#include <sstream>

#include <stdcorelib/path.h>
#include <stdcorelib/str.h>
#include <stdcorelib/stlextra/algorithms.h>

namespace fs = std::filesystem;

namespace Utils {

    std::string executeCommand(const std::string &command, const std::vector<std::string> &args) {
        // printf("Executing command: %s", command.data());
        // for (const auto &arg : args) {
        //     printf(" %s", arg.data());
        // }
        // printf("\n");

        static const auto &dupStr = [](char *&dest, const char *src, size_t size) {
            dest = new char[size + 1];
            memcpy(dest, src, size);
            dest[size] = '\0';
        };

        enum PipeNum {
            PN_Read,
            PN_Write,
        };

        // Create pipe
        int pipefd[2];
        if (pipe(pipefd) == -1) {
            throw std::runtime_error("failed to call \"pipe\"");
        }

        pid_t pid = fork();
        if (pid < 0) {
            // Close pipes right away
            close(pipefd[PN_Read]);
            close(pipefd[PN_Write]);
            throw std::runtime_error("failed to call \"fork\"");
        }

        if (pid == 0) {
            // --------
            // Child process
            // --------

            // Close read pipe
            close(pipefd[PN_Read]);

            // Redirect "stdout" and "stderr" to write pipe
            dup2(pipefd[PN_Write], STDOUT_FILENO);
            dup2(pipefd[PN_Write], STDERR_FILENO);

            // Prepare arguments
            auto argv = new char *[args.size() + 2]; // +2 for command and nullptr
            dupStr(argv[0], command.data(), command.size());
            for (size_t i = 0; i < args.size(); ++i) {
                dupStr(argv[i + 1], args[i].data(), args[i].size());
            }
            argv[args.size() + 1] = nullptr;

            // Call "exec"
            execvp(argv[0], argv);

            // If the control flow reaches here, there must be a mistake

            // Clean allocated memory
            for (size_t i = 0; i < args.size() + 2; ++i) {
                delete[] argv[i];
            }
            delete[] argv;

            // Fail
            printf("exec \"%s\" failed: %s\n", command.data(), strerror(errno));

            // No need to close write pipe, let the System handle everything
            // Simply exit
            exit(EXIT_FAILURE);
        }

        // --------
        // Parent process
        // --------

        // Close write pipe
        close(pipefd[PN_Write]);

        // Read child process output
        char buffer[256];
        std::string output;
        ssize_t bytesRead;
        while ((bytesRead = read(pipefd[0], buffer, sizeof(buffer) - 1)) > 0) {
            buffer[bytesRead] = '\0';
            output += buffer;
        }

        // Close read pipe
        close(pipefd[PN_Read]);

        // Wait for child process to terminate
        int status;
        waitpid(pid, &status, 0);

        // Check exit status
        if (WIFEXITED(status)) {
            auto exitCode = WEXITSTATUS(status);
            if (exitCode == 0)
                return output;

            // Throw error
            throw std::runtime_error(stdc::str::trim(std::move(output)));
        }

        if (WIFSIGNALED(status)) {
            auto sig = WTERMSIG(status);
            throw std::runtime_error("command \"" + command + "\" was terminated by signal " +
                                     std::to_string(sig));
        }

        throw std::runtime_error("command \"" + command + "\" terminated abnormally with status " +
                                 std::to_string(status));
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

    static std::vector<std::string> readMacBinaryRPaths(const std::string &path) {
        std::vector<std::string> rpaths;
        std::string output;

        try {
            output = executeCommand("otool", {"-l", path});
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to get RPATHs: " + std::string(e.what()));
        }

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

        return rpaths;
    }

    static std::vector<std::string> readMacBinaryDependencies(const std::string &path) {
        std::vector<std::string> dependencies;
        std::string output;

        // Get dependencies
        try {
            output = executeCommand("otool", {"-L", path});
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to get dependencies: " + std::string(e.what()));
        }

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
                dependencies.emplace_back(dep);
            }
        }
        return dependencies;
    }

    std::vector<std::string>
        resolveUnixBinaryDependencies(const std::filesystem::path &path,
                                      const std::vector<std::filesystem::path> &searchingPaths,
                                      std::vector<std::string> *unparsed) {
        auto rpaths = readMacBinaryRPaths(path);
        for (const auto &item : searchingPaths) {
            rpaths.push_back(item);
        }

        auto dependencies = readMacBinaryDependencies(path);
        const std::string &loaderPath = fs::canonical(path).parent_path();

        std::vector<std::string> res;
        for (auto dep : std::as_const(dependencies)) {
            // Replace @executable_path and @loader_path
            replaceString(dep, std::string("@executable_path"), loaderPath);
            replaceString(dep, std::string("@loader_path"), loaderPath);

            // Find dependency
            std::string target = dep;
            if (dep.find("@rpath") != std::string::npos) {
                for (auto rpath : rpaths) {
                    // Replace again
                    replaceString(rpath, std::string("@executable_path"), loaderPath);
                    replaceString(rpath, std::string("@loader_path"), loaderPath);

                    std::string fullPath = dep;
                    replaceString(fullPath, std::string("@rpath"), rpath);
                    if (fs::exists(fullPath)) {
                        target = fullPath;
                        break;
                    }
                }
            }

            target = stdc::path::clean_path(target);
            if (fs::exists(target)) {
                if (fs::canonical(target).filename() == fs::canonical(path).filename())
                    continue;
                res.push_back(target);
            } else if (unparsed) {
                unparsed->push_back(target);
            }
        }

        return res;
    }

    void setFileRPaths(const std::string &file, const std::vector<std::string> &paths) {
        // Remove rpaths
        do {
            auto rpaths = readMacBinaryRPaths(file);
            if (rpaths.empty())
                break;
            std::vector<std::string> args;
            args.reserve(rpaths.size() * 2 + 1);
            for (const auto &rpath : std::as_const(rpaths)) {
                args.push_back("-delete_rpath");
                args.push_back(rpath);
            }
            args.push_back(file);

            try {
                std::ignore = executeCommand("install_name_tool", args);
            } catch (const std::exception &e) {
                throw std::runtime_error("Failed to remove rpaths: " + std::string(e.what()));
            }
        } while (false);

        // Add rpaths
        if (!paths.empty()) {
            std::set<std::string> visited;
            std::vector<std::string> args;
            args.reserve(paths.size() * 2 + 1);
            for (const auto &rpath : std::as_const(paths)) {
                if (stdc::contains(visited, rpath))
                    continue;

                visited.insert(rpath);
                args.push_back("-add_rpath");
                args.push_back(rpath);
            }
            args.push_back(file);

            try {
                std::ignore = executeCommand("install_name_tool", args);
            } catch (const std::exception &e) {
                throw std::runtime_error("Failed to add rpaths: " + std::string(e.what()));
            }
        }

        // Remove code signature if it exists
        try {
            std::ignore = executeCommand("codesign", {"--remove-signature", file});
            std::ignore = executeCommand("codesign", {"-s", "-", file});
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to resign: " + std::string(e.what()));
        }
    }

    std::vector<std::string> getMacAbsoluteDependencies(const std::string &file) {
        auto deps = readMacBinaryDependencies(file);
        std::vector<std::string> res;
        for (const auto &dep : std::as_const(deps)) {
            if (fs::path(dep).is_absolute()) {
                res.push_back(dep);
            }
        }
        return res;
    }

    void replaceMacFileDependencies(
        const std::string &file, const std::vector<std::pair<std::string, std::string>> &depPairs) {
        std::string output;
        std::vector<std::string> args;
        args.reserve(depPairs.size() * 3 + 1);

        std::string id;
        for (const auto &pair : depPairs) {
            if (fs::exists(pair.first) &&
                fs::canonical(pair.first).filename() == fs::canonical(file).filename()) {
                id = pair.second;
                continue;
            }
            args.push_back("-change");
            args.push_back(pair.first);
            args.push_back(pair.second);
        }
        if (!id.empty()) {
            args.push_back("-id");
            args.push_back(id);
        }
        args.push_back(file);

        try {
            output = executeCommand("install_name_tool", args);
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to replace dependency: " + std::string(e.what()));
        }
    }

#else
    // Linux
    // Use `ldd` and `patchelf`

    // The dynamic loader, which the C library names as a dependency of its own.
    //
    // It is the interpreter rather than a library to be deployed, it is never
    // where a binary says it is, and `ldd` reports it on a line of its own with
    // no name to resolve. Spelled out rather than as "ld-", which would take a
    // library that happens to begin that way with it.
    static bool isDynamicLoader(const std::string &name) {
        return stdc::str::starts_with(name, "ld-linux") ||
               stdc::str::starts_with(name, "ld-musl") ||
               stdc::str::starts_with(name, "ld-elf") ||
               stdc::str::starts_with(name, "ld.so") ||
               stdc::str::starts_with(name, "ld64.so");
    }

    // The names in the binary's own DT_NEEDED, which is where its dependency
    // graph actually has an edge.
    static std::vector<std::string> readNeededNames(const std::string &fileName) {
        std::string output;

        try {
            output = executeCommand("patchelf", {
                                                    "--print-needed",
                                                    fileName,
                                                });
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to get dependencies: " + std::string(e.what()));
        }

        std::vector<std::string> names;
        std::istringstream iss(output);
        std::string line;
        while (std::getline(iss, line)) {
            auto name = std::string(stdc::str::trim(line));
            if (!name.empty() && !isDynamicLoader(name)) {
                names.push_back(std::move(name));
            }
        }
        return names;
    }

    // What each name in the binary's closure resolves to.
    //
    // Working this out by hand would mean reimplementing the loader: the
    // search order of DT_RPATH against DT_RUNPATH, the way the first is
    // inherited down the loading chain and the second is not, LD_LIBRARY_PATH,
    // the binary format of /etc/ld.so.cache, whatever /etc/ld.so.conf.d says,
    // multiarch directories, the hwcaps subdirectories, and skipping a library
    // of the wrong ELF class. `ldd` has all of that right for the machine it
    // runs on, so it is asked instead.
    static std::map<std::string, std::string> readLddOutput(const std::string &fileName) {
        std::string output;

        try {
            output = executeCommand("ldd", {fileName});
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to get dependencies: " + std::string(e.what()));
        }

        std::istringstream iss(output);
        std::string line;

        static const std::regex regexp("^\\s*(.+) => (.+) \\(.*");

        std::map<std::string, std::string> resolved;
        while (std::getline(iss, line)) {
            std::smatch match;
            if (std::regex_match(line, match, regexp) && match.size() >= 3) {
                resolved.emplace(std::string(stdc::str::trim(match[1].str())),
                                 stdc::path::clean_path(match[2].str()));
            }
        }
        return resolved;
    }

    std::vector<std::string>
        resolveUnixBinaryDependencies(const std::filesystem::path &path,
                                      const std::vector<std::filesystem::path> &searchingPaths,
                                      std::vector<std::string> *unparsed) {
        // `ldd` answers with the whole closure at once, flattened, so reading
        // its output as a list of edges makes everything in the closure look
        // like a direct dependency of this one file. That is wrong wherever
        // the shape of the graph matters rather than only its contents.
        // Excluding a library, for one, would then leave behind whatever was
        // reachable only through it instead of dropping that too.
        //
        // So the two questions are asked separately. What the names are comes
        // from the binary itself, and what they resolve to comes from `ldd`.
        // Its table holds more than this file asks for, which does no harm,
        // because only the names it asks for are looked up.
        const auto &needed = readNeededNames(path);
        if (needed.empty()) {
            return {};
        }
        const auto &resolved = readLddOutput(path);

        std::vector<std::string> dependencies;
        dependencies.reserve(needed.size());
        for (const auto &name : needed) {
            const auto it = resolved.find(name);
            if (it != resolved.end()) {
                dependencies.push_back(it->second);
                continue;
            }

            // `ldd` said the name is not there, or did not mention it at all.
            fs::path target;
            for (const auto &item : searchingPaths) {
                auto fullPath = item / name;
                if (fs::exists(fullPath)) {
                    target = fullPath;
                    break;
                }
            }

            if (!target.empty()) {
                dependencies.push_back(target);
            } else if (unparsed) {
                unparsed->push_back(name);
            }
        }

        return dependencies;
    }

    void setFileRPaths(const std::string &file, const std::vector<std::string> &paths) {
        if (paths.empty()) {
            try {
                std::ignore = executeCommand("patchelf", {
                                                             "--remove-rpath",
                                                             file,
                                                         });
            } catch (const std::exception &e) {
                throw std::runtime_error("Failed to remove rpaths: " + std::string(e.what()));
            }
            return;
        }

        try {
            std::ignore = executeCommand("patchelf", {
                                                         "--set-rpath",
                                                         stdc::str::join(paths, ":"),
                                                         file,
                                                     });
        } catch (const std::exception &e) {
            throw std::runtime_error("Failed to replace rpaths: " + std::string(e.what()));
        }
    }

#endif


#ifdef __linux__
    static inline bool errorIsInterpNotFound(const std::string &what) {
        return what.find("cannot find section '.interp'") != std::string::npos;
    };

    std::string getInterpreter(const std::string &file) {
        std::string output;
        try {
            output = executeCommand("patchelf", {
                                                    "--print-interpreter",
                                                    file,
                                                });
        } catch (const std::exception &e) {
            if (errorIsInterpNotFound(e.what()))
                return {};
            throw std::runtime_error("Failed to get interpreter: " + std::string(e.what()));
        }

        output = stdc::str::trim(std::move(output));
        replaceString(output, std::string("$ORIGIN"), fs::canonical(file).parent_path().string());
        return output;
    }

    bool setFileInterpreter(const std::string &file, const std::string &interpreter) {
        try {
            std::ignore = executeCommand("patchelf", {
                                                         "--set-interpreter",
                                                         interpreter,
                                                         file,
                                                     });
        } catch (const std::exception &e) {
            if (errorIsInterpNotFound(e.what()))
                return false;
            throw std::runtime_error("Failed to set interpreter: " + std::string(e.what()));
        }
        return true;
    }
#endif

}
