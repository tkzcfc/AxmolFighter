#include "Object.h"

namespace af
{

std::unordered_set<Object*> g_objectGCSet;

Object::Object()
{
    g_objectGCSet.insert(this);
}

Object::~Object()
{
    g_objectGCSet.erase(this);
}

}  // namespace af
