#include "utils.h"

#include <shlwapi.h>

#include <delayimp.h>

#include <windows.h>

#include <algorithm>
#include <sstream>
#include <filesystem>
#include <stdexcept>

#include <syscmdline/system.h>

namespace SCL = SysCmdLine;

namespace fs = std::filesystem;

namespace Utils {

    // Helper functions to convert between FILETIME and std::chrono::system_clock::time_point
    static std::chrono::system_clock::time_point filetime_to_timepoint(const FILETIME &ft) {
        // Windows file time starts from January 1, 1601
        // std::chrono::system_clock starts from January 1, 1970
        static constexpr const long long WIN_EPOCH = 116444736000000000LL; // in hundreds of nanoseconds
        long long duration = (static_cast<long long>(ft.dwHighDateTime) << 32) + ft.dwLowDateTime;
        duration -= WIN_EPOCH;                            // convert to Unix epoch
        return std::chrono::system_clock::from_time_t(duration / 10000000LL);
    }

    static FILETIME timepoint_to_filetime(const std::chrono::system_clock::time_point &tp) {
        FILETIME ft;
        static constexpr const long long WIN_EPOCH = 116444736000000000LL; // in hundreds of nanoseconds
        long long duration =
            std::chrono::duration_cast<std::chrono::microseconds>(tp.time_since_epoch()).count();
        duration = duration * 10 + WIN_EPOCH;
        ft.dwLowDateTime = static_cast<DWORD>(duration & 0xFFFFFFFF);
        ft.dwHighDateTime = static_cast<DWORD>((duration >> 32) & 0xFFFFFFFF);
        return ft;
    }

    FileTime fileTime(const fs::path &path) {
        HANDLE hFile = CreateFileW(path.wstring().data(), GENERIC_READ, FILE_SHARE_READ, nullptr,
                                   OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile == INVALID_HANDLE_VALUE) {
            throw std::runtime_error("invalid path: \"" + SCL::wideToUtf8(path) + "\"");
        }

        FILETIME creationTime, lastAccessTime, lastWriteTime;
        if (!GetFileTime(hFile, &creationTime, &lastAccessTime, &lastWriteTime)) {
            CloseHandle(hFile);
            throw std::runtime_error("failed to get file time: \"" + SCL::wideToUtf8(path) + "\"");
        }
        CloseHandle(hFile);

        FileTime times;
        // ... (convert FILETIMEs to std::chrono::system_clock::time_point and store in times)
        times.accessTime = filetime_to_timepoint(lastAccessTime);
        times.modifyTime = filetime_to_timepoint(lastWriteTime);
        times.statusChangeTime = filetime_to_timepoint(creationTime);

        return times;
    }

    void setFileTime(const fs::path &path, const FileTime &times) {
        HANDLE hFile = CreateFileW(path.wstring().data(), FILE_WRITE_ATTRIBUTES, FILE_SHARE_WRITE,
                                   nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
        if (hFile == INVALID_HANDLE_VALUE) {
            throw std::runtime_error("invalid path: \"" + SCL::wideToUtf8(path) + "\"");
        }

        FILETIME creationTime, lastAccessTime, lastWriteTime;
        lastAccessTime = timepoint_to_filetime(times.accessTime);
        lastWriteTime = timepoint_to_filetime(times.modifyTime);
        creationTime = timepoint_to_filetime(times.statusChangeTime);

        if (!SetFileTime(hFile, &creationTime, &lastAccessTime, &lastWriteTime)) {
            CloseHandle(hFile);
            throw std::runtime_error("failed to set file time: \"" + SCL::wideToUtf8(path) + "\"");
        }
        CloseHandle(hFile);
    }

    static constexpr const DWORD g_EnglishLangId = MAKELANGID(LANG_ENGLISH, SUBLANG_ENGLISH_US);

    static std::wstring winErrorMessage(uint32_t error, bool nativeLanguage = true) {
        std::wstring rc;
        wchar_t *lpMsgBuf;

        const DWORD len =
            ::FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
                                 FORMAT_MESSAGE_IGNORE_INSERTS,
                             NULL, error, nativeLanguage ? 0 : g_EnglishLangId,
                             reinterpret_cast<LPWSTR>(&lpMsgBuf), 0, NULL);

        if (len) {
            // Remove tail line breaks
            if (lpMsgBuf[len - 1] == L'\n') {
                lpMsgBuf[len - 1] = L'\0';
                if (len > 2 && lpMsgBuf[len - 2] == L'\r') {
                    lpMsgBuf[len - 2] = L'\0';
                }
            }
            rc = std::wstring(lpMsgBuf, int(len));
            ::LocalFree(lpMsgBuf);
        } else {
            rc += L"unknown error";
        }

        return rc;
    }

    // ================================================================================
    // Modified from windeployqt 5.15.2(Copyright Qt company)
    // ================================================================================
    static inline std::string stringFromRvaPtr(const void *rvaPtr) {
        return static_cast<const char *>(rvaPtr);
    }

    // Helper for reading out PE executable files: Find a section header for an RVA
    // (IMAGE_NT_HEADERS64, IMAGE_NT_HEADERS32).
    template <class ImageNtHeader>
    static const IMAGE_SECTION_HEADER *findSectionHeader(DWORD rva, const ImageNtHeader *nTHeader) {
        const IMAGE_SECTION_HEADER *section = IMAGE_FIRST_SECTION(nTHeader);
        const IMAGE_SECTION_HEADER *sectionEnd = section + nTHeader->FileHeader.NumberOfSections;
        for (; section < sectionEnd; ++section)
            if (rva >= section->VirtualAddress &&
                rva < (section->VirtualAddress + section->Misc.VirtualSize))
                return section;
        return 0;
    }

    // Helper for reading out PE executable files: convert RVA to pointer (IMAGE_NT_HEADERS64,
    // IMAGE_NT_HEADERS32).
    template <class ImageNtHeader>
    inline const void *rvaToPtr(DWORD rva, const ImageNtHeader *nTHeader, const void *imageBase) {
        const IMAGE_SECTION_HEADER *sectionHdr = findSectionHeader(rva, nTHeader);
        if (!sectionHdr)
            return 0;
        const DWORD delta = sectionHdr->VirtualAddress - sectionHdr->PointerToRawData;
        return static_cast<const char *>(imageBase) + rva - delta;
    }

    // Helper for reading out PE executable files: return word size of a IMAGE_NT_HEADERS64,
    // IMAGE_NT_HEADERS32
    template <class ImageNtHeader>
    static unsigned ntHeaderWordSize(const ImageNtHeader *header) {
        // defines IMAGE_NT_OPTIONAL_HDR32_MAGIC, IMAGE_NT_OPTIONAL_HDR64_MAGIC
        enum { imageNtOptionlHeader32Magic = 0x10b, imageNtOptionlHeader64Magic = 0x20b };
        if (header->OptionalHeader.Magic == imageNtOptionlHeader32Magic)
            return 32;
        if (header->OptionalHeader.Magic == imageNtOptionlHeader64Magic)
            return 64;
        return 0;
    }

    // Helper for reading out PE executable files: Retrieve the NT image header of an
    // executable via the legacy DOS header.
    static IMAGE_NT_HEADERS *getNtHeader(void *fileMemory, std::wstring *errorMessage) {
        IMAGE_DOS_HEADER *dosHeader = static_cast<PIMAGE_DOS_HEADER>(fileMemory);
        // Check DOS header consistency
        if (IsBadReadPtr(dosHeader, sizeof(IMAGE_DOS_HEADER)) ||
            dosHeader->e_magic != IMAGE_DOS_SIGNATURE) {
            *errorMessage = L"DOS header check failed.";
            return 0;
        }
        // Retrieve NT header
        char *ntHeaderC = static_cast<char *>(fileMemory) + dosHeader->e_lfanew;
        IMAGE_NT_HEADERS *ntHeaders = reinterpret_cast<IMAGE_NT_HEADERS *>(ntHeaderC);
        // check NT header consistency
        if (IsBadReadPtr(ntHeaders, sizeof(ntHeaders->Signature)) ||
            ntHeaders->Signature != IMAGE_NT_SIGNATURE ||
            IsBadReadPtr(&ntHeaders->FileHeader, sizeof(IMAGE_FILE_HEADER))) {
            *errorMessage = L"NT header check failed.";
            return 0;
        }
        // Check magic
        if (!ntHeaderWordSize(ntHeaders)) {
            std::wostringstream ss;
            ss << "NT header check failed; magic " << ntHeaders->OptionalHeader.Magic
               << " is invalid.";
            *errorMessage = ss.str();
            return 0;
        }
        // Check section headers
        IMAGE_SECTION_HEADER *sectionHeaders = IMAGE_FIRST_SECTION(ntHeaders);
        if (IsBadReadPtr(sectionHeaders,
                         ntHeaders->FileHeader.NumberOfSections * sizeof(IMAGE_SECTION_HEADER))) {
            *errorMessage = L"NT header section header check failed.";
            return 0;
        }
        return ntHeaders;
    }

    // Helper for reading out PE executable files: Read out import sections from
    // IMAGE_NT_HEADERS64, IMAGE_NT_HEADERS32.
    template <class ImageNtHeader>
    static std::vector<std::string> readImportSections(const ImageNtHeader *ntHeaders,
                                                       const void *base,
                                                       std::wstring *errorMessage) {
        // Get import directory entry RVA and read out
        const DWORD importsStartRVA =
            ntHeaders->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress;
        if (!importsStartRVA) {
            *errorMessage = L"Failed to find IMAGE_DIRECTORY_ENTRY_IMPORT entry.";
            return {};
        }
        const IMAGE_IMPORT_DESCRIPTOR *importDesc = static_cast<const IMAGE_IMPORT_DESCRIPTOR *>(
            rvaToPtr(importsStartRVA, ntHeaders, base));
        if (!importDesc) {
            *errorMessage = L"Failed to find IMAGE_IMPORT_DESCRIPTOR entry.";
            return {};
        }
        std::vector<std::string> result;
        for (; importDesc->Name; ++importDesc)
            result.push_back(stringFromRvaPtr(rvaToPtr(importDesc->Name, ntHeaders, base)));

        // Read delay-loaded DLLs, see http://msdn.microsoft.com/en-us/magazine/cc301808.aspx .
        // Check on grAttr bit 1 whether this is the format using RVA's > VS 6
        if (const DWORD delayedImportsStartRVA =
                ntHeaders->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT]
                    .VirtualAddress) {
            const ImgDelayDescr *delayedImportDesc = static_cast<const ImgDelayDescr *>(
                rvaToPtr(delayedImportsStartRVA, ntHeaders, base));
            for (; delayedImportDesc->rvaDLLName && (delayedImportDesc->grAttrs & 1);
                 ++delayedImportDesc)
                result.push_back(
                    stringFromRvaPtr(rvaToPtr(delayedImportDesc->rvaDLLName, ntHeaders, base)));
        }

        return result;
    }

    // Check for MSCV runtime (MSVCP90D.dll/MSVCP90.dll, MSVCP120D.dll/MSVCP120.dll,
    // VCRUNTIME140D.DLL/VCRUNTIME140.DLL (VS2015) or msvcp120d_app.dll/msvcp120_app.dll).
    enum MsvcDebugRuntimeResult {
        MsvcDebugRuntime,
        MsvcReleaseRuntime,
        NoMsvcRuntime,
    };

    static MsvcDebugRuntimeResult
        checkMsvcDebugRuntime(const std::vector<std::string> &dependentLibraries) {
        for (auto lib : dependentLibraries) {
            int pos = 0;

            std::transform(lib.begin(), lib.end(), lib.begin(), [](unsigned char c) {
                return std::tolower(c); //
            });

            if (lib.starts_with("msvcr") || lib.starts_with("msvcp") ||
                lib.starts_with("vcruntime")) {
                int lastDotPos = lib.find_last_of('.');
                pos = -1 == lastDotPos ? 0 : lastDotPos - 1;
            }

            if (pos > 0 && lib.find("_app") != std::string::npos)
                pos -= 4;

            if (pos) {
                return lib.at(pos) == 'd' ? MsvcDebugRuntime : MsvcReleaseRuntime;
            }
        }
        return NoMsvcRuntime;
    }

    template <class ImageNtHeader>
    static void determineDebugAndDependentLibs(const ImageNtHeader *nth, const void *fileMemory,
                                               bool isMinGW,
                                               std::vector<std::string> *dependentLibrariesIn,
                                               bool *isDebugIn, std::wstring *errorMessage) {
        const bool hasDebugEntry =
            nth->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_DEBUG].Size;
        std::vector<std::string> dependentLibraries;
        if (dependentLibrariesIn || (isDebugIn != nullptr && hasDebugEntry && !isMinGW))
            dependentLibraries = readImportSections(nth, fileMemory, errorMessage);

        if (dependentLibrariesIn)
            *dependentLibrariesIn = dependentLibraries;
        if (isDebugIn != nullptr) {
            if (isMinGW) {
                // Use logic that's used e.g. in objdump / pfd library
                *isDebugIn = !(nth->FileHeader.Characteristics & IMAGE_FILE_DEBUG_STRIPPED);
            } else {
                // When an MSVC debug entry is present, check whether the debug runtime
                // is actually used to detect -release / -force-debug-info builds.
                *isDebugIn = hasDebugEntry &&
                             checkMsvcDebugRuntime(dependentLibraries) != MsvcReleaseRuntime;
            }
        }
    }

    // Read a PE executable and determine dependent libraries, word size
    // and debug flags.
    bool readPeExecutable(const std::wstring &peExecutableFileName, std::wstring *errorMessage,
                          std::vector<std::string> *dependentLibrariesIn, unsigned *wordSizeIn,
                          bool *isDebugIn, bool isMinGW, unsigned short *machineArchIn) {
        bool result = false;
        HANDLE hFile = NULL;
        HANDLE hFileMap = NULL;
        void *fileMemory = 0;

        if (dependentLibrariesIn)
            dependentLibrariesIn->clear();
        if (wordSizeIn)
            *wordSizeIn = 0;
        if (isDebugIn)
            *isDebugIn = false;

        do {
            // Create a memory mapping of the file
            hFile = CreateFileW(peExecutableFileName.data(), GENERIC_READ, FILE_SHARE_READ, NULL,
                                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
            if (hFile == INVALID_HANDLE_VALUE || hFile == NULL) {
                std::wostringstream ss;
                ss << L"Cannot open \"" << peExecutableFileName << L"\": "
                   << winErrorMessage(::GetLastError());
                *errorMessage = ss.str();
                break;
            }

            hFileMap = CreateFileMappingW(hFile, NULL, PAGE_READONLY, 0, 0, NULL);
            if (hFileMap == NULL) {
                std::wostringstream ss;
                ss << L"Cannot create file mapping of \"" << peExecutableFileName << L"\": "
                   << winErrorMessage(::GetLastError());
                *errorMessage = ss.str();
                break;
            }

            fileMemory = MapViewOfFile(hFileMap, FILE_MAP_READ, 0, 0, 0);
            if (!fileMemory) {
                std::wostringstream ss;
                ss << L"Cannot map \"" << peExecutableFileName << L"\": "
                   << winErrorMessage(::GetLastError());
                *errorMessage = ss.str();
                break;
            }

            const IMAGE_NT_HEADERS *ntHeaders = getNtHeader(fileMemory, errorMessage);
            if (!ntHeaders)
                break;

            const unsigned wordSize = ntHeaderWordSize(ntHeaders);
            if (wordSizeIn)
                *wordSizeIn = wordSize;
            if (wordSize == 32) {
                determineDebugAndDependentLibs(
                    reinterpret_cast<const IMAGE_NT_HEADERS32 *>(ntHeaders), fileMemory, isMinGW,
                    dependentLibrariesIn, isDebugIn, errorMessage);
            } else {
                determineDebugAndDependentLibs(
                    reinterpret_cast<const IMAGE_NT_HEADERS64 *>(ntHeaders), fileMemory, isMinGW,
                    dependentLibrariesIn, isDebugIn, errorMessage);
            }

            if (machineArchIn)
                *machineArchIn = ntHeaders->FileHeader.Machine;

            result = true;
        } while (false);

        if (fileMemory)
            UnmapViewOfFile(fileMemory);

        if (hFileMap != NULL)
            CloseHandle(hFileMap);

        if (hFile != NULL && hFile != INVALID_HANDLE_VALUE)
            CloseHandle(hFile);

        return result;
    }

    std::vector<std::string> resolveExecutableDependencies(const std::filesystem::path &path) {
        std::wstring errorMessage;
        std::vector<std::string> dependentLibrariesIn;
        unsigned wordSizeIn;
        bool isDebugIn;
        bool isMinGW = false;
        unsigned short machineArchIn;
        if (!readPeExecutable(path, &errorMessage, &dependentLibrariesIn, &wordSizeIn, &isDebugIn,
                              isMinGW, &machineArchIn)) {
            throw std::runtime_error(SCL::wideToUtf8(errorMessage));
        }
        return dependentLibrariesIn;
    }

    std::string local8bit_to_utf8(const std::string &s) {
        if (s.empty()) {
            return {};
        }
        const auto utf8Length = static_cast<int>(s.size());
        if (utf8Length >= (std::numeric_limits<int>::max)()) {
            return {};
        }
        const int utf16Length =
            ::MultiByteToWideChar(CP_ACP, MB_ERR_INVALID_CHARS, s.data(), utf8Length, nullptr, 0);
        if (utf16Length <= 0) {
            return {};
        }
        std::wstring utf16Str;
        utf16Str.resize(utf16Length);
        ::MultiByteToWideChar(CP_ACP, MB_ERR_INVALID_CHARS, s.data(), utf8Length, utf16Str.data(),
                              utf16Length);
        return SCL::wideToUtf8(utf16Str);
    }

}
