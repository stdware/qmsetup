#ifndef COMMANDS_H
#define COMMANDS_H

#include <string>
#include <vector>

#include <stdcorelib/support/commandline.h>

#include "utils/utils.h"

namespace cli = stdc::cli;

// What the commands are, and the few things every one of them does with a parse result. Anything
// that is not about a command line is in utils/utils.h.

/// \name The commands
///
/// One per file, named after it. deploy is three, being a different program on every platform.
/// @{

int cmd_copy(const cli::ParseResult &result);
int cmd_rmdir(const cli::ParseResult &result);
int cmd_touch(const cli::ParseResult &result);
int cmd_configure(const cli::ParseResult &result);
int cmd_incsync(const cli::ParseResult &result);
int cmd_deploy(const cli::ParseResult &result);

/// @}

/// \name The options more than one command declares
///
/// Read the same way by all of them, so that a command line means one thing.
/// @{

inline bool isForceSet(const cli::ParseResult &result) {
    return result.option("-f").has_value();
}

inline bool isDryRunSet(const cli::ParseResult &result) {
    return result.option("-d").has_value();
}

inline bool isVerboseSet(const cli::ParseResult &result) {
    return result.isRoleSet(cli::Option::Verbose);
}

inline bool isStandardSet(const cli::ParseResult &result) {
    return result.option("-s").has_value();
}

/// @}

/// The values of one argument of \a token, across every time it was given.
///
/// \param index which of the option's arguments to read, for the ones that take more than one
/// \return nothing at all where the option was not given
inline std::vector<std::string> optionValues(const cli::ParseResult &result,
                                             std::string_view token, int index = 0) {
    auto given = result.option(token);
    if (!given) {
        return {};
    }
    return given->values<std::string>(index).value_or(std::vector<std::string>{});
}

/// The values of one positional argument of the command that was reached.
inline std::vector<std::string> argumentValues(const cli::ParseResult &result, int index) {
    return result.values<std::string>(index).value_or(std::vector<std::string>{});
}

#endif // COMMANDS_H
