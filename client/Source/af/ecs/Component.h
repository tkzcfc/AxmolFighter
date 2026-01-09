#pragma once

#include "Types.h"

namespace af
{
class Component
{
public:
    Component();

    virtual ~Component();

private:
    friend class ECSManager;
    friend class Entity;
    ComponentTypeId m_typeId = INVALID_COMPONENT_TYPE_ID;
};

}  // namespace af
