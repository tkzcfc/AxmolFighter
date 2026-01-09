#pragma once

#include "Types.h"
#include "Component.h"

namespace af
{
class ECSManager;
class Entity : public Object
{
public:
    Entity();

    virtual ~Entity();

    EntityId getId() const;

    Component* addComponent(const std::string& name);

    void removeComponent(const std::string& name);

    bool containsComponent(const std::string& name) const;

    bool containsComponentByTypeId(ComponentTypeId typeId) const;

    Component* getComponent(const std::string& name) const;

    Component* getComponentByTypeId(ComponentTypeId typeId) const;

    bool isPendingRemoval() const;

    Signature getSignature() const;

    void destroy();

private:
    friend class ECSManager;
    ECSManager* m_ecsManager;
    EntityId m_id;
    // Indicates whether the entity is marked for removal
    bool m_pendingRemoval;

    std::vector<Component*> m_components;
};

}  // namespace af
