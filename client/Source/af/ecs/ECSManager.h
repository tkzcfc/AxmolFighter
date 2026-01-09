#pragma once

#include "Types.h"
#include "Entity.h"
#include "System.h"
#include "Component.h"

namespace af
{
class ECSManager final
{
public:
    ECSManager();

    ~ECSManager();

    Entity* newEntity();

    Entity* getEntity(EntityId entityId);

    void destroyEntityById(EntityId entityId);

    void destroyEntity(Entity* entity);

    void addSystem(System* system);

    uint32_t registerComponentType(const std::string& name);

    uint32_t getComponentType(const std::string& name) const;

    void addComponent(Entity* entity, const std::string& name, Component* component);

    void removeComponent(Entity* entity, const std::string& name);

    void update(float dt);

private:
    void doRemoveEntities();

private:
    std::unordered_map<std::string, uint32_t> m_componentTypes;

    std::vector<System*> m_systems;
    std::vector<Entity*> m_entities;

    bool m_willRemoveEntities;
    EntityId m_nextEntityId;
};
}  // namespace af
