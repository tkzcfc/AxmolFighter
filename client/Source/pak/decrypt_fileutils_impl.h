#pragma once
#include "axmol.h"

#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32
#    include "platform/win32/FileUtils-win32.h"
using FileUtilsImpl = ax::FileUtilsWin32;
#elif AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID
#    include "platform/android/FileUtils-android.h"
using FileUtilsImpl = ax::FileUtilsAndroid;
#else
#    import <Foundation/Foundation.h>
#    include "platform/apple/FileUtils-apple.h"
using FileUtilsImpl = ax::FileUtilsApple;
#endif

#include "pak/pak.h"

class DecryptFileUtilsImpl : public FileUtilsImpl
{

public:
    using Base = FileUtilsImpl;
    using Base::Base;

    virtual ~DecryptFileUtilsImpl();

    bool init() override;

    virtual std::unique_ptr<ax::IFileStream> openFileStream(std::string_view filePath,
                                                            ax::IFileStream::Mode mode) const override;

    virtual ax::FileUtils::Status getContents(std::string_view f, ax::ResizableBuffer* b) const override;

    virtual bool isFileExist(std::string_view s) const override;

    virtual std::string fullPathForFilename(std::string_view f) const override;

    bool mount(const std::string& archiveLocation, const std::string& mntpoint, const bool front, bool keepFd);

    void unmount(const std::string& archiveLocation);

    std::vector<std::string> getArchiveFiles(const std::string& archiveLocation);

private:
    std::string fullPathInArchives(std::string_view fn, int* archiveInfoIndex = NULL) const;

private:
    std::vector<pak::PakArchive*> m_archives;
    mutable std::recursive_mutex m_archivesLock;
};
