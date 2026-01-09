local luapb = require "luapb"
local PBLoader = require("logic.net.PBLoader")

local function UploadNetMessageError(err) end

local function __NET_READ_TRACKBACK__(msg)
    local message = ""
    message = message .. "LUA ERROR: " .. tostring(msg) .. "\n"
    message = message .. debug.traceback()
	print(message)
	UploadNetMessageError("yasio net read error message")

	go(function()
		print("yasio net read error message, disconnecting...")
		gNetMgr:disconnect()
	end)
end

local function __NET_WRITE_TRACKBACK__(msg)
    local message = ""
    message = message .. "LUA ERROR: " .. tostring(msg) .. "\n"
    message = message .. debug.traceback()
	print(message)
	UploadNetMessageError("yasio net write error message")
end

local function dumpPb(msg)
	print("===============================================")
	print("|||||||||||||||||||||||||||||||||||||||||||||||")
	dump(msg, msg._msgName_)
	print("|||||||||||||||||||||||||||||||||||||||||||||||")
	print("===============================================")
end

local Message = class("Message")

require("framework.utils.Logger").attachTo(Message)

-- @brief 消息编码
function Message:encode(msg)
    local msgName = msg._msgName_
	assert(msgName, "msg must contain '_msgName_' field")
	local typeId = PBLoader:getMsgId(msgName)
	if typeId == nil then
		self:logE(string.format("Unknown message name: '%s'", tostring(msgName)))
		UploadNetMessageError("yasio write unknown message")
		return
	end

	local ok, binary = xpcall(luapb.encode, __NET_WRITE_TRACKBACK__, msgName, msg)
	if not ok then
		self:logE(string.format("Encode protobuf failed: '%s'", tostring(msgName)))
		return
	end

	-- print(">>>>>>>>>>>>>> send <<<<<<<<<<<<<<")
	-- dumpPb(msg)

	-- if protoLog then
	-- 	local str = Crypto.encodeJson(msg) or "encode failed"
	-- 	protoLog("send " .. tostring(str))
	-- end

	return net.client.wi32(typeId) .. binary
end

-- @brief 消息解码
function Message:decode(bytes)
    local ok, typeId, len = net.client.ri32(bytes)
    if not ok then
		self:logE("Decoding protobuf failed: unable to get typeId", string.len(bytes))
        return
    end
	
	local msgName = PBLoader:getMsgName(typeId)
	if not msgName then
		self:logE(string.format("Decoding protobuf failed: Unknown typeID '%s'", tostring(typeId)))
		return
	end
    
    local ok, msg = xpcall(luapb.decode, __NET_READ_TRACKBACK__, msgName, string.sub(bytes, len + 1))
    if not ok then
        self:logE(string.format("Decoding protobuf failed:%s", msgName))
        return nil, true
    end

	-- 添加一个msgName名称,便于客户端区分消息类型
	msg._msgName_ = msgName
	
	-- if gConfigData.isOpenNetDebug then
	-- 	print(">>>>>>>>>>>>>> recv <<<<<<<<<<<<<<")
	-- 	dumpPb(msg)
	-- end
	
	-- if protoLog and len < 1024 * 1024 * 8 then
	-- 	local str = Crypto.encodeJson(msg) or "encode failed"
	-- 	protoLog("recv " .. tostring(str))
	-- end

	-- 兼容PKG读取方式，具体查看函数注释
	-- CompatiblePKG_Read(msg)

	return msg
end

return Message