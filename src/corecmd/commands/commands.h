#ifndef COMMANDS_H
#define COMMANDS_H

#include <string>
#include <vector>

#include <stdcorelib/console.h>
#include <stdcorelib/path.h>
#include <stdcorelib/support/commandline.h>

#include "utils/utils.h"

namespace cli = stdc::cli;

// What the commands are, and the few things every one of them does with a parse result. Anything
// that is not about a command line is in utils/utils.h.

/// \name The commands
///
/// One per file, named after it. deploy is three, being a different program on every platform.
///
/// copy, rmdir and touch are here because Windows has no command of its own for any of them and
/// because CMake's answers are either slower or do not exist.
/// @{

int cmd_copy(const cli::ParseResult &result);
int cmd_rmdir(const cli::ParseResult &result);
int cmd_touch(const cli::ParseResult &result);
int cmd_configure(const cli::ParseResult &result);
int cmd_incsync(const cli::ParseResult &result);
int cmd_deploy(const cli::ParseResult &result);

/// @}

/// \name Reading what was given
///
/// A parse result answers with \c std::optional, since a value that is not there and a value
/// that is empty are different questions. Nothing here needs them to be: an argument that was
/// not given and one given as an empty string both mean the command has nothing to work with.
/// So these fold the two together and hand back a plain value.
///
/// They are also the readable way to spell it. Written out, asking for one string is
/// <tt>result.value<std::string>(0).value_or(std::string())</tt>, and the tail of that cannot
/// be shortened to \c {} because \c value_or deduces its parameter and a braced initialiser
/// deduces nothing. MSVC takes it anyway, so a line written that way builds here and stops the
/// build on GCC.
/// @{

/// One positional argument of the command that was reached.
inline std::string argumentValue(const cli::ParseResult &result, int index) {
    return result.value<std::string>(index).value_or(std::string());
}

/// The values of one positional argument of the command that was reached.
inline std::vector<std::string> argumentValues(const cli::ParseResult &result, int index) {
    return result.values<std::string>(index).value_or(std::vector<std::string>{});
}

/// The first argument of \a token's first occurrence.
inline std::string optionValue(const cli::ParseResult &result, std::string_view token) {
    return result.valueForOption<std::string>(token).value_or(std::string());
}

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
    return given->allValues<std::string>(index).value_or(std::vector<std::string>{});
}

/// One argument of one occurrence of an option already known to have been given.
///
/// \param index which of the option's arguments to read
/// \param occurrence which time it was given, for an option that may be repeated
///
/// \pre \a occurrence names a time the option was given, which is what \c count() answers
inline std::string givenValue(const cli::OptionResult &given, int index = 0, int occurrence = 0) {
    return given.at(occurrence).value<std::string>(index).value_or(std::string());
}

/// @}

/// The listing of \c --list, the machine-readable output of deploy and incsync.
///
/// Each entry is one line on stdout, ended by \c \\n on every platform, with \c / as the
/// separator and UTF-8 as the encoding. The format is stable, unlike the messages of \c -V,
/// which printLog() then writes to stderr.
class Listing {
public:
    enum Mode {
        None,    ///< No listing
        Source,  ///< The absolute path of the source of each entry
        Target,  ///< The absolute path of the target of each entry
        Mapping, ///< The source and the target of each entry, separated by a tab
    };

    /// Returns the mode that \c --list selects, or None if the option is absent.
    static Mode modeOf(const cli::ParseResult &result) {
        const auto mode = optionValue(result, "--list");
        if (mode == "source") {
            return Source;
        }
        if (mode == "target") {
            return Target;
        }
        if (mode == "mapping") {
            return Mapping;
        }
        return None;
    }

    /// Prints the entry of \a source and \a target in \a mode.
    static void print(Mode mode, const fs::path &source, const fs::path &target) {
        switch (mode) {
            case Source:
                stdc::u8printf("%s\n", stdc::path::normalize_separators(source).data());
                break;
            case Target:
                stdc::u8printf("%s\n", stdc::path::normalize_separators(target).data());
                break;
            case Mapping:
                stdc::u8printf("%s\t%s\n", stdc::path::normalize_separators(source).data(),
                               stdc::path::normalize_separators(target).data());
                break;
            case None:
                break;
        }
    }
};

/// The options more than one command declares.
///
/// Read once, by the pre handler of the root command, so that a command line means one thing
/// in every command. An option that the command does not declare reads as absent.
struct CommonOptions {
    bool force = false;                 ///< \c -f
    bool dryRun = false;                ///< \c -n
    bool verbose = false;               ///< \c -V, or \c -n without \c --list
    bool standard = false;              ///< \c -s
    Listing::Mode list = Listing::None; ///< \c --list

    /// Returns the options that read() read.
    static CommonOptions &instance() {
        static CommonOptions options;
        return options;
    }

    /// Reads the options of \a result into instance(), and sends the log to stderr if a
    /// listing occupies stdout.
    ///
    /// A dry run reports what it found, unless the listing takes the place of the report.
    static void read(const cli::ParseResult &result) {
        auto &options = instance();
        options.force = result.option("-f").has_value();
        options.dryRun = result.option("-n").has_value();
        options.standard = result.option("-s").has_value();
        options.list = Listing::modeOf(result);
        options.verbose =
            (options.dryRun && options.list == Listing::None) || result.option("-V").has_value();
        if (options.list != Listing::None) {
            Utils::setLogToStderr(true);
            Utils::setStdoutBinary();
        }
    }
};

#endif // COMMANDS_H
