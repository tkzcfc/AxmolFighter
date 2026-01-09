#include "native_utils_tolua.h"
#include "axmol.h"
#include "sol/sol.hpp"
#include "font/FontEngine.h"
#include "utils/native_utils.h"

using namespace ax;

void register_native_utils_tolua(lua_State* L)
{
    // clang-format off
    sol::state_view lua(L);

    // native_utils
    auto native_utils_lua = lua["native_utils"].get_or_create<sol::table>();
    native_utils_lua.set_function("get_command_line", [](lua_State* L) -> int {
        lua_newtable(L);
        int index = 1;
        for (auto& arg : native_utils::get_command_line())
        {
            lua_pushnumber(L, (lua_Number)index);
            lua_pushlstring(L, arg.c_str(), arg.size());
            lua_settable(L, -3);
            index++;
        }
        return 1;
    });
    native_utils_lua.set_function("get_executable_path", native_utils::get_executable_path);
    native_utils_lua.set_function("set_clipboard_string", native_utils::set_clipboard_string);
    native_utils_lua.set_function("get_clipboard_string", native_utils::get_clipboard_string);

    // ax.FontEngine
    auto ax_lua = lua["ax"].get_or_create<sol::table>();

    auto font_engine = ax_lua.new_usertype<FontEngine>(
        "FontEngine", sol::constructors<FontEngine()>(),
        "getInstance", &FontEngine::getInstance,
        "destroy", &FontEngine::destroy,
        "setFontEngine", &FontEngine::setFontEngine,
        "loadFont", &FontEngine::loadFont,
        "isLoadedFont", &FontEngine::isLoadedFont,
        "clearLoadedFonts", &FontEngine::clearLoadedFonts,
        "isAutoMatchSystemFontsByCharacter", &FontEngine::isAutoMatchSystemFontsByCharacter,
        "setAutoMatchSystemFontsByCharacter", &FontEngine::setAutoMatchSystemFontsByCharacter);

    font_engine.set_function("lookupSystemFontsByCharacter", [](lua_State* L) -> int {
        sol::stack_object self_obj(L, 1);
        FontEngine& self = self_obj.as<FontEngine&>();

        sol::stack_object codepoint_obj(L, 2);
        char32_t codepoint = static_cast<char32_t>(codepoint_obj.as<unsigned int>());

        FontStyle style = FontStyle::Normal();
        if (lua_gettop(L) >= 3)
        {
            sol::stack_table style_obj(L, 3);
            int weight = style_obj.get_or<int>("weight", FontStyle::kNormal_Weight);
            int width  = style_obj.get_or<int>("width", FontStyle::kNormal_Width);
            int slant  = style_obj.get_or<int>("slant", FontStyle::kUpright_Slant);
            style      = FontStyle(weight, width, (FontStyle::Slant)slant);
        }

        int num = 1;
        if (lua_gettop(L) >= 4)
        {
            sol::stack_object num_obj(L, 4);
            num = num_obj.as<int>();
        }

        lua_newtable(L);
        int indexTable = 1;
        for (auto& file : self.lookupSystemFontsByCharacter(codepoint, style, num))
        {
            lua_pushnumber(L, (lua_Number)indexTable);
            lua_pushstring(L, file.c_str());
            lua_settable(L, -3);
            indexTable++;
        }

        return 1;
    });

    font_engine.set_function("lookupSystemFontsByName", [](lua_State* L) -> int {
        sol::stack_object self_obj(L, 1);
        FontEngine& self = self_obj.as<FontEngine&>();

        sol::stack_object family_name_obj(L, 2);
        std::string family_name = family_name_obj.as<std::string>();

        FontStyle style = FontStyle::Normal();
        if (lua_gettop(L) >= 3)
        {
            sol::stack_table style_obj(L, 3);
            int weight = style_obj.get_or<int>("weight", FontStyle::kNormal_Weight);
            int width  = style_obj.get_or<int>("width", FontStyle::kNormal_Width);
            int slant  = style_obj.get_or<int>("slant", FontStyle::kUpright_Slant);
            style      = FontStyle(weight, width, (FontStyle::Slant)slant);
        }

        std::string fontPath = self.lookupSystemFontsByName(family_name, style);
        lua_pushstring(L, fontPath.c_str());
        return 1;
    });

    font_engine.set_function("loadSystemFont", [](lua_State* L) -> int {
        sol::stack_object self_obj(L, 1);
        FontEngine& self = self_obj.as<FontEngine&>();

        sol::stack_object family_name_obj(L, 2);
        std::string family_name = family_name_obj.as<std::string>();

        FontStyle style = FontStyle::Normal();
        if (lua_gettop(L) >= 3)
        {
            sol::stack_table style_obj(L, 3);
            int weight = style_obj.get_or<int>("weight", FontStyle::kNormal_Weight);
            int width  = style_obj.get_or<int>("width", FontStyle::kNormal_Width);
            int slant  = style_obj.get_or<int>("slant", FontStyle::kUpright_Slant);
            style      = FontStyle(weight, width, (FontStyle::Slant)slant);
        }

        bool ret = self.loadSystemFont(family_name, style);
        lua_pushboolean(L, (int)ret);
        return 1;
    });

    font_engine.set_function("setDefaultFontStyle", [](lua_State* L) -> int {
        sol::stack_object self_obj(L, 1);
        FontEngine& self = self_obj.as<FontEngine&>();

        sol::stack_table style_obj(L, 2);
        int weight = style_obj.get_or<int>("weight", FontStyle::kNormal_Weight);
        int width  = style_obj.get_or<int>("width", FontStyle::kNormal_Width);
        int slant  = style_obj.get_or<int>("slant", FontStyle::kUpright_Slant);
        auto style = FontStyle(weight, width, (FontStyle::Slant)slant);

        self.setDefaultFontStyle(style);
        return 0;
    });

    // clang-format on
}
