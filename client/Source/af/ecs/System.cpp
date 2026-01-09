#include "System.h"

namespace af
{
System::System()
{
    AF_ECS_LOG("[%p] new System\n", this);
}

System::~System()
{
    AF_ECS_LOG("[%p] System delete\n", this);
}

void System::update(float dt) {}

bool System::filtersMatch(const Signature& entitySignature) const
{
    return (entitySignature & m_signature) == m_signature;
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

void System::addEntity(Entity* entity)
{
#if _DEBUG
    for (auto* it : m_entities)
    {
        if (it == entity)
        {
            assert(false && "Entity already exists in the system.");
            return;
        }
    }
#endif
    m_entities.push_back(entity);
    onEntityAdded(entity);
    AF_ECS_LOG("[%p] onEntityAdded %p\n", this, entity);
}

void System::removeEntity(Entity* entity)
{
    for (auto it = m_entities.begin(); it != m_entities.end(); ++it)
    {
        if (*it == entity)
        {
            AF_ECS_LOG("[%p] onEntityRemoved %p\n", this, entity);
            onEntityRemoved(entity);
            m_entities.erase(it);
            break;
        }
    }
}

}  // namespace af
