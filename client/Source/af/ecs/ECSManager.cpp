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
        AF_ECS_LOG("[ECS] Destroy System: %s\n", it->getName().c_str());
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
    AF_ECS_LOG("[ECS] New Entity [%u] created.\n", entity->getId());
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

void ECSManager::registerSystem(const std::string& name, const SystemCreateFuncType& createFunc)
{
    assert(m_systemMetas.find(name) == m_systemMetas.end() && "System type already registered.");

    AF_ECS_LOG("[ECS] RegisterSystem: %s\n", name.c_str());
    SystemMeta meta;
    meta.createFunc     = createFunc;
    m_systemMetas[name] = meta;
}

System* ECSManager::addSystem(const std::string& name)
{
    auto it = m_systemMetas.find(name);
    if (it == m_systemMetas.end())
    {
        assert(false && "System type not registered.");
        return nullptr;
    }

    auto system = it->second.createFunc(this);
    assert(system != nullptr && "Failed to create system instance.");

    if (system == nullptr)
    {
        return nullptr;
    }

    AF_ECS_LOG("[ECS] Add System: %s\n", name.c_str());
    system->m_name = name;
    m_systems.push_back(system);

    for (auto entity : m_entities)
    {
        if (system->filtersMatch(entity->getSignature()))
        {
            system->addEntity(entity);
        }
    }

    return system;
}

void ECSManager::registerComponent(const std::string& name, const ComponentCreateFuncType& createFunc)
{
    assert(m_componentMetas.find(name) == m_componentMetas.end() && "Component type already registered.");

    ComponentMeta meta;
    meta.createFunc        = createFunc;
    meta.typeId            = static_cast<uint32_t>(m_componentMetas.size()) + 1;  // Start IDs from 1
    m_componentMetas[name] = meta;

    AF_ECS_LOG("[ECS] RegisterComponent: %s (typeId=%u)\n", name.c_str(), meta.typeId);
}

uint32_t ECSManager::getComponentType(const std::string& name) const
{
    auto it = m_componentMetas.find(name);
    if (it != m_componentMetas.end())
    {
        return it->second.typeId;
    }
    assert(false && "Component type not registered.");
    return INVALID_COMPONENT_TYPE_ID;
}

const std::string& ECSManager::getComponentName(ComponentTypeId typeId) const
{
    for (const auto& pair : m_componentMetas)
    {
        if (pair.second.typeId == typeId)
        {
            return pair.first;
        }
    }
    assert(false && "Component type ID not registered.");
    static const std::string unknown = "Unknown Component";
    return unknown;
}

Component* ECSManager::addComponent(Entity* entity, const std::string& name)
{
    if (entity == nullptr)
    {
        assert(false && "Entity is null.");
        return nullptr;
    }

    auto it = m_componentMetas.find(name);
    if (it == m_componentMetas.end())
    {
        assert(false && "Component type not registered.");
        return nullptr;
    }

    Component* component = it->second.createFunc();
    if (component == nullptr)
    {
        assert(false && "Failed to create component instance.");
        return nullptr;
    }

    component->m_typeId = it->second.typeId;

    if (entity->containsComponentByTypeId(component->m_typeId))
    {
        assert(false && "Entity already contains component of this type.");
        delete component;
        return nullptr;
    }

    AF_ECS_LOG("[ECS] Entity [%u] addComponent: %s (typeId=%u)\n", entity->getId(), name.c_str(), component->m_typeId);
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

    return component;
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
            AF_ECS_LOG("[ECS] Entity [%u] removeComponent: %s (typeId=%u)\n", entity->getId(), name.c_str(), typeId);
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
                auto entityId = (*it)->getId();
                delete *it;
                it = m_entities.erase(it);
                AF_ECS_LOG("[ECS] Destroy Entity [%u]\n", entityId);
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
