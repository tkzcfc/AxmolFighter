-- @Author : fc
-- @Date   : 2021-11-10 16:34:03
-- @remark : 自动存储对象

local Crypto = require("framework.utils.Crypto")
local type = type
local fileUtils = cc.FileUtils:getInstance()
local scheduler = cc.Director:getInstance():getScheduler()
local scriptEntryID = nil
local task = {}

--------------------------------------------------- functions ---------------------------------------------------

local function writeEx(filePath, data)
    local content = Crypto.encodeJson(data)
    if content == nil then 
        dump(data, "JSON编码失败")
        return
    end
    fileUtils:writeStringToFile(content, filePath)
end

local function doWrite()
    if scriptEntryID == nil then return end
    scheduler:unscheduleScriptEntry(scriptEntryID)
    scriptEntryID = nil

    for k, v in pairs(task) do
        writeEx(k, v)
    end
    task = {}
end

-- @brief 文件写入
local function write(filePath, data)
    task[filePath] = data

    if scriptEntryID == nil then
        scriptEntryID = scheduler:scheduleScriptFunc(doWrite, 1, false)
    end
end

-- @brief 文件读取
local function read(filePath)
    if fileUtils:isFileExist(filePath) then
        local data = fileUtils:getStringFromFile(filePath)
        return Crypto.decodeJson(data, true) or {}
    end
    return {}
end


--------------------------------------------------- StorageObject ---------------------------------------------------

-- @brief 
local StorageObject = {}


StorageObject.__index = function(this, key)
    return this.__map_key_value__[key]
end

StorageObject.__newindex = function(this, key, value)
    -- if table.equals(this.__map_key_value__[key], value) then 
    --     return
    -- end

    if type(value) == "table" then
        -- this.__map_key_value__[key] = clone(value)
        this.__map_key_value__[key] = value
    else
        this.__map_key_value__[key] = value
    end
    write(this.__file_path__, this.__map_key_value__)
end

StorageObject.new = function(filePath)
    if not fileUtils:isAbsolutePath(filePath) then        
        local writablePath = fileUtils:getWritablePath() .. "storage/"
        if not fileUtils:isDirectoryExist(writablePath) then
            fileUtils:createDirectory(writablePath)
        end
        filePath = writablePath .. filePath
    end

    local t = {}
    t.__map_key_value__ = read(filePath)
    t.__file_path__ = filePath
    t.setDefaultValue = StorageObject.setDefaultValue
    t.setValue = StorageObject.setValue
    t.getValue = StorageObject.getValue
    t.getNumber = StorageObject.getNumber
    t.getBool = StorageObject.getBool
    t.getString = StorageObject.getString
    t.getTable = StorageObject.getTable
    t.flush = StorageObject.flush
    t.setContentDirty = StorageObject.setContentDirty
    t.getStorageSize = StorageObject.getStorageSize
    setmetatable(t, StorageObject)
    return t
end

function StorageObject:setDefaultValue(key, value)
    if self[key] == nil and value ~= nil then
        self[key] = value
    end
end

function StorageObject:setValue(key, value)
    self[key] = value
end

function StorageObject:getValue(key)
    return self[key]
end

function StorageObject:getNumber(key, defaultValue)
    assert(key ~= nil)

    local value = self[key]
    if type(value) ~= "number" then
        return defaultValue or 0
    end
    return value
end

function StorageObject:getBool(key, defaultValue)
    assert(key ~= nil)
    if defaultValue == nil then defaultValue = false end

    local value = self[key]
    if type(value) ~= "boolean" then
        return defaultValue
    end
    return value
end

function StorageObject:getString(key, defaultValue)
    assert(key ~= nil)

    local value = self[key]
    if type(value) ~= "string" then
        return defaultValue or ""
    end
    return value
end

function StorageObject:getTable(key, defaultValue)
    assert(key ~= nil)

    local value = self[key]
    if type(value) ~= "table" then
        return defaultValue
    end
    return value
end

function StorageObject:setContentDirty()
    write(self.__file_path__, self.__map_key_value__ or {})
end

function StorageObject:flush()
    doWrite()
end

function StorageObject:getStorageSize()
    return cc.FileUtils:getInstance():getFileSize(self.__file_path__)
end

return StorageObject