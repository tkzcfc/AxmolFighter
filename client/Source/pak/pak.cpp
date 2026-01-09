#include "pak.h"
#include <zlib.h>
#include "utils/game_utils.h"
#include "pak_file_stream.h"

inline uint32_t readUint32InBigEndian(void* memory)
{
    uint8_t* p = (uint8_t*)memory;
    return (((uint32_t)p[0]) << 24) | (((uint32_t)p[1]) << 16) | (((uint32_t)p[2]) << 8) | (((uint32_t)p[3]));
}

inline uint64_t readUint64InBigEndian(void* memory)
{
    uint8_t* p = (uint8_t*)memory;
    return (((uint64_t)p[0]) << 56) | (((uint64_t)p[1]) << 48) | (((uint64_t)p[2]) << 40) | (((uint64_t)p[3]) << 32) |
           (((uint64_t)p[4]) << 24) | (((uint64_t)p[5]) << 16) | (((uint64_t)p[6]) << 8) | (((uint64_t)p[7]));
}

inline bool isBigEndian()
{
    union
    {
        uint32_t i;
        char c[4];
    } bint = {0x01000000};

    return bint.c[0] == 1;
}

inline void xorContent(uint32_t s, char* buf, size_t len)
{
    if (s == 0)
        return;
    auto p = reinterpret_cast<unsigned char*>(&s);

    char sBuf[4] = {0};
    if (isBigEndian())
    {
        sBuf[0] = p[3];
        sBuf[1] = p[2];
        sBuf[2] = p[1];
        sBuf[3] = p[0];
    }
    else
    {
        sBuf[0] = p[0];
        sBuf[1] = p[1];
        sBuf[2] = p[2];
        sBuf[3] = p[3];
    }

    for (size_t i = 0; i < len; ++i)
    {
        buf[i] ^= sBuf[i % sizeof(s)];
    }
}

static const char signature[] = {'P', 'A', 'C', 'K'};
constexpr int HEADER_LENGTH   = 28;

namespace pak
{
PakArchive::PakArchive()
    : m_dataSecret(0), m_isMounted(false), m_version(0), m_crc32Value(0), m_indexOffset(0), m_packedFileSize(0)
{}

PakArchive::~PakArchive() {}

bool PakArchive::init(const std::string& archiveLocation, const std::string& mntpoint, bool keepFd)
{
    std::string filePath = ax::FileUtils::getInstance()->fullPathForFilename(archiveLocation);

    auto fp = ax::FileUtils::getInstance()->openFileStream(filePath, ax::IFileStream::Mode::READ);
    if (!fp || !fp->isOpen())
        return false;

    auto fileSize = fp->size();

    // 头部信息校验
    if (fileSize < HEADER_LENGTH)
    {
        AXLOGE("mount error: not a pack file");
        return false;
    }

    // 头部信息读取
    char headBuffer[HEADER_LENGTH];
    fp->seek(0, SEEK_SET);

    if (fp->read(headBuffer, HEADER_LENGTH) != HEADER_LENGTH)
    {
        AXLOGE("mount error: failed to read head data");
        return false;
    }

    // 头部信息校验
    if (memcmp(headBuffer, signature, sizeof(signature)) != 0)
    {
        AXLOGE("mount error: not a pack file");
        return false;
    }

    uint64_t offset = sizeof(signature);

    // version
    auto version = readUint32InBigEndian(&headBuffer[offset]);
    offset += 4;

    // 索引加密秘钥
    auto indexSecret = readUint32InBigEndian(&headBuffer[offset]);
    offset += 4;

    // 数据加密秘钥
    auto dataSecret = readUint32InBigEndian(&headBuffer[offset]);
    offset += 4;

    // 索引偏移
    auto indexOffset = readUint64InBigEndian(&headBuffer[offset]);
    offset += 8;

    // crc32校验码
    auto crc32Value = readUint32InBigEndian(&headBuffer[offset]);
    offset += 4;

    if (version != 0 && version != 1)
    {
        AXLOGE("mount error: unsupported version {}", version);
        return false;
    }

    // 重置偏移值
    offset           = indexOffset;
    m_packedFileSize = fileSize;

    // 索引下标越界
    if (m_packedFileSize < indexOffset)
    {
        AXLOGE("mount error: index out of bounds");
        return false;
    }

    // 空文件
    if (m_packedFileSize == indexOffset)
    {
        AXLOGE("mount error: empty file");
        return true;
    }

    // 分配索引区域内存
    auto indexBufLength = m_packedFileSize - indexOffset;
    std::unique_ptr<char[]> indexBuffer(new char[indexBufLength]);
    if (!indexBuffer)
    {
        AXLOGE("mount error: out of memory");
        return false;
    }

    memset(&indexBuffer[0], 0x0c, indexBufLength);

    // 读取索引数据
    if (fp->seek(indexOffset, SEEK_SET) != indexOffset)
    {
        int errsv = errno;
        AXLOGE("mount error: read index data failed, errno {}", errsv);
        return false;
    }
    if (fp->read(&indexBuffer[0], static_cast<unsigned int>(indexBufLength)) != indexBufLength)
    {
        AXLOGE("mount error: read index data failed");
        return false;
    }

    FileInfo fileInfo;
    std::string filename;

#define CHECK_SIZE(num)                         \
    if (offset + num > indexBufLength)          \
    {                                           \
        AXLOGE("mount error: not a pack file"); \
        return false;                           \
    }

    // 读取索引数据
    offset = 0;
    while (offset < indexBufLength)
    {
        CHECK_SIZE(8);
        fileInfo.offset = readUint64InBigEndian(&indexBuffer[offset]);
        offset += 8;

        CHECK_SIZE(4);
        fileInfo.length = readUint32InBigEndian(&indexBuffer[offset]);
        offset += 4;

        CHECK_SIZE(1);
        auto nameLength = (uint8_t)indexBuffer[offset];
        offset += 1;

        CHECK_SIZE(1);
        fileInfo.compressionType = (uint8_t)(indexBuffer[offset]);
        offset += 1;

        CHECK_SIZE(nameLength);
        xorContent(indexSecret, &indexBuffer[offset], nameLength);
        filename = mntpoint;
        filename.append(&indexBuffer[offset], nameLength);
        offset += nameLength;

        m_files.insert(std::make_pair(filename, fileInfo));
    }
#undef CHECK_SIZE

    m_rawArchiveLocation = archiveLocation;
    m_archiveLocation    = filePath;
    m_version            = version;
    m_dataSecret         = dataSecret;
    m_mntpoint           = mntpoint;
    m_isMounted          = true;
    m_crc32Value         = crc32Value;
    m_indexOffset        = indexOffset;
    if (keepFd)
    {
        m_fileStreamPtr = std::move(fp);
    }
    return true;
}

std::unique_ptr<ax::IFileStream> PakArchive::openFileStream(const std::string& filename,
                                                            ax::IFileStream::Mode mode) const
{
    if (mode != ax::IFileStream::Mode::READ)
        return nullptr;

    auto it = m_files.find(filename);
    if (it == m_files.end())
        return nullptr;
    auto fileInfo = it->second;
    if (fileInfo.length == 0)
    {
        return nullptr;
    }

    if (fileInfo.compressionType == 0 && m_dataSecret == 0)
    {
        auto fs = ax::FileUtils::getInstance()->openFileStream(m_archiveLocation, ax::IFileStream::Mode::READ);
        if (fs == nullptr || !fs->isOpen())
            return nullptr;

        return std::make_unique<PakFileStream>(fs.release(), fileInfo, nullptr);
    }
    else
    {
        auto d = new ax::Data();
        if (d == nullptr)
            return nullptr;

        ax::ResizableBufferAdapter<ax::Data> buf(d);
        if (getContents(filename, static_cast<ax::ResizableBuffer*>(&buf)) == ax::FileUtils::Status::OK)
        {
            return std::make_unique<PakFileStream>(nullptr, fileInfo, d);
        }
        return nullptr;
    }
}

ax::FileUtils::Status PakArchive::getContents(const std::string& filename, ax::ResizableBuffer* buffer) const
{
    auto it = m_files.find(filename);
    if (it == m_files.end())
        return ax::FileUtils::Status::NotExists;

    auto length = it->second.length;
    if (it->second.offset + length > m_packedFileSize)
    {
        AXLOGE("read error: read data failed, file '{}' length out of bounds", it->first);
        return ax::FileUtils::Status::ReadFailed;
    }

    buffer->resize(length);

    if (m_fileStreamPtr)
    {
        std::lock_guard<std::mutex> lock(m_fileStreamLock);

        if (m_fileStreamPtr->seek(it->second.offset, SEEK_SET) != it->second.offset)
        {
            int errsv = errno;
            AXLOGE("read error: read data failed, errno {}", errsv);
            return ax::FileUtils::Status::ReadFailed;
        }

        if (m_fileStreamPtr->read(buffer->buffer(), length) != length)
        {
            AXLOGE("read error: read data failed");
            return ax::FileUtils::Status::ReadFailed;
        }
    }
    else
    {
        auto fp = ax::FileUtils::getInstance()->openFileStream(m_archiveLocation, ax::IFileStream::Mode::READ);
        if (fp == nullptr || !fp->isOpen())
            return ax::FileUtils::Status::ReadFailed;

        if (fp->seek(it->second.offset, SEEK_SET) != it->second.offset)
        {
            int errsv = errno;
            AXLOGE("read error: read data failed, errno {}", errsv);
            return ax::FileUtils::Status::ReadFailed;
        }

        if (fp->read(buffer->buffer(), length) != length)
        {
            AXLOGE("read error: read data failed");
            return ax::FileUtils::Status::ReadFailed;
        }
    }
    xorContent(m_dataSecret, (char*)buffer->buffer(), length);

    auto compressionType = it->second.compressionType;
    if (compressionType == 0)  // none
    {
        return ax::FileUtils::Status::OK;
    }
    else if (compressionType == 1)  // gzip
    {
        std::string plaintext;
        if (game_utils::decompress((char*)buffer->buffer(), length, plaintext) != 0)
        {
            AXLOGE("read error: file '{}' decompression failed", it->first);
            return ax::FileUtils::Status::ReadFailed;
        }

        buffer->resize(plaintext.length());
        ::memcpy(buffer->buffer(), plaintext.data(), plaintext.length());

        return ax::FileUtils::Status::OK;
    }

    // unsupport
    AXLOGE("read error: unsupported compression method({}), {}", compressionType, it->first);
    return ax::FileUtils::Status::ReadFailed;
}

bool PakArchive::verifyCRC32()
{
    if (!m_isMounted)
    {
        AXLOGE("verifyCRC32 error: archive not mounted");
        return false;
    }

    constexpr uint64_t BLOCK_SIZE = 1024 * 1024 * 1;  // 1MB
    std::unique_ptr<char[]> buffer(new char[BLOCK_SIZE]);
    if (!buffer)
    {
        AXLOGE("verifyCRC32 error: out of memory");
        return false;
    }

    uLong crc          = crc32(0L, Z_NULL, 0);
    uint64_t offset    = HEADER_LENGTH;
    uint64_t maxOffset = m_version == 0 ? m_indexOffset : m_packedFileSize;
    uint64_t readSize  = 0;

    if (m_fileStreamPtr)
    {
        std::lock_guard<std::mutex> lock(m_fileStreamLock);

        if (m_fileStreamPtr->seek(HEADER_LENGTH, SEEK_SET) != HEADER_LENGTH)
        {
            int errsv = errno;
            AXLOGE("verifyCRC32 error: seek failed, errno {}", errsv);
            return false;
        }

        do
        {
            readSize = MIN(BLOCK_SIZE, maxOffset - offset);
            if (m_fileStreamPtr->read(buffer.get(), static_cast<unsigned int>(readSize)) != static_cast<int>(readSize))
            {
                return false;
            }
            offset += readSize;

            crc = crc32(crc, (const Bytef*)buffer.get(), static_cast<unsigned int>(readSize));
        } while (offset < maxOffset);

        return crc == m_crc32Value;
    }
    else
    {
        auto fp = ax::FileUtils::getInstance()->openFileStream(m_archiveLocation, ax::IFileStream::Mode::READ);
        if (fp == nullptr || !fp->isOpen())
        {
            AXLOGE("mount error: file stream open failed");
            return false;
        }
        if (fp->seek(HEADER_LENGTH, SEEK_SET) != HEADER_LENGTH)
        {
            int errsv = errno;
            AXLOGE("verifyCRC32 error: seek failed, errno {}", errsv);
            return false;
        }

        do
        {
            readSize = MIN(BLOCK_SIZE, maxOffset - offset);
            if (fp->read(buffer.get(), static_cast<unsigned int>(readSize)) != static_cast<int>(readSize))
            {
                return false;
            }
            offset += readSize;

            crc = crc32(crc, (const Bytef*)buffer.get(), static_cast<unsigned int>(readSize));
        } while (offset < maxOffset);

        return crc == m_crc32Value;
    }
}
}  // namespace pak
