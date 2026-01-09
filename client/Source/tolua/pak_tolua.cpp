#include "pak_tolua.h"
#include <spine/spine-axmol.h>
#include <spine/AttachmentVertices.h>
#include "spine/LuaSkeletonAnimation.h"
#include "LuaStack.h"
#include "LuaEngine.h"
#include "LuaBasicConversions.h"
#include "base/Utils.h"
#include "pak/pak.h"
#include "pak/decrypt_fileutils.h"
#include "lua-bindings/manual/tolua_fix.h"
#include "sol/sol.hpp"
#include "algorithms/sha-256.h"

USING_NS_AX;

using namespace spine;

class PakTextureLoader : public TextureLoader
{
public:
    PakTextureLoader();

    virtual ~PakTextureLoader();

    virtual void load(AtlasPage& page, const String& path);

    virtual void unload(void* texture);

    pak::PakArchive* _pakArchivePtr;
};

//////////////////////////////////////////////////////////////////// IMPLEMENTATION
/////////////////////////////////////////////////////////
/// PakTextureLoader

backend::SamplerAddressMode pak_sampler_wrap(TextureWrap wrap)
{
    return wrap == TextureWrap_ClampToEdge ? backend::SamplerAddressMode::CLAMP_TO_EDGE
                                           : backend::SamplerAddressMode::REPEAT;
}

backend::SamplerFilter pak_sampler_filter(TextureFilter filter)
{
    switch (filter)
    {
    case TextureFilter_Unknown:
        break;
    case TextureFilter_Nearest:
        return backend::SamplerFilter::NEAREST;
    case TextureFilter_Linear:
        return backend::SamplerFilter::LINEAR;
    case TextureFilter_MipMap:
        return backend::SamplerFilter::LINEAR;
    case TextureFilter_MipMapNearestNearest:
        return backend::SamplerFilter::NEAREST;
    case TextureFilter_MipMapLinearNearest:
        return backend::SamplerFilter::NEAREST;
    case TextureFilter_MipMapNearestLinear:
        return backend::SamplerFilter::LINEAR;
    case TextureFilter_MipMapLinearLinear:
        return backend::SamplerFilter::LINEAR;
    }
    return backend::SamplerFilter::LINEAR;
}

PakTextureLoader::PakTextureLoader() : TextureLoader() {}
PakTextureLoader::~PakTextureLoader() {}

void PakTextureLoader::load(AtlasPage& page, const spine::String& path)
{
    std::string key    = path.buffer();
    Texture2D* texture = Director::getInstance()->getTextureCache()->getTextureForKey(key);
    if (!texture)
    {
        do
        {
            AX_BREAK_IF(_pakArchivePtr == nullptr);

            Data data;
            if (_pakArchivePtr->getContents(key, &data) == ax::FileUtils::Status::OK)
            {
                Image* image = new Image();
                if (image && image->initWithImageData(data.getBytes(), data.getSize(), false))
                {
                    texture = Director::getInstance()->getTextureCache()->addImage(image, key);
                }
                AX_SAFE_RELEASE(image);
            }
        } while (false);
    }

    AXASSERT(texture != nullptr, "Invalid image");
    if (texture)
    {
        texture->retain();
        Texture2D::TexParams textureParams(pak_sampler_filter(page.minFilter), pak_sampler_filter(page.magFilter),
                                           pak_sampler_wrap(page.uWrap), pak_sampler_wrap(page.vWrap));
        texture->setTexParameters(textureParams);

        page.setRendererObject(texture);
        page.width  = texture->getPixelsWide();
        page.height = texture->getPixelsHigh();
    }
}

void PakTextureLoader::unload(void* texture)
{
    if (texture)
    {
        ((Texture2D*)texture)->release();
    }
}

static PakTextureLoader pakTextureLoader;

static LuaSkeletonAnimation* createSkeletonAnimation(pak::PakArchive* pakArchive,
                                                     const std::string& skeletonDataFile,
                                                     const std::string& atlasFile,
                                                     float scale)
{
    Data atlasFileData, skeletonFileData;
    if (pakArchive->getContents(atlasFile, &atlasFileData) != ax::FileUtils::Status::OK)
    {
        AXLOGE("Error reading atlas file: {}", atlasFile.c_str());
        return nullptr;
    }
    if (pakArchive->getContents(skeletonDataFile, &skeletonFileData) != ax::FileUtils::Status::OK)
    {
        AXLOGE("Error reading skeleton file: {}", skeletonDataFile.c_str());
        return nullptr;
    }

    pakTextureLoader._pakArchivePtr = pakArchive;

    //////////////////////////////////////////////
    // dir
    const char* path              = atlasFile.data();
    const char* lastForwardSlash  = strrchr(path, '/');
    const char* lastBackwardSlash = strrchr(path, '\\');
    const char* lastSlash         = lastForwardSlash > lastBackwardSlash ? lastForwardSlash : lastBackwardSlash;
    if (lastSlash == path)
        lastSlash++; /* Never drop starting slash. */
    auto dirLength = (int)(lastSlash ? lastSlash - path : 0);

    std::string dir;
    dir.resize(dirLength + 1);
    memcpy(dir.data(), path, dirLength);
    dir[dirLength] = '\0';
    //////////////////////////////////////////////

    auto pAtlas = new Atlas((const char*)atlasFileData.getBytes(), static_cast<int>(atlasFileData.getSize()),
                            dir.c_str(), &pakTextureLoader, true);
    AXASSERT(pAtlas, "Error reading atlas file.");

    if (pAtlas == nullptr)
        return nullptr;

    auto pAttachmentLoader      = new spine::Cocos2dAtlasAttachmentLoader(pAtlas);
    SkeletonData* pSkeletonData = NULL;

    if (FileUtils::getPathExtension(skeletonDataFile) == ".json")
    {
        SkeletonJson json(pAttachmentLoader, true);
        json.setScale(scale);

        pSkeletonData = json.readSkeletonData((const char*)skeletonFileData.getBytes());
        AXASSERT(pSkeletonData,
                 (json.getError().isEmpty() ? json.getError().buffer() : "Error reading skeleton data file."));
    }
    else
    {
        SkeletonBinary binary(pAttachmentLoader, true);
        binary.setScale(scale);

        pSkeletonData =
            binary.readSkeletonData((const unsigned char*)skeletonFileData.getBytes(), (int)skeletonFileData.getSize());
        AXASSERT(pSkeletonData,
                 (!binary.getError().isEmpty() ? binary.getError().buffer() : "Error reading skeleton data."));
    }
    AX_SAFE_DELETE(pAtlas);

    LuaSkeletonAnimation* skeletonAni = new LuaSkeletonAnimation();
    skeletonAni->initWithData(pSkeletonData, true);
    skeletonAni->autorelease();
    return skeletonAni;
}

static int axlua_CCSkeletonAnimation_createWithPackFile(lua_State* L)
{
    if (nullptr == L)
        return 0;

    int argc = 0;

#if _AX_DEBUG >= 1
    tolua_Error tolua_err;
    if (!tolua_isusertable(L, 1, "sp.SkeletonAnimation", 0, &tolua_err))
        goto tolua_lerror;
#endif

    argc = lua_gettop(L) - 1;

    if (3 == argc)
    {
#if _AX_DEBUG >= 1
        if (!tolua_isuserdata(L, 2, 0, &tolua_err) || !tolua_isstring(L, 3, 0, &tolua_err) ||
            !tolua_isstring(L, 4, 0, &tolua_err))
        {
            goto tolua_lerror;
        }
#endif
        pak::PakArchive* pakArchive  = (pak::PakArchive*)tolua_touserdata(L, 2, nullptr);
        const char* skeletonDataFile = tolua_tostring(L, 3, "");
        const char* atlasFile        = tolua_tostring(L, 4, "");

        auto tolua_ret = createSkeletonAnimation(pakArchive, skeletonDataFile, atlasFile, 1.0f);

        int nID     = (tolua_ret) ? (int)tolua_ret->_ID : -1;
        int* pLuaID = (tolua_ret) ? &tolua_ret->_luaID : NULL;
        toluafix_pushusertype_object(L, nID, pLuaID, (void*)tolua_ret, "sp.SkeletonAnimation");
        return 1;
    }
    else if (4 == argc)
    {
#if _AX_DEBUG >= 1
        if (!tolua_isuserdata(L, 2, 0, &tolua_err) || !tolua_isstring(L, 3, 0, &tolua_err) ||
            !tolua_isstring(L, 4, 0, &tolua_err) || !tolua_isnumber(L, 5, 0, &tolua_err))
        {
            goto tolua_lerror;
        }
#endif
        pak::PakArchive* pakArchive  = (pak::PakArchive*)tolua_touserdata(L, 2, nullptr);
        const char* skeletonDataFile = tolua_tostring(L, 3, "");
        const char* atlasFile        = tolua_tostring(L, 4, "");
        LUA_NUMBER scale             = tolua_tonumber(L, 5, 1);

        auto tolua_ret = createSkeletonAnimation(pakArchive, skeletonDataFile, atlasFile, scale);
        int nID        = (tolua_ret) ? (int)tolua_ret->_ID : -1;
        int* pLuaID    = (tolua_ret) ? &tolua_ret->_luaID : NULL;
        toluafix_pushusertype_object(L, nID, pLuaID, (void*)tolua_ret, "sp.SkeletonAnimation");
        return 1;
    }

    luaL_error(
        L, "'createWithPackFile' function of SkeletonAnimation has wrong number of arguments: %d, was expecting %d\n",
        argc, 2);

#if _AX_DEBUG >= 1
tolua_lerror:
    tolua_error(L, "#ferror in function 'createWithPackFile'.", &tolua_err);
#endif
    return 0;
}

void register_pak_tolua(lua_State* L)
{
    lua_pushstring(L, "sp.SkeletonAnimation");
    lua_rawget(L, LUA_REGISTRYINDEX);
    if (lua_istable(L, -1))
    {
        tolua_function(L, "createWithPackFile", axlua_CCSkeletonAnimation_createWithPackFile);
    }
    lua_pop(L, 1);

    // clang-format off
	sol::state_view lua(L);
	auto pak = lua["pak"].get_or_create<sol::table>();

	auto pakArchive = pak.new_usertype<pak::PakArchive>("PakArchive",
		sol::constructors<pak::PakArchive()>(),
		"init", &pak::PakArchive::init,
		"contains", &pak::PakArchive::contains,
		"getDataSecret", &pak::PakArchive::getDataSecret,
		"getVersion", &pak::PakArchive::getVersion,
		"getMntpoint", &pak::PakArchive::getMntpoint,
		"getCrc32Value", &pak::PakArchive::getCrc32Value,
		"isMounted", &pak::PakArchive::isMounted,
		"verifyCRC32", &pak::PakArchive::verifyCRC32,
		"getRawArchiveLocation", &pak::PakArchive::getRawArchiveLocation,
		"getArchiveLocation", &pak::PakArchive::getArchiveLocation
	);

	pakArchive.set_function("getContents", [](lua_State* L)->int {
		auto top = lua_gettop(L);
		if (top == 2)
		{
			sol::stack_object self_obj(L, 1);
			pak::PakArchive& self = self_obj.as<pak::PakArchive&>();

			const char* path = lua_tostring(L, 2);
			ax::Data data;
			self.getContents(path, &data);
			lua_pushlstring(L, (const char*)data.getBytes(), data.getSize());
			return 1;
		}
		luaL_error(L, "pak.PackArchive:getContents args error");
		return 0;
	});

	pakArchive.set_function("createSkeletonAnimation", [](lua_State* L)->int {
		auto top = lua_gettop(L);
		if (top >= 3)
		{
			sol::stack_object self_obj(L, 1);
			pak::PakArchive& self = self_obj.as<pak::PakArchive&>();

			const char* skeletonDataFile = tolua_tostring(L, 2, "");
			const char* atlasFile = tolua_tostring(L, 3, "");

			LUA_NUMBER scale = 1.0;
			if(top > 3 && lua_isnumber(L, 4))
				scale = tolua_tonumber(L, 4, 1);

			auto tolua_ret = createSkeletonAnimation(&self, skeletonDataFile, atlasFile, scale);
			int nID = (tolua_ret) ? (int)tolua_ret->_ID : -1;
			int* pLuaID = (tolua_ret) ? &tolua_ret->_luaID : NULL;
			toluafix_pushusertype_object(L, nID, pLuaID, (void*)tolua_ret, "sp.SkeletonAnimation");
			return 1;
		}
		luaL_error(L, "pak.PackArchive:createSkeletonAnimation args error");
		return 0;
	});

	pakArchive.set_function("require", [](lua_State* L)->int {
		sol::stack_object self_obj(L, 1);
		pak::PakArchive& self = self_obj.as<pak::PakArchive&>();

		sol::stack_object path_obj(L, 2);
		std::string relativePath = path_obj.as<std::string>();

		int args = lua_gettop(L);

		//  convert any '.' to '/'
		std::replace(relativePath.begin(), relativePath.end(), '.', '/');

		bool nofile = true;
		const char* arrExt[] = { ".lua", ".luac" };
		for (const char* ext : arrExt)
		{
			std::string path = self.getMntpoint() + relativePath + ext;
			if (self.contains(path))
			{
				relativePath = path;
				nofile = false;
				break;
			}
		}

		if (nofile)
		{
			relativePath = self.getMntpoint() + relativePath;
			luaL_error(L, "can not find file \"%s\" in pak archive", relativePath.c_str());
			return 0;
		}
		
		Data chunk;
		self.getContents(relativePath, &chunk);
		int nret = chunk.getSize() > 0 ? 1 : 0;
		if (nret)
		{
			LuaStack* stack = LuaEngine::getInstance()->getLuaStack();

			relativePath.insert(relativePath.begin(), '@');  // lua standard, add file chunck mark '@'
			if (stack->luaLoadBuffer(L, reinterpret_cast<const char*>(chunk.getBytes()), static_cast<int>(chunk.getSize()),
				relativePath.c_str()) != LUA_OK)
			{
				return lua_error(L);
			}

			// Check if there's an environment parameter (3rd argument)
			if (args >= 3 && lua_istable(L, 3))
			{
				// Set the environment for the loaded chunk
				lua_pushvalue(L, 3);  // Push the environment table
				lua_setupvalue(L, -2, 1);  // Set as first upvalue (_ENV)
			}

			if (lua_pcall(L, 0, LUA_MULTRET, 0) != LUA_OK)
			{
				//AXLOG("Error running script: %s", lua_tostring(L, -1));
				return lua_error(L);
			}
			return lua_gettop(L) - args;
		}
		else
		{
			luaL_error(L, "can not get file data of \"%s\"", relativePath.c_str());
		}
		return 0;
	});

	pakArchive.set_function("createTexture", [](lua_State* L)->int {
		auto top = lua_gettop(L);
		if (top >= 2)
		{
			sol::stack_object self_obj(L, 1);
			pak::PakArchive& self = self_obj.as<pak::PakArchive&>();

			const char* textureName = tolua_tostring(L, 2, "");
			Texture2D* texture = Director::getInstance()->getTextureCache()->getTextureForKey(textureName);

			if (texture == nullptr)
			{
				Data data;
				if (self.getContents(textureName, &data) == ax::FileUtils::Status::OK)
				{
					Image* image = new Image();
					if (image && image->initWithImageData(data.getBytes(), data.getSize(), false))
					{
						if (top > 2)
						{
							ax::backend::PixelFormat pixelFormat;
							if (!luaval_to_int32(L, 3, (int*)&pixelFormat, "pak.PackArchive:createTexture"))
							{
								pixelFormat = Texture2D::getDefaultAlphaPixelFormat();
							}
							texture = Director::getInstance()->getTextureCache()->addImage(image, textureName, pixelFormat);
						}
						else
						{
							texture = Director::getInstance()->getTextureCache()->addImage(image, textureName);
						}
					}
					AX_SAFE_RELEASE(image);
				}
			}

			int ID = (texture) ? (int)texture->_ID : -1;
			int* luaID = (texture) ? &texture->_luaID : nullptr;
			toluafix_pushusertype_object(L, ID, luaID, (void*)texture, "ax.Texture2D");
			return 1;
		}
		luaL_error(L, "pak.PackArchive:createSkeletonAnimation args error");
		return 0;
	});

	pakArchive.set_function("getFilesList", [](lua_State* L)->int {
		sol::stack_object self_obj(L, 1);
		pak::PakArchive& self = self_obj.as<pak::PakArchive&>();

		lua_newtable(L);
		int indexTable = 1;
		for (auto& file : self.getFilesList())
		{
			lua_pushnumber(L, (lua_Number)indexTable);
			lua_pushstring(L, file.c_str());
			lua_settable(L, -3);
			indexTable++;
		}

		return 1;
	});

	pakArchive.set_function("md5", [](lua_State* L)->int {
		sol::stack_object self_obj(L, 1);
		pak::PakArchive& self = self_obj.as<pak::PakArchive&>();

		sol::stack_object filename_obj(L, 2);
		std::string filename = filename_obj.as<std::string>();

		ax::Data data;
		self.getContents(filename, &data);

        std::string hash = utils::getDataMD5Hash(data);
        lua_pushstring(L, hash.c_str());

		return 1;
	});

	pakArchive.set_function("sha256", [](lua_State* L)->int {
		sol::stack_object self_obj(L, 1);
		pak::PakArchive& self = self_obj.as<pak::PakArchive&>();

		sol::stack_object filename_obj(L, 2);
		std::string filename = filename_obj.as<std::string>();

		ax::Data data;
		self.getContents(filename, &data);

		static const unsigned int SHA_DIGEST_LENGTH = 32;

        unsigned char hashOutput[SHA_DIGEST_LENGTH];
		char hexOutput[(SHA_DIGEST_LENGTH << 1) + 1] = { 0 };

		calc_sha_256(hashOutput, data.data(), (size_t)data.size());

		for (int di = 0; di < SHA_DIGEST_LENGTH; ++di) {
			sprintf(hexOutput + di * 2, "%02x", hashOutput[di]);
		}

		lua_pushstring(L, hexOutput);

		return 1;
	});

    /// DecryptFileUtils
    lua.new_usertype<DecryptFileUtils>("DecryptFileUtils",
        "enable", &DecryptFileUtils::enable,
        "mount", &DecryptFileUtils::mount,
        "unmount", &DecryptFileUtils::unmount
    );

    // clang-format on
}
