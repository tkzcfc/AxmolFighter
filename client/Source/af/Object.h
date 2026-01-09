#pragma once

#include <stdint.h>
#include <string>
#include <assert.h>
#include <vector>
#include <unordered_map>
#include <memory>
#include <unordered_set>

namespace af
{

class Object
{
public:
    Object();

    virtual ~Object();
};

extern std::unordered_set<Object*> g_objectGCSet;

}  // namespace af
