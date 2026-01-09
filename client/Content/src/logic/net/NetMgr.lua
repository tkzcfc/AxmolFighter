local Message = require("logic.net.Message").new()

-- 默认请求超时时间
local DEFAULT_REQUEST_TIMEOUT<const> = 10

local NetMgr = class("NetMgr")

propertyReadOnly(NetMgr, "pPushMsgEventEmitter")

require("framework.utils.Logger").attachTo(NetMgr)

function NetMgr:ctor(address, port)
    -- 连接地址
    self.address = address
    -- 连接端口
    self.port = port
    -- 是否使用TCP
    self.is_use_tcp = true
    -- 是否禁用KCP
    self.disable_kcp = true
    -- 连接KCP失败的次数
    self.count_of_kcp_no_active = 0
    -- 游戏服务器ID
    self.game_server_id = -1

    self.pPushMsgEventEmitter = require("framework.utils.EventEmitter").new()
    
    self.client = net.client.new(20)
    self.client:setHost(address, port)
    self.client:addRecvMsgCallback(function(target, serial, data)
        if target == 0 then
            self.last_recv_msg_time = NowEpochMS()
        end
        if self.cppServiceId == target then return end

        local msg, bad_data = Message:decode(data)
		if msg == nil then
            self:logE("Decode message failed")
            if bad_data then
                go(function() self:disconnect() end)
            end
            return
        end
        
        if serial <= 0 then
            self:logI("Receive push message:", msg._msgName_)
            self.pPushMsgEventEmitter:emit(msg._msgName_, msg, target)
            gSysEventEmitter:emit(SysEvent.ON_MSG_RECV_PUSH_MSG, msg, target)
        end
    end, "lua")

    self.last_recv_msg_time = NowEpochMS()
    go(function()
        local lose_ping_num = 0
        while true do
            if self:isOpen(0) then
                sleep(1)
                if NowEpochMS() - self.last_recv_msg_time > 5000 then
                    
                    local ping = {
                        _msgName_ = "PB.client_lobby.Ping",
                        ticks = NowEpochMS()
                    }
                    -- self:logI("Send ping to lobby server...")

                    if self:sendRequestToLobby(ping, 5) then
                        lose_ping_num = 0
                    else
                        lose_ping_num = lose_ping_num + 1
                        -- ping超时
                        if lose_ping_num > 3 then
                            self:logW("Ping timeout, disconnecting from server")
                            self:disconnect()
                        end
                    end
                end
            else
                yield()
            end
        end
    end)
end

-- @brief 连接到服务器(异步版本)
-- @param on_connect_callback 连接回调函数
-- @param retry_count 重试次数
function NetMgr:connectToServerAsync(on_connect_callback, retry_count)
    retry_count = retry_count or 0
    retry_count = retry_count - 1
    on_connect_callback = on_connect_callback or function() end

    self:connectAsync(function(ok, err)
        if ok then
            on_connect_callback(ok, err)
            gSysEventEmitter:emit(SysEvent.ON_MSG_NET_CONNECT_RESULT, ok, err)
        else
            if retry_count > 0 then
                go(function()
                    self:logI("Retry connecting to server, retry count:", retry_count)
                    self:connectToServerAsync(on_connect_callback, retry_count)
                end)
            else
                on_connect_callback(ok, err)
                gSysEventEmitter:emit(SysEvent.ON_MSG_NET_CONNECT_RESULT, ok, err)
            end
        end
    end)
end

-- @brief 断开连接
function NetMgr:disconnect()
    self:logI("Proactively call to disconnect, disconnecting from server")
    self.client:disconnect()
end

-- @brief 是否已连接
function NetMgr:isConnected()
    return self.client:isConnected()
end

-- @brief 是否繁忙（正在连接中...）
function NetMgr:isBusy()
    return self.client:isBusy()
end

-- @brief 查询某个服务是否打开
-- @param server_id 服务器ID
-- @return true 打开
function NetMgr:isOpen(server_id)
    return self.client:isConnected() and self.client:isOpened(server_id)
end

-- @brief 设置游戏服务器ID
-- @param server_id 服务器ID
function NetMgr:setGameServerId(server_id)
    self:logI("Set game server id:", tostring(server_id))
    self.game_server_id = server_id
end

-- @brief 获取游戏服务器ID
function NetMgr:getGameServerId()
    return self.game_server_id
end

-- @brief 发送请求到游戏服务器(协程版本)
-- @param msg 消息体
-- @param timeout 超时时间
function NetMgr:sendRequestToGame(msg, timeout)
    return self:sendRequest(self.game_server_id, msg, timeout)
end

-- @brief 发送推送消息到游戏
function NetMgr:sendPushToGame(msg)
    return self:sendPush(self.game_server_id, msg)
end

-- @brief 发送请求到大厅服务器(协程版本)
-- @param msg 消息体
-- @param timeout 超时时间
function NetMgr:sendRequestToLobby(msg, timeout)
    return self:sendRequest(0, msg, timeout)
end

-- @brief 发送推送消息到大厅
function NetMgr:sendPushToLobby(msg)
    return self:sendPush(0, msg)
end

function NetMgr:setCppServiceId(id)
    if id > 0 then
        self.cppServiceId = id
    end
    self.client:setCppServiceId(id)
end

------------------------------------------------------------- private functions -------------------------------------------------------------

-- @brief 发送请求到指定的服务器(协程版本)
-- @param server_id 服务器ID
-- @param msg 消息体
-- @param timeout 超时时间
-- @return response 响应消息
-- @return nil 发送失败
function NetMgr:sendRequest(server_id, msg, timeout)
    local wait_open_timeout = NowEpochMS() + 3000
    while not self.client:isOpened(server_id) do
        if not self.client:isConnected() then
            self:logW("Server not connected, server_id:", server_id)
            return nil
        end

        yield()

        if NowEpochMS() > wait_open_timeout then
            self:logE("Wait for server open timeout, server_id:", server_id)
            return nil
        end
    end

    local done = false
    local response = nil

    done = not self:sendRequestAsync(server_id, msg, function(ok, recvmsg)
        done = true
		if ok then
			response = recvmsg
		else
            self:logE("Send request failed:", recvmsg, msg._msgName_)
		end
    end, timeout)

    repeat yield() until (done)

    return response
end

-- @brief 发送请求到指定的服务器(异步版本)
-- @param server_id 服务器ID
-- @param msg 消息体
-- @param callback 回调函数
-- @param timeout 超时时间
-- @return true 发送成功
function NetMgr:sendRequestAsync(server_id, msg, callback, timeout)
    if not self:isOpen(server_id) then
        self:logW("Server not opened, server_id:", server_id)
        return false
    end

    local bytes = Message:encode(msg)
    if not bytes then
        self:logE("Send message failed, unable to encode message")
        return false
    end

    -- self:logI("Send message to server:", msg._msgName_, server_id)
    local err_code = self.client:sendRequest(server_id, bytes, string.len(bytes), function(ok, bytes)
        if ok then
            local msg, bad_data = Message:decode(bytes)
            if msg then
                callback(true, msg)
            else
                callback(false, "Decode message failed")
                if bad_data then
                    go(function() self:disconnect() end)
                end
            end
        else
            callback(false, bytes)
        end
    end, timeout or DEFAULT_REQUEST_TIMEOUT)
    if err_code < 0 then
        self:logE("Send message failed, error code:", err_code)
        return false
    end
    return true
end

-- @brief 发送推送到指定的服务器
-- @param server_id 服务器ID
-- @param msg 消息体
-- @return true 发送成功
function NetMgr:sendPush(server_id, msg)
    if not self:isOpen(server_id) then
        self:logW("Server not opened, server_id:", server_id)
        return false
    end

    local bytes = Message:encode(msg)
    if not bytes then
        self:logE("Send push failed, unable to encode message")
        return false
    end

    local err_code = self.client:sendPush(server_id, bytes, string.len(bytes))
    if err_code < 0 then
        self:logE("Send push failed, error code:", err_code)
        return false
    end
    return true
end

function NetMgr:connectAsync(on_connect_callback)
	if self.disable_kcp then
		self.is_use_tcp = true
	else
		self.is_use_tcp = not self.is_use_tcp
	end

    print(fmt("NetMgr:connect {0}:{1} with {2}", self.address, self.port, self.is_use_tcp and "tcp" or "kcp"))

    self.client:disconnect()
    self.client:setDisconnectCallback(function()
        if self.client:isWillDestroy() then
            return
        end
        self:logW("Disconnected from server")
        gSysEventEmitter:emit(SysEvent.ON_MSG_NET_DISCONNECT)
    end)
    self.client:connect(self.is_use_tcp, function(ok, err)
        if self.client:isWillDestroy() then
            return
        end
        

		-- 使用KCP
		if not self.is_use_tcp then
			if ok then
				self.count_of_kcp_no_active = 0
				-- 本次使用kcp并且连接时间很短，下次继续使用KCP
				if NowEpochMS() - now < 1500 then
					self.is_use_tcp = true
				end
			else
				-- kcp几次都连不上，后续都不使用kcp了
				self.count_of_kcp_no_active = self.count_of_kcp_no_active + 1
				if self.count_of_kcp_no_active >= 2 then
					self.disable_kcp = true
				end
			end
		end

        if ok then
            self:logI(fmt("Successfully connected to server : {0}:{1}", self.address, self.port))
        else
            self:logE(fmt("Failed to connect to server: {0}:{1}, error:{2}", self.address, self.port, err))
        end

        if on_connect_callback then
            on_connect_callback(ok, err)
        end
    end)
end

return NetMgr