#include "FontEngine.h"

#if (AX_TARGET_PLATFORM != AX_PLATFORM_ANDROID && AX_TARGET_PLATFORM != AX_PLATFORM_WIN32 && \
     AX_TARGET_PLATFORM != AX_PLATFORM_IOS && AX_TARGET_PLATFORM != AX_PLATFORM_MAC)

namespace ax
{

std::vector<std::string> FontEngine::lookupSystemFontsByCharacter(char32_t codepoint, FontStyle style, int numOfMax)
{
    return {};
}

std::string FontEngine::lookupSystemFontsByName(const std::string& familyName, FontStyle style)
{
    return "";
}

}  // namespace ax

#endif
