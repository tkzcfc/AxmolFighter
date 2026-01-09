#include "game_world_tolua.h"
#include "af/GameWord.h"

using namespace af;

void register_game_world_tolua(sol::table& af)
{
    // clang-format off
    auto lua_game_world = af.new_usertype<GameWord>(
        "GameWord", sol::constructors<GameWord()>(),
        "init", &GameWord::init,
        "update", &GameWord::update);

    // clang-format on
}
