#pragma once

#include "yasio_client.h"
#include <unordered_set>
#include "ikcp.h"

typedef std::function<void(bool, const std::string_view&)> client_connect_callback;
typedef std::function<void()> client_disconnect_callback;
typedef std::function<void(bool, const std::string_view&)> client_request_callback;
typedef std::function<void(uint32_t, int, const std::string_view&)> client_recv_msg_callback;

class client
{
public:
    client() = delete;

    client(int maxChannelCount);

    ~client();

    void setHost(const std::string& host, int port);

    int connect(bool useTcp, const client_connect_callback& callback);

    void disconnect();

    int sendRequest(uint32_t target,
                    const char* data,
                    size_t length,
                    const client_request_callback& callback,
                    float timeout = 10.0f);

    int sendPush(uint32_t target, const char* data, size_t length);

    int sendTo(uint32_t target,
               int32_t serial,
               const char* data,
               size_t length,
               const client_request_callback& callback,
               float timeout);

    bool isBusy();

    bool isConnected();

    bool isWillDestroy();

    bool isOpened(uint32_t serverId);

    void setConnectCallback(const client_connect_callback& callback) { m_onConnectCallback = callback; }

    void setDisconnectCallback(const client_disconnect_callback& callback) { m_onDisconnectCallback = callback; }

    void addRecvMsgCallback(const client_recv_msg_callback& callback, const std::string& key);

    void removeRecvMsgCallback(const std::string& key);

    void cancelAllRequest(uint32_t target);

    void setCppServiceId(uint32_t id) { m_cppServiceId = id; }

    uint32_t getCppServiceId() { return m_cppServiceId; }

public:
    int getCurConnectionId() { return m_curConnectionId; }
    const std::vector<uint8_t>& getKcpSecret() { return m_kcpSecret; }

public:
    // 变长类型读取/写入
    static std::string wi32(int32_t value);
    static std::string wu32(uint32_t value);
    static std::string wi64(int64_t value);
    static std::string wu64(uint64_t value);
    static std::tuple<bool, int32_t, size_t> ri32(const std::string& value);
    static std::tuple<bool, uint32_t, size_t> ru32(const std::string& value);
    static std::tuple<bool, int64_t, size_t> ri64(const std::string& value);
    static std::tuple<bool, uint64_t, size_t> ru64(const std::string& value);

private:
    void onEvnet(int eventType, int id, const std::string_view& data);

    void onRecvTcpData(const std::string_view& data);

    void onRecvFirstUdpData(const std::string_view& data);

    void onRecvUdpData(const std::string_view& data);

    // 返回0:已处理完毕  <0出错,断线
    int onTargetMessage(uint32_t target, uint8_t* data, size_t& offset, size_t length);

    void timeoutCheck(float dt);

    void updateLogic(float dt);

    void clearInvalidCallbacks();

    enum State : uint8_t
    {
        Connecting,
        Connected,
        Disconnect
    };

private:
    std::string m_host;
    int m_port;
    int m_curConnectionId;
    bool m_useTcp;
    bool m_willDestroy;
    State m_state;

    std::vector<uint8_t> m_kcpSecret;
    std::vector<uint8_t> m_kcpRecvDataBuf;
    ikcpcb* m_kcp;
    float m_kcpWaitDur;

    yasio_client* m_impl;
    int32_t m_serial;
    uint32_t m_cppServiceId;
    std::unordered_set<uint32_t> m_openServerIds;

    struct RequestData
    {
        client_request_callback callback;
        float timeout;
        int target;
    };
    std::unordered_map<int32_t, RequestData> m_requestMap;

    client_connect_callback m_onConnectCallback;
    client_disconnect_callback m_onDisconnectCallback;

    struct RecvMsgCallbackData
    {
        client_recv_msg_callback callback;
        std::string key;
        bool removed;
    };
    std::vector<RecvMsgCallbackData> m_onRecvMsgCallbacks;
    bool m_recvMsgCallbackDirty;

    std::vector<client_request_callback> m_clientRequestCallbacks;
};
