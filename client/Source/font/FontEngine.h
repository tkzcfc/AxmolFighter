#pragma once

#include "axmol.h"

namespace ax
{

template <typename T>
static constexpr const T& font_style_pin(const T& x, const T& lo, const T& hi)
{
    return std::max(lo, std::min(x, hi));
}

class FontStyle
{
public:
    enum Weight
    {
        kInvisible_Weight  = 0,
        kThin_Weight       = 100,
        kExtraLight_Weight = 200,
        kLight_Weight      = 300,
        kNormal_Weight     = 400,
        kMedium_Weight     = 500,
        kSemiBold_Weight   = 600,
        kBold_Weight       = 700,
        kExtraBold_Weight  = 800,
        kBlack_Weight      = 900,
        kExtraBlack_Weight = 1000,
    };

    enum Width
    {
        kUltraCondensed_Width = 1,
        kExtraCondensed_Width = 2,
        kCondensed_Width      = 3,
        kSemiCondensed_Width  = 4,
        kNormal_Width         = 5,
        kSemiExpanded_Width   = 6,
        kExpanded_Width       = 7,
        kExtraExpanded_Width  = 8,
        kUltraExpanded_Width  = 9,
    };

    enum Slant
    {
        kUpright_Slant,
        kItalic_Slant,
        kOblique_Slant,
    };

    constexpr FontStyle(int weight, int width, Slant slant)
        : _value((font_style_pin<int>(weight, kInvisible_Weight, kExtraBlack_Weight)) +
                 (font_style_pin<int>(width, kUltraCondensed_Width, kUltraExpanded_Width) << 16) +
                 (font_style_pin<int>(slant, kUpright_Slant, kOblique_Slant) << 24))
    {}

    constexpr FontStyle() : FontStyle{kNormal_Weight, kNormal_Width, kUpright_Slant} {}

    bool operator==(const FontStyle& rhs) const { return _value == rhs._value; }

    int weight() const { return _value & 0xFFFF; }
    int width() const { return (_value >> 16) & 0xFF; }
    Slant slant() const { return (Slant)((_value >> 24) & 0xFF); }
    bool isItalic() const { return slant() != kUpright_Slant; }

    static constexpr FontStyle Normal() { return FontStyle(kNormal_Weight, kNormal_Width, kUpright_Slant); }
    static constexpr FontStyle Bold() { return FontStyle(kBold_Weight, kNormal_Width, kUpright_Slant); }
    static constexpr FontStyle Italic() { return FontStyle(kNormal_Weight, kNormal_Width, kItalic_Slant); }
    static constexpr FontStyle BoldItalic() { return FontStyle(kBold_Weight, kNormal_Width, kItalic_Slant); }

private:
    int32_t _value;
};

class FontEngine : public IFontEngine
{
    static FontEngine* _instance;

public:
    FontEngine();

    ~FontEngine();

    static FontEngine* getInstance();

    static void destroy();

    static void setFontEngine();

    bool loadSystemFont(const std::string& familyName, FontStyle style);

    bool loadFont(const std::string& fontPath);

    bool isLoadedFont(std::string_view fontPath) const;

    void clearLoadedFonts();

    std::vector<std::string> lookupSystemFontsByCharacter(char32_t codepoint, FontStyle style, int numOfMax);

    std::string lookupSystemFontsByName(const std::string& familyName, FontStyle style);

    bool isAutoMatchSystemFontsByCharacter() const;

    void setAutoMatchSystemFontsByCharacter(bool autoMatch);

    void setDefaultFontStyle(const FontStyle& style);

    const FontStyle& getDefaultFontStyle() const;

public:
    virtual FontFaceInfo* lookupFontFaceForCodepoint(char32_t charCode) override;

private:
    FontFaceInfo* lookupFontFaceForCodepointImpl(char32_t charCode);

    FontFaceInfo* createFontFaceInfo(const std::string& fontPath, long index = 0);

    void freeFontFaceInfo(FontFaceInfo* faceInfo);

private:
    std::vector<FontFaceInfo*> _fonts;
    std::unordered_map<char32_t, FontFaceInfo*> _fontMap;
    bool _autoMatchSystemFontsByCharacter;
    FontStyle _defaultFontStyle;
    EventListenerCustom* _resetDirectorListener;
};

}  // namespace ax
