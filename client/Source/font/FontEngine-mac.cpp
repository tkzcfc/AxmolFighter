#include "FontEngine.h"

#if AX_TARGET_PLATFORM == AX_PLATFORM_IOS || AX_TARGET_PLATFORM == AX_PLATFORM_MAC

#    include <CoreText/CoreText.h>
#    include <CoreText/CTFontManager.h>
#    include <CoreGraphics/CoreGraphics.h>
#    include <CoreFoundation/CoreFoundation.h>
#    include <memory>
#    include <type_traits>
#    include <dlfcn.h>

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#    include <stdint.h>

// 完整的字节序判断宏
#    if defined(__BYTE_ORDER__)
#        if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
#            define IS_LITTLE_ENDIAN 1
#            define IS_BIG_ENDIAN    0
#        elif __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
#            define IS_LITTLE_ENDIAN 0
#            define IS_BIG_ENDIAN    1
#        endif
#    elif defined(__LITTLE_ENDIAN__) || defined(__i386__) || defined(__x86_64__) || defined(__arm__) || \
        defined(__arm64__)
// x86, x86_64, ARM, ARM64 都是小端
#        define IS_LITTLE_ENDIAN 1
#        define IS_BIG_ENDIAN    0
#    elif defined(__BIG_ENDIAN__) || defined(__powerpc__) || defined(__POWERPC__)
// PowerPC 是大端
#        define IS_LITTLE_ENDIAN 0
#        define IS_BIG_ENDIAN    1
#    else
// 默认使用运行时检测
static inline int detectEndianness()
{
    static const uint32_t testValue = 0x01020304;
    return (*(const uint8_t*)&testValue == 0x04) ? 1 : 0;
}
#        define IS_LITTLE_ENDIAN (detectEndianness())
#        define IS_BIG_ENDIAN    (!IS_LITTLE_ENDIAN)
#    endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class SkOnce
{
public:
    constexpr SkOnce() = default;

    template <typename Fn, typename... Args>
    void operator()(Fn&& fn, Args&&... args)
    {
        auto state = fState.load(std::memory_order_acquire);

        if (state == Done)
        {
            return;
        }

        // If it looks like no one has started calling fn(), try to claim that job.
        if (state == NotStarted &&
            fState.compare_exchange_strong(state, Claimed, std::memory_order_relaxed, std::memory_order_relaxed))
        {
            // Great!  We'll run fn() then notify the other threads by releasing Done into fState.
            fn(std::forward<Args>(args)...);
            return fState.store(Done, std::memory_order_release);
        }

        // Some other thread is calling fn().
        // We'll just spin here acquiring until it releases Done into fState.
        while (fState.load(std::memory_order_acquire) != Done)
        { /*spin*/
        }
    }

private:
    enum State : uint8_t
    {
        NotStarted,
        Claimed,
        Done
    };
    std::atomic<uint8_t> fState{NotStarted};
};

template <typename T, T* P>
struct SkOverloadedFunctionObject
{
    template <typename... Args>
    auto operator()(Args&&... args) const -> decltype(P(std::forward<Args>(args)...))
    {
        return P(std::forward<Args>(args)...);
    }
};

template <auto F>
using SkFunctionObject = SkOverloadedFunctionObject<std::remove_pointer_t<decltype(F)>, F>;

template <typename CFRef>
using SkUniqueCFRef = std::unique_ptr<std::remove_pointer_t<CFRef>, SkFunctionObject<CFRelease>>;

static SkUniqueCFRef<CFStringRef> make_CFString(const char s[])
{
    return SkUniqueCFRef<CFStringRef>(CFStringCreateWithCString(nullptr, s, kCFStringEncodingUTF8));
}

using SkCTFontWeightMapping = const CGFloat[11];
SkCTFontWeightMapping& SkCTFontGetNSFontWeightMapping()
{
    // In the event something goes wrong finding the real values, use this mapping.
    static constexpr CGFloat defaultNSFontWeights[] = {-1.00, -0.80, -0.60, -0.40, 0.00, 0.23,
                                                       0.30,  0.40,  0.56,  0.62,  1.00};

    // Declarations in <AppKit/AppKit.h> on macOS, <UIKit/UIKit.h> on iOS
#    if AX_TARGET_PLATFORM == AX_PLATFORM_MAC
#        define SK_KIT_FONT_WEIGHT_PREFIX "NS"
#    endif
#    if AX_TARGET_PLATFORM == AX_PLATFORM_IOS
#        define SK_KIT_FONT_WEIGHT_PREFIX "UI"
#    endif
    static constexpr const char* nsFontWeightNames[] = {
        SK_KIT_FONT_WEIGHT_PREFIX "FontWeightUltraLight", SK_KIT_FONT_WEIGHT_PREFIX "FontWeightThin",
        SK_KIT_FONT_WEIGHT_PREFIX "FontWeightLight",      SK_KIT_FONT_WEIGHT_PREFIX "FontWeightRegular",
        SK_KIT_FONT_WEIGHT_PREFIX "FontWeightMedium",     SK_KIT_FONT_WEIGHT_PREFIX "FontWeightSemibold",
        SK_KIT_FONT_WEIGHT_PREFIX "FontWeightBold",       SK_KIT_FONT_WEIGHT_PREFIX "FontWeightHeavy",
        SK_KIT_FONT_WEIGHT_PREFIX "FontWeightBlack",
    };
    static_assert(std::size(nsFontWeightNames) == 9, "");

    static CGFloat nsFontWeights[11];
    static const CGFloat(*selectedNSFontWeights)[11] = &defaultNSFontWeights;
    static SkOnce once;
    once([&] {
        size_t i           = 0;
        nsFontWeights[i++] = -1.00;
        for (const char* nsFontWeightName : nsFontWeightNames)
        {
            void* nsFontWeightValuePtr = dlsym(RTLD_DEFAULT, nsFontWeightName);
            if (nsFontWeightValuePtr)
            {
                nsFontWeights[i++] = *(static_cast<CGFloat*>(nsFontWeightValuePtr));
            }
            else
            {
                return;
            }
        }
        nsFontWeights[i++]    = 1.00;
        selectedNSFontWeights = &nsFontWeights;
    });
    return *selectedNSFontWeights;
}

template <typename S, typename D, typename C>
struct LinearInterpolater
{
    struct Mapping
    {
        S src_val;
        D dst_val;
    };
    constexpr LinearInterpolater(Mapping const mapping[], int mappingCount)
        : fMapping(mapping), fMappingCount(mappingCount)
    {}

    static D map(S value, S src_min, S src_max, D dst_min, D dst_max)
    {
        assert(src_min < src_max);
        assert(dst_min <= dst_max);
        return C()(dst_min + (((value - src_min) * (dst_max - dst_min)) / (src_max - src_min)));
    }

    D map(S val) const
    {
        // -Inf to [0]
        if (val < fMapping[0].src_val)
        {
            return fMapping[0].dst_val;
        }

        // Linear from [i] to [i+1]
        for (int i = 0; i < fMappingCount - 1; ++i)
        {
            if (val < fMapping[i + 1].src_val)
            {
                return map(val, fMapping[i].src_val, fMapping[i + 1].src_val, fMapping[i].dst_val,
                           fMapping[i + 1].dst_val);
            }
        }

        // From [n] to +Inf
        // if (fcweight < Inf)
        return fMapping[fMappingCount - 1].dst_val;
    }

    Mapping const* fMapping;
    int fMappingCount;
};

struct RoundCGFloatToInt
{
    int operator()(CGFloat s) { return s + 0.5; }
};
struct CGFloatIdentity
{
    CGFloat operator()(CGFloat s) { return s; }
};

/** Convert the [0, 1000] CSS weight to [-1, 1] CTFontDescriptor weight (for system fonts).
 *
 *  The -1 to 1 weights reported by CTFontDescriptors have different mappings depending on if the
 *  CTFont is native or created from a CGDataProvider.
 */
CGFloat SkCTFontCTWeightForCSSWeight(int fontstyleWeight)
{
    using Interpolator = LinearInterpolater<int, CGFloat, CGFloatIdentity>;

    // Note that Mac supports the old OS2 version A so 0 through 10 are as if multiplied by 100.
    // However, on this end we can't tell, so this is ignored.

    static Interpolator::Mapping nativeWeightMappings[11];
    static SkOnce once;
    once([&] {
        const CGFloat(&nsFontWeights)[11] = SkCTFontGetNSFontWeightMapping();
        for (int i = 0; i < 11; ++i)
        {
            nativeWeightMappings[i].src_val = i * 100;
            nativeWeightMappings[i].dst_val = nsFontWeights[i];
        }
    });
    static constexpr Interpolator nativeInterpolator(nativeWeightMappings, std::size(nativeWeightMappings));

    return nativeInterpolator.map(fontstyleWeight);
}

/** Convert the [0, 10] CSS weight to [-1, 1] CTFontDescriptor width. */
CGFloat SkCTFontCTWidthForCSSWidth(int fontstyleWidth)
{
    using Interpolator = LinearInterpolater<int, CGFloat, CGFloatIdentity>;

    // Values determined by creating font data with every width, creating a CTFont,
    // and asking the CTFont for its width. See TypefaceStyle test for basics.
    static constexpr Interpolator::Mapping widthMappings[] = {
        {0, -0.5},
        {10, 0.5},
    };
    static constexpr Interpolator interpolator(widthMappings, std::size(widthMappings));
    return interpolator.map(fontstyleWidth);
}

namespace ax
{

static SkUniqueCFRef<CTFontDescriptorRef> create_descriptor(const char familyName[], const FontStyle& style)
{
    SkUniqueCFRef<CFMutableDictionaryRef> cfAttributes(CFDictionaryCreateMutable(
        kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
    SkUniqueCFRef<CFMutableDictionaryRef> cfTraits(CFDictionaryCreateMutable(
        kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
    if (!cfAttributes || !cfTraits)
    {
        return nullptr;
    }
    // TODO(crbug.com/1018581) Some CoreText versions have errant behavior when
    // certain traits set.  Temporary workaround to omit specifying trait for
    // those versions.
    // Long term solution will involve serializing typefaces instead of relying
    // upon this to match between processes.
    //
    // Compare CoreText.h in an up to date SDK for where these values come from.
    static const uint32_t kSkiaLocalCTVersionNumber10_14 = 0x000B0000;
    static const uint32_t kSkiaLocalCTVersionNumber10_15 = 0x000C0000;
    // CTFontTraits (symbolic)
    // macOS 14 and iOS 12 seem to behave badly when kCTFontSymbolicTrait is set.
    // macOS 15 yields LastResort font instead of a good default font when
    // kCTFontSymbolicTrait is set.
    if (!(&CTGetCoreTextVersion && CTGetCoreTextVersion() >= kSkiaLocalCTVersionNumber10_14))
    {
        CTFontSymbolicTraits ctFontTraits = 0;
        if (style.weight() >= FontStyle::kBold_Weight)
        {
            ctFontTraits |= kCTFontBoldTrait;
        }
        if (style.slant() != FontStyle::kUpright_Slant)
        {
            ctFontTraits |= kCTFontItalicTrait;
        }
        SkUniqueCFRef<CFNumberRef> cfFontTraits(
            CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &ctFontTraits));
        if (cfFontTraits)
        {
            CFDictionaryAddValue(cfTraits.get(), kCTFontSymbolicTrait, cfFontTraits.get());
        }
    }
    // CTFontTraits (weight)
    CGFloat ctWeight = SkCTFontCTWeightForCSSWeight(style.weight());
    SkUniqueCFRef<CFNumberRef> cfFontWeight(CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &ctWeight));
    if (cfFontWeight)
    {
        CFDictionaryAddValue(cfTraits.get(), kCTFontWeightTrait, cfFontWeight.get());
    }
    // CTFontTraits (width)
    CGFloat ctWidth = SkCTFontCTWidthForCSSWidth(style.width());
    SkUniqueCFRef<CFNumberRef> cfFontWidth(CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &ctWidth));
    if (cfFontWidth)
    {
        CFDictionaryAddValue(cfTraits.get(), kCTFontWidthTrait, cfFontWidth.get());
    }
    // CTFontTraits (slant)
    // macOS 15 behaves badly when kCTFontSlantTrait is set.
    if (!(&CTGetCoreTextVersion && CTGetCoreTextVersion() == kSkiaLocalCTVersionNumber10_15))
    {
        CGFloat ctSlant = style.slant() == FontStyle::kUpright_Slant ? 0 : 1;
        SkUniqueCFRef<CFNumberRef> cfFontSlant(CFNumberCreate(kCFAllocatorDefault, kCFNumberCGFloatType, &ctSlant));
        if (cfFontSlant)
        {
            CFDictionaryAddValue(cfTraits.get(), kCTFontSlantTrait, cfFontSlant.get());
        }
    }
    // CTFontTraits
    CFDictionaryAddValue(cfAttributes.get(), kCTFontTraitsAttribute, cfTraits.get());
    // CTFontFamilyName
    if (familyName)
    {
        SkUniqueCFRef<CFStringRef> cfFontName = make_CFString(familyName);
        if (cfFontName)
        {
            CFDictionaryAddValue(cfAttributes.get(), kCTFontFamilyNameAttribute, cfFontName.get());
        }
    }
    return SkUniqueCFRef<CTFontDescriptorRef>(CTFontDescriptorCreateWithAttributes(cfAttributes.get()));
}

// Same as the above function except style is included so we can
// compare whether the created font conforms to the style. If not, we need
// to recreate the font with symbolic traits. This is needed due to MacOS 10.11
// font creation problem https://bugs.chromium.org/p/skia/issues/detail?id=8447.
static SkUniqueCFRef<CTFontRef> create_from_desc_and_style(CTFontDescriptorRef desc, const FontStyle& style)
{
    SkUniqueCFRef<CTFontRef> ctFont(CTFontCreateWithFontDescriptor(desc, 0, nullptr));
    if (!ctFont)
    {
        return nullptr;
    }
    const CTFontSymbolicTraits traits    = CTFontGetSymbolicTraits(ctFont.get());
    CTFontSymbolicTraits expected_traits = traits;
    if (style.slant() != FontStyle::kUpright_Slant)
    {
        expected_traits |= kCTFontItalicTrait;
    }
    if (style.weight() >= FontStyle::kBold_Weight)
    {
        expected_traits |= kCTFontBoldTrait;
    }
    if (expected_traits != traits)
    {
        SkUniqueCFRef<CTFontRef> ctNewFont(
            CTFontCreateCopyWithSymbolicTraits(ctFont.get(), 0, nullptr, expected_traits, expected_traits));
        if (ctNewFont)
        {
            ctFont = std::move(ctNewFont);
        }
    }
    return ctFont;
}

static std::string CFStringToStdString(CFStringRef cfString, CFStringEncoding encoding = kCFStringEncodingUTF8)
{
    if (!cfString)
        return "";

    std::string result;

    // 首先尝试快速方法
    const char* cstr = CFStringGetCStringPtr(cfString, encoding);
    if (cstr)
    {
        result = std::string(cstr);
    }
    else
    {
        // 快速方法失败，使用缓冲方法
        CFIndex length  = CFStringGetLength(cfString);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, encoding) + 1;

        char* buffer = new char[maxSize];
        if (CFStringGetCString(cfString, buffer, maxSize, encoding))
        {
            result = std::string(buffer);
        }
        delete[] buffer;
    }

    return result;
}

static std::string GetCTFontRefFilePath(CTFontRef font)
{
    CFTypeRef fontURLRawRef = CTFontCopyAttribute(font, kCTFontURLAttribute);
    SkUniqueCFRef<CFURLRef> fontURL((CFURLRef)fontURLRawRef);
    if (!fontURL)
    {
        return "";
    }

    SkUniqueCFRef<CFStringRef> pathString(CFURLCopyFileSystemPath(fontURL.get(), kCFURLPOSIXPathStyle));

    if (!pathString)
    {
        return "";
    }

    return CFStringToStdString(pathString.get());
}

std::vector<std::string> FontEngine::lookupSystemFontsByCharacter(char32_t codepoint, FontStyle style, int numOfMax)
{
    SkUniqueCFRef<CTFontDescriptorRef> desc = create_descriptor(nullptr, style);
    SkUniqueCFRef<CTFontRef> familyFont(CTFontCreateWithFontDescriptor(desc.get(), 0, nullptr));

    // kCFStringEncodingUTF32 is BE unless there is a BOM.
    // Since there is no machine endian option, explicitly state machine endian.
#    ifdef IS_LITTLE_ENDIAN
    constexpr CFStringEncoding encoding = kCFStringEncodingUTF32LE;
#    else
    constexpr CFStringEncoding encoding = kCFStringEncodingUTF32BE;
#    endif
    SkUniqueCFRef<CFStringRef> string(CFStringCreateWithBytes(
        kCFAllocatorDefault, reinterpret_cast<const UInt8*>(&codepoint), sizeof(codepoint), encoding, false));
    // If 0xD800 <= codepoint <= 0xDFFF || 0x10FFFF < codepoint 'string' may be nullptr.
    // No font should be covering such codepoints (even the magic fallback font).
    if (!string)
    {
        return {};
    }
    CFRange range = CFRangeMake(0, CFStringGetLength(string.get()));  // in UniChar units.
    SkUniqueCFRef<CTFontRef> fallbackFont(CTFontCreateForString(familyFont.get(), string.get(), range));

    if (!fallbackFont)
    {
        return {};
    }
    return {GetCTFontRefFilePath(fallbackFont.get())};
}

std::string FontEngine::lookupSystemFontsByName(const std::string& familyName, FontStyle style)
{
    SkUniqueCFRef<CTFontDescriptorRef> desc = create_descriptor(familyName.c_str(), style);
    if (!desc)
    {
        return "";
    }

    SkUniqueCFRef<CTFontRef> font = create_from_desc_and_style(desc.get(), style);
    if (!font)
    {
        return "";
    }

    return GetCTFontRefFilePath(font.get());
}

}  // namespace ax

#endif
