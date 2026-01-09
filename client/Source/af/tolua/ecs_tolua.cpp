#include "ecs_tolua.h"
#include "af/ecs/ECSManager.h"

using namespace af;

void register_ecs_tolua(sol::table& af)
{
    // clang-format off

    // Entity
    af.new_usertype<Entity>(
        "Entity", sol::no_constructor,
        LUA_METHOD_0(Entity, getId),
        LUA_METHOD_1(Entity, addComponent, const std::string&),
        LUA_METHOD_1(Entity, removeComponent, const std::string&),
        LUA_METHOD_1(Entity, containsComponent, const std::string&),
        LUA_METHOD_1(Entity, containsComponentByTypeId, ComponentTypeId),
        LUA_METHOD_1(Entity, getComponent, const std::string&),
        LUA_METHOD_1(Entity, getComponentByTypeId, ComponentTypeId),
        LUA_METHOD_0(Entity, isPendingRemoval),
        LUA_METHOD_0(Entity, destroy));

    // System
    af.new_usertype<System>(
        "System", sol::no_constructor,
        LUA_METHOD_1(System, addRequiredComponent, ComponentTypeId));

    // Component
    af.new_usertype<Component>(
        "Component", sol::no_constructor);

    // ECSManager
    af.new_usertype<ECSManager>(
        "ECSManager", sol::no_constructor,
        LUA_METHOD_0(ECSManager, newEntity),
        LUA_METHOD_1(ECSManager, getEntity, EntityId),
        LUA_METHOD_1(ECSManager, destroyEntityById, EntityId),
        LUA_METHOD_1(ECSManager, destroyEntity, Entity*),
        LUA_METHOD_1(ECSManager, addSystem, const std::string&),
        LUA_METHOD_1(ECSManager, getComponentType, const std::string&),
        LUA_METHOD_1(ECSManager, getComponentName, ComponentTypeId),
        LUA_METHOD_2(ECSManager, addComponent, Entity*, const std::string&),
        LUA_METHOD_2(ECSManager, removeComponent, Entity*, const std::string&),
        LUA_METHOD_1(ECSManager, update, float));

    // clang-format on
}
