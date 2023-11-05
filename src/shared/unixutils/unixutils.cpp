#include "unixutils.h"

#include <unistd.h>
#include <sys/wait.h>

#include <iostream>
#include <cstring>

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
        char **argv = new char *[args.size() + 2]; // +2 for command and nullptr
        argv[0] = new char[command.size() + 1];    // +1 for null terminator
        strcpy(argv[0], command.c_str());
        for (size_t i = 0; i < args.size(); ++i) {
            argv[i + 1] = new char[args[i].size() + 1]; // +1 for null terminator
            strcpy(argv[i + 1], args[i].c_str());
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

    bool readUnixExecutable(const std::string &fileName, std::string *errorMessage) {

        return true;
    }

}