#pragma once

#ifdef __cplusplus
extern "C" {
#endif
#include "tolua++.h"
#ifdef __cplusplus
}
#endif
#include "sol/sol.hpp"

#define USE_LUA_VALID_CHECK 1

#if USE_LUA_VALID_CHECK

#    define LUA_METHOD_VALID_CHECK(CLASS, SELF)              \
        if (!(g_objectGCSet).count(SELF))                    \
        {                                                    \
            throw std::runtime_error(#CLASS " has expired"); \
        }

#    define LUA_PROPERTY_VALID_CHECK(CLASS, SELF)            \
        if (!(g_objectGCSet).count(SELF))                    \
        {                                                    \
            throw std::runtime_error(#CLASS " has expired"); \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_0(CLASS, METHOD) \
        #METHOD, [](CLASS* self) {                       \
            LUA_METHOD_VALID_CHECK(CLASS, self);         \
            return self->METHOD();                       \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_1(CLASS, METHOD, ARG1_TYPE) \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1) {                  \
            LUA_METHOD_VALID_CHECK(CLASS, self);                    \
            return self->METHOD(arg1);                              \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_2(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE) \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1, ARG2_TYPE arg2) {             \
            LUA_METHOD_VALID_CHECK(CLASS, self);                               \
            return self->METHOD(arg1, arg2);                                   \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_3(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE) \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1, ARG2_TYPE arg2, ARG3_TYPE arg3) {        \
            LUA_METHOD_VALID_CHECK(CLASS, self);                                          \
            return self->METHOD(arg1, arg2, arg3);                                        \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_4(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE) \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1, ARG2_TYPE arg2, ARG3_TYPE arg3, ARG4_TYPE arg4) {   \
            LUA_METHOD_VALID_CHECK(CLASS, self);                                                     \
            return self->METHOD(arg1, arg2, arg3, arg4);                                             \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_5(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE)    \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1, ARG2_TYPE arg2, ARG3_TYPE arg3, ARG4_TYPE arg4, ARG5_TYPE arg5) { \
            LUA_METHOD_VALID_CHECK(CLASS, self);                                                                   \
            return self->METHOD(arg1, arg2, arg3, arg4, arg5);                                                     \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_6(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE,  \
                                          ARG6_TYPE)                                                             \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1, ARG2_TYPE arg2, ARG3_TYPE arg3, ARG4_TYPE arg4, ARG5_TYPE arg5, \
                    ARG6_TYPE arg6) {                                                                            \
            LUA_METHOD_VALID_CHECK(CLASS, self);                                                                 \
            return self->METHOD(arg1, arg2, arg3, arg4, arg5, arg6);                                             \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_7(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE,  \
                                          ARG6_TYPE, ARG7_TYPE)                                                  \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1, ARG2_TYPE arg2, ARG3_TYPE arg3, ARG4_TYPE arg4, ARG5_TYPE arg5, \
                    ARG6_TYPE arg6, ARG7_TYPE arg7) {                                                            \
            LUA_METHOD_VALID_CHECK(CLASS, self);                                                                 \
            return self->METHOD(arg1, arg2, arg3, arg4, arg5, arg6, arg7);                                       \
        }

#    define LUA_METHOD_WITH_VALID_CHECK_8(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE,  \
                                          ARG6_TYPE, ARG7_TYPE, ARG8_TYPE)                                       \
        #METHOD, [](CLASS* self, ARG1_TYPE arg1, ARG2_TYPE arg2, ARG3_TYPE arg3, ARG4_TYPE arg4, ARG5_TYPE arg5, \
                    ARG6_TYPE arg6, ARG7_TYPE arg7, ARG8_TYPE arg8) {                                            \
            LUA_METHOD_VALID_CHECK(CLASS, self);                                                                 \
            return self->METHOD(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8);                                 \
        }

#    define LUA_METHOD_0(CLASS, METHOD)            LUA_METHOD_WITH_VALID_CHECK_0(CLASS, METHOD)
#    define LUA_METHOD_1(CLASS, METHOD, ARG1_TYPE) LUA_METHOD_WITH_VALID_CHECK_1(CLASS, METHOD, ARG1_TYPE)
#    define LUA_METHOD_2(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE) \
        LUA_METHOD_WITH_VALID_CHECK_2(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE)
#    define LUA_METHOD_3(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE) \
        LUA_METHOD_WITH_VALID_CHECK_3(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE)
#    define LUA_METHOD_4(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE) \
        LUA_METHOD_WITH_VALID_CHECK_4(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE)
#    define LUA_METHOD_5(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE) \
        LUA_METHOD_WITH_VALID_CHECK_5(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE)
#    define LUA_METHOD_6(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE) \
        LUA_METHOD_WITH_VALID_CHECK_6(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE)
#    define LUA_METHOD_7(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE, ARG7_TYPE)   \
        LUA_METHOD_WITH_VALID_CHECK_7(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE, \
                                      ARG7_TYPE)
#    define LUA_METHOD_8(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE, ARG7_TYPE,   \
                         ARG8_TYPE)                                                                                    \
        LUA_METHOD_WITH_VALID_CHECK_8(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE, \
                                      ARG7_TYPE, ARG8_TYPE)

#    define LUA_PROPERTY_GET(CLASS, PROPERTY)      \
        #PROPERTY, sol::property([](CLASS* self) { \
            LUA_PROPERTY_VALID_CHECK(CLASS, self); \
            return self->PROPERTY;                 \
        })

#    define LUA_PROPERTY_GET_SET(CLASS, PROPERTY, VALUE_TYPE) \
        #PROPERTY, sol::property([](CLASS* self) {            \
            LUA_PROPERTY_VALID_CHECK(CLASS, self);            \
            return self->PROPERTY;                            \
        }, [](CLASS* self, VALUE_TYPE value) {                \
            LUA_PROPERTY_VALID_CHECK(CLASS, self);            \
            self->PROPERTY = value;                           \
        })

#else

#    define LUA_METHOD_0(CLASS, METHOD)                                                        #METHOD, &CLASS::METHOD
#    define LUA_METHOD_1(CLASS, METHOD, ARG1_TYPE)                                             #METHOD, &CLASS::METHOD
#    define LUA_METHOD_2(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE)                                  #METHOD, &CLASS::METHOD
#    define LUA_METHOD_3(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE)                       #METHOD, &CLASS::METHOD
#    define LUA_METHOD_4(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE)            #METHOD, &CLASS::METHOD
#    define LUA_METHOD_5(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE) #METHOD, &CLASS::METHOD
#    define LUA_METHOD_6(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE) \
        #METHOD, &CLASS::METHOD
#    define LUA_METHOD_7(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE, ARG7_TYPE) \
        #METHOD, &CLASS::METHOD
#    define LUA_METHOD_8(CLASS, METHOD, ARG1_TYPE, ARG2_TYPE, ARG3_TYPE, ARG4_TYPE, ARG5_TYPE, ARG6_TYPE, ARG7_TYPE, \
                         ARG8_TYPE)                                                                                  \
        #METHOD, &CLASS::METHOD

#    define LUA_PROPERTY_GET(CLASS, PROPERTY)                 #PROPERTY, sol::property([](CLASS* self) { return self->PROPERTY; })
#    define LUA_PROPERTY_GET_SET(CLASS, PROPERTY, VALUE_TYPE) #PROPERTY, &CLASS::PROPERTY

#endif
