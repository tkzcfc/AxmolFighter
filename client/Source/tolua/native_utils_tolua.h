#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
}
#endif

void register_native_utils_tolua(lua_State* L);
