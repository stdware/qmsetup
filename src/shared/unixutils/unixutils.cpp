#include "unixutils.h"

#include <unistd.h>
#include <sys/wait.h>

#include <iostream>
#include <cstring>
#include <sstream>
#include <vector>
#include <regex>

static int executeCommand(const std::string &command, const std::vector<std::string> &args,
                          std::string *output) {
    // 创建管道
    int pipefd[2];
    if (pipe(pipefd) == -1) {
        perror("pipe");
        return -1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        // Fork失败
        perror("fork");
        return -1;
    }

    if (pid == 0) {
        // 子进程
        close(pipefd[0]); // 关闭读端

        // 重定向stdout到管道写端
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);

        // 准备参数
        auto argv = new char *[args.size() + 2]; // +2 for command and nullptr
        argv[0] = new char[command.size() + 1];  // +1 for null terminator
        memcpy(argv[0], command.data(), command.size());
        for (size_t i = 0; i < args.size(); ++i) {
            argv[i + 1] = new char[args[i].size() + 1]; // +1 for null terminator
            memcpy(argv[i + 1], args[i].data(), args[i].size());
        }
        argv[args.size() + 1] = nullptr;

        execvp(argv[0], argv);

        // 清理内存
        for (size_t i = 0; i < args.size() + 2; ++i) {
            delete[] argv[i];
        }
        delete[] argv;

        // 如果execvp失败
        perror("execvp");
        exit(EXIT_FAILURE);
    } else {
        // 父进程
        close(pipefd[1]); // 关闭写端

        // 读取子进程输出
        char buffer[256];
        ssize_t bytes_read;
        while ((bytes_read = read(pipefd[0], buffer, sizeof(buffer) - 1)) > 0) {
            buffer[bytes_read] = '\0';
            if (output) {
                *output += buffer;
            }
        }
        close(pipefd[0]);

        // 等待子进程结束
        int status;
        waitpid(pid, &status, 0);
        if (WIFEXITED(status)) {
            return WEXITSTATUS(status);
        }
    }

    return -1;
}

namespace UnixUtils {

#ifdef __APPLE__
    // Mac
    // Use `otool` and `install_name_tool`

    struct DylibInfo {
        std::string binaryPath;
        std::string compatibilityVersion;
        std::string currentVersion;
    };

    struct OtoolInfo {
        std::string binaryPath;
        std::string installName;
        std::string compatibilityVersion;
        std::string currentVersion;
        std::vector<DylibInfo> dependencies;
    };

    bool readUnixExecutable(const std::string &fileName, std::vector<std::string> *libs,
                            std::string *errorMessage) {
        OtoolInfo info;
        info.binaryPath = fileName;

        std::string output;
        if (executeCommand("otool", {"-L", fileName}, &output) != 0) {
            *errorMessage = "Error executing otool command";
            return false;
        }

        std::istringstream iss(output);
        std::string line;

        std::getline(iss, line); // Skip the line containing the binary path

        static const std::regex regexp(
            R"(^\t(.+) \(compatibility version (\d+\.\d+\.\d+), current version (\d+\.\d+\.\d+)(, weak)?\)$)");

        while (std::getline(iss, line)) {
            std::smatch match;
            if (std::regex_match(line, match, regexp)) {
                DylibInfo dylib;
                dylib.binaryPath = match[1].str();
                dylib.compatibilityVersion = match[2].str();
                dylib.currentVersion = match[3].str();
                info.dependencies.push_back(dylib);
            }
        }

        for (const auto &dep : info.dependencies) {
            libs->push_back(dep.binaryPath);
        }
        return true;
    }
#else
    // Linux
    // Use `ldd` and `patchelf`

    bool readUnixExecutable(const std::string &fileName, std::vector<std::string> *libs,
                            std::string *errorMessage) {
        std::string output;
        if (executeCommand("ldd", {fileName}, &output) != 0) {
            *errorMessage = "Error executing ldd command";
            return false;
        }

        std::istringstream iss(output);
        std::string line;

        static const std::regex regexp("^\\s*.+ => (.+) \\(.*");

        std::vector<std::string> info;
        while (std::getline(iss, line)) {
            std::smatch match;
            if (std::regex_match(line, match, regexp)) {
                info.push_back(match[1].str());
            }
        }

        *libs = std::move(info);
        return true;
    }
#endif

}