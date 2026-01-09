#include "System.h"

namespace af
{
System::System()
{
    AF_ECS_OBJECT_GC_LOG("[%p] new System\n", this);
}

System::~System()
{
    assert(m_entities.empty() && "System entities not fully removed.");
    AF_ECS_OBJECT_GC_LOG("[%p] System delete\n", this);
}

void System::update(float dt) {}

bool System::filtersMatch(const Signature& entitySignature) const
{
    return !m_signature.none() && !entitySignature.none() && ((entitySignature & m_signature) == m_signature);
}

bool System::containsComponentType(ComponentTypeId typeId) const
{
    return m_signature.test(static_cast<size_t>(typeId));
}

bool System::isActive() const
{
    return !m_entities.empty();
}

void System::addRequiredComponent(ComponentTypeId typeId)
{
    m_signature.set(static_cast<size_t>(typeId));
}

std::string System::getName() const
{
    return m_name;
}

void System::addEntity(Entity* entity)
{
    for (auto* it : m_entities)
    {
        if (it == entity)
        {
            return;
        }
    }
    m_entities.push_back(entity);
    onEntityAdded(entity);
    AF_ECS_LOG("[ECS] %s onEntityAdded [%u]\n", m_name.c_str(), entity->getId());
}

void System::removeEntity(Entity* entity)
{
    for (auto it = m_entities.begin(); it != m_entities.end(); ++it)
    {
        if (*it == entity)
        {
            AF_ECS_LOG("[ECS] %s onEntityRemoved [%u]\n", m_name.c_str(), entity->getId());
            onEntityRemoved(entity);
            m_entities.erase(it);
            break;
        }
    }
}

}  // namespace af
