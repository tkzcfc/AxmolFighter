#include "af/tolua/af.h"
#include "ecs_tolua.h"
#include "game_world_tolua.h"

void register_af_tolua(lua_State* L)
{
    sol::state_view lua(L);
    auto af = lua["af"].get_or_create<sol::table>();
    register_ecs_tolua(af);
    register_game_world_tolua(af);
}
