#include "net_tolua.h"
#include "net/yasio_client.h"
#include "net/client.h"
#include "sol/sol.hpp"

void register_net_tolua(lua_State* L)
{
    // clang-format off
    sol::state_view lua(L);

    auto net              = lua["net"].get_or_create<sol::table>();
    auto lua_yasio_client = net.new_usertype<yasio_client>(
        "yasio_client", sol::constructors<yasio_client(int)>(),
        "connect", &yasio_client::connect,
        "disconnect", &yasio_client::disconnect,
        "send", sol::resolve<int(int, const char*, size_t)>(&yasio_client::send),
        "setEventCallback", &yasio_client::setEventCallback);

    // 静态方法,方便lua扩展选项
    lua_yasio_client.set_function("set_yasio_service_opt_callback",
                                  [](sol::main_protected_function callback) {
        yasio_client::on_yasio_service_opt_callback = callback.as<yasio_client_service_opt_callback_type>();
    });

    lua_yasio_client.set_function("setEventCallback",
                                  [](yasio_client& self, sol::main_protected_function callback) {
        return self.setEventCallback(callback.as<yasio_client_event_callback_type>());
    });

    auto lua_client = net.new_usertype<client>(
        "client", sol::constructors<client(int)>(),
        "setHost", &client::setHost,
        "disconnect", &client::disconnect,
        "sendPush", &client::sendPush,
        "isBusy", &client::isBusy,
        "isConnected", &client::isConnected,
        "isOpened", &client::isOpened,
        "setCppServiceId", &client::setCppServiceId,
        "getCppServiceId", &client::getCppServiceId,
        "isWillDestroy", &client::isWillDestroy,
        "wi32", &client::wi32, "wu32", &client::wu32,
        "wi64", &client::wi64, "wu64", &client::wu64,
        "ri32", &client::ri32, "ru32", &client::ru32,
        "ri64", &client::ri64, "ru64", &client::ru64);

    lua_client.set_function("connect", [](client& self, bool useTcp, sol::main_protected_function callback) {
        return self.connect(useTcp, callback.as<client_connect_callback>());
    });
    lua_client.set_function("sendTo", [](client& self, uint32_t target, int32_t serial, const char* data, size_t length,
                               sol::main_protected_function callback, float timeout) {
        return self.sendTo(target, serial, data, length, callback.as<client_request_callback>(), timeout);
    });
    lua_client.set_function("sendRequest", [](client& self, uint32_t target, const char* data, size_t length,
                               sol::main_protected_function callback, float timeout) {
        return self.sendRequest(target, data, length, callback.as<client_request_callback>(), timeout);
    });
    lua_client.set_function("setConnectCallback", [](client& self, sol::main_protected_function callback) {
        self.setConnectCallback(callback.as<client_connect_callback>());
    });
    lua_client.set_function("setDisconnectCallback", [](client& self, sol::main_protected_function callback) {
        self.setDisconnectCallback(callback.as<client_disconnect_callback>());
    });
    lua_client.set_function("addRecvMsgCallback", [](client& self, sol::main_protected_function callback, std::string key) {
        self.addRecvMsgCallback(callback.as<client_recv_msg_callback>(), key);
    });

    // clang-format on
}
