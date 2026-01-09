#include "game_utils_tolua.h"
#include "utils/game_utils.h"
#include "sol/sol.hpp"
#include "LuaBasicConversions.h"
#include "LuaValue.h"
#include "LuaEngine.h"
#include "ui/UIWebView/UIWebView.h"
#include "base/Utils.h"
#include "algorithms/sha-256.h"
#include "unzip/unzip.h"
#include "yasio/xxsocket.hpp"
#include "algorithms/xxtea.h"

using namespace ax;

static std::unordered_map<std::string, std::string> memory_data_map;

void register_game_utils_tolua(lua_State* lua_S)
{
    // clang-format off
    lua_pushlightuserdata(lua_S, (void*)0);
    lua_setglobal(lua_S, "null");

    lua_pushlightuserdata(lua_S, (void*)0);
    lua_setglobal(lua_S, "NULL");

    lua_pushlightuserdata(lua_S, (void*)0);
    lua_setglobal(lua_S, "nullptr");

    sol::state_view lua_sv(lua_S);
    auto game_utils_lua = lua_sv["game_utils"].get_or_create<sol::table>();

    game_utils_lua["runtime_version"] = 1;

    game_utils_lua.set_function("now_epoch_ms", []() -> int64_t { return game_utils::now_epoch_ms(); });

    game_utils_lua.set_function("now_epoch_10m", []() -> int64_t { return game_utils::now_epoch_10m(); });
    
    game_utils_lua.set_function("get_utc_timestamp_seconds", []() -> int64_t { return game_utils::get_utc_timestamp_seconds(); });
    
    game_utils_lua.set_function("get_utc_timestamp_milliseconds", []() -> int64_t { return game_utils::get_utc_timestamp_milliseconds(); });

    game_utils_lua.set_function("i64_to_datetime", [](long long time) {
        std::tm tm;
        auto tp = std::chrono::system_clock::time_point(std::chrono::duration_cast<std::chrono::system_clock::duration>(
            std::chrono::duration<long long, std::ratio<1LL, 10000000LL>>(time)));
        auto t  = std::chrono::system_clock::to_time_t(tp);
        tm      = *localtime(&t);

        return std::make_tuple(tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec,
                               tm.tm_wday, tm.tm_yday);
    });

    game_utils_lua.set_function("i64_to_string", [](lua_State* L) -> int {
        auto argc  = lua_gettop(L);
        int64_t v = 0;
        if (argc != 1)
        {
            luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.i64_to_string", argc, 1);
            return 0;
        }
        if (lua_isuserdata(L, 1))
        {
            v = *(int64_t*)lua_touserdata(L, 1);
        }
        else if (lua_isnumber(L, 1))
        {
            v = (int64_t)lua_tonumber(L, 1);
        }
        else
        {
            luaL_error(L, "game_utils.i64_to_string args should be number or userdata");
            return 0;
        }

        auto s = std::to_string(v);
        lua_pushlstring(L, s.c_str(), s.size());
        return 1;
    });

    game_utils_lua.set_function("create_sprite_with_base64", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 1)
        {
            const char* str      = lua_tostring(L, 1);
            ax::Sprite* ret = ax::utils::createSpriteFromBase64(str);
            object_to_luaval<ax::Sprite>(L, "ax.Sprite", (ax::Sprite*)ret);
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.create_sprite_with_base64", argc, 1);
        return 0;
    });


	game_utils_lua.set_function("unzip", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc < 2)
        {
            luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.unzip", argc, 2);
            return 0;
        }
        std::string zipFile  = lua_tostring(L, 1);
        std::string dstDir   = lua_tostring(L, 2);
        std::string password = lua_tostring(L, 3);

        LUA_FUNCTION handler        = toluafix_ref_function(L, 4, 0);
        LUA_FUNCTION percentHandler = LUA_NOREF;

        if (argc >= 5)
            percentHandler = toluafix_ref_function(L, 5, 0);

        Director::getInstance()->getJobSystem()->enqueue([zipFile, dstDir, password, handler, percentHandler]() {
            bool success = game_utils::unzip_file(zipFile.c_str(), dstDir.c_str(), password.c_str(), [=](float percent) {
                if (percentHandler != LUA_NOREF)
                {
                    Director::getInstance()->getScheduler()->runOnAxmolThread([=]() {
                        auto stack = LuaEngine::getInstance()->getLuaStack();
                        stack->pushFloat(percent);
                        stack->executeFunctionByHandler(percentHandler, 1);
                    });
                }
            });

            Director::getInstance()->getScheduler()->runOnAxmolThread([success, handler, percentHandler]() {
                auto stack = LuaEngine::getInstance()->getLuaStack();
                stack->pushBoolean(success);
                stack->pushString("");  // zipFile.c_str());
                stack->executeFunctionByHandler(handler, 2);
                stack->removeScriptHandler(handler);

                if (percentHandler != LUA_NOREF)
                {
                    stack->removeScriptHandler(percentHandler);
                }
            });
        });

        return 0;
    });

    game_utils_lua.set_function("set_memory_data", [](std::string key, std::string value) {
        memory_data_map.insert(std::make_pair(key, value));
    });

    game_utils_lua.set_function("get_memory_data", [](std::string key, std::string defaultValue) -> std::string {
        auto it = memory_data_map.find(key);
        if (it == memory_data_map.end())
        {
            return defaultValue;
        }
        return it->second;
    });

#if (AX_TARGET_PLATFORM == AX_PLATFORM_ANDROID || AX_TARGET_PLATFORM == AX_PLATFORM_IOS || AX_TARGET_PLATFORM == AX_PLATFORM_WIN32)
    game_utils_lua.set_function("bind_webView_js_callback", [](lua_State* L) -> int {
        if (lua_gettop(L) == 2)
        {
            ui::WebView* self          = static_cast<ui::WebView*>(tolua_tousertype(L, 1, 0));
            auto javascriptInterfaceScheme = luaL_tolstring(L, 2, 0);

            self->setJavascriptInterfaceScheme(javascriptInterfaceScheme);
            self->setOnJSCallback([](ui::WebView* sender, std::string_view url) {
                auto luaStack = LuaEngine::getInstance()->getLuaStack();
                auto luaState = luaStack->getLuaState();
                lua_getglobal(luaState, "OnWebViewJsCallback"); /* query function by name, stack: function */
                if (!lua_isfunction(luaState, -1))
                {
                    lua_pop(luaState, 1);
                    return;
                }
                luaStack->pushString(url.data(), static_cast<int>(url.length()));
                luaStack->executeFunction(1);
            });
        }
        return 0;
    });
#endif

    game_utils_lua.set_function("base64_decode", [](lua_State* L) -> int {
        auto argc= lua_gettop(L);
        if (argc == 1 && lua_isstring(L, 1))
        {
            size_t len  = 0;
            const char* s = lua_tolstring(L, 1, &len);
            if (len > 0)
            {
                unsigned char* encoded;
                int length = utils::base64Decode((unsigned char*)s, static_cast<unsigned int>(len), &encoded);
                lua_pushlstring(L, (const char*)encoded, length);
                free(encoded);
            }
            else
            {
                lua_pushstring(L, "");
            }
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.base64_decode", argc, 1);
        return 0;
    });

    game_utils_lua.set_function("base64_encode", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 1 && lua_isstring(L, 1))
        {
            size_t len  = 0;
            const char* s = lua_tolstring(L, 1, &len);
            if (len > 0)
            {
                char* decoded;
                int length = utils::base64Encode((unsigned char*)s, static_cast<unsigned int>(len), &decoded);
                lua_pushlstring(L, (const char*)decoded, length);
                free(decoded);
            }
            else
            {
                lua_pushstring(L, "");
            }
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.base64_encode", argc, 1);
        return 0;
    });

	game_utils_lua.set_function("md5", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 1 && lua_isstring(L, 1))
        {
            size_t len  = 0;
            const char* data = lua_tolstring(L, 1, &len);

            std::string hash = utils::getStringMD5Hash(std::string_view{data, len});

            lua_pushstring(L, hash.c_str());
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.md5", argc, 1);
        return 0;
    });

	game_utils_lua.set_function("md5_file", [](std::string filename) -> std::string {
        auto fullPath = FileUtils::getInstance()->fullPathForFilename(filename);
        if (fullPath.empty())
        {
            return std::string();
        }
        else
        {
            return utils::getFileMD5Hash(fullPath);
        }
    });

    game_utils_lua.set_function("sha256", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 1 && lua_isstring(L, 1))
        {
            size_t s_len  = 0;
            const char* s = lua_tolstring(L, 1, &s_len);

            static const unsigned int SHA_DIGEST_LENGTH = 32;

            unsigned char hashOutput[SHA_DIGEST_LENGTH];
            char hexOutput[(SHA_DIGEST_LENGTH << 1) + 1] = {0};

            calc_sha_256(hashOutput, s, s_len);

            for (int di = 0; di < SHA_DIGEST_LENGTH; ++di)
            {
                sprintf(hexOutput + di * 2, "%02x", hashOutput[di]);
            }

            lua_pushstring(L, hexOutput);
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.sha256", argc, 1);
        return 0;
    });

	game_utils_lua.set_function("resolve", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc >= 2 && lua_isstring(L, 1) && lua_isfunction(L, 2))
        {
            std::string hostname = lua_tostring(L, 1);
            LUA_FUNCTION handler = toluafix_ref_function(L, 2, 0);

            Director::getInstance()->getJobSystem()->enqueue([hostname, handler]() {
                std::vector<yasio::endpoint> eps;
                yasio::xxsocket::resolve_v4(eps, hostname.c_str());
                Director::getInstance()->getScheduler()->runOnAxmolThread([=]() {
                    LuaValueArray result;
                    for (auto& endpoint : eps)
                        result.push_back(LuaValue::stringValue(endpoint.to_string()));

                    auto stack = LuaEngine::getInstance()->getLuaStack();
                    stack->pushLuaValueArray(result);
                    stack->executeFunctionByHandler(handler, 1);
                    stack->removeScriptHandler(handler);
                });
            });
            lua_pushboolean(L, true);
            return 1;
        }
        lua_pushboolean(L, false);
        return 1;
    });

    game_utils_lua.set_function("compress", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 1 && lua_isstring(L, 1))
        {
            size_t s_len  = 0;
            const char* s = lua_tolstring(L, 1, &s_len);

            std::string data;
            auto ret = game_utils::compress(s, s_len, data, Z_DEFAULT_COMPRESSION);
            if (Z_OK == ret)
            {
                lua_pushboolean(L, true);
                lua_pushlstring(L, data.c_str(), data.size());
            }
            else
            {
                lua_pushboolean(L, false);
                lua_pushnumber(L, ret);
            }
            return 2;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.compress", argc, 1);
        return 0;
    });


    game_utils_lua.set_function("compress_to_file", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 2 && lua_isstring(L, 1) && lua_isstring(L, 2))
        {
            size_t s_len  = 0;
            const char* s = lua_tolstring(L, 1, &s_len);
            auto filepath = lua_tostring(L, 2);

            std::string data;
            auto ret = game_utils::compress(s, s_len, data, Z_DEFAULT_COMPRESSION);
            if (Z_OK == ret && FileUtils::getInstance()->writeBinaryToFile(data.c_str(), data.size(), filepath))
            {
                lua_pushboolean(L, true);
            }
            else
            {
                lua_pushboolean(L, false);
            }
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.compress_to_file", argc, 2);
        return 0;
    });

	game_utils_lua.set_function("compress_file_to_file", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 2 && lua_isstring(L, 1) && lua_isstring(L, 2))
        {
            auto targetFile = lua_tostring(L, 1);
            auto fullPath   = lua_tostring(L, 2);

            Data rawData;
            FileUtils::getInstance()->getContents(targetFile, &rawData);
            if (rawData.size() <= 0)
            {
                lua_pushboolean(L, false);
                return 1;
            }

            std::string data;
            auto ret = game_utils::compress((const char*)rawData.data(), rawData.size(), data, Z_DEFAULT_COMPRESSION);
            if (Z_OK == ret && FileUtils::getInstance()->writeBinaryToFile(data.c_str(), data.size(), fullPath))
            {
                lua_pushboolean(L, true);
            }
            else
            {
                lua_pushboolean(L, false);
            }
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.compress_file_to_file", argc, 2);
        return 0;
    });

    game_utils_lua.set_function("decompress", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 1 && lua_isstring(L, 1))
        {
            size_t s_len  = 0;
            const char* s = lua_tolstring(L, 1, &s_len);

            std::string data;
            auto ret = game_utils::decompress(s, s_len, data);
            if (Z_OK == ret)
            {
                lua_pushboolean(L, true);
                lua_pushlstring(L, data.c_str(), data.size());
            }
            else
            {
                lua_pushboolean(L, false);
                lua_pushnumber(L, ret);
            }
            return 2;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.decompress", argc, 1);
        return 0;
    });

    game_utils_lua.set_function("xxtea_encrypt", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 2 && lua_isstring(L, 1) && lua_isstring(L, 2))
        {
            size_t data_len = 0;
            const char* data = lua_tolstring(L, 1, &data_len);

            size_t key_len   = 0;
            const char* key = lua_tolstring(L, 2, &key_len);

            xxtea_long newLen     = 0;
            unsigned char* buffer = xxtea_encrypt((unsigned char*)data, static_cast<xxtea_long>(data_len), (unsigned char*)key, static_cast<xxtea_long>(key_len), &newLen);

            lua_pushlstring(L, (const char*)buffer, static_cast<size_t>(newLen));
            free(buffer);
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.xxtea_encrypt", argc, 2);
        return 0;
    });

    game_utils_lua.set_function("xxtea_decrypt", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 2 && lua_isstring(L, 1) && lua_isstring(L, 2))
        {
            size_t data_len  = 0;
            const char* data = lua_tolstring(L, 1, &data_len);

            size_t key_len  = 0;
            const char* key = lua_tolstring(L, 2, &key_len);

            xxtea_long newLen     = 0;
            unsigned char* buffer = xxtea_decrypt((unsigned char*)data, static_cast<xxtea_long>(data_len),
                                                  (unsigned char*)key, static_cast<xxtea_long>(key_len), &newLen);

            lua_pushlstring(L, (const char*)buffer, static_cast<size_t>(newLen));
            free(buffer);
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.xxtea_decrypt", argc, 2);
        return 0;
    });

    game_utils_lua.set_function("load_chunks", [](lua_State* L) -> int {
        auto argc = lua_gettop(L);
        if (argc == 1 && lua_isstring(L, 1))
        {
            const char* chunkName = lua_tostring(L, 1);
            if (FileUtils::getInstance()->isFileExist(chunkName))
            {
                auto ret = LuaEngine::getInstance()->getLuaStack()->loadChunksFromZIP(chunkName);
                lua_pushnumber(L, ret);
            }
            else
            {
                lua_pushnumber(L, -2);
            }
            return 1;
        }
        luaL_error(L, "%s has wrong number of arguments: %d, was expecting %d \n", "game_utils.load_chunks", argc, 1);
        return 0;
    });

	game_utils_lua.set_function("get_engine_cfg_info", [](lua_State* L) -> int {
        auto info = ax::Configuration::getInstance()->getInfo();
        lua_pushlstring(L, info.c_str(), info.size());
        return 1;
    });

	game_utils_lua.set_function("set_font_free_type_share_distance_field_enabled", [](bool value) {
        FontFreeType::setGlobalSDFEnabled(value);
    });

	game_utils_lua.set_function("set_font_free_type_stream_parsing_enabled", [](bool value) {
        FontFreeType::setStreamParsingEnabled(value);
    });
    
	game_utils_lua.set_function("is_font_free_type_stream_parsing_enabled", []()-> bool {
        return FontFreeType::isStreamParsingEnabled();
    });

#ifdef AX_PLATFORM_PC
    game_utils_lua.set("is_pc", true);
#else
    game_utils_lua.set("is_pc", false);
#endif

#if AX_OBJECT_LEAK_DETECTION
    ax::Object::setRefLockGuardEnabled(true);
    game_utils_lua.set_function("start_collecting", [](lua_State* L) -> int {
        ax::Object::startCollecting();
        return 0;
    });
    game_utils_lua.set_function("stop_collecting", [](lua_State* L) -> int {
        ax::Object::stopCollecting();
        return 0;
    });
    game_utils_lua.set_function("print_difference_snapshot", [](lua_State* L) -> int {
        ax::Object::printDifferenceSnapshot();
        return 0;
    });
#endif

    // clang-format on
}
