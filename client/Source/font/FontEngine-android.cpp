#include "FontEngine.h"
#include <freetype/freetype.h>

#if AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID

#    define ANDROID_NDK_FONT_API_EXISTS       29
#    define ANDROID_NDK_FONT_API_LOCALE_WORKS 30

#    include <android/api-level.h>
#    include <android/log.h>

#    if __ANDROID_API__ >= ANDROID_NDK_FONT_API_EXISTS
#        include <android/font.h>
#        include <android/font_matcher.h>
#        include <android/system_fonts.h>
#    else
#        include <dlfcn.h>

struct AFontMatcher;
struct ASystemFontIterator;
struct AFont;

typedef AFontMatcher* (*PFN_AFontMatcher_create)();
typedef void (*PFN_AFontMatcher_destroy)(AFontMatcher*);
typedef AFont* (*PFN_AFontMatcher_match)(const AFontMatcher*, const char*, const uint16_t*, const uint32_t, uint32_t*);
typedef void (*PFN_AFontMatcher_setStyle)(AFontMatcher*, uint16_t, bool);

typedef ASystemFontIterator* (*PFN_ASystemFontIterator_open)();
typedef void (*PFN_ASystemFontIterator_close)(ASystemFontIterator*);
typedef AFont* (*PFN_ASystemFontIterator_next)(ASystemFontIterator*);

typedef void (*PFN_AFont_close)(AFont*);
typedef const char* (*PFN_AFont_getFontFilePath)(const AFont*);
typedef uint16_t (*PFN_AFont_getWeight)(const AFont*);
typedef bool (*PFN_AFont_isItalic)(const AFont*);
typedef const char* (*PFN_AFont_getLocale)(const AFont*);
typedef size_t (*PFN_AFont_getCollectionIndex)(const AFont*);
typedef size_t (*PFN_AFont_getAxisCount)(const AFont*);
typedef uint32_t (*PFN_AFont_getAxisTag)(const AFont*, uint32_t axisIndex);
typedef float (*PFN_AFont_getAxisValue)(const AFont*, uint32_t axisIndex);

static PFN_AFontMatcher_create AFontMatcher_create     = nullptr;
static PFN_AFontMatcher_destroy AFontMatcher_destroy   = nullptr;
static PFN_AFontMatcher_match AFontMatcher_match       = nullptr;
static PFN_AFontMatcher_setStyle AFontMatcher_setStyle = nullptr;

static PFN_ASystemFontIterator_open ASystemFontIterator_open   = nullptr;
static PFN_ASystemFontIterator_close ASystemFontIterator_close = nullptr;
static PFN_ASystemFontIterator_next ASystemFontIterator_next   = nullptr;

static PFN_AFont_close AFont_close                           = nullptr;
static PFN_AFont_getFontFilePath AFont_getFontFilePath       = nullptr;
static PFN_AFont_getWeight AFont_getWeight                   = nullptr;
static PFN_AFont_isItalic AFont_isItalic                     = nullptr;
static PFN_AFont_getLocale AFont_getLocale                   = nullptr;
static PFN_AFont_getCollectionIndex AFont_getCollectionIndex = nullptr;
static PFN_AFont_getAxisCount AFont_getAxisCount             = nullptr;
static PFN_AFont_getAxisTag AFont_getAxisTag                 = nullptr;
static PFN_AFont_getAxisValue AFont_getAxisValue             = nullptr;

#    endif

#    define LOG_TAG "axmol"

#    include "pugixml.hpp"

#    define ANDROID_SYSTEM_FONTS_NOUGAT "/system/etc/fonts.xml"
#    define ANDROID_FONT_PATH           "/system/fonts/"

namespace ax
{

std::string safeToLower(const std::string& s)
{
    std::string newstr = s;
    std::transform(newstr.begin(), newstr.end(), newstr.begin(), [](unsigned char c) {
        if (c < 128)  // 只处理 ASCII
            return static_cast<char>(std::tolower(c));
        return static_cast<char>(c);  // 保留原字节
    });
    return newstr;
}

class AndroidFontLoader
{
public:
    struct FontInfo
    {
        std::string path;
        int weight;
        std::string style;
        bool isItalic;
    };

    struct FontFamily
    {
        std::string name;
        std::vector<FontInfo*> fonts;
    };

    std::unordered_map<std::string, FontFamily> familyMap;
    std::vector<FontInfo*> allFonts;
    FontStyle lastSortStyle;

    AndroidFontLoader() = default;

    ~AndroidFontLoader()
    {
        for (auto font : allFonts)
            delete font;
    }

    void initialize()
    {
        // https://github.com/nomadsinteractive/ark/blob/master/platform/android/util/font_config.cpp
        // https://github.com/Juniper/amt-vlc/blob/master/vlc/modules/text_renderer/freetype/fonts/android.c
        // https://android.googlesource.com/platform//external/skia/+/refs/tags/android-7.1.1_r11/src/ports/SkFontMgr_android_parser.cpp#759

        // 此处只支持Android5.0(level 21)及以上版本的字体配置解析
        // 低于这个版本的配置文件在 /system/etc/system_fonts.xml /system/etc/fallback_fonts.xml 中
        // 版本过低没必要进行支持了

        pugi::xml_document doc;
        pugi::xml_parse_result result = doc.load_file(ANDROID_SYSTEM_FONTS_NOUGAT);
        if (!result)
        {
            AXLOGE("Failed to load font config file: {}", ANDROID_SYSTEM_FONTS_NOUGAT);
            return;
        }

        pugi::xml_node familyset = doc.child("familyset");
        if (!familyset)
        {
            AXLOGE("Invalid fonts.xml structure: missing familyset");
            return;
        }

        // 解析主要字体家族
        for (pugi::xml_node family_node : familyset.children("family"))
        {
            FontFamily family;
            family.name = family_node.attribute("name").as_string();
            family.name = safeToLower(family.name);

            // 解析字体变体
            for (pugi::xml_node font_node : family_node.children("font"))
            {
                auto font  = new FontInfo();
                font->path = ANDROID_FONT_PATH;
                font->path.append(font_node.text().as_string());
                font->weight   = font_node.attribute("weight").as_int(400);  // 默认normal
                font->style    = font_node.attribute("style").as_string("normal");
                font->isItalic = (font->style == "italic");

                allFonts.push_back(font);
                family.fonts.push_back(font);
            }

            if (!family.fonts.empty())
                familyMap[family.name] = family;
        }

        // 解析别名
        for (pugi::xml_node alias_node : familyset.children("alias"))
        {
            std::string_view name_sv = alias_node.attribute("name").as_string();
            std::string_view to_sv   = alias_node.attribute("to").as_string();

            std::string name(name_sv);
            std::string to(to_sv);

            if (familyMap.find(name) != familyMap.end())
            {
                AXLOGW("Alias name conflicts with existing family: {}", name);
                continue;
            }

            auto family = familyMap.find(to);
            if (family == familyMap.end())
            {
                AXLOGW("Alias refers to unknown family: {}", to);
                continue;
            }

            int weight = alias_node.attribute("weight").as_int(0);

            FontFamily newFamily;
            newFamily.name = safeToLower(name);
            for (auto& font : family->second.fonts)
            {
                if (weight == 0)
                {
                    newFamily.fonts.push_back(font);
                }
                else if (font->weight == weight)
                {
                    newFamily.fonts.push_back(font);
                }
            }

            if (!newFamily.fonts.empty())
                familyMap[newFamily.name] = newFamily;
        }

        lastSortStyle = FontStyle::Bold();
        enumFont(FontStyle::Normal(), [](auto) -> bool { return true; });

        //         for (const auto& familyIt : familyMap)
        //         {
        //             const auto& family = familyIt.second;
        //             AXLOGW("Font Family: {}", family.name);
        //
        //             for (const auto& font : family.fonts)
        //             {
        //                 AXLOGI("    Font: {} (weight: {}, style: {})", font->path, font->weight, font->style);
        //             }
        //         }
    }

    void enumFont(FontStyle style, std::function<bool(FontInfo*)> callback)
    {
        if (lastSortStyle != style)
        {
            lastSortStyle     = style;
            static auto score = [](const FontStyle& style, const FontInfo* f) {
                int s = 0;
                s -= std::abs(f->weight - style.weight());  // 越接近越好
                if (f->isItalic == style.isItalic())
                    s += 1000;  // 奖励匹配斜体
                return s;
            };

            std::sort(allFonts.begin(), allFonts.end(),
                      [&style](const auto a, const auto b) { return score(style, a) > score(style, b); });
        }

        std::set<std::string_view> sees;
        for (auto font : allFonts)
        {
            if (!sees.contains(font->path))
            {
                sees.insert(font->path);

                if (callback(font))
                    break;
            }
        }
    }

    std::string matchFontByFamilyName(const std::string& familyName, FontStyle style)
    {
        auto it = familyMap.find(safeToLower(familyName));
        if (it == familyMap.end())
            return "";

        FontInfo* best = nullptr;
        int bestScore  = std::numeric_limits<int>::max();

        for (auto font : it->second.fonts)
        {
            int score = 0;

            // 斜体不匹配加较大惩罚
            if (font->isItalic != style.isItalic())
                score += 1000;

            // 权重差距越小越好
            score += std::abs(font->weight - style.weight());

            if (score < bestScore)
            {
                bestScore = score;
                best      = font;
            }
        }

        if (best)
            return best->path;

        return "";
    }
};

static AndroidFontLoader s_androidFontLoader;
static bool s_androidFontAPIInited = false;
static bool s_supportFontAPI       = false;

static void initAndroidFontAPI()
{
    if (s_androidFontAPIInited)
        return;

    s_androidFontAPIInited = true;

    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "[FontEngine] Init start, api-level: %d",
                        android_get_device_api_level());
    if (android_get_device_api_level() < ANDROID_NDK_FONT_API_LOCALE_WORKS)
    {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "[FontEngine] Device not supported.");
        s_androidFontLoader.initialize();
        return;
    }

#    if __ANDROID_API__ >= ANDROID_NDK_FONT_API_EXISTS
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "[FontEngine] Init finish");
#    else
    void* handle = dlopen("libandroid.so", RTLD_NOW | RTLD_LOCAL);
    if (!handle)
    {
        __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "[FontEngine] Failed to load libandroid.so");
        s_androidFontLoader.initialize();
        return;
    }

#        define DLSYM_ANDROID_FONT_API(NAME)                                                                  \
            do                                                                                                \
            {                                                                                                 \
                NAME = reinterpret_cast<PFN_##NAME>(dlsym(handle, #NAME));                                    \
                if (!NAME)                                                                                    \
                {                                                                                             \
                    __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, "[FontEngine] Failed to load:%s", #NAME); \
                    dlclose(handle);                                                                          \
                    s_androidFontLoader.initialize();                                                         \
                    return;                                                                                   \
                }                                                                                             \
            } while (0)

    DLSYM_ANDROID_FONT_API(AFontMatcher_create);
    DLSYM_ANDROID_FONT_API(AFontMatcher_destroy);
    DLSYM_ANDROID_FONT_API(AFontMatcher_match);
    DLSYM_ANDROID_FONT_API(AFontMatcher_setStyle);

    DLSYM_ANDROID_FONT_API(ASystemFontIterator_open);
    DLSYM_ANDROID_FONT_API(ASystemFontIterator_close);
    DLSYM_ANDROID_FONT_API(ASystemFontIterator_next);

    DLSYM_ANDROID_FONT_API(AFont_close);
    DLSYM_ANDROID_FONT_API(AFont_getFontFilePath);
    DLSYM_ANDROID_FONT_API(AFont_getWeight);
    DLSYM_ANDROID_FONT_API(AFont_isItalic);
    DLSYM_ANDROID_FONT_API(AFont_getLocale);
    DLSYM_ANDROID_FONT_API(AFont_getCollectionIndex);
    DLSYM_ANDROID_FONT_API(AFont_getAxisCount);
    DLSYM_ANDROID_FONT_API(AFont_getAxisTag);
    DLSYM_ANDROID_FONT_API(AFont_getAxisValue);

#        undef SK_DLSYM_ANDROID_FONT_API
#    endif
    s_supportFontAPI = true;
}

std::vector<std::string> FontEngine::lookupSystemFontsByCharacter(char32_t codepoint, FontStyle style, int numOfMax)
{
    initAndroidFontAPI();
    if (s_supportFontAPI)
    {
        AFontMatcher* matcher = AFontMatcher_create();
        if (matcher == nullptr)
        {
            return {};
        }
        AFontMatcher_setStyle(matcher, style.weight(), style.isItalic());

        // 转换 codepoint 到 UTF-16
        uint16_t utf16Buf[2];
        int utf16Len = 0;
        if (codepoint <= 0xFFFF)
        {
            utf16Buf[0] = (uint16_t)codepoint;
            utf16Len    = 1;
        }
        else
        {
            uint32_t cp = codepoint - 0x10000;
            utf16Buf[0] = (uint16_t)((cp >> 10) + 0xD800);
            utf16Buf[1] = (uint16_t)((cp & 0x3FF) + 0xDC00);
            utf16Len    = 2;
        }

        std::vector<std::string> result;
        uint32_t runLen = 0;
        AFont* matched  = AFontMatcher_match(matcher, "sans-serif", utf16Buf, utf16Len, &runLen);

        if (matched && runLen > 0)
        {
            // 找到了支持该字符的字体
            const char* path = AFont_getFontFilePath(matched);
            if (path)
            {
                result.emplace_back(path);
            }
            AFont_close(matched);
        }

        AFontMatcher_destroy(matcher);
        return result;
    }
    else
    {
        std::vector<std::string> result;
        s_androidFontLoader.enumFont(style, [this, codepoint, &result, numOfMax](auto font) -> bool {
            if (this->isLoadedFont(font->path))
                return false;

            FT_Face face;
            // 初始化失败,继续遍历下一个字体
            if (FT_New_Face(FontFreeType::getFTLibrary(), font->path.c_str(), (FT_Long)0, &face) != 0)
                return false;

            FT_UInt glyphIndex = FT_Get_Char_Index(face, static_cast<FT_ULong>(codepoint));
            FT_Done_Face(face);

            // 这个字体没有这个字符
            if (glyphIndex == 0)
                return false;

            result.push_back(font->path);
            if (numOfMax > 0 && result.size() >= numOfMax)
            {
                return true;
            }

            return false;
        });
        return result;
    }
}

std::string FontEngine::lookupSystemFontsByName(const std::string& familyName, FontStyle style)
{
    initAndroidFontAPI();
    if (s_supportFontAPI)
    {
        AFontMatcher* matcher = AFontMatcher_create();
        AFontMatcher_setStyle(matcher, style.weight(), style.isItalic());

        // Use e.g. a dummy text "A"
        uint16_t dummyUtf16[1] = {'A'};
        uint32_t runLen        = 0;
        AFont* font            = AFontMatcher_match(matcher, familyName.c_str(), dummyUtf16, 1, &runLen);
        std::string path;
        if (font)
        {
            const char* p = AFont_getFontFilePath(font);
            if (p)
                path = p;
            AFont_close(font);
        }
        AFontMatcher_destroy(matcher);
        return path;
    }
    else
    {
        return s_androidFontLoader.matchFontByFamilyName(familyName, style);
    }
}

}  // namespace ax

#endif
