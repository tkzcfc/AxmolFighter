#pragma once

#include "axmol.h"
#include "ecs/ECSManager.h"

namespace af
{
class GameWord
{
public:
    GameWord();
    ~GameWord();

    bool init();

    void update(float dt);

    ECSManager ecsManager;
};

}  // namespace af
