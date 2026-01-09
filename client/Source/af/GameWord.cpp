#include "GameWord.h"

namespace af
{

GameWord::GameWord() {}
GameWord::~GameWord() {}

bool GameWord::init()
{
    ecsManager.registerComponent("Component_Move", []() { return new Component(); });
    ecsManager.registerComponent("Component_Render", []() { return new Component(); });
    ecsManager.registerComponent("Component_AI", []() { return new Component(); });
    ecsManager.registerSystem("RenderSystem", [](auto ecs) {
        auto system = new System();

        system->addRequiredComponent(ecs->getComponentType("Component_Move"));
        system->addRequiredComponent(ecs->getComponentType("Component_Render"));

        return system;
    });

    return true;
}

void GameWord::update(float dt)
{
    ecsManager.update(dt);
}

}  // namespace af
