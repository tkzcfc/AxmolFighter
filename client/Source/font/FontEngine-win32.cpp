#include "FontEngine.h"

#if AX_TARGET_PLATFORM == AX_PLATFORM_WIN32

#    include "ntcvt/ntcvt.hpp"
#    include <dwrite.h>
#    include <wrl/client.h>
using Microsoft::WRL::ComPtr;

#    pragma comment(lib, "dwrite.lib")

namespace ax
{

struct DWriteStyle
{
    explicit DWriteStyle(const FontStyle& pattern)
    {
        fWeight = (DWRITE_FONT_WEIGHT)pattern.weight();
        fWidth  = (DWRITE_FONT_STRETCH)pattern.width();
        switch (pattern.slant())
        {
        case FontStyle::kUpright_Slant:
            fSlant = DWRITE_FONT_STYLE_NORMAL;
            break;
        case FontStyle::kItalic_Slant:
            fSlant = DWRITE_FONT_STYLE_ITALIC;
            break;
        case FontStyle::kOblique_Slant:
            fSlant = DWRITE_FONT_STYLE_OBLIQUE;
            break;
        default:
            assert(false);
            break;
        }
    }
    DWRITE_FONT_WEIGHT fWeight;
    DWRITE_FONT_STRETCH fWidth;
    DWRITE_FONT_STYLE fSlant;
};

std::vector<std::string> FontEngine::lookupSystemFontsByCharacter(char32_t codepoint, FontStyle style, int numOfMax)
{
    std::vector<std::string> fontPaths;
    std::set<std::wstring> seenPaths;
    DWriteStyle dwStyle(style);

    ComPtr<IDWriteFactory> factory;
    DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &factory);

    ComPtr<IDWriteFontCollection> fontCollection;
    factory->GetSystemFontCollection(&fontCollection);

    UINT32 familyCount = fontCollection->GetFontFamilyCount();
    for (UINT32 i = 0; i < familyCount; ++i)
    {
        ComPtr<IDWriteFontFamily> family;
        fontCollection->GetFontFamily(i, &family);

        UINT32 fontCount = family->GetFontCount();
        for (UINT32 j = 0; j < fontCount; ++j)
        {
            ComPtr<IDWriteFont> font;
            family->GetFont(j, &font);

            bool ok = false;
            if (font->GetWeight() == dwStyle.fWeight)
            {
                ok = true;
            }

            if (!ok)
            {
                if (fontPaths.empty() && i == familyCount - 1 && j == fontCount - 1)
                {
                    ok = true;
                }
            }

            if (ok)
            {
                ComPtr<IDWriteFontFace> fontFace;
                font->CreateFontFace(&fontFace);

                UINT32 codePoint  = (UINT32)codepoint;  // char32_t to UINT32
                UINT16 glyphIndex = 0;
                fontFace->GetGlyphIndicesW(&codePoint, 1, &glyphIndex);
                if (glyphIndex != 0)
                {
                    UINT32 fileCount = 0;
                    fontFace->GetFiles(&fileCount, nullptr);

                    if (fileCount > 0)
                    {
                        std::vector<ComPtr<IDWriteFontFile>> files(fileCount);
                        fontFace->GetFiles(&fileCount, &files[0]);

                        const void* fontFileRefKey;
                        UINT32 fontFileRefKeySize;
                        files[0]->GetReferenceKey(&fontFileRefKey, &fontFileRefKeySize);

                        IDWriteFontFileLoader* loader = nullptr;
                        files[0]->GetLoader(&loader);

                        IDWriteLocalFontFileLoader* localLoader = nullptr;
                        loader->QueryInterface(&localLoader);

                        UINT32 filePathLen = 0;
                        localLoader->GetFilePathLengthFromKey(fontFileRefKey, fontFileRefKeySize, &filePathLen);

                        std::wstring wfilePath(filePathLen, L'\0');
                        localLoader->GetFilePathFromKey(fontFileRefKey, fontFileRefKeySize, &wfilePath[0],
                                                        filePathLen + 1);

                        if (seenPaths.count(wfilePath) == 0)
                        {
                            seenPaths.insert(wfilePath);

                            std::string filePath = ntcvt::from_chars(wfilePath);
                            if (filePath.size() > 0)
                            {
                                fontPaths.push_back(filePath);
                                if (numOfMax > 0 && fontPaths.size() >= numOfMax)
                                {
                                    return fontPaths;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return fontPaths;
}

std::string FontEngine::lookupSystemFontsByName(const std::string& familyName, FontStyle style)
{
    std::wstring wfamilyName = ntcvt::from_chars(familyName);
    DWriteStyle dwStyle(style);

    ComPtr<IDWriteFactory> factory;
    DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &factory);

    ComPtr<IDWriteFontCollection> fontCollection;
    factory->GetSystemFontCollection(&fontCollection);

    UINT32 index;
    BOOL exists;
    fontCollection->FindFamilyName(wfamilyName.c_str(), &index, &exists);
    if (!exists)
        return "";

    ComPtr<IDWriteFontFamily> fontFamily;
    fontCollection->GetFontFamily(index, &fontFamily);

    index = 0;
    for (int i = 0; i < fontFamily->GetFontCount(); ++i)
    {
        ComPtr<IDWriteFont> font;
        fontFamily->GetFont(i, &font);
        if (font->GetWeight() == dwStyle.fWeight)
        {
            index = i;
            break;
        }
    }

    ComPtr<IDWriteFont> font;
    fontFamily->GetFont(index, &font);

    ComPtr<IDWriteFontFace> fontFace;
    font->CreateFontFace(&fontFace);

    UINT32 fileCount = 0;
    fontFace->GetFiles(&fileCount, nullptr);
    if (fileCount == 0)
        return "";

    std::vector<ComPtr<IDWriteFontFile>> files(fileCount);
    fontFace->GetFiles(&fileCount, &files[0]);

    const void* key = nullptr;
    UINT32 keySize  = 0;
    files[0]->GetReferenceKey(&key, &keySize);

    ComPtr<IDWriteFontFileLoader> loader;
    files[0]->GetLoader(&loader);

    ComPtr<IDWriteLocalFontFileLoader> localLoader;
    loader.As(&localLoader);

    UINT32 pathLen = 0;
    localLoader->GetFilePathLengthFromKey(key, keySize, &pathLen);

    std::wstring path(pathLen, L'\0');
    localLoader->GetFilePathFromKey(key, keySize, &path[0], pathLen + 1);

    return ntcvt::from_chars(path);
}

}  // namespace ax

#endif
