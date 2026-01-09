#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
}
#endif

void extension_manual_purge();

void register_extension_manual_tolua(lua_State* L);
