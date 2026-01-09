#include "decrypt_fileutils.h"
#include "base/Utils.h"
#include "algorithms/xxtea.h"

#if AX_TARGET_PLATFORM != AX_PLATFORM_IOS && AX_TARGET_PLATFORM != AX_PLATFORM_MAC
#    define COMPILE_DECYPT_FILE_UTILS_CPP 1
#endif

#if COMPILE_DECYPT_FILE_UTILS_CPP
#    include "decrypt_fileutils_impl.h"

// set_yasio_service_opt_callback
// c2V0X3lhc2lvX3NlcnZpY2Vfb3B0X2NhbGxiYWNr
inline std::string generate_a()
{
    constexpr std::array<uint8_t, 40> encrypted = {0x36, 0x67, 0x03, 0x65, 0x0D, 0x66, 0x39, 0x3D, 0x36, 0x67,
                                                   0x39, 0x23, 0x0D, 0x66, 0x1B, 0x39, 0x36, 0x3B, 0x0F, 0x25,
                                                   0x0C, 0x67, 0x03, 0x33, 0x37, 0x66, 0x17, 0x65, 0x0D, 0x67,
                                                   0x1B, 0x3D, 0x37, 0x12, 0x2D, 0x3C, 0x0C, 0x02, 0x1B, 0x27};

    std::string result;
    result.reserve(encrypted.size());

    for (uint8_t c : encrypted)
    {
        result += static_cast<char>(c ^ 0x55);
    }

    return result;
}

// GetCurrentCannonAngle
// R2V0Q3VycmVudENhbm5vbkFuZ2xl
inline std::string generate_b()
{
    constexpr std::array<uint8_t, 28> encrypted = {0xB0, 0xD0, 0xB4, 0xD2, 0xB3, 0xD1, 0xB4, 0x9B, 0x81, 0x8F,
                                                   0xB4, 0x97, 0x86, 0xA7, 0xAC, 0x8A, 0x80, 0x8F, 0xD7, 0x94,
                                                   0x80, 0x89, 0xA4, 0x97, 0xB8, 0xD0, 0x9A, 0x8E};

    std::string result;
    result.reserve(encrypted.size());

    for (uint8_t c : encrypted)
    {
        result += static_cast<char>(c ^ 0xE2);
    }

    return result;
}

void DecryptFileUtils::enable()
{
    static yasio::byte_buffer buffera = ax::utils::base64Decode(generate_a());
    static yasio::byte_buffer bufferb = ax::utils::base64Decode(generate_b());

    auto fu = new DecryptFileUtilsImpl();
    if (!fu->init())
    {
        delete fu;
    }
    else
    {
        ax::FileUtils::setDelegate(fu);
        ax::FileUtils::getInstance()->setFileDataDecoder([](ax::Data& data) {
            if (!data.isNull())
            {
                bool isEncoder     = false;
                unsigned char* buf = data.getBytes();
                ssize_t size       = data.getSize();
                ssize_t len        = buffera.size();
                if (size <= len)
                {
                    return;
                }

                for (int i = 0; i < len; ++i)
                {
                    isEncoder = buf[i] == buffera[i];
                    if (!isEncoder)
                    {
                        break;
                    }
                }

                if (isEncoder)
                {
                    xxtea_long newLen = 0;
                    unsigned char* buffer =
                        xxtea_decrypt(buf + len, (xxtea_long)(size - len), (unsigned char*)bufferb.data(),
                                      (xxtea_long)bufferb.size(), &newLen);
                    data.clear();
                    data.fastSet(buffer, newLen);
                }
            }
        });
    }
}

bool DecryptFileUtils::mount(const std::string& archiveLocation,
                             const std::string& mntpoint,
                             const bool front,
                             bool keepFd)
{
    auto impl = dynamic_cast<DecryptFileUtilsImpl*>(ax::FileUtils::getInstance());
    return impl && impl->mount(archiveLocation, mntpoint, front, keepFd);
}

void DecryptFileUtils::unmount(const std::string& archiveLocation)
{
    auto impl = dynamic_cast<DecryptFileUtilsImpl*>(ax::FileUtils::getInstance());
    if (impl)
    {
        impl->unmount(archiveLocation);
    }
}

std::vector<std::string> DecryptFileUtils::getArchiveFiles(const std::string& archiveLocation)
{
    auto impl = dynamic_cast<DecryptFileUtilsImpl*>(ax::FileUtils::getInstance());
    if (impl)
    {
        return impl->getArchiveFiles(archiveLocation);
    }
    return std::vector<std::string>();
}

#endif
