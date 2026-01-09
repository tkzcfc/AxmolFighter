#if AX_TARGET_PLATFORM == AX_PLATFORM_IOS || AX_TARGET_PLATFORM == AX_PLATFORM_MAC
#    define COMPILE_DECYPT_FILE_UTILS_IMPL_CPP 1
#    include "decrypt_fileutils_impl.cpp"

#    define COMPILE_DECYPT_FILE_UTILS_CPP 1
#    include "decrypt_fileutils.cpp"

#endif
