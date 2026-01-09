#pragma once

#include "pak.h"

namespace pak
{
class PakFileStream : public ax::IFileStream
{
public:
    PakFileStream(ax::IFileStream* fs, FileInfo fileInfo, ax::Data* dataPtr);

    virtual ~PakFileStream();

    /**
     *  Open a file
     *  @param path file to open
     *  @param mode File open mode, being READ, WRITE, APPEND
     *  @return true if successful, false if not
     */
    virtual bool open(std::string_view path, ax::IFileStream::Mode mode) override;

    /**
     *  Close a file stream
     *  @return 0 if successful, -1 if not
     */
    virtual int close() override;

    /**
     *  Seek to position in a file stream
     *  @param offset how many bytes to move within the stream
     *  @param origin SEEK_SET, SEEK_CUR, SEEK_END
     *  @return offset from file begining
     */
    virtual int64_t seek(int64_t offset, int origin) const override;

    /**
     *  Read data from file stream
     *  @param buf pointer to data
     *  @param size the amount of data to read in bytes
     *  @return amount of data read successfully, -1 if error
     */
    virtual int read(void* buf, unsigned int size) const override;

    /**
     *  Write data to file stream
     *  @param buf pointer to data
     *  @param size the amount of data to write in bytes
     *  @return amount of data written successfully, -1 if error
     */
    virtual int write(const void* buf, unsigned int size) const override;

    /**
     *  Get the current position in the file stream
     *  @return current position, -1 if error
     */
    virtual int64_t tell() const override;

    /**
     *  Get the size of the file stream
     *  @return stream size, -1 if error (Mode::WRITE and Mode::APPEND may return -1)
     */
    virtual int64_t size() const override;

    /*
     * Resize file
     */
    virtual bool resize(int64_t /*size*/) const override;

    /**
     *  Get status of file stream
     *  @return true if open, false if closed
     */
    virtual bool isOpen() const override;

protected:
    FileInfo m_fileInfo;
    ax::IFileStream* m_fs;
    ax::Data* m_dataPtr;
    mutable size_t m_offset;
};
}  // namespace pak
