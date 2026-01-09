#pragma once
#include "axmol.h"

class DecryptFileUtils
{
public:
    static void enable();

    static bool mount(const std::string& archiveLocation,
                      const std::string& mntpoint = "",
                      const bool front            = false,
                      bool keepFd                 = true);

    static void unmount(const std::string& archiveLocation);

    static std::vector<std::string> getArchiveFiles(const std::string& archiveLocation);
};
