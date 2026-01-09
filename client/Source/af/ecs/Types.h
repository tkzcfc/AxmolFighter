#pragma once

#include <stdint.h>
#include <bitset>
#include <string>
#include <assert.h>
#include <vector>
#include <unordered_map>

namespace af
{
using EntityId                   = uint32_t;
const uint32_t INVALID_ENTITY_ID = 0;

using ComponentTypeId                           = uint8_t;
const ComponentTypeId INVALID_COMPONENT_TYPE_ID = 0;

const uint32_t MAX_SIGNATURES = 255;
using Signature               = std::bitset<MAX_SIGNATURES>;
}  // namespace af

#define AF_ECS_ENABLE_LOG 1

#if AF_ECS_ENABLE_LOG
#    define AF_ECS_LOG(...) printf(__VA_ARGS__)
#else
#    define AF_ECS_LOG(...)
#endif

#define AF_ECS_OBJECT_GC_LOG_ENABLED 0

#if AF_ECS_OBJECT_GC_LOG_ENABLED
#    define AF_ECS_OBJECT_GC_LOG(...) printf(__VA_ARGS__)
#else
#    define AF_ECS_OBJECT_GC_LOG(...)
#endif
