#pragma once

#include "Entity.h"
#include <vector>

namespace af
{
class System
{
public:
    System();

    virtual ~System();

    virtual void update(float dt);

    bool filtersMatch(const Signature& entitySignature) const;

    bool containsComponentType(ComponentTypeId typeId) const;

    bool isActive() const;

    void addRequiredComponent(ComponentTypeId typeId);

    std::string getName() const;

private:
    virtual void onEntityAdded(Entity* entity) {}

    virtual void onEntityRemoved(Entity* entity) {}

private:
    void addEntity(Entity* entity);

    void removeEntity(Entity* entity);

private:
    friend class ECSManager;
    Signature m_signature;
    std::vector<Entity*> m_entities;
    std::string m_name;
};

}  // namespace af
