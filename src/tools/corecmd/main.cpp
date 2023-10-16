#include <iostream>

#include <stdimpl.h>

using namespace StdImpl;

static int cmd_cpdir(const TStringList &args);
static int cmd_rmdir(const TStringList &args);
static int cmd_touch(const TStringList &args);

static void printHelp();

static struct {
    const TChar *cmd;
    const TChar *desc;
    int (*entry)(const TStringList &);
} commandEntries[] = {
    {_TSTR("cpdir <src> <dest>"),      _TSTR("Copy directory if different"),  cmd_cpdir},
    {_TSTR("rmdir <dir>"),             _TSTR("Remove all empty directories"), cmd_rmdir},
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
    return 0;
}

int cmd_rmdir(const TStringList &args) {
    return 0;
}

int cmd_touch(const TStringList &args) {
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
        tprintf(_TSTR("Error: Unknown option \"%s\"\n"), first.data());
        return -1;
    }
    for (const auto &item : std::as_const(commandEntries)) {
        auto cmd = TString(item.cmd);
        if (first == cmd.substr(0, cmd.find(_TSTR(' ')))) {
            return item.entry(args);
        }
    }
    tprintf(_TSTR("Error: Unknown command \"%s\"\n"), first.data());
    return -1;
}