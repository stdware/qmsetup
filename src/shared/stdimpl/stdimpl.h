#ifndef STDIMPL_H
#define STDIMPL_H

#include <string>
#include <vector>

namespace StdImpl {

#ifdef _WIN32
    using TChar = wchar_t;
    using TString = std::wstring;

#  define _TSTR(X) L##X
#  define _FOPEN   _wfopen
#else
    using TChar = char;
    using TString = std::string;

#  define _TSTR(X) X
#  define _FOPEN   fopen
#endif

    using TStringList = std::vector<TString>;

    TStringList commandLineArguments();

    TString appPath();

    TString appName();

    void tprintf(const TChar *format, ...);

    inline int tstrcmp(const TChar *s, const TChar *p) {
#ifdef _WIN32
        return wcscmp(s, p);
#else
        return strcmp(s, p);
#endif
    }

    inline int tstrcmp(const TString &s, const TChar *p) {
        return tstrcmp(s.data(), p);
    }

    std::string toHexString(const std::vector<uint8_t> &data);

    std::vector<uint8_t> fromHexString(const std::string &str);

}

#endif // STDIMPL_H
