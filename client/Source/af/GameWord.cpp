#include "GameWord.h"

namespace af
{

GameWord::GameWord() {}
GameWord::~GameWord() {}

bool GameWord::init()
{
    ecsManager = std::make_unique<ECSManager>();

    ecsManager->registerComponentType("Component_Move");
    ecsManager->registerComponentType("Component_Render");
    ecsManager->registerComponentType("Component_AI");

    auto player1 = ecsManager->newEntity();
    auto player2 = ecsManager->newEntity();

    player1->addComponent("Component_Move", new Component());
    player1->addComponent("Component_Render", new Component());
    player1->addComponent("Component_AI", new Component());

    player2->addComponent("Component_Render", new Component());
    player2->addComponent("Component_AI", new Component());

    auto systemRender = new System();
    systemRender->addRequiredComponent(ecsManager->getComponentType("Component_Move"));
    systemRender->addRequiredComponent(ecsManager->getComponentType("Component_Render"));
    ecsManager->addSystem(systemRender);

    printf("---------------------------------------------------[1]\n");

    // ecsManager->removeComponent(player1, "Component_Move");
    player1->destroy();
    player2->addComponent("Component_Move", new Component());

    printf("---------------------------------------------------[2]\n");

    return true;
}

void GameWord::update(float dt)
{
    ecsManager->update(dt);
}

}  // namespace af
