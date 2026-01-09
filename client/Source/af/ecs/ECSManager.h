#pragma once

#include "Types.h"
#include "Entity.h"
#include "System.h"
#include "Component.h"
#include <functional>

namespace af
{

class ECSManager;
using ComponentCreateFuncType = std::function<Component*()>;
using SystemCreateFuncType    = std::function<System*(ECSManager*)>;

class ECSManager : public Object
{
public:
    ECSManager();

    virtual ~ECSManager();

public:
    Entity* newEntity();

    Entity* getEntity(EntityId entityId);

    void destroyEntityById(EntityId entityId);

    void destroyEntity(Entity* entity);

public:
    void registerSystem(const std::string& name, const SystemCreateFuncType& createFunc);

    System* addSystem(const std::string& name);

public:
    void registerComponent(const std::string& name, const ComponentCreateFuncType& createFunc);

    uint32_t getComponentType(const std::string& name) const;

    const std::string& getComponentName(ComponentTypeId typeId) const;

    Component* addComponent(Entity* entity, const std::string& name);

    void removeComponent(Entity* entity, const std::string& name);

public:
    void update(float dt);

private:
    void doRemoveEntities();

private:
    struct ComponentMeta
    {
        uint32_t typeId;
        ComponentCreateFuncType createFunc;
    };
    std::unordered_map<std::string, ComponentMeta> m_componentMetas;

    struct SystemMeta
    {
        SystemCreateFuncType createFunc;
    };
    std::unordered_map<std::string, SystemMeta> m_systemMetas;

    std::vector<System*> m_systems;
    std::vector<Entity*> m_entities;

    bool m_willRemoveEntities;
    EntityId m_nextEntityId;
};
}  // namespace af
