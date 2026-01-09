#include "Component.h"

namespace af
{

Component::Component()
{
    AF_ECS_OBJECT_GC_LOG("[%p] new Component\n", this);
}
Component::~Component()
{
    AF_ECS_OBJECT_GC_LOG("[%p] delete Component\n", this);
}

ComponentTypeId Component::getTypeId()
{
    return m_typeId;
}

}  // namespace af
