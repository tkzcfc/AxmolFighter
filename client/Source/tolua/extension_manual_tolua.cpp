#include "extension_manual_tolua.h"
#include "fairygui/GCache.h"
#include "LuaBasicConversions.h"
#include "FairyGUI.h"
#include "sol/sol.hpp"
#include "curl/curl.h"

USING_NS_AX;

std::unordered_map<std::string, spine::AnimationStateData*> cacheStateData;
fairygui::GCache* pCache = NULL;

inline fairygui::GCache* getCache()
{
    if (pCache == NULL)
    {
        pCache = new fairygui::GCache();
    }
    return pCache;
}

static int tolua_create_batching_spine(lua_State* L)
{
    int argc = lua_gettop(L);
    if (argc >= 2 && lua_isstring(L, 1) && lua_isstring(L, 2))
    {
        auto skeletonDataFile = tolua_tostring(L, 1, 0);
        auto atlasFile        = tolua_tostring(L, 2, 0);

        auto pSkeletonData = getCache()->getOrCreateSkeletonData(skeletonDataFile, atlasFile);
        if (pSkeletonData == NULL)
        {
            return 0;
        }

        std::string key                       = std::string(skeletonDataFile) + std::string(atlasFile);
        spine::AnimationStateData* pStateData = NULL;

        auto it = cacheStateData.find(key);
        if (it == cacheStateData.end())
        {
            pStateData = new (__FILE__, __LINE__) spine::AnimationStateData(pSkeletonData);
            if (pStateData)
            {
                cacheStateData[key] = pStateData;
            }
        }
        else
        {
            pStateData = it->second;
        }

        if (lua_isboolean(L, 3) && lua_toboolean(L, 3) != 0)
        {
            return 0;
        }

        if (pStateData == NULL)
        {
            return 0;
        }

        auto skeletonNode = spine::SkeletonAnimation::createWithData(pSkeletonData, false);
        skeletonNode->setAnimationStateData(pStateData);
        if (skeletonNode == NULL)
        {
            return 0;
        }

        int ID     = (skeletonNode) ? (int)skeletonNode->_ID : -1;
        int* luaID = (skeletonNode) ? &skeletonNode->_luaID : NULL;
        toluafix_pushusertype_object(L, ID, luaID, (void*)skeletonNode, "ax.Node");
        return 1;
    }
    return 0;
}

static int tolua_clear_batching_spine_sache(lua_State* L)
{
    if (pCache)
    {
        delete pCache;
        pCache = NULL;
    }
    for (auto& it : cacheStateData)
    {
        delete it.second;
    }
    cacheStateData.clear();
    return 0;
}

static int tolua_get_node_children(lua_State* L)
{
    ax::Node* cobj = nullptr;
    cobj           = (ax::Node*)tolua_tousertype(L, 1, 0);
    if (cobj)
    {
        const ax::Vector<ax::Node*>& ret = cobj->getChildren();

        lua_newtable(L);

        int indexTable = 1;
        for (const auto& obj : ret)
        {
            if (nullptr == obj)
                continue;

            lua_pushnumber(L, (lua_Number)indexTable);
            int ID     = (obj) ? (int)obj->_ID : -1;
            int* luaID = (obj) ? &obj->_luaID : NULL;

            auto luaTypeName = getLuaTypeName(obj, nullptr);
            if (luaTypeName)
            {
                toluafix_pushusertype_object(L, ID, luaID, (void*)obj, luaTypeName);
            }
            else
            {
                toluafix_pushusertype_object(L, ID, luaID, (void*)obj, "ax.Node");
            }

            lua_rawset(L, -3);
            ++indexTable;
        }
        return 1;
    }
    return 0;
}

static int tolua_get_fgui_component_children(lua_State* L)
{
    fairygui::GComponent* cobj = nullptr;
    cobj                       = (fairygui::GComponent*)tolua_tousertype(L, 1, 0);
    if (cobj)
    {
        const ax::Vector<fairygui::GObject*>& ret = cobj->getChildren();

        lua_newtable(L);

        int indexTable = 1;
        for (const auto& obj : ret)
        {
            if (nullptr == obj)
                continue;

            lua_pushnumber(L, (lua_Number)indexTable);
            int ID     = (obj) ? (int)obj->_ID : -1;
            int* luaID = (obj) ? &obj->_luaID : NULL;

            auto luaTypeName = getLuaTypeName(obj, nullptr);
            if (luaTypeName)
            {
                toluafix_pushusertype_object(L, ID, luaID, (void*)obj, luaTypeName);
            }
            else
            {
                toluafix_pushusertype_object(L, ID, luaID, (void*)obj, "fairygui.GObject");
            }

            lua_rawset(L, -3);
            ++indexTable;
        }
        return 1;
    }
    return 0;
}

int lua_ax_base_Grid3D_getVertex(lua_State* tolua_S)
{
    int argc         = 0;
    ax::Grid3D* cobj = nullptr;
    bool ok          = true;

#if _AX_DEBUG >= 1
    tolua_Error tolua_err;
#endif

#if _AX_DEBUG >= 1
    if (!tolua_isusertype(tolua_S, 1, "ax.Grid3D", 0, &tolua_err))
        goto tolua_lerror;
#endif

    cobj = (ax::Grid3D*)tolua_tousertype(tolua_S, 1, 0);

#if _AX_DEBUG >= 1
    if (!cobj)
    {
        tolua_error(tolua_S, "invalid 'cobj' in function 'lua_ax_base_Grid3D_getVertex'", nullptr);
        return 0;
    }
#endif

    argc = lua_gettop(tolua_S) - 1;
    if (argc == 1)
    {
        ax::Vec2 arg0;

        ok &= luaval_to_vec2(tolua_S, 2, &arg0, "ax.Grid3D:getVertex");
        if (!ok)
        {
            tolua_error(tolua_S, "invalid arguments in function 'lua_ax_base_Grid3D_getVertex'", nullptr);
            return 0;
        }
        auto&& ret = cobj->getVertex(arg0);
        vec3_to_luaval(tolua_S, ret);
        return 1;
    }
    luaL_error(tolua_S, "%s has wrong number of arguments: %d, was expecting %d \n", "ax.Grid3D:getVertex", argc, 0);
    return 0;

#if _AX_DEBUG >= 1
tolua_lerror:
    tolua_error(tolua_S, "#ferror in function 'lua_ax_base_Grid3D_getVertex'.", &tolua_err);
#endif

    return 0;
}

int lua_ax_base_Grid3D_setVertex(lua_State* tolua_S)
{
    int argc         = 0;
    ax::Grid3D* cobj = nullptr;
    bool ok          = true;

#if _AX_DEBUG >= 1
    tolua_Error tolua_err;
#endif

#if _AX_DEBUG >= 1
    if (!tolua_isusertype(tolua_S, 1, "ax.Grid3D", 0, &tolua_err))
        goto tolua_lerror;
#endif

    cobj = (ax::Grid3D*)tolua_tousertype(tolua_S, 1, 0);

#if _AX_DEBUG >= 1
    if (!cobj)
    {
        tolua_error(tolua_S, "invalid 'cobj' in function 'lua_ax_base_Grid3D_setVertex'", nullptr);
        return 0;
    }
#endif

    argc = lua_gettop(tolua_S) - 1;
    if (argc == 2)
    {
        ax::Vec2 arg0;
        ax::Vec3 arg1;

        ok &= luaval_to_vec2(tolua_S, 2, &arg0, "ax.Grid3D:setVertex");
        if (!ok)
        {
            tolua_error(tolua_S, "invalid arguments in function 'lua_ax_base_Grid3D_setVertex'", nullptr);
            return 0;
        }

        ok &= luaval_to_vec3(tolua_S, 3, &arg1, "ax.Grid3D:setVertex");
        if (!ok)
        {
            tolua_error(tolua_S, "invalid arguments in function 'lua_ax_base_Grid3D_setVertex'", nullptr);
            return 0;
        }
        cobj->setVertex(arg0, arg1);
        return 0;
    }
    luaL_error(tolua_S, "%s has wrong number of arguments: %d, was expecting %d \n", "ax.Grid3D:setVertex", argc, 0);
    return 0;

#if _AX_DEBUG >= 1
tolua_lerror:
    tolua_error(tolua_S, "#ferror in function 'lua_ax_base_Grid3D_setVertex'.", &tolua_err);
#endif

    return 0;
}

int lua_ax_base_FileUtils_createDirectory(lua_State* tolua_S)
{
    int argc            = 0;
    ax::FileUtils* cobj = nullptr;
    bool ok             = true;

#if _AX_DEBUG >= 1
    tolua_Error tolua_err;
#endif

#if _AX_DEBUG >= 1
    if (!tolua_isusertype(tolua_S, 1, "ax.FileUtils", 0, &tolua_err))
        goto tolua_lerror;
#endif

    cobj = (ax::FileUtils*)tolua_tousertype(tolua_S, 1, 0);

#if _AX_DEBUG >= 1
    if (!cobj)
    {
        tolua_error(tolua_S, "invalid 'cobj' in function 'lua_ax_base_FileUtils_createDirectory'", nullptr);
        return 0;
    }
#endif

    argc = lua_gettop(tolua_S) - 1;
    if (argc == 1)
    {
        std::string_view arg0;

        ok &= luaval_to_std_string_view(tolua_S, 2, &arg0, "ax.FileUtils:createDirectory");
        if (!ok)
        {
            tolua_error(tolua_S, "invalid arguments in function 'lua_ax_base_FileUtils_createDirectory'", nullptr);
            return 0;
        }
        auto&& ret = cobj->createDirectories(arg0);
        tolua_pushboolean(tolua_S, (bool)ret);
        return 1;
    }
    luaL_error(tolua_S, "%s has wrong number of arguments: %d, was expecting %d \n", "ax.FileUtils:createDirectory",
               argc, 1);
    return 0;

#if _AX_DEBUG >= 1
tolua_lerror:
    tolua_error(tolua_S, "#ferror in function 'lua_ax_base_FileUtils_createDirectory'.", &tolua_err);
#endif

    return 0;
}

void extension_manual_purge()
{
    tolua_clear_batching_spine_sache(NULL);
}

void export_curl_code(lua_State* L)
{
    sol::state_view lua(L);
    auto lua_curl_code                              = lua["curl_code"].get_or_create<sol::table>();
    lua_curl_code["CURLE_OK"]                       = CURLcode::CURLE_OK;
    lua_curl_code["CURLE_UNSUPPORTED_PROTOCOL"]     = CURLcode::CURLE_UNSUPPORTED_PROTOCOL;
    lua_curl_code["CURLE_FAILED_INIT"]              = CURLcode::CURLE_FAILED_INIT;
    lua_curl_code["CURLE_URL_MALFORMAT"]            = CURLcode::CURLE_URL_MALFORMAT;
    lua_curl_code["CURLE_NOT_BUILT_IN"]             = CURLcode::CURLE_NOT_BUILT_IN;
    lua_curl_code["CURLE_COULDNT_RESOLVE_PROXY"]    = CURLcode::CURLE_COULDNT_RESOLVE_PROXY;
    lua_curl_code["CURLE_COULDNT_RESOLVE_HOST"]     = CURLcode::CURLE_COULDNT_RESOLVE_HOST;
    lua_curl_code["CURLE_COULDNT_CONNECT"]          = CURLcode::CURLE_COULDNT_CONNECT;
    lua_curl_code["CURLE_WEIRD_SERVER_REPLY"]       = CURLcode::CURLE_WEIRD_SERVER_REPLY;
    lua_curl_code["CURLE_REMOTE_ACCESS_DENIED"]     = CURLcode::CURLE_REMOTE_ACCESS_DENIED;
    lua_curl_code["CURLE_FTP_ACCEPT_FAILED"]        = CURLcode::CURLE_FTP_ACCEPT_FAILED;
    lua_curl_code["CURLE_FTP_WEIRD_PASS_REPLY"]     = CURLcode::CURLE_FTP_WEIRD_PASS_REPLY;
    lua_curl_code["CURLE_FTP_ACCEPT_TIMEOUT"]       = CURLcode::CURLE_FTP_ACCEPT_TIMEOUT;
    lua_curl_code["CURLE_FTP_WEIRD_PASV_REPLY"]     = CURLcode::CURLE_FTP_WEIRD_PASV_REPLY;
    lua_curl_code["CURLE_FTP_WEIRD_227_FORMAT"]     = CURLcode::CURLE_FTP_WEIRD_227_FORMAT;
    lua_curl_code["CURLE_FTP_CANT_GET_HOST"]        = CURLcode::CURLE_FTP_CANT_GET_HOST;
    lua_curl_code["CURLE_HTTP2"]                    = CURLcode::CURLE_HTTP2;
    lua_curl_code["CURLE_FTP_COULDNT_SET_TYPE"]     = CURLcode::CURLE_FTP_COULDNT_SET_TYPE;
    lua_curl_code["CURLE_PARTIAL_FILE"]             = CURLcode::CURLE_PARTIAL_FILE;
    lua_curl_code["CURLE_FTP_COULDNT_RETR_FILE"]    = CURLcode::CURLE_FTP_COULDNT_RETR_FILE;
    lua_curl_code["CURLE_OBSOLETE20"]               = CURLcode::CURLE_OBSOLETE20;
    lua_curl_code["CURLE_QUOTE_ERROR"]              = CURLcode::CURLE_QUOTE_ERROR;
    lua_curl_code["CURLE_HTTP_RETURNED_ERROR"]      = CURLcode::CURLE_HTTP_RETURNED_ERROR;
    lua_curl_code["CURLE_WRITE_ERROR"]              = CURLcode::CURLE_WRITE_ERROR;
    lua_curl_code["CURLE_OBSOLETE24"]               = CURLcode::CURLE_OBSOLETE24;
    lua_curl_code["CURLE_UPLOAD_FAILED"]            = CURLcode::CURLE_UPLOAD_FAILED;
    lua_curl_code["CURLE_READ_ERROR"]               = CURLcode::CURLE_READ_ERROR;
    lua_curl_code["CURLE_OUT_OF_MEMORY"]            = CURLcode::CURLE_OUT_OF_MEMORY;
    lua_curl_code["CURLE_OPERATION_TIMEDOUT"]       = CURLcode::CURLE_OPERATION_TIMEDOUT;
    lua_curl_code["CURLE_OBSOLETE29"]               = CURLcode::CURLE_OBSOLETE29;
    lua_curl_code["CURLE_FTP_PORT_FAILED"]          = CURLcode::CURLE_FTP_PORT_FAILED;
    lua_curl_code["CURLE_FTP_COULDNT_USE_REST"]     = CURLcode::CURLE_FTP_COULDNT_USE_REST;
    lua_curl_code["CURLE_OBSOLETE32"]               = CURLcode::CURLE_OBSOLETE32;
    lua_curl_code["CURLE_RANGE_ERROR"]              = CURLcode::CURLE_RANGE_ERROR;
    lua_curl_code["CURLE_OBSOLETE34"]               = CURLcode::CURLE_OBSOLETE34;
    lua_curl_code["CURLE_SSL_CONNECT_ERROR"]        = CURLcode::CURLE_SSL_CONNECT_ERROR;
    lua_curl_code["CURLE_BAD_DOWNLOAD_RESUME"]      = CURLcode::CURLE_BAD_DOWNLOAD_RESUME;
    lua_curl_code["CURLE_FILE_COULDNT_READ_FILE"]   = CURLcode::CURLE_FILE_COULDNT_READ_FILE;
    lua_curl_code["CURLE_LDAP_CANNOT_BIND"]         = CURLcode::CURLE_LDAP_CANNOT_BIND;
    lua_curl_code["CURLE_LDAP_SEARCH_FAILED"]       = CURLcode::CURLE_LDAP_SEARCH_FAILED;
    lua_curl_code["CURLE_OBSOLETE40"]               = CURLcode::CURLE_OBSOLETE40;
    lua_curl_code["CURLE_OBSOLETE41"]               = CURLcode::CURLE_OBSOLETE41;
    lua_curl_code["CURLE_ABORTED_BY_CALLBACK"]      = CURLcode::CURLE_ABORTED_BY_CALLBACK;
    lua_curl_code["CURLE_BAD_FUNCTION_ARGUMENT"]    = CURLcode::CURLE_BAD_FUNCTION_ARGUMENT;
    lua_curl_code["CURLE_OBSOLETE44"]               = CURLcode::CURLE_OBSOLETE44;
    lua_curl_code["CURLE_INTERFACE_FAILED"]         = CURLcode::CURLE_INTERFACE_FAILED;
    lua_curl_code["CURLE_OBSOLETE46"]               = CURLcode::CURLE_OBSOLETE46;
    lua_curl_code["CURLE_TOO_MANY_REDIRECTS"]       = CURLcode::CURLE_TOO_MANY_REDIRECTS;
    lua_curl_code["CURLE_UNKNOWN_OPTION"]           = CURLcode::CURLE_UNKNOWN_OPTION;
    lua_curl_code["CURLE_SETOPT_OPTION_SYNTAX"]     = CURLcode::CURLE_SETOPT_OPTION_SYNTAX;
    lua_curl_code["CURLE_OBSOLETE50"]               = CURLcode::CURLE_OBSOLETE50;
    lua_curl_code["CURLE_OBSOLETE51"]               = CURLcode::CURLE_OBSOLETE51;
    lua_curl_code["CURLE_GOT_NOTHING"]              = CURLcode::CURLE_GOT_NOTHING;
    lua_curl_code["CURLE_SSL_ENGINE_NOTFOUND"]      = CURLcode::CURLE_SSL_ENGINE_NOTFOUND;
    lua_curl_code["CURLE_SSL_ENGINE_SETFAILED"]     = CURLcode::CURLE_SSL_ENGINE_SETFAILED;
    lua_curl_code["CURLE_SEND_ERROR"]               = CURLcode::CURLE_SEND_ERROR;
    lua_curl_code["CURLE_RECV_ERROR"]               = CURLcode::CURLE_RECV_ERROR;
    lua_curl_code["CURLE_OBSOLETE57"]               = CURLcode::CURLE_OBSOLETE57;
    lua_curl_code["CURLE_SSL_CERTPROBLEM"]          = CURLcode::CURLE_SSL_CERTPROBLEM;
    lua_curl_code["CURLE_SSL_CIPHER"]               = CURLcode::CURLE_SSL_CIPHER;
    lua_curl_code["CURLE_PEER_FAILED_VERIFICATION"] = CURLcode::CURLE_PEER_FAILED_VERIFICATION;
    lua_curl_code["CURLE_BAD_CONTENT_ENCODING"]     = CURLcode::CURLE_BAD_CONTENT_ENCODING;
    lua_curl_code["CURLE_OBSOLETE62"]               = CURLcode::CURLE_OBSOLETE62;
    lua_curl_code["CURLE_FILESIZE_EXCEEDED"]        = CURLcode::CURLE_FILESIZE_EXCEEDED;
    lua_curl_code["CURLE_USE_SSL_FAILED"]           = CURLcode::CURLE_USE_SSL_FAILED;
    lua_curl_code["CURLE_SEND_FAIL_REWIND"]         = CURLcode::CURLE_SEND_FAIL_REWIND;
    lua_curl_code["CURLE_SSL_ENGINE_INITFAILED"]    = CURLcode::CURLE_SSL_ENGINE_INITFAILED;
    lua_curl_code["CURLE_LOGIN_DENIED"]             = CURLcode::CURLE_LOGIN_DENIED;
    lua_curl_code["CURLE_TFTP_NOTFOUND"]            = CURLcode::CURLE_TFTP_NOTFOUND;
    lua_curl_code["CURLE_TFTP_PERM"]                = CURLcode::CURLE_TFTP_PERM;
    lua_curl_code["CURLE_REMOTE_DISK_FULL"]         = CURLcode::CURLE_REMOTE_DISK_FULL;
    lua_curl_code["CURLE_TFTP_ILLEGAL"]             = CURLcode::CURLE_TFTP_ILLEGAL;
    lua_curl_code["CURLE_TFTP_UNKNOWNID"]           = CURLcode::CURLE_TFTP_UNKNOWNID;
    lua_curl_code["CURLE_REMOTE_FILE_EXISTS"]       = CURLcode::CURLE_REMOTE_FILE_EXISTS;
    lua_curl_code["CURLE_TFTP_NOSUCHUSER"]          = CURLcode::CURLE_TFTP_NOSUCHUSER;
    lua_curl_code["CURLE_OBSOLETE75"]               = CURLcode::CURLE_OBSOLETE75;
    lua_curl_code["CURLE_OBSOLETE76"]               = CURLcode::CURLE_OBSOLETE76;
    lua_curl_code["CURLE_SSL_CACERT_BADFILE"]       = CURLcode::CURLE_SSL_CACERT_BADFILE;
    lua_curl_code["CURLE_REMOTE_FILE_NOT_FOUND"]    = CURLcode::CURLE_REMOTE_FILE_NOT_FOUND;
    lua_curl_code["CURLE_SSH"]                      = CURLcode::CURLE_SSH;
    lua_curl_code["CURLE_SSL_SHUTDOWN_FAILED"]      = CURLcode::CURLE_SSL_SHUTDOWN_FAILED;
    lua_curl_code["CURLE_AGAIN"]                    = CURLcode::CURLE_AGAIN;
    lua_curl_code["CURLE_SSL_CRL_BADFILE"]          = CURLcode::CURLE_SSL_CRL_BADFILE;
    lua_curl_code["CURLE_SSL_ISSUER_ERROR"]         = CURLcode::CURLE_SSL_ISSUER_ERROR;
    lua_curl_code["CURLE_FTP_PRET_FAILED"]          = CURLcode::CURLE_FTP_PRET_FAILED;
    lua_curl_code["CURLE_RTSP_CSEQ_ERROR"]          = CURLcode::CURLE_RTSP_CSEQ_ERROR;
    lua_curl_code["CURLE_RTSP_SESSION_ERROR"]       = CURLcode::CURLE_RTSP_SESSION_ERROR;
    lua_curl_code["CURLE_FTP_BAD_FILE_LIST"]        = CURLcode::CURLE_FTP_BAD_FILE_LIST;
    lua_curl_code["CURLE_CHUNK_FAILED"]             = CURLcode::CURLE_CHUNK_FAILED;
    lua_curl_code["CURLE_NO_CONNECTION_AVAILABLE"]  = CURLcode::CURLE_NO_CONNECTION_AVAILABLE;
    lua_curl_code["CURLE_SSL_PINNEDPUBKEYNOTMATCH"] = CURLcode::CURLE_SSL_PINNEDPUBKEYNOTMATCH;
    lua_curl_code["CURLE_SSL_INVALIDCERTSTATUS"]    = CURLcode::CURLE_SSL_INVALIDCERTSTATUS;
    lua_curl_code["CURLE_HTTP2_STREAM"]             = CURLcode::CURLE_HTTP2_STREAM;
    lua_curl_code["CURLE_RECURSIVE_API_CALL"]       = CURLcode::CURLE_RECURSIVE_API_CALL;
    lua_curl_code["CURLE_AUTH_ERROR"]               = CURLcode::CURLE_AUTH_ERROR;
    lua_curl_code["CURLE_HTTP3"]                    = CURLcode::CURLE_HTTP3;
    lua_curl_code["CURLE_QUIC_CONNECT_ERROR"]       = CURLcode::CURLE_QUIC_CONNECT_ERROR;
    lua_curl_code["CURLE_PROXY"]                    = CURLcode::CURLE_PROXY;
    lua_curl_code["CURLE_SSL_CLIENTCERT"]           = CURLcode::CURLE_SSL_CLIENTCERT;
    lua_curl_code["CURLE_UNRECOVERABLE_POLL"]       = CURLcode::CURLE_UNRECOVERABLE_POLL;
    lua_curl_code["CURLE_TOO_LARGE"]                = CURLcode::CURLE_TOO_LARGE;
    lua_curl_code["CURLE_ECH_REQUIRED"]             = CURLcode::CURLE_ECH_REQUIRED;
}

void register_extension_manual_tolua(lua_State* L)
{
    {
        lua_pushstring(L, "ax.FileUtils");
        lua_rawget(L, LUA_REGISTRYINDEX);
        if (lua_istable(L, -1))
        {
            lua_pushstring(L, "createDirectory");
            lua_pushcfunction(L, lua_ax_base_FileUtils_createDirectory);
            lua_rawset(L, -3);
        }
        lua_pop(L, 1);
    }
    {
        tolua_usertype(L, "ax.Grid3D");
        tolua_cclass(L, "Grid3D", "ax.Grid3D", "ax.GridBase", nullptr);

        tolua_beginmodule(L, "Grid3D");
        tolua_function(L, "getVertex", lua_ax_base_Grid3D_getVertex);
        tolua_function(L, "setVertex", lua_ax_base_Grid3D_setVertex);
        tolua_endmodule(L);
    }

    sol::state_view lua(L);

    auto lua_game_utils = lua["game_utils"].get_or_create<sol::table>();

    lua_game_utils.set_function("create_batching_spine", tolua_create_batching_spine);
    lua_game_utils.set_function("clear_batching_spine_sache", tolua_clear_batching_spine_sache);
    lua_game_utils.set_function("get_node_children", tolua_get_node_children);
    lua_game_utils.set_function("get_fgui_component_children", tolua_get_fgui_component_children);

    export_curl_code(L);
}
