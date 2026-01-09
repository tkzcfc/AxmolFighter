
#include "cocos2d.h"
#if AX_TARGET_PLATFORM != AX_PLATFORM_IOS && AX_TARGET_PLATFORM != AX_PLATFORM_MAC
#    define COMPILE_DECYPT_FILE_UTILS_IMPL_CPP 1
#endif

#if COMPILE_DECYPT_FILE_UTILS_IMPL_CPP

#    include "decrypt_fileutils_impl.h"

////////////////////////////////////////////////////////////////////////////////////////////////////////
// DecryptFileUtilsImpl
////////////////////////////////////////////////////////////////////////////////////////////////////////

DecryptFileUtilsImpl::~DecryptFileUtilsImpl()
{
    for (auto& ptr : m_archives)
    {
        delete ptr;
    }
    m_archives.clear();
}

bool DecryptFileUtilsImpl::init()
{
    m_archives.reserve(50);
    return Base::init();
}

bool DecryptFileUtilsImpl::mount(const std::string& archiveLocation,
                                 const std::string& mntpoint,
                                 const bool front,
                                 bool keepFd)
{
    std::lock_guard<std::recursive_mutex> lock(m_archivesLock);

    auto archiveInfo = new pak::PakArchive();
    if (!archiveInfo->init(archiveLocation, mntpoint, keepFd))
    {
        delete archiveInfo;
        return false;
    }

    if (front)
        m_archives.insert(m_archives.begin(), archiveInfo);
    else
        m_archives.push_back(archiveInfo);

    return true;
}

void DecryptFileUtilsImpl::unmount(const std::string& archiveLocation)
{
    std::lock_guard<std::recursive_mutex> lock(m_archivesLock);
    pak::PakArchive* archivePtr = nullptr;
    for (auto it = m_archives.begin(); it != m_archives.end(); ++it)
    {
        archivePtr = *it;
        if (archivePtr->getRawArchiveLocation() == archiveLocation)
        {
            delete archivePtr;
            m_archives.erase(it);
            break;
        }
    }
}

std::vector<std::string> DecryptFileUtilsImpl::getArchiveFiles(const std::string& archiveLocation)
{
    std::vector<std::string> files;
    pak::PakArchive* archivePtr = nullptr;

    std::lock_guard<std::recursive_mutex> lock(m_archivesLock);
    for (auto it = m_archives.begin(); it != m_archives.end(); ++it)
    {
        archivePtr = *it;
        if (archivePtr->getRawArchiveLocation() == archiveLocation)
        {
            files.reserve(archivePtr->getFiles().size());
            for (auto& file : archivePtr->getFiles())
            {
                files.push_back(file.first);
            }
            break;
        }
    }
    return files;
}

std::string DecryptFileUtilsImpl::fullPathInArchives(std::string_view fn, int* archiveInfoIndex) const
{
    std::lock_guard<std::recursive_mutex> lock(m_archivesLock);

    if (archiveInfoIndex)
        *archiveInfoIndex = -1;

    if (fn.empty())
        return "";

    // 尝试裁掉前缀。
    if (fn.size() >= 2 && (fn.starts_with("./") || fn.starts_with(".\\")))
    {
        fn = fn.substr(2, fn.size() - 2);
    }

    if (fn.empty())
        return "";

    auto archiveCount = m_archives.size();
    if (archiveCount <= 0)
        return "";

    std::string filename;
    filename.reserve(fn.size());

    char c            = 0;
    int separator_num = 0;
    for (std::size_t i = 0; i < fn.size(); ++i)
    {
        c = fn[i];
        if (c == '\\')
            c = '/';

        if (c == '/')
        {
            if (separator_num == 0)
            {
                separator_num++;
                filename.push_back(c);
            }
        }
        else
        {
            separator_num = 0;
            filename.push_back(c);
        }
    }

    std::string temp;
    for (std::size_t i = 0; i < archiveCount; ++i)
    {
        temp           = filename;
        auto& archives = m_archives[i];
        if (archives->contains(temp))
        {
            if (archiveInfoIndex)
                *archiveInfoIndex = i;
            return temp;
        }

        for (const auto& searchs : _originalSearchPaths)
        {
            if (!searchs.empty() && searchs.back() == '/')
            {
                temp = searchs + std::string(fn);
            }
            else
            {
                temp = searchs + "/" + std::string(fn);
            }
            if (archives->contains(temp))
            {
                if (archiveInfoIndex)
                    *archiveInfoIndex = i;
                return temp;
            }
        }
    }

    return "";
}

std::unique_ptr<ax::IFileStream> DecryptFileUtilsImpl::openFileStream(std::string_view filePath,
                                                                      ax::IFileStream::Mode mode) const
{
    auto fs = Base::openFileStream(filePath, mode);
    if (fs)
    {
        return fs;
    }

    if (mode != ax::IFileStream::Mode::READ)
        return nullptr;

    int archiveInfoIndex = 0;
    auto fullfilename    = fullPathInArchives(filePath, &archiveInfoIndex);
    if (archiveInfoIndex < 0 || archiveInfoIndex >= m_archives.size())
        return nullptr;

    std::lock_guard<std::recursive_mutex> lock(m_archivesLock);

    auto& archive = m_archives[archiveInfoIndex];
    return archive->openFileStream(fullfilename, mode);
}

ax::FileUtils::Status DecryptFileUtilsImpl::getContents(std::string_view filename, ax::ResizableBuffer* buffer) const
{
    auto bak = isPopupNotify();
    ((Base*)this)->setPopupNotify(false);
    auto status = Base::getContents(filename, buffer);
    ((Base*)this)->setPopupNotify(bak);

    if (status == ax::FileUtils::Status::OK)
        return status;

    int archiveInfoIndex = 0;
    auto fullfilename    = fullPathInArchives(filename, &archiveInfoIndex);
    if (archiveInfoIndex < 0 || archiveInfoIndex >= m_archives.size())
        return Status::NotExists;

    std::lock_guard<std::recursive_mutex> lock(m_archivesLock);

    auto& archive = m_archives[archiveInfoIndex];
    return archive->getContents(fullfilename, buffer);
}

bool DecryptFileUtilsImpl::isFileExist(std::string_view s) const
{
    return Base::isFileExist(s) || !fullPathInArchives(s).empty();
}

std::string DecryptFileUtilsImpl::fullPathForFilename(std::string_view f) const
{
    if (f.empty())
        return {};
    auto bak = isPopupNotify();
    ((Base*)this)->setPopupNotify(false);
    auto s = Base::fullPathForFilename(f);
    if (s.empty())
    {
        s = fullPathInArchives(f);
    }
    ((Base*)this)->setPopupNotify(bak);
    return s;
}

#endif
