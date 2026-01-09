#include "game_utils.h"
#include "unzip/unzip.h"

using namespace ax;

namespace game_utils
{
bool unzip_file(const char* zipFile,
                std::string dstDir,
                const char* password,
                const std::function<void(float)>& percentCallback)
{
    constexpr static int BUFFER_SIZE  = 8192;
    constexpr static int MAX_FILENAME = 512;

    unzFile zipfile = unzOpen(zipFile);
    if (!zipfile)
    {
        AXLOG("can not open downloaded zip file %s", zipFile);
        return false;
    }
    // Get info about the zip file
    unz_global_info global_info;
    if (unzGetGlobalInfo(zipfile, &global_info) != UNZ_OK)
    {
        AXLOG("can not read file global info of %s", zipFile);
        unzClose(zipfile);
        return false;
    }
    // Buffer to hold data read from the zip file
    char readBuffer[BUFFER_SIZE];
    AXLOG("start uncompressing");
    // Loop to extract all files.
    uLong i;
    float lastPercent = -1.f;
    for (i = 0; i < global_info.number_entry; ++i)
    {
        // Get info about current file.
        unz_file_info fileInfo;
        char fileName[MAX_FILENAME];
        if (unzGetCurrentFileInfo(zipfile, &fileInfo, fileName, MAX_FILENAME, nullptr, 0, nullptr, 0) != UNZ_OK)
        {
            AXLOG("can not read file info");
            unzClose(zipfile);
            return false;
        }
        std::string path           = dstDir;
        const std::string fullPath = path + "/" + fileName;
        // Check if this entry is a directory or a file.
        const size_t filenameLength = strlen(fileName);
        if (fileName[filenameLength - 1] == '/')
        {
            // Entry is a directory, so create it.
            // If the directory exists, it will failed silently.
            if (!FileUtils::getInstance()->createDirectories(fullPath))
            {
                AXLOG("can not create directory %s", fullPath.c_str());
                unzClose(zipfile);
                return false;
            }
        }
        else
        {
            // Entry is a file, so extract it.
            // Open current file.
            if (unzOpenCurrentFile(zipfile) != UNZ_OK)
            {
                AXLOG("can not open file %s", fileName);
                unzClose(zipfile);
                return false;
            }
            // make sure the dir
            std::string fullName = fullPath;
            const size_t pos     = fullName.find_last_of('/');
            std::string dir      = fullName.substr(0, pos);
            if (!FileUtils::getInstance()->isDirectoryExist(dir))
            {
                FileUtils::getInstance()->createDirectories(dir);
            }
            // Create a file to store current file.
            std::string p = fullPath;
            FILE* out     = fopen(fullPath.c_str(), "wb");
            if (!out)
            {
                AXLOG("can not open destination file %s", fullPath.c_str());
                unzCloseCurrentFile(zipfile);
                unzClose(zipfile);
                return false;
            }

            // Write current file content to destinate file.
            int error = UNZ_OK;
            do
            {
                error = unzReadCurrentFile(zipfile, readBuffer, BUFFER_SIZE);
                if (error < 0)
                {
                    AXLOG("can not read zip file %s, error code is %d", fileName, error);
                    unzCloseCurrentFile(zipfile);
                    unzClose(zipfile);
                    return false;
                }

                if (error > 0)
                {
                    fwrite(readBuffer, error, 1, out);
                }
            } while (error > 0);
            fclose(out);
        }
        unzCloseCurrentFile(zipfile);
        // Goto next entry listed in the zip file.
        if ((i + 1) < global_info.number_entry)
        {
            if (unzGoToNextFile(zipfile) != UNZ_OK)
            {
                AXLOG("can not read next file");
                unzClose(zipfile);
                return false;
            }
        }

        float percent = (float)(i + 1) / (float)global_info.number_entry;
        if (int(percent * 100.0f) != int(lastPercent * 100.0f))
        {
            lastPercent = percent;
            if (percentCallback)
            {
                percentCallback(percent);
            }
        }
    }
    AXLOG("end uncompressing");
    unzClose(zipfile);
    return true;
}

int compress(const char* in_str, size_t in_len, std::string& out_str, int level)
{
    if (!in_str)
        return Z_DATA_ERROR;

    int ret, flush;
    unsigned have;
    z_stream strm;

    constexpr static int CHUNK = 16384;
    unsigned char out[CHUNK];

    /* allocate deflate state */
    strm.zalloc = Z_NULL;
    strm.zfree  = Z_NULL;
    strm.opaque = Z_NULL;
    ret         = deflateInit2(&strm, level, Z_DEFLATED, MAX_WBITS + 16, MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK)
        return ret;

    std::shared_ptr<z_stream> sp_strm(&strm, [](z_stream* strm) { (void)deflateEnd(strm); });
    const char* end = in_str + in_len;

    size_t pos_index = 0;
    size_t distance  = 0;
    /* compress until end of file */
    do
    {
        distance      = end - in_str;
        strm.avail_in = (distance >= CHUNK) ? CHUNK : distance;
        strm.next_in  = (Bytef*)in_str;

        // next pos
        in_str += strm.avail_in;
        flush = (in_str == end) ? Z_FINISH : Z_NO_FLUSH;

        /* run deflate() on input until output buffer not full, finish
          compression if all of source has been read in */
        do
        {
            strm.avail_out = CHUNK;
            strm.next_out  = out;
            ret            = deflate(&strm, flush); /* no bad return value */
            if (ret == Z_STREAM_ERROR)
                break;
            have = CHUNK - strm.avail_out;
            out_str.append((const char*)out, have);
        } while (strm.avail_out == 0);
        if (strm.avail_in != 0) /* all input will be used */
            break;

        /* done when last data in file processed */
    } while (flush != Z_FINISH);
    if (ret != Z_STREAM_END) /* stream will be complete */
        return Z_STREAM_ERROR;

    /* clean up and return */
    return Z_OK;
}

int decompress(const char* in_str, size_t in_len, std::string& out_str)
{
    if (!in_str)
        return Z_DATA_ERROR;

    int ret;
    unsigned have;
    z_stream strm;
    constexpr static int CHUNK = 16384;
    std::unique_ptr<unsigned char[]> outBuf(new unsigned char[CHUNK]);

    /* allocate inflate state */
    strm.zalloc   = Z_NULL;
    strm.zfree    = Z_NULL;
    strm.opaque   = Z_NULL;
    strm.avail_in = 0;
    strm.next_in  = Z_NULL;
    ret           = inflateInit2(&strm, MAX_WBITS + 16);
    if (ret != Z_OK)
        return ret;

    std::shared_ptr<z_stream> sp_strm(&strm, [](z_stream* strm) { (void)inflateEnd(strm); });

    const char* end = in_str + in_len;

    size_t pos_index = 0;
    size_t distance  = 0;

    int flush = 0;
    /* decompress until deflate stream ends or end of file */
    do
    {
        distance      = end - in_str;
        strm.avail_in = (distance >= CHUNK) ? CHUNK : distance;
        strm.next_in  = (Bytef*)in_str;

        // next pos
        in_str += strm.avail_in;
        flush = (in_str == end) ? Z_FINISH : Z_NO_FLUSH;

        /* run inflate() on input until output buffer not full */
        do
        {
            strm.avail_out = CHUNK;
            strm.next_out  = &outBuf[0];
            ret            = inflate(&strm, Z_NO_FLUSH);
            if (ret == Z_STREAM_ERROR) /* state not clobbered */
                break;
            switch (ret)
            {
            case Z_NEED_DICT:
                ret = Z_DATA_ERROR; /* and fall through */
            case Z_DATA_ERROR:
            case Z_MEM_ERROR:
                return ret;
            }
            have = CHUNK - strm.avail_out;
            out_str.append((const char*)&outBuf[0], have);
        } while (strm.avail_out == 0);

        /* done when inflate() says it's done */
    } while (flush != Z_FINISH);

    /* clean up and return */
    return ret == Z_STREAM_END ? Z_OK : Z_DATA_ERROR;
}

int64_t now_epoch_ms()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

int64_t now_epoch_10m()
{
    typedef std::chrono::duration<long long, std::ratio<1LL, 10000000LL>> duration_10m;
    auto val = std::chrono::steady_clock::now();
    return std::chrono::duration_cast<duration_10m>(val.time_since_epoch()).count();
}

int64_t get_utc_timestamp_seconds()
{
    return static_cast<int64_t>(std::chrono::system_clock::to_time_t(std::chrono::system_clock::now()));
}

int64_t get_utc_timestamp_milliseconds()
{
    return static_cast<int64_t>(
        std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch())
            .count());
}

}  // namespace game_utils
