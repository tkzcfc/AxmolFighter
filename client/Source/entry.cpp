#include "entry.h"
#include "axmol.h"

#include "tolua/extension_manual_tolua.h"
#include "LuaEngine.h"
#include "lua-bindings/manual/lua_module_register.h"

#include "network/HttpClient.h"
#if AX_TARGET_PLATFORM != AX_PLATFORM_IOS && AX_TARGET_PLATFORM != AX_PLATFORM_ANDROID
#    include "ImGui/ImGuiPresenter.h"
#endif
#include "fairygui/FairyGUI.h"
#include "fairygui/utils/html/HtmlObject.h"
#include "fairygui/utils/UBBParser.h"
#include "fairygui/GCache.h"
#include "Webm.h"

#include "pak/pak.h"
#include "pak/decrypt_fileutils.h"
#include "base/FPSImages.h"
#include "lua_repair_bytecode.h"
#include "font/FontEngine.h"

#include "tolua/net_tolua.h"
#include "tolua/game_utils_tolua.h"
#include "tolua/native_utils_tolua.h"
#include "tolua/pak_tolua.h"
#include "af/tolua/af.h"

#define USE_AUDIO_ENGINE 1

#if USE_AUDIO_ENGINE
#    include "audio/AudioEngine.h"
#endif

using namespace ax;

#ifndef BUILT_IN_FILE_MOUNT_ENABLED
#    define BUILT_IN_FILE_MOUNT_ENABLED     1
#    define BUILT_IN_FILE_MOUNT_CHUNK_COUNT 1
#    define BUILT_IN_FILE_MOUNT_CHUNK_NAME  "data.bin"
#endif

static void boot_repair()
{
    auto fileUtils = FileUtils::getInstance();

    std::string writablePath     = fileUtils->getWritablePath();
    std::string bootRepairFile   = writablePath + "boot_repair.pak";
    std::string bootRepairOutDir = writablePath + "repair";

    if (fileUtils->isFileExist(bootRepairFile))
    {
        fileUtils->removeDirectory(bootRepairOutDir);

        auto archiveInfo = new pak::PakArchive();
        if (archiveInfo->init(bootRepairFile, "/", true))
        {
            for (auto& file : archiveInfo->getFiles())
            {
                Data data;
                archiveInfo->getContents(file.first, &data);

                std::string fullName = bootRepairOutDir + file.first;
                const size_t pos     = fullName.find_last_of('/');
                std::string dirName  = fullName.substr(0, pos);
                if (!fileUtils->isDirectoryExist(dirName))
                {
                    fileUtils->createDirectories(dirName);
                }

                if (!fileUtils->writeDataToFile(std::move(data), fullName))
                {
                    AXLOGE("boot repair failed: cannot write file '{}'", fullName);
                    fileUtils->removeDirectory(bootRepairOutDir);
                    break;
                }
            }
        }
        else
        {
            AXLOGE("boot repair pak file '{}' init failed", bootRepairFile);
        }
        delete archiveInfo;
        fileUtils->removeFile(bootRepairFile);
    }

    if (fileUtils->isDirectoryExist(bootRepairOutDir))
    {
        if (fileUtils->isFileExist(bootRepairOutDir + "/chunks/boot.chunk"))
        {
            fileUtils->addSearchPath(bootRepairOutDir, true);
        }
        else
        {
            AXLOGE("boot repair failed: cannot find 'chunks/boot.chunk' in '{}'", bootRepairOutDir);
            fileUtils->removeDirectory(bootRepairOutDir);
        }
    }

    Director::getInstance()->getScheduler()->schedule([](float) {
        Image* image = new Image();
        bool isOK    = image->initWithImageData(ax_fps_images_png, ax_fps_images_len(), false);
        if (isOK)
        {
            Director::getInstance()->getTextureCache()->addImage(image, "/boot_repairs_images", PixelFormat::RGBA4);
        }
        AX_SAFE_RELEASE(image);

        auto L = LuaEngine::getInstance()->getLuaStack()->getLuaState();
        if (L && luaL_loadbuffer(L, reinterpret_cast<const char*>(lua_boot_repair_bytecode),
                                 sizeof(lua_boot_repair_bytecode), "@boot_repair") == 0)
        {
            lua_pcall(L, 0, LUA_MULTRET, 0);
        }
    }, (void*)1, 1 / 40.0f, 0, 0.1f, false, "repair_tick");

    FileUtils::getInstance()->purgeCachedEntries();
}

#define DELAY_WAIT_SCREE_ORIENTATION 0
#if DELAY_WAIT_SCREE_ORIENTATION
enum class WaitScreenOrientationType
{
    Landscape,
    Portrait,
    None,
};

static WaitScreenOrientationType launchScreenOrientation  = WaitScreenOrientationType::Landscape;
static WaitScreenOrientationType waitForScreenOrientation = WaitScreenOrientationType::None;
#endif

bool app_start()
{
    // set default FPS
    Director::getInstance()->setAnimationInterval(1.0 / 60.0f);

    Device::setKeepScreenOn(true);

    DecryptFileUtils::enable();
#if BUILT_IN_FILE_MOUNT_ENABLED
#    if BUILT_IN_FILE_MOUNT_CHUNK_COUNT > 1
    {
        std::string chunkFileName = BUILT_IN_FILE_MOUNT_CHUNK_NAME;
        auto extension            = FileUtils::getPathExtension(chunkFileName);
        auto prefix               = chunkFileName.substr(0, chunkFileName.size() - extension.size());
        for (auto i = 0; i < BUILT_IN_FILE_MOUNT_CHUNK_COUNT; ++i)
        {
            if (!DecryptFileUtils::mount(prefix + std::to_string(i) + extension, "", false, false))
            {
                AXLOGE("mount built-in pak file '{}' failed", prefix + std::to_string(i) + extension);
            }
        }
    }
#    else
    {
        if (!DecryptFileUtils::mount(BUILT_IN_FILE_MOUNT_CHUNK_NAME, "", false, false))
        {
            AXLOGE("mount built-in pak file '{}' failed", BUILT_IN_FILE_MOUNT_CHUNK_NAME);
        }
    }
#    endif
#endif

    FontEngine::destroy();
    FontEngine::setFontEngine();
    FontEngine::getInstance()->setAutoMatchSystemFontsByCharacter(false);
    FontFreeType::setStreamParsingEnabled(true);

    // register lua module
    auto engine = LuaEngine::getInstance();
    ScriptEngineManager::getInstance()->setScriptEngine(engine);
    lua_State* L = engine->getLuaStack()->getLuaState();
    lua_module_register(L);

    register_net_tolua(L);
    register_extension_manual_tolua(L);
    register_game_utils_tolua(L);
    register_native_utils_tolua(L);
    register_pak_tolua(L);
    register_af_tolua(L);

#ifndef AX_PLATFORM_PC
    boot_repair();
#endif

    const char* chunkName = "chunks/boot.chunk";
    if (FileUtils::getInstance()->isFileExist(chunkName))
    {
        LuaEngine::getInstance()->getLuaStack()->loadChunksFromZIP(chunkName);
    }
    else
    {
        AXLOGE("cannot find boot chunk file: {}", chunkName);
    }

    if (engine->executeString("require 'boot.src.setup'"))
    {
        AXLOGE("failed to load boot.src.setup file");
        return false;
    }

    auto director = Director::getInstance();
    if (director->getRenderView() == nullptr)
    {
        AXLOGE("RenderView is null");
        return false;
    }
#if DELAY_WAIT_SCREE_ORIENTATION
    auto framesize = director->getRenderView()->getFrameSize();
    if (framesize.width < framesize.height)
    {
        // Portrait
        waitForScreenOrientation = WaitScreenOrientationType::Portrait;
    }
    else
    {
        // Landscape
        waitForScreenOrientation = WaitScreenOrientationType::Landscape;
    }

    if (waitForScreenOrientation == launchScreenOrientation)
    {
        waitForScreenOrientation = WaitScreenOrientationType::None;
        if (engine->executeString("require 'boot.src.launch'"))
        {
            AXLOGE("failed to load boot.src.launch file");
            return false;
        }
    }
    else
    {
        waitForScreenOrientation = launchScreenOrientation;
    }
#else
    if (engine->executeString("require 'boot.src.launch'"))
    {
        AXLOGE("failed to load boot.src.launch file");
        return false;
    }
#endif

    return true;
}

void app_restart_start()
{
#if AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID
    auto script = R"(local luaj = require "axmol.core.luaj"
        if luaj and luaj.checkStaticMethod and luaj.checkStaticMethod("dev/axmol/app/AppActivity", "onEngineRestart", "()V") then
            luaj.callStaticMethod("dev/axmol/app/AppActivity", "onEngineRestart", {}, "()V")
        end
)";
    LuaEngine::getInstance()->executeString(script);
#endif

    ax::network::HttpClient::destroyInstance();
    spine::SkeletonBatch::destroyInstance();
    spine::SkeletonTwoColorBatch::destroyInstance();
#if AX_TARGET_PLATFORM != AX_PLATFORM_IOS && AX_TARGET_PLATFORM != AX_PLATFORM_ANDROID
    ax::extension::ImGuiPresenter::destroyInstance();
#endif
    if (fairygui::GRoot::_forceRefInst)
    {
        assert(fairygui::GRoot::_forceRefInst->getReferenceCount() == 1);
        if (fairygui::GRoot::_forceRefInst->getReferenceCount() > 0)
        {
            fairygui::GRoot::_forceRefInst->displayObject()->removeFromParent();
            fairygui::GRoot::_forceRefInst->release();
        }
    }
    fairygui::UIPackage::removeAllPackages();
    fairygui::UIPackage::clearVar();
    fairygui::HtmlObject::objectPool.clear();
    fairygui::HtmlObject::loaderPool.clear();
    fairygui::UBBParser::destroyInstance();
    fairygui::DragDropManager::destroyInstance();
    fairygui::UIConfig::clearFont();
    fairygui::UIConfig::onMusicCallback = nullptr;
    fairygui::UIObjectFactory::clearPackageItemExtension();
    fairygui::UIObjectFactory::setLoaderExtension(nullptr);
    fairygui::GTween::clean();
    fairygui::GCache::destroy();
    ax::Webm::cancelAllAsync();
#if USE_AUDIO_ENGINE
    ax::AudioEngine::uncacheAll();
#endif
}

void app_restart_finish()
{
    extension_manual_purge();
    ScriptEngineManager::destroyInstance();

    app_start();
}

void app_screen_size_changed(int width, int height)
{
#if DELAY_WAIT_SCREE_ORIENTATION
    auto director = Director::getInstance();
    if (director->getRenderView() == nullptr || waitForScreenOrientation == WaitScreenOrientationType::None ||
        ScriptEngineManager::getInstance() == nullptr)
    {
        return;
    }

    auto framesize = director->getRenderView()->getFrameSize();
    if (framesize.width < framesize.height)
    {
        // Portrait
        if (waitForScreenOrientation == WaitScreenOrientationType::Portrait)
        {
            waitForScreenOrientation = WaitScreenOrientationType::None;
        }
    }
    else
    {
        // Landscape
        if (waitForScreenOrientation == WaitScreenOrientationType::Landscape)
        {
            waitForScreenOrientation = WaitScreenOrientationType::None;
        }
    }

    if (waitForScreenOrientation == WaitScreenOrientationType::None)
    {
        auto engine = LuaEngine::getInstance();
        if (engine->executeString("require 'boot.src.launch'"))
        {
            AXLOGE("failed to load boot.src.launch file");
        }
    }
#endif
}
