#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
}
#endif

void register_net_tolua(lua_State* L);
