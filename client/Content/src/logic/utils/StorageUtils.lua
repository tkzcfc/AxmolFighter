-- 保存需要存储在用户身上的配置

StorageUtils = {}

function StorageUtils:init()
    -- 登录成功
    gSysEventEmitter:on(SysEvent.ON_MSG_LOGIN_SUCCESS, function()
        local storageFile = string.format("user_%s.json", tostring(gLobbyData:getUserData().id))
        self.userStorage = require("framework.utils.StorageObject").new(storageFile)
    end, self)
    
    -- 退出登录
    gSysEventEmitter:on(SysEvent.ON_MSG_LOGOUT, function()
        if self.userStorage then
            self.userStorage:flush()
            self.userStorage = nil
        end
    end, self)
end

function StorageUtils:setValue(key, value)
    if self.userStorage then
        self.userStorage:setValue(key, value)
    end
end

function StorageUtils:getValue(key)
    if self.userStorage then
        return self.userStorage:getValue(key)
    end
end

function StorageUtils:getNumber(key, defaultValue)
    if self.userStorage then
        return self.userStorage:getNumber(key, defaultValue)
    else
        return defaultValue or 0
    end
end

function StorageUtils:getBool(key, defaultValue)
    if self.userStorage then
        return self.userStorage:getBool(key, defaultValue)
    else
        if defaultValue == nil then return false end
        return defaultValue
    end
end

function StorageUtils:getString(key, defaultValue)
    if self.userStorage then
        return self.userStorage:getString(key, defaultValue)
    else
        return defaultValue or ""
    end
end

function StorageUtils:getTable(key, defaultValue)
    if self.userStorage then
        return self.userStorage:getTable(key, defaultValue)
    else
        return defaultValue
    end
end

function StorageUtils:flush()
    if self.userStorage then
        self.userStorage:flush()
    end
end

StorageUtils:init()