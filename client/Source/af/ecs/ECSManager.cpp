#include "ECSManager.h"

namespace af
{

ECSManager::ECSManager() : m_willRemoveEntities(false), m_nextEntityId(0)
{
    m_systems.reserve(20);
    m_entities.reserve(200);
}

ECSManager::~ECSManager()
{
    for (auto* it : m_entities)
    {
        it->m_pendingRemoval = true;
    }
    m_willRemoveEntities = true;
    doRemoveEntities();

    for (auto& it : m_systems)
    {
        delete it;
    }
}

Entity* ECSManager::newEntity()
{
    m_nextEntityId++;
    auto entity          = new Entity();
    entity->m_id         = m_nextEntityId;
    entity->m_ecsManager = this;
    m_entities.push_back(entity);
    return entity;
}

Entity* ECSManager::getEntity(EntityId entityId)
{
    for (auto& entity : m_entities)
    {
        if (entity->getId() == entityId)
        {
            return entity;
        }
    }
    return nullptr;
}

void ECSManager::destroyEntityById(EntityId entityId)
{
    destroyEntity(getEntity(entityId));
}

void ECSManager::destroyEntity(Entity* entity)
{
    if (entity)
    {
        entity->m_pendingRemoval = true;
        m_willRemoveEntities     = true;
    }
}

void ECSManager::addSystem(System* system)
{
    m_systems.push_back(system);

    for (auto entity : m_entities)
    {
        if (system->filtersMatch(entity->getSignature()))
        {
            system->addEntity(entity);
        }
    }
}

uint32_t ECSManager::registerComponentType(const std::string& name)
{
    assert(m_componentTypes.find(name) == m_componentTypes.end() && "Component type already registered.");

    uint32_t typeId        = static_cast<uint32_t>(m_componentTypes.size()) + 1;  // Start IDs from 1
    m_componentTypes[name] = typeId;
    return typeId;
}

uint32_t ECSManager::getComponentType(const std::string& name) const
{
    auto it = m_componentTypes.find(name);
    if (it != m_componentTypes.end())
    {
        return it->second;
    }
    assert(false && "Component type not registered.");
    return INVALID_COMPONENT_TYPE_ID;
}

void ECSManager::addComponent(Entity* entity, const std::string& name, Component* component)
{
    if (entity == nullptr)
    {
        assert(false && "Entity is null.");
        return;
    }
    component->m_typeId = getComponentType(name);

    if (entity->containsComponentByTypeId(component->m_typeId))
    {
        assert(false && "Entity already contains component of this type.");
        delete component;
        return;
    }

    entity->m_components.push_back(component);

    // Update entity signature in systems
    Signature entitySignature = entity->getSignature();
    for (auto* system : m_systems)
    {
        if (system->filtersMatch(entitySignature))
        {
            system->addEntity(entity);
        }
    }
}

void ECSManager::removeComponent(Entity* entity, const std::string& name)
{
    if (entity == nullptr)
    {
        assert(false && "Entity is null.");
        return;
    }

    auto typeId = getComponentType(name);

    for (auto it = entity->m_components.begin(); it != entity->m_components.end();)
    {
        if ((*it)->m_typeId == typeId)
        {
            for (auto* system : m_systems)
            {
                if (system->containsComponentType(typeId))
                {
                    system->removeEntity(entity);
                }
            }

            delete *it;
            it = entity->m_components.erase(it);
        }
        else
        {
            ++it;
        }
    }
}

void ECSManager::update(float dt)
{
    doRemoveEntities();

    for (auto system : m_systems)
    {
        if (system->isActive())
        {
            system->update(dt);
        }
    }
}

void ECSManager::doRemoveEntities()
{

    if (m_willRemoveEntities)
    {
        for (auto it = m_entities.begin(); it != m_entities.end();)
        {
            if ((*it)->m_pendingRemoval)
            {
                for (auto* system : m_systems)
                {
                    system->removeEntity(*it);
                }

                delete *it;
                it = m_entities.erase(it);
            }
            else
            {
                ++it;
            }
        }
        m_willRemoveEntities = false;
    }
}

}  // namespace af
