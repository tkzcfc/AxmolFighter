
local pb = require "luapb"
local ProtobufData = require("logic.net.ProtobufData")

local PBLoader = {}

-- @brief pb初始化
function PBLoader:initialize()
    -- pb文件加载
    for filename, bytes in pairs(ProtobufData) do
        local ok, err = pb.load(bytes)
        if ok then
            -- logI(string.format("load pb(%s), ok", filename))
        else
            logE(string.format("load pb(%s), error: %s\n", filename, tostring(err)))
        end
    end
    
    -- 配合no_default_values选项，对于数组，将空值解码为空表
    pb.option("decode_default_array")

    self.msgIdMap = {}
    self.idMsgMap = {}

    local repeatErrors = {}

    -- 消息ID和消息名称映射
    for name, basename, type in pb.types() do
        if type == "enum" and basename == "MsgId" then
            local id = pb.enum(name, "Id")
            if id then
            	local msgName = string.sub(name, 2, -7)

                if self.idMsgMap[id] then
                    table.insert(repeatErrors, string.format("消息ID重复定义:%d, %s, %s", id, self.idMsgMap[id], msgName))
                end

            	self.msgIdMap[msgName] = id
            	self.idMsgMap[id] = msgName
            end
        end
    end

    if #repeatErrors > 0 then
        error(table.concat(repeatErrors, "\n"))
    end
end

-- @brief 通过消息名称获取消息ID
function PBLoader:getMsgName(id)
	return self.idMsgMap[id]
end

-- @brief 通过id获取消息名称
function PBLoader:getMsgId(name)
	return self.msgIdMap[name]
end

function PBLoader:checkFiled(name, msg)
    for k, v in pb.fields(name) do
        if msg[k] == nil and not string.find(name, "PB.Client_Slots") then
            error(string.format("消息:%s,缺少字段:%s", name, k))
        end
    end
end

PBLoader:initialize()

return PBLoader
