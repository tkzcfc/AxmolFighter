#include "client.h"
#include "axmol.h"

using namespace ax;

// 生成指定长度的随机码并返回
inline std::vector<uint8_t> genSecret(int lenFrom = 5, int lenTo = 19)
{
    std::mt19937 rng(std::random_device{}());
    std::uniform_int_distribution<int> dis1(lenFrom, lenTo);  // 4: old protocol
    std::uniform_int_distribution<int> dis2(0, 255);
    auto siz = dis1(rng);

    std::vector<uint8_t> d;
    d.resize(siz);
    for (size_t i = 0; i < siz; i++)
    {
        d[i] = dis2(rng);
    }
    return d;
}

inline void xorContent(char const* s, size_t slen, char* b, size_t blen)
{
    auto e = b + blen;
    for (size_t i = 0; b < e; *b++ ^= s[i++])
    {
        if (i == slen)
            i = 0;
    }
}

inline void writeUint32InLittleEndian(void* memory, uint32_t value)
{
    uint8_t* p = (uint8_t*)memory;
    p[3]       = (uint8_t)(value >> 24);
    p[2]       = (uint8_t)(value >> 16);
    p[1]       = (uint8_t)(value >> 8);
    p[0]       = (uint8_t)(value);
}

inline bool readUint32InLittleEndian(uint32_t& out, uint8_t* buf, size_t& offset, size_t length)
{
    if (offset + 4 > length)
        return false;

    uint8_t* p = buf + offset;
    out        = (((uint32_t)p[3]) << 24) | (((uint32_t)p[2]) << 16) | (((uint32_t)p[1]) << 8) | (((uint32_t)p[0]));
    offset += 4;

    return true;
}

// 带符号整数 编码  return in < 0 ? (-in * 2 - 1) : (in * 2)
// inline uint16_t zigZagEncode(int16_t const& in)
//{
//	return (uint16_t)((in << 1) ^ (in >> 15));
//}
inline uint32_t zigZagEncode(int32_t const& in)
{
    return (in << 1) ^ (in >> 31);
}
inline uint64_t zigZagEncode(int64_t const& in)
{
    return (in << 1) ^ (in >> 63);
}

// 带符号整数 解码 return (in 为单数) ? -(in + 1) / 2 : in / 2
// inline int16_t zigZagDecode(uint16_t const& in)
//{
//	return (int16_t)((int16_t)(in >> 1) ^ (-(int16_t)(in & 1)));
//}
inline int32_t zigZagDecode(uint32_t const& in)
{
    return (int32_t)(in >> 1) ^ (-(int32_t)(in & 1));
}
inline int64_t zigZagDecode(uint64_t const& in)
{
    return (int64_t)(in >> 1) ^ (-(int64_t)(in & 1));
}

template <typename T, typename = std::enable_if_t<std::is_integral_v<T>>>
inline size_t writeVarInteger(uint8_t* buf, T const& v)
{
    using UT = std::make_unsigned_t<T>;
    UT u(v);
    if constexpr (std::is_signed_v<T>)
    {
        if constexpr (sizeof(T) <= 4)
            u = zigZagEncode(int32_t(v));
        else
            u = zigZagEncode(int64_t(v));
    }
    size_t len = 0;
    while (u >= 1 << 7)
    {
        buf[len++] = uint8_t((u & 0x7fu) | 0x80u);
        u          = UT(u >> 7);
    }
    buf[len++] = uint8_t(u);
    return len;
}

template <typename T>
inline bool readVarInteger(T& v, uint8_t* buf, size_t& offset, size_t length)
{
    using UT = std::make_unsigned_t<T>;
    UT u(0);
    for (size_t shift = 0; shift < sizeof(T) * 8; shift += 7)
    {
        if (offset == length)
            return false;

        auto b = (UT)buf[offset++];
        u |= UT((b & 0x7Fu) << shift);
        if ((b & 0x80) == 0)
        {
            if constexpr (std::is_signed_v<T>)
            {
                if constexpr (sizeof(T) <= 4)
                    v = zigZagDecode(uint32_t(u));
                else
                    v = zigZagDecode(uint64_t(u));
            }
            else
            {
                v = u;
            }
            return true;
        }
    }
    return false;
}

inline bool readString(std::string& str, uint8_t* buf, size_t& offset, size_t length)
{
    size_t strLen;
    if (!readVarInteger(strLen, buf, offset, length))
        return false;

    if (offset + strLen > length)
        return false;

    str.assign((char*)buf + offset, strLen);
    offset += strLen;

    return true;
}

static void defaultCallback(bool, const std::string_view&) {}

inline int64_t now()
{
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch())
        .count();
}

static int64_t lastTime = 0;
/////////////////////////////////////////////////////////////////////////////////////////////
/// client
/////////////////////////////////////////////////////////////////////////////////////////////

client::client(int maxChannelCount)
    : m_curConnectionId(-1)
    , m_serial(0)
    , m_onConnectCallback(nullptr)
    , m_onDisconnectCallback(nullptr)
    , m_cppServiceId(0xFFFFFFFF)
    , m_state(State::Disconnect)
    , m_port(0)
    , m_recvMsgCallbackDirty(false)
    , m_useTcp(true)
    , m_willDestroy(false)
    , m_kcp(nullptr)
    , m_kcpWaitDur(0.0f)
{
    m_impl = new yasio_client(maxChannelCount);
    m_impl->setEventCallback(
        std::bind(&client::onEvnet, this, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3));
    Director::getInstance()->getScheduler()->schedule([this](float dt) { this->timeoutCheck(dt); }, this, 0.5, false,
                                                      "#");
    Director::getInstance()->getScheduler()->schedule([this](float dt) { this->updateLogic(dt); }, this, 0.0, false,
                                                      "#update");
#ifdef AX_PLATFORM_PC
    lastTime = now();
#endif
}

client::~client()
{
    m_willDestroy = true;
    this->disconnect();
    delete m_impl;
    Director::getInstance()->getScheduler()->unscheduleAllForTarget(this);
}

void client::setHost(const std::string& host, int port)
{
    m_host = host;
    m_port = port;
}

int client::connect(bool useTcp, const client_connect_callback& callback)
{
    assert(m_state == State::Disconnect);
    m_useTcp            = useTcp;
    m_state             = State::Connecting;
    m_curConnectionId   = m_impl->connect(m_host, m_port, useTcp ? yasio::YCK_TCP_CLIENT : yasio::YCK_UDP_CLIENT);
    m_onConnectCallback = callback;
    m_kcpWaitDur        = 0.0f;
    AXLOGI("connect with {}...", useTcp ? "tcp" : "kcp");
    return m_curConnectionId;
}

void client::disconnect()
{
    for (auto it = m_requestMap.begin(); it != m_requestMap.end(); ++it)
    {
        it->second.timeout = 0.0f;
    }

    auto lastState = m_state;
    m_state        = State::Disconnect;
    if (m_curConnectionId != -1)
    {
        auto id           = m_curConnectionId;
        m_curConnectionId = -1;

        m_impl->disconnect(id);
    }
    if (m_kcp)
    {
        ikcp_release(m_kcp);
        m_kcp = nullptr;
    }
    m_kcpRecvDataBuf.clear();
    m_kcpSecret.clear();
    m_openServerIds.clear();

    // 正在连接中...
    if (lastState == State::Connecting)
    {
        if (m_onConnectCallback)
        {
            m_onConnectCallback(false, "user actively cancels the connection");
            m_onConnectCallback = nullptr;
        }
    }
    else if (lastState == State::Connected)
    {
        if (m_onDisconnectCallback)
        {
            m_onDisconnectCallback();
            m_onDisconnectCallback = nullptr;
        }
    }
}

bool client::isBusy()
{
    return m_state == State::Connecting;
}

bool client::isConnected()
{
    return m_curConnectionId != -1 && m_state == State::Connected;
}

bool client::isWillDestroy()
{
    return m_willDestroy;
}

bool client::isOpened(uint32_t serverId)
{
    if (m_openServerIds.empty())
        return false;
    return m_openServerIds.contains(serverId);
}
void client::addRecvMsgCallback(const client_recv_msg_callback& callback, const std::string& key)
{
    if (callback == nullptr)
        return;
    assert(!key.empty());
    RecvMsgCallbackData data;
    data.callback = callback;
    data.key      = key;
    data.removed  = false;
    m_onRecvMsgCallbacks.push_back(data);
}

void client::removeRecvMsgCallback(const std::string& key)
{
    for (auto& it : m_onRecvMsgCallbacks)
    {
        if (it.key == key)
        {
            it.removed             = true;
            m_recvMsgCallbackDirty = true;
        }
    }
}

void client::cancelAllRequest(uint32_t target)
{
    for (auto& it : m_requestMap)
    {
        if (it.second.target == target)
        {
            it.second.timeout  = 0.0f;
            it.second.callback = defaultCallback;
        }
    }
}

void client::onEvnet(int eventType, int id, const std::string_view& data)
{
    if (m_curConnectionId != id)
        return;

    bool isConnecting = (m_state == State::Connecting);
    m_state           = State::Connected;

    switch (eventType)
    {
    case yasio_client::event_type::OnConnectSuccess:
        if (m_useTcp)
        {
            if (m_onConnectCallback)
            {
                m_onConnectCallback(true, ""sv);
                m_onConnectCallback = nullptr;
            }
        }
        else
        {
            m_state = State::Connecting;
            m_kcpRecvDataBuf.reserve(1024 * 1024);
            m_kcpWaitDur = 0.0f;

            m_kcpSecret = genSecret();
            yasio::obstream obs;
            obs.write_bytes(m_kcpSecret.data(), (int)m_kcpSecret.size());
            m_impl->send(m_curConnectionId, obs);
        }
        break;
    case yasio_client::event_type::OnConnectFailed:
        m_state           = State::Disconnect;
        m_curConnectionId = -1;
        if (m_onConnectCallback)
        {
            m_onConnectCallback(false, data);
            m_onConnectCallback = nullptr;
        }
        break;

    case yasio_client::event_type::OnDisconnect:
        m_state           = State::Disconnect;
        m_curConnectionId = -1;
        if (isConnecting)
        {
            if (m_onConnectCallback)
            {
                m_onConnectCallback(false, data);
                m_onConnectCallback = nullptr;
            }
        }
        else
        {
            if (m_onDisconnectCallback)
            {
                m_onDisconnectCallback();
                m_onDisconnectCallback = nullptr;
            }
        }
        break;

    case yasio_client::event_type::OnRecvData:
        if (m_useTcp)
        {
            onRecvTcpData(data);
        }
        else
        {
            if (isConnecting)
            {
                onRecvFirstUdpData(data);
            }
            else
            {
                onRecvUdpData(data);
            }
        }

        break;
    }
}

void client::onRecvTcpData(const std::string_view& data)
{
    uint8_t* p    = (uint8_t*)data.data();
    size_t length = data.length();

    size_t offset   = 0;
    uint32_t target = 0;
    if (readUint32InLittleEndian(target, p, offset, length))
    {
        auto result = onTargetMessage(target, p, offset, length);
        if (result < 0)
        {
            AXLOGE("onTargetMessage error:{}", result);
            this->disconnect();
        }
    }
    else
    {
        AXLOGE("readUint32InLittleEndian error");
        this->disconnect();
    }
}

void client::onRecvFirstUdpData(const std::string_view& data)
{
    if (m_kcpSecret.empty())
    {
        m_state = State::Connecting;
        return;
    }

    size_t resultLen = m_kcpSecret.size() + 4;

    if (data.length() >= resultLen && memcmp(m_kcpSecret.data(), data.data() + 4, m_kcpSecret.size()) == 0)
    {
        // init kcp
        uint32_t kcpConv;
        memcpy(&kcpConv, data.data(), 4);
        m_kcp = ikcp_create(kcpConv, this);
        (void)ikcp_wndsize(m_kcp, 1024, 1024);
        (void)ikcp_nodelay(m_kcp, 1, 10, 2, 1);
        m_kcp->rx_minrto = 10;
        m_kcp->stream    = 1;
        // ikcp_setmtu(m_kcp, 470);    // maybe speed up because small package first role
        ikcp_setoutput(m_kcp, [](const char* inBuf, int len, ikcpcb* _, void* userdata) -> int {
            client* self = (client*)userdata;

            std::vector<uint8_t> binary;
            binary.resize(len);
            memcpy(binary.data(), inBuf, 4);

            auto& secret     = self->getKcpSecret();
            size_t secretLen = secret.size();
            size_t j         = 0;
            for (size_t i = 4; i < len; i++)
            {
                binary[i] = inBuf[i] ^ secret[j++];
                if (j == secretLen)
                {
                    j = 0;
                }
            }

            yasio::obstream obs;
            obs.write_bytes(binary.data(), (int)binary.size());
            self->m_impl->send(self->getCurConnectionId(), obs);

            return 0;
        });

        m_state = State::Connected;
        if (m_onConnectCallback)
        {
            m_onConnectCallback(true, ""sv);
            m_onConnectCallback = nullptr;
        }

        char buf[]  = {1, 0, 0, 0, 0};
        auto result = ikcp_send(m_kcp, buf, sizeof(buf));
        assert(!result);
        ikcp_flush(m_kcp);
    }
    else
    {
        AXLOGE("onRecvFirstUdpData error");
        m_state           = State::Disconnect;
        m_curConnectionId = -1;
        if (m_onConnectCallback)
        {
            m_onConnectCallback(false, data);
            m_onConnectCallback = nullptr;
        }
    }
}

void client::onRecvUdpData(const std::string_view& data)
{
    if (m_kcp == nullptr)
        return;

    if (data.size() > 4)
    {
        xorContent((const char*)m_kcpSecret.data(), m_kcpSecret.size(), (char*)data.data() + 4, data.length() - 4);
    }

    if (int result = ikcp_input(m_kcp, (const char*)data.data(), (long)data.length()))
    {
        AXLOGE("kcp_input error:%d", result);
        this->disconnect();
    }
    else
    {
        do
        {
            auto peeksize = ikcp_peeksize(m_kcp);
            if (peeksize <= 0)
                break;

            char* buf = (char*)malloc(peeksize);
            if (buf == NULL)
            {
                AXLOGE("ikcp_recv malloc error");
                this->disconnect();
                break;
            }
            auto recvLen = ikcp_recv(m_kcp, buf, peeksize);
            if (recvLen <= 0)
            {
                free(buf);
                AXLOGE("ikcp_recv error:%d", recvLen);
                this->disconnect();
                break;
            }

            assert(recvLen == peeksize);

            for (int i = 0; i < recvLen; ++i)
            {
                m_kcpRecvDataBuf.push_back(buf[i]);
            }
            free(buf);

            while (m_kcpRecvDataBuf.size() > 4)
            {
                uint32_t len = m_kcpRecvDataBuf[0] + (m_kcpRecvDataBuf[1] << 8) + (m_kcpRecvDataBuf[2] << 16) +
                               (m_kcpRecvDataBuf[3] << 24);
                if (m_kcpRecvDataBuf.size() >= len + 4)
                {
                    onRecvTcpData(std::string_view(reinterpret_cast<char*>(m_kcpRecvDataBuf.data() + 4), len));
                    if (m_state == State::Connected)
                    {
                        size_t remaining = m_kcpRecvDataBuf.size() - len - 4;
                        if (remaining == 0)
                        {
                            m_kcpRecvDataBuf.clear();
                        }
                        else
                        {
                            buf = (char*)malloc(remaining);
                            memcpy(buf, &m_kcpRecvDataBuf[4 + len], remaining);

                            m_kcpRecvDataBuf.resize(remaining);
                            memcpy(m_kcpRecvDataBuf.data(), buf, remaining);

                            free(buf);
                        }
                    }
                }
                else
                {
                    break;
                }
            }
        } while (m_state != State::Disconnect);
    }
}

// 返回0:已处理完毕  <0出错,断线
int client::onTargetMessage(uint32_t target, uint8_t* data, size_t& offset, size_t length)
{
    // command
    if (target == 0xFFFFFFFF)
    {
        std::string command;
        if (!readString(command, data, offset, length))
            return -__LINE__;

        if (command == "open" || command == "close")
        {
            uint32_t serviceId = -1;
            if (!readVarInteger(serviceId, data, offset, length))
                return -__LINE__;

            if (command == "open")
                m_openServerIds.insert(serviceId);
            else
            {
                m_openServerIds.erase(serviceId);

                m_clientRequestCallbacks.clear();
                for (auto it = m_requestMap.begin(); it != m_requestMap.end();)
                {
                    if (it->second.target == serviceId)
                    {
                        m_clientRequestCallbacks.emplace_back(it->second.callback);
                        it = m_requestMap.erase(it);
                    }
                    else
                    {
                        ++it;
                    }
                }

                for (auto&& callback : m_clientRequestCallbacks)
                {
                    callback(false, "service close"sv);
                }
                m_clientRequestCallbacks.clear();
            }
            return m_openServerIds.empty() ? -__LINE__ : 0;
        }

        return 0;
    }

    // 读出序号
    int32_t serial;
    if (!readVarInteger(serial, data, offset, length))
        return -__LINE__;

    // response
    if (serial > 0)
    {
        auto it = m_requestMap.find(serial);
        if (it != m_requestMap.end())
        {
            auto callback = it->second.callback;
            m_requestMap.erase(it);
            callback(true, std::string_view((char*)data + offset, length - offset));
        }
    }

    clearInvalidCallbacks();
    for (auto& it : m_onRecvMsgCallbacks)
    {
        if (!it.removed)
        {
            it.callback(target, serial, std::string_view((char*)data + offset, length - offset));
        }
    }

    return 0;
}

int client::sendRequest(uint32_t target,
                        const char* data,
                        size_t length,
                        const client_request_callback& callback,
                        float timeout)
{
    if (m_serial >= INT32_MAX)
        m_serial = 0;

    m_serial++;
    return this->sendTo(target, -m_serial, data, length, callback, timeout);
}

int client::sendPush(uint32_t target, const char* data, size_t length)
{
    return this->sendTo(target, 0, data, length, nullptr, 10.0f);
}

int client::sendTo(uint32_t target,
                   int32_t serial,
                   const char* data,
                   size_t length,
                   const client_request_callback& callback,
                   float timeout)
{
    if (m_curConnectionId == -1)
        return -1;

    yasio::obstream obs;
    obs.buffer().reserve(length + 16);

    uint8_t buf1[8];
    uint8_t buf2[4];

    // 序号（变长i32）
    auto intLength = writeVarInteger(buf1, serial);

    // 写入包长
    writeUint32InLittleEndian(buf2, 4U + static_cast<uint32_t>(length) + static_cast<uint32_t>(intLength));
    obs.write_bytes(buf2, sizeof(uint32_t));

    // 写入目标服务器
    writeUint32InLittleEndian(buf2, target);
    obs.write_bytes(buf2, sizeof(uint32_t));

    // 写入序号
    obs.write_bytes(buf1, static_cast<int>(intLength));

    // 写入数据
    obs.write_bytes(data, static_cast<int>(length));

    if (serial < 0)
    {
        RequestData requestData;
        requestData.callback = callback == nullptr ? defaultCallback : callback;
        requestData.timeout  = timeout;
        requestData.target   = target;
        m_requestMap.emplace(-serial, requestData);
    }

    if (m_useTcp)
    {
        return m_impl->send(m_curConnectionId, obs);
    }
    else
    {
        if (m_kcp)
        {
            auto result = ikcp_send(m_kcp, obs.data(), (int)obs.length());
            assert(!result);
            ikcp_flush(m_kcp);
            return 0;
        }
        else
        {
            return -1;
        }
    }
}

void client::timeoutCheck(float dt)
{
#ifdef AX_PLATFORM_PC
    auto n   = now();
    dt       = (n - lastTime) / 1000.0f;
    lastTime = n;
#endif
    m_clientRequestCallbacks.clear();
    for (auto it = m_requestMap.begin(); it != m_requestMap.end();)
    {
        it->second.timeout -= dt;

        if (it->second.timeout <= 0)
        {
            m_clientRequestCallbacks.emplace_back(it->second.callback);
            it = m_requestMap.erase(it);
        }
        else
        {
            ++it;
        }
    }

    if (!m_clientRequestCallbacks.empty())
    {
        for (auto&& callback : m_clientRequestCallbacks)
        {
            callback(false, "timeout"sv);
        }
        m_clientRequestCallbacks.clear();
    }

    clearInvalidCallbacks();
}

void client::updateLogic(float dt)
{
    if (m_useTcp)
        return;

    if (m_state == State::Connecting)
    {
        m_kcpWaitDur += dt;
        if (m_kcpWaitDur >= 4.0f)
        {
            m_state           = State::Disconnect;
            m_curConnectionId = -1;
            if (m_onConnectCallback)
            {
                m_onConnectCallback(false, "kcp connect timeout");
                m_onConnectCallback = nullptr;
            }
        }
    }
    else
    {
        if (m_kcp)
        {
            uint64_t current = now();
            ikcp_update(m_kcp, (IUINT32)(current & 0xfffffffful));
        }
    }
}

void client::clearInvalidCallbacks()
{
    if (!m_recvMsgCallbackDirty)
        return;

    for (auto it = m_onRecvMsgCallbacks.begin(); it != m_onRecvMsgCallbacks.end();)
    {
        if (it->removed)
            it = m_onRecvMsgCallbacks.erase(it);
        else
            ++it;
    }
    m_recvMsgCallbackDirty = false;
}

std::string client::wi32(int32_t value)
{
    uint8_t buf[8] = {0};
    auto len       = writeVarInteger(buf, value);
    return std::string((char*)buf, len);
}

std::string client::wu32(uint32_t value)
{
    uint8_t buf[8] = {0};
    auto len       = writeVarInteger(buf, value);
    return std::string((char*)buf, len);
}

std::string client::wi64(int64_t value)
{
    uint8_t buf[16] = {0};
    auto len        = writeVarInteger(buf, value);
    return std::string((char*)buf, len);
}

std::string client::wu64(uint64_t value)
{
    uint8_t buf[16] = {0};
    auto len        = writeVarInteger(buf, value);
    return std::string((char*)buf, len);
}

std::tuple<bool, int32_t, size_t> client::ri32(const std::string& data)
{
    int32_t value = 0;
    size_t offset = 0;
    bool ok       = readVarInteger(value, (uint8_t*)data.data(), offset, data.length());
    return {ok, value, offset};
}

std::tuple<bool, uint32_t, size_t> client::ru32(const std::string& data)
{
    uint32_t value = 0;
    size_t offset  = 0;
    bool ok        = readVarInteger(value, (uint8_t*)data.data(), offset, data.length());
    return {ok, value, offset};
}

std::tuple<bool, int64_t, size_t> client::ri64(const std::string& data)
{
    int64_t value = 0;
    size_t offset = 0;
    bool ok       = readVarInteger(value, (uint8_t*)data.data(), offset, data.length());
    return {ok, value, offset};
}

std::tuple<bool, uint64_t, size_t> client::ru64(const std::string& data)
{
    uint64_t value = 0;
    size_t offset  = 0;
    bool ok        = readVarInteger(value, (uint8_t*)data.data(), offset, data.length());
    return {ok, value, offset};
}
