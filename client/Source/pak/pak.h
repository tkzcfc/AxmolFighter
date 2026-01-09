#pragma once

#include "axmol.h"

namespace pak
{
struct FileInfo
{
    uint64_t offset;
    uint32_t length;  // file max size 3GB
    uint8_t compressionType;
};

class PakArchive
{
public:
    PakArchive();

    virtual ~PakArchive();

    bool init(const std::string& archiveLocation, const std::string& mntpoint, bool keepFd);

    std::unique_ptr<ax::IFileStream> openFileStream(const std::string& filename, ax::IFileStream::Mode mode) const;

    ax::FileUtils::Status getContents(const std::string& filename, ax::ResizableBuffer* buffer) const;

    bool verifyCRC32();

    template <typename T, typename Enable = std::enable_if_t<ax::is_resizable_container_v<T>>>
    ax::FileUtils::Status getContents(const std::string& filename, T* buffer) const
    {
        ax::ResizableBufferAdapter<T> buf(buffer);
        return getContents(filename, static_cast<ax::ResizableBuffer*>(&buf));
    }

    bool contains(const std::string& filename) const { return m_files.find(filename) != m_files.end(); }

    uint32_t getVersion() const { return m_version; }

    uint32_t getDataSecret() const { return m_dataSecret; }

    uint32_t getCrc32Value() const { return m_crc32Value; }

    bool isMounted() const { return m_isMounted; }

    const std::string& getMntpoint() const { return m_mntpoint; }

    const std::string& getRawArchiveLocation() const { return m_rawArchiveLocation; }

    const std::string& getArchiveLocation() const { return m_archiveLocation; }

    const std::unordered_map<std::string, FileInfo>& getFiles() const { return m_files; }

    FileInfo* getFileInfo(const std::string& filename)
    {
        auto it = m_files.find(filename);
        if (it != m_files.end())
        {
            return &it->second;
        }
        return nullptr;
    }

    std::vector<std::string> getFilesList() const
    {
        std::vector<std::string> filesList;
        filesList.reserve(m_files.size());
        for (const auto& file : m_files)
        {
            filesList.push_back(file.first);
        }
        return filesList;
    }

protected:
    uint32_t m_version;
    uint32_t m_dataSecret;
    uint32_t m_crc32Value;
    uint64_t m_indexOffset;
    uint64_t m_packedFileSize;
    std::string m_rawArchiveLocation;
    std::string m_archiveLocation;
    std::string m_mntpoint;
    std::unordered_map<std::string, FileInfo> m_files;
    std::unique_ptr<ax::IFileStream> m_fileStreamPtr;
    mutable std::mutex m_fileStreamLock;
    bool m_isMounted;
};

}  // namespace pak
