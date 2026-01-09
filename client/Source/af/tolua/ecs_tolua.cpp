#include "ecs_tolua.h"
#include "af/ecs/ECSManager.h"

using namespace af;

void register_ecs_tolua(sol::table& af)
{
    // clang-format off

    // Entity
    af.new_usertype<Entity>(
        "Entity", sol::no_constructor,
        "getId", &Entity::getId,
        "addComponent", &Entity::addComponent,
        "removeComponent", &Entity::removeComponent,
        "containsComponent", &Entity::containsComponent,
        "containsComponentByTypeId", &Entity::containsComponentByTypeId,
        "getComponent", &Entity::getComponent,
        "getComponentByTypeId", &Entity::getComponentByTypeId,
        "isPendingRemoval", &Entity::isPendingRemoval,
        "destroy", &Entity::destroy);

    // System
    af.new_usertype<System>(
        "System", sol::no_constructor,
        "addRequiredComponent", &System::addRequiredComponent);

    // Component
    af.new_usertype<Component>(
        "Component", sol::no_constructor);

    // ECSManager
    af.new_usertype<ECSManager>(
        "ECSManager", sol::no_constructor,
        "newEntity", &ECSManager::newEntity,
        "getEntity", &ECSManager::getEntity,
        "destroyEntityById", &ECSManager::destroyEntityById,
        "destroyEntity", &ECSManager::destroyEntity,
        "addSystem", &ECSManager::addSystem,
        "getComponentType", &ECSManager::getComponentType,
        "addComponent", &ECSManager::addComponent,
        "removeComponent", &ECSManager::removeComponent,
        "update", &ECSManager::update);

    // clang-format on
}
