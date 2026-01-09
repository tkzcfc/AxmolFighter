#include "FontEngine.h"
#include <freetype/freetype.h>

#if AX_TARGET_PLATFORM == AX_PLATFORM_IOS || AX_TARGET_PLATFORM == AX_PLATFORM_MAC
static const char* map_css_names(const char* name)
{
    static const struct
    {
        const char* fFrom;  // name the caller specified
        const char* fTo;    // "canonical" name we map to
    } gPairs[] = {{"sans-serif", "Helvetica"}, {"serif", "Times"}, {"monospace", "Courier"}};

    for (size_t i = 0; i < std::size(gPairs); i++)
    {
        if (strcmp(name, gPairs[i].fFrom) == 0)
        {
            return gPairs[i].fTo;
        }
    }
    return name;  // no change
}
#endif

namespace ax
{
FontEngine* FontEngine::_instance = nullptr;

FontEngine* FontEngine::getInstance()
{
    if (!_instance)
    {
        _instance = new FontEngine();
    }
    return _instance;
}

void FontEngine::destroy()
{
    FontFreeType::setFontEngine(nullptr);
    if (_instance)
    {
        delete _instance;
        _instance = nullptr;
    }
}

void FontEngine::setFontEngine()
{
    FontFreeType::setFontEngine(getInstance());
}

FontEngine::FontEngine() : _autoMatchSystemFontsByCharacter(true)
{
    _defaultFontStyle      = FontStyle::Normal();
    _resetDirectorListener = Director::getInstance()->getEventDispatcher()->addCustomEventListener(
        Director::EVENT_RESET, [this](EventCustom*) { clearLoadedFonts(); });
}

FontEngine::~FontEngine()
{
    Director::getInstance()->getEventDispatcher()->removeEventListener(_resetDirectorListener);
    clearLoadedFonts();
}

FontFaceInfo* FontEngine::lookupFontFaceForCodepoint(char32_t charCode)
{
    auto it = _fontMap.find(charCode);
    if (it != _fontMap.end())
    {
        return it->second;
    }

    auto faceInfo      = lookupFontFaceForCodepointImpl(charCode);
    _fontMap[charCode] = faceInfo;
    return faceInfo;
}

bool FontEngine::loadSystemFont(const std::string& familyName, FontStyle fontStyle)
{
#if AX_TARGET_PLATFORM == AX_PLATFORM_IOS || AX_TARGET_PLATFORM == AX_PLATFORM_MAC
    auto fontPath = lookupSystemFontsByName(map_css_names(familyName.c_str()), fontStyle);
#else
    auto fontPath = lookupSystemFontsByName(familyName, fontStyle);
#endif

    if (fontPath.empty())
    {
        AXLOGW("No system font found: {}", familyName);
        return false;
    }

    if (isLoadedFont(fontPath))
    {
        AXLOGI("System font already loaded({}): {}", familyName, fontPath);
        return true;
    }

    FontFaceInfo* font = createFontFaceInfo(fontPath);
    if (font)
    {
        AXLOGI("Loaded system font({}): {}", familyName, fontPath);
        _fonts.push_back(font);
        return true;
    }
    else
    {
        AXLOGW("Failed to load system font({}): {}", familyName, fontPath);
        return false;
    }
}

bool FontEngine::loadFont(const std::string& fontPath)
{
    if (isLoadedFont(fontPath))
    {
        AXLOGI("Font already loaded: {}", fontPath);
        return true;
    }
    FontFaceInfo* font = createFontFaceInfo(fontPath);
    if (font)
    {
        AXLOGI("Loaded font: {}", fontPath);
        _fonts.push_back(font);
        return true;
    }
    AXLOGW("Failed to load font: {}", fontPath);
    return false;
}

bool FontEngine::isLoadedFont(std::string_view fontPath) const
{
    for (auto font : _fonts)
    {
        if (font->path == fontPath)
            return true;
    }
    return false;
}

void FontEngine::clearLoadedFonts()
{
    for (auto font : _fonts)
    {
        freeFontFaceInfo(font);
    }
    _fonts.clear();
    _fontMap.clear();
}

FontFaceInfo* FontEngine::lookupFontFaceForCodepointImpl(char32_t charCode)
{
    for (auto font : _fonts)
    {
        FT_UInt glyphIndex = FT_Get_Char_Index(font->face, static_cast<FT_ULong>(charCode));
        if (glyphIndex != 0)
        {
            font->currentGlyphIndex = glyphIndex;
            // AXLOGI("[A]use fallback font: {}   glyphIndex;{}", font->path, glyphIndex);
            return font;
        }
    }

    if (!_autoMatchSystemFontsByCharacter)
        return nullptr;

    auto fontPaths = lookupSystemFontsByCharacter(charCode, _defaultFontStyle, 1);
    if (fontPaths.empty())
        return nullptr;

    for (auto& fontPath : fontPaths)
    {
        FontFaceInfo* font = createFontFaceInfo(fontPath);
        if (font)
        {
            FT_UInt glyphIndex = FT_Get_Char_Index(font->face, static_cast<FT_ULong>(charCode));
            if (glyphIndex != 0)
            {
                font->currentGlyphIndex = glyphIndex;
                _fonts.push_back(font);
                // AXLOGI("[B]use fallback font: {}   glyphIndex;{}", font->path, glyphIndex);
                return font;
            }
            else
            {
                freeFontFaceInfo(font);
            }
        }
    }

    return nullptr;
}

FontFaceInfo* FontEngine::createFontFaceInfo(const std::string& fontPath, long index /* = 0*/)
{
    if (fontPath.empty())
        return nullptr;

    auto fontPathLen  = fontPath.size();
    char* fontPathPtr = new char[fontPathLen + 1];
    ::memcpy(fontPathPtr, fontPath.data(), fontPathLen);
    fontPathPtr[fontPathLen] = '\0';

    auto* info  = new FontFaceInfo();
    info->path  = std::string_view(fontPathPtr, fontPathLen);
    info->index = index;

    FT_Face face;
    if (FT_New_Face(FontFreeType::getFTLibrary(), info->path.data(), (FT_Long)index, &face) == 0)
    {
        info->face              = face;
        info->family            = face->family_name ? face->family_name : "";
        info->currentGlyphIndex = 0;
    }
    else
    {
        freeFontFaceInfo(info);
        return nullptr;
    }
    return info;
}

void FontEngine::freeFontFaceInfo(FontFaceInfo* faceInfo)
{
    if (faceInfo)
    {
        FT_Done_Face(faceInfo->face);
        delete[] faceInfo->path.data();
        delete faceInfo;
    }
}

bool FontEngine::isAutoMatchSystemFontsByCharacter() const
{
    return _autoMatchSystemFontsByCharacter;
}

void FontEngine::setAutoMatchSystemFontsByCharacter(bool autoMatch)
{
    _autoMatchSystemFontsByCharacter = autoMatch;
}

void FontEngine::setDefaultFontStyle(const FontStyle& style)
{
    _defaultFontStyle = style;
}

const FontStyle& FontEngine::getDefaultFontStyle() const
{
    return _defaultFontStyle;
}

}  // namespace ax
