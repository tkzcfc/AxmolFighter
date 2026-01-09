#include "native_utils.h"

#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32
#    include <windows.h>
#    include "ntcvt/ntcvt.hpp"
#endif  // AX_TARGET_PLATFORM == AX_PLATFORM_WIN32

#if AX_TARGET_PLATFORM == AX_PLATFORM_LINUX
#    include <unistd.h>
#    include <stdio.h>
#elif AX_TARGET_PLATFORM == AX_PLATFORM_MAC
#    include <mach-o/dyld.h>
#endif

namespace native_utils
{

#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32
std::vector<std::string> get_command_line()
{
    std::vector<std::string> args;
    int argc;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);

    if (argv)
    {
        for (int i = 1; i < argc; i++)
        {
            args.push_back(ntcvt::from_chars(argv[i]));
        }
        LocalFree(argv);
    }
    return args;
}
#else
#    if AX_TARGET_PLATFORM != AX_PLATFORM_MAC
std::vector<std::string> get_command_line()
{
    std::vector<std::string> args;
    return args;
}
#    endif  // AX_TARGET_PLATFORM != AX_PLATFORM_MAC
#endif      // AX_TARGET_PLATFORM == AX_PLATFORM_WIN32

void set_clipboard_string(std::string data)
{
#ifdef AX_PLATFORM_PC
    auto window = static_cast<ax::RenderViewImpl*>(ax::Director::getInstance()->getRenderView())->getWindow();
    glfwSetClipboardString(window, data.c_str());
#endif
}

std::string get_clipboard_string()
{
#ifdef AX_PLATFORM_PC
    auto window = static_cast<ax::RenderViewImpl*>(ax::Director::getInstance()->getRenderView())->getWindow();
    return glfwGetClipboardString(window);
#else
    return "";
#endif
}

std::string get_executable_path()
{
    constexpr size_t max_path_length = 1024;
#if AX_TARGET_PLATFORM == AX_PLATFORM_LINUX
    char buffer[max_path_length];
    int buffer_size = sizeof(buffer);
    ssize_t len     = readlink("/proc/self/exe", buffer, buffer_size - 1);
    if (len == -1)
    {
        return "";
    }
    buffer[len] = '\0';
    return std::string(buffer);
#elif AX_TARGET_PLATFORM == AX_PLATFORM_MAC
    char buffer[max_path_length];
    int buffer_size = sizeof(buffer);
    if (_NSGetExecutablePath(buffer, &buffer_size) == 0)
    {
        return std::string(buffer, buffer_size);
    }
#elif AX_TARGET_PLATFORM == AX_PLATFORM_WIN32
    wchar_t buffer[max_path_length];
    int buffer_size = sizeof(buffer) / sizeof(wchar_t);
    DWORD size      = GetModuleFileName(NULL, buffer, buffer_size);
    if (size > 0)
    {
        return ntcvt::from_chars(std::wstring_view(buffer, size));
    }
#endif
    return "";
}

}  // namespace native_utils
