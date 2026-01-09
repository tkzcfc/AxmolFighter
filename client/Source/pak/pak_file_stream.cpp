#include "pak_file_stream.h"
#include <algorithm>
namespace pak
{
PakFileStream::PakFileStream(ax::IFileStream* fs, FileInfo fileInfo, ax::Data* dataPtr)
    : m_fs(fs), m_dataPtr(dataPtr), m_fileInfo(fileInfo), m_offset(0)
{}

PakFileStream::~PakFileStream()
{
    close();
}

bool PakFileStream::open(std::string_view path, IFileStream::Mode mode)
{
    return true;
}

int PakFileStream::close()
{
    if (m_dataPtr)
    {
        delete m_dataPtr;
        m_dataPtr = nullptr;
    }
    if (m_fs)
    {
        m_fs->close();
        m_fs = nullptr;
    }
    return 0;
}

int64_t PakFileStream::seek(int64_t offset, int origin) const
{
    if (origin == SEEK_CUR)
    {
        m_offset += static_cast<size_t>(offset);
    }
    else if (origin == SEEK_END)
    {
        if (static_cast<size_t>(m_fileInfo.length) < static_cast<size_t>(offset))
            return 0;

        m_offset = static_cast<size_t>(m_fileInfo.length) - static_cast<size_t>(offset);
    }
    else if (origin == SEEK_SET)
    {
        m_offset = static_cast<size_t>(offset);
    }

    return m_offset;
}

int PakFileStream::read(void* buf, unsigned int size) const
{
    if (size == 0 || m_offset >= static_cast<size_t>(m_fileInfo.length))
        return 0;

    size_t readLen = std::min(static_cast<size_t>(size), static_cast<size_t>(m_fileInfo.length) - m_offset);
    if (readLen > 0)
    {
        if (m_dataPtr)
        {
            ::memcpy(buf, m_dataPtr->getBytes() + m_offset, readLen);
            m_offset += readLen;
            return static_cast<int>(readLen);
        }
        else
        {
            if (m_fs)
            {
                m_fs->seek(m_offset + static_cast<size_t>(m_fileInfo.offset), SEEK_SET);
                auto result = static_cast<size_t>(m_fs->read(buf, static_cast<unsigned int>(readLen)));
                assert(readLen == result);
                m_offset += result;
                return static_cast<int>(result);
            }
            else
            {
                return 0;
            }
        }
    }
    return -1;
}

int PakFileStream::write(const void* buf, unsigned int size) const
{
    return -1;
}

int64_t PakFileStream::tell() const
{
    if (m_offset > static_cast<size_t>(m_fileInfo.length))
        return -1;
    return m_offset;
}

int64_t PakFileStream::size() const
{
    return static_cast<int64_t>(m_fileInfo.length);
}

bool PakFileStream::resize(int64_t /*size*/) const
{
    errno = ENOTSUP;
    return false;
}

bool PakFileStream::isOpen() const
{
    return m_dataPtr != nullptr || m_fs != nullptr;
}

}  // namespace pak
