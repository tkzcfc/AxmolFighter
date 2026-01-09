#include "Entity.h"
#include "ECSManager.h"

namespace af
{

Entity::Entity() : m_pendingRemoval(false), m_id(INVALID_ENTITY_ID), m_ecsManager(nullptr)
{
    AF_ECS_LOG("[%p] new Entity\n", this);
    m_components.reserve(10);
}
Entity::~Entity()
{
    for (auto* it : m_components)
    {
        delete it;
    }
    AF_ECS_LOG("[%p] delete Entity\n", this);
}

EntityId Entity::getId() const
{
    return m_id;
}

void Entity::addComponent(const std::string& name, Component* component)
{
    m_ecsManager->addComponent(this, name, component);
}

void Entity::removeComponent(const std::string& name)
{
    m_ecsManager->removeComponent(this, name);
}

bool Entity::containsComponent(const std::string& name) const
{
    return getComponent(name) != nullptr;
}

bool Entity::containsComponentByTypeId(ComponentTypeId typeId) const
{
    return getComponentByTypeId(typeId) != nullptr;
}

Component* Entity::getComponent(const std::string& name) const
{
    for (auto* component : m_components)
    {
        if (component->m_typeId == m_ecsManager->getComponentType(name))
        {
            return component;
        }
    }
    return nullptr;
}

Component* Entity::getComponentByTypeId(ComponentTypeId typeId) const
{
    for (auto* component : m_components)
    {
        if (component->m_typeId == typeId)
        {
            return component;
        }
    }
    return nullptr;
}

bool Entity::isPendingRemoval() const
{
    return m_pendingRemoval;
}

Signature Entity::getSignature() const
{
    Signature signature;
    for (auto* comp : m_components)
    {
        signature.set(comp->m_typeId);
    }
    return signature;
}

void Entity::destroy()
{
#if _DEBUG
    assert(m_ecsManager != nullptr && "ECSManager is null.");
    assert(!m_pendingRemoval && "Entity is already pending removal.");
#endif
    m_ecsManager->destroyEntity(this);
}

}  // namespace af
