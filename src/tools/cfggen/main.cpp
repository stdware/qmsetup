#include <algorithm>
#include <cctype>
#include <fstream>
#include <iostream>
#include <regex>
#include <sstream>
#include <string>
#include <system_error>
#include <vector>

#include <stdimpl.h>

#include <syscmdline/parser.h>
#include <syscmdline/system.h>

#include "sha-256.h"

using StdImpl::tprintf;
using StdImpl::TString;

namespace SCL = SysCmdLine;

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

static const char STR_WARNING[] =
    R"(// Caution: This file is generated by CMake automatically during configure.
// WARNING!!! DO NOT EDIT THIS FILE MANUALLY!!!
// ALL YOUR MODIFICATIONS HERE WILL GET LOST AFTER RE-CONFIGURING!!!)";

static std::string toHeaderGuard(const std::string &filename) {
    std::string guard = filename;
    std::replace(guard.begin(), guard.end(), '.', '_');
    for (char &c : guard) {
        c = char(std::toupper(c));
    }
    return guard;
}

static std::string calculateHash(const std::string &data) {
    static const int sha_size = 32;

    uint8_t buf[sha_size];
    calc_sha_256(buf, data.data(), data.size());

    return StdImpl::toHexString({buf, buf + sha_size});
}

static int generateHeaderFile(const TString &filename, const std::vector<std::string> &defines) {
    std::string definitions;

    {
        std::stringstream ss;
        for (const auto &def : defines) {
            size_t pos = def.find('=');
            if (pos != std::string::npos) {
                ss << "#define " << def.substr(0, pos) << " " << def.substr(pos + 1) << "\n";
            } else {
                ss << "#define " << def << "\n";
            }
        }
        definitions = ss.str();
    }

    auto hash = calculateHash(definitions);

    // Read file
    do {
        // Check if file exists and has the same hash
        std::ifstream inFile(filename);
        if (!inFile.is_open()) {
            break;
        }

        std::regex hashPattern(R"(^// SHA256: (\w+)$)");
        std::smatch match;
        std::string line;
        bool matched = false;

        int pp_cnt = 0;
        while (std::getline(inFile, line)) {
            if (line.empty())
                continue;

            if (line.starts_with('#')) {
                pp_cnt++; // Skip header guard
                if (pp_cnt > 2) {
                    break;
                }
                continue;
            }

            if (!line.starts_with("//"))
                break;

            if (std::regex_match(line, match, hashPattern)) {
                if (match[1] == hash) {
                    matched = true;
                }
                break;
            }
        }

        inFile.close();

        if (matched) {
            printf("Content matched. (%s)\n", hash.data());
            return 0; // Same hash found, no need to overwrite the file
        }

    } while (false);

    // Create file
    {
        std::ofstream outFile(filename);
        if (!outFile.is_open()) {
            tprintf(_TSTR("Failed to open file \"%s\": %s."), filename.data(),
                    str2tstr(std::error_code(errno, std::generic_category()).message()).data());
            return -1;
        }

        // Header guard
        std::string guard = toHeaderGuard(tstr2str(filename));
        outFile << "#ifndef " << guard << "\n";
        outFile << "#define " << guard << "\n\n";

        outFile << STR_WARNING << "\n\n";           // Warning
        outFile << "// SHA256: " << hash << "\n\n"; // Hash
        outFile << definitions << "\n";             // Definitions
        outFile << "#endif // " << guard << "\n";   // Header guard end

        outFile.close();
    }

    return 0;
}

int main(int argc, char *argv[]) {
    SCL::Command command(SCL::appName(), "Generate configuration header.");
    command.addArgument(SCL::Argument("output file", "Output header path"));
    command.addOptions({
        SCL::Option({"-D", "--define"}, R"(Define a variable, format: "key" or "key=value")")
            .arg("expr")
            .multi()
            .short_match(SCL::Option::ShortMatchSingleChar),
    });
    command.addVersionOption(TOOL_VERSION);
    command.addHelpOption(true);
    command.setHandler([](const SCL::ParseResult &result) -> int {
        // Add defines
        std::vector<std::string> defines;
        {
            const auto &definesResult = result.option("-D").allValues();
            defines.reserve(definesResult.size());
            for (const auto &item : definesResult) {
                defines.emplace_back(item.toString());
            }
        }
        return generateHeaderFile(str2tstr(result.value(0).toString()), defines);
    });

    SCL::Parser parser(command);
    parser.setPrologue(TOOL_DESC);
    parser.setDisplayOptions(SCL::Parser::ShowOptionsHintFront);

#ifdef _WIN32
    std::ignore = argc;
    std::ignore = argv;
    return parser.invoke(SCL::commandLineArguments());
#else
    return parser.invoke(argc, argv);
#endif
}