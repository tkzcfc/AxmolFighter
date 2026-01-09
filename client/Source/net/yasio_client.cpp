#include "yasio_client.h"
#include "cocos2d.h"

using namespace ax;
using namespace yasio;

#define NET_LOG_ENABLED 0

#if NET_LOG_ENABLED
#    define NET_LOG(format, ...) AXLOGI(format, ##__VA_ARGS__)
#else
#    define NET_LOG(...) \
        do               \
        {                \
        } while (0)
#endif

yasio_client_service_opt_callback_type yasio_client::on_yasio_service_opt_callback = nullptr;

yasio_client::yasio_client(int maxChannelCount) : m_connectionIdSeed(0), m_eventCallback(nullptr)
{
    if (maxChannelCount <= 0)
        maxChannelCount = 1;

    m_connectQue.reserve(maxChannelCount);

    m_service = new yasio::io_service(maxChannelCount);
    m_service->set_option(yasio::YOPT_S_CONNECT_TIMEOUT, 5);
    m_service->set_option(yasio::YOPT_S_NO_DISPATCH, 1);
    m_service->set_option(yasio::YOPT_S_DNS_QUERIES_TIMEOUT, 3);
    m_service->set_option(yasio::YOPT_S_DNS_QUERIES_TRIES, 1);
    // m_service->set_option(yasio::YOPT_S_TCP_KEEPALIVE, 5, 5, 3);

    for (auto i = 0; i < maxChannelCount; ++i)
    {
        m_availChannelQueue.push(i);
        if (on_yasio_service_opt_callback)
            on_yasio_service_opt_callback(m_service, i);
    }
    if (on_yasio_service_opt_callback)
        on_yasio_service_opt_callback(m_service, -1);

    on_yasio_service_opt_callback = nullptr;

    m_service->start([this](yasio::event_ptr&& e) { handleNetworkEvent(e.get()); });

    Director::getInstance()->getScheduler()->schedule([this](float) { this->tickInput(); }, this, 0, false, "#");
}

yasio_client::~yasio_client()
{
    delete m_service;
    Director::getInstance()->getScheduler()->unscheduleAllForTarget(this);
}

int yasio_client::connect(const std::string& host, int port, int kind)
{
    Connection conn;
    conn.id        = m_connectionIdSeed++;
    conn.status    = ConnectionStatus::Queuing;
    conn.port      = port;
    conn.host      = host;
    conn.kind      = kind;
    conn.channel   = -1;
    conn.transport = nullptr;
    m_connectQue.push_back(conn);
    return conn.id;
}

void yasio_client::disconnect(int connectionId)
{
    auto it = m_aliveConnects.find(connectionId);
    if (it != m_aliveConnects.end())
    {
        m_service->close(it->second.channel);
        return;
    }

    for (auto it = m_connectQue.begin(); it != m_connectQue.end(); ++it)
    {
        if (it->id == connectionId)
        {
            m_connectQue.erase(it);
            break;
        }
    }
}

int yasio_client::send(int connectionId, const char* data, size_t length)
{
    auto it = m_aliveConnects.find(connectionId);
    if (it == m_aliveConnects.end())
        return -1000;

    auto& transport = it->second.transport;
    if (!transport)
        return -1001;

    return m_service->write(transport, data, length);
}

int yasio_client::send(int connectionId, const yasio::obstream& obs)
{
    NET_LOG("yasio_client: try send packet, id = {}, size = {}", connectionId, obs.length());
    auto it = m_aliveConnects.find(connectionId);
    if (it == m_aliveConnects.end())
        return -1000;

    auto& transport = it->second.transport;
    if (!transport)
        return -1001;

    NET_LOG("yasio_client: do send packet, id = {}, size = {}", connectionId, obs.length());
    return m_service->write(transport, std::move(obs.buffer()));
}

void yasio_client::setEventCallback(const yasio_client_event_callback_type& callback)
{
    m_eventCallback = callback;
}

void yasio_client::handleNetworkEvent(yasio::io_event* event)
{
    int channelIndex = event->cindex();
    auto channel     = m_service->channel_at(channelIndex);
    int connectionId = channel->ud_.ival;

    switch (event->kind())
    {
    case YEK_ON_OPEN:
    {
        if (event->status() == 0)
        {
            auto it = m_aliveConnects.find(connectionId);
            if (it != m_aliveConnects.end())
            {
                it->second.transport = event->transport();
            }
            NET_LOG("yasio_client: connect success, id = {}", connectionId);
            dispatchEvent(event_type::OnConnectSuccess, connectionId, 0, 0);
        }
        else
        {
            NET_LOG("yasio_client: connect failed, id = {}", connectionId);
            handleNetworkEOF(channel, event->status());

            auto err = fmt::format("connect failed, internal error code: {}", event->status());
            dispatchEvent(event_type::OnConnectFailed, connectionId, err.data(), err.size());
        }
    }
    break;
    case YEK_ON_CLOSE:
    {
        NET_LOG("yasio_client: disconnect, id = {}", connectionId);
        handleNetworkEOF(channel, event->status());

        auto err = fmt::format("disconnect, internal error code: {}", event->status());
        dispatchEvent(event_type::OnDisconnect, connectionId, err.data(), err.size());
    }
    break;
    case YEK_ON_PACKET:
    {
        auto& packet = event->packet();
        NET_LOG("yasio_client: recv packet, id = {}, size = {}", connectionId, packet.size());
        dispatchEvent(event_type::OnRecvData, connectionId, packet.data(), packet.size());
    }
    break;
    }
}

void yasio_client::handleNetworkEOF(yasio::io_channel* channel, int internalErrorCode)
{
    int connectionId  = channel->ud_.ival;
    channel->ud_.ival = -1;

    auto it = m_aliveConnects.find(connectionId);
    if (it != m_aliveConnects.end())
    {
        m_aliveConnects.erase(it);
    }
    // 回收信道
    m_availChannelQueue.push(channel->index());
}

void yasio_client::tickInput()
{
    doConnect();
    m_service->dispatch();
}

void yasio_client::doConnect()
{
    while (!m_connectQue.empty())
    {
        auto& conn   = m_connectQue.front();
        auto channel = tryTakeAvailChannel();
        if (channel < 0)
            break;

        conn.channel = channel;

        auto channelHandle = m_service->channel_at(channel);
        NET_LOG("yasio_client: open connection for {}:{}, id = {}", conn.host.data(), conn.port, conn.id);
        channelHandle->ud_.ival = conn.id;

        if (conn.kind == yasio::YCK_UDP_CLIENT)
        {
            m_service->set_option(YOPT_C_UNPACK_PARAMS, channel, 1024 * 1024 * 10, -1, 4, 0);
            m_service->set_option(YOPT_C_UNPACK_STRIP, channel, 0);
            m_service->set_option(YOPT_C_UNPACK_NO_BSWAP, channel, 0);
        }
        else
        {
            m_service->set_option(YOPT_C_UNPACK_PARAMS, channel, 1024 * 1024 * 10, 0, 4, 4);
            m_service->set_option(YOPT_C_UNPACK_STRIP, channel, 4);
            m_service->set_option(YOPT_C_UNPACK_NO_BSWAP, channel, 1);
        }

        m_service->set_option(YOPT_C_REMOTE_ENDPOINT, channel, conn.host.data(), conn.port);
        m_service->open(channel, conn.kind);

        m_aliveConnects.insert(std::make_pair(conn.id, m_connectQue[0]));
        m_connectQue.erase(m_connectQue.begin());
    }
}

int yasio_client::tryTakeAvailChannel()
{
    if (!m_availChannelQueue.empty())
    {
        int channel = m_availChannelQueue.front();
        m_availChannelQueue.pop();
        return channel;
    }
    return -1;
}
