#include "Component.h"

namespace af
{

Component::Component()
{

    AF_ECS_LOG("[%p] new Component\n", this);
}
Component::~Component()
{
    AF_ECS_LOG("[%p] delete Component\n", this);
}

}  // namespace af
