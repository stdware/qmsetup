#include "utils.h"

namespace fs = std::filesystem;

namespace Utils {

    std::filesystem::path cleanPath(const std::filesystem::path &path) {
        fs::path result;
        for (const auto &part : path) {
            if (part == "..") {
                if (!result.empty() && result.filename() != "..") {
                    result = result.parent_path();
                } else {
                    result /= part;
                }
            } else if (part != ".") {
                result /= part;
            }
        }
        return result;
    }

}