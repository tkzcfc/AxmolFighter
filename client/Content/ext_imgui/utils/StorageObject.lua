local cjson = require("cjson")

local type = type
local scriptEntryID = nil
local task = {}

--------------------------------------------------- functions ---------------------------------------------------
local function encodeJson(var)
    local status, result = pcall(cjson.encode, var)
    if status and type(result) == "string" then return result end
end

local function decodeJson(text, checkTable)
    if text == nil then text = "" end
    local status, result = pcall(cjson.decode, text)
    if status then 
        if checkTable then
            if type(result) == "table" then
                return result
            end
        else
            return result
        end
    end
end

local function writeEx(filePath, data)
    local content = encodeJson(data)
    if content == nil then return end
    local fileUtils = cc.FileUtils:getInstance()
    fileUtils:writeStringToFile(content, filePath)
end

local function doWrite()
    if scriptEntryID == nil then return end

    local scheduler = cc.Director:getInstance():getScheduler()
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
        local scheduler = cc.Director:getInstance():getScheduler()
        scriptEntryID = scheduler:scheduleScriptFunc(doWrite, 1 / 60, false)
    end
end

-- @brief 文件读取
local function read(filePath)
    local fileUtils = cc.FileUtils:getInstance()
    if fileUtils:isFileExist(filePath) then
        local data = fileUtils:getStringFromFile(filePath)
        return decodeJson(data, true) or {}
    end
    return {}
end


--------------------------------------------------- StorageObject ---------------------------------------------------

-- @brief 
local StorageObject = {}

StorageObject.new = function(filePath)
    local fileUtils = cc.FileUtils:getInstance()
    if not fileUtils:isAbsolutePath(filePath) then        
        local writablePath = fileUtils:getWritablePath() .. "imgui_storage/"
        if not fileUtils:isDirectoryExist(writablePath) then
            fileUtils:createDirectory(writablePath)
        end
        filePath = writablePath .. filePath
    end

    local t = {}
    t.map_key_value = read(filePath)
    t.filePath = filePath
    t.get = StorageObject.get
    t.set = StorageObject.set
    t.flush = StorageObject.flush
    setmetatable(t, StorageObject)
    return t
end

StorageObject.get = function(this, key, defaultVal)
    local val = this.map_key_value[key]
    if val == nil then return defaultVal end
    return val
end

StorageObject.set = function(this, key, value)
    this.map_key_value[key] = value
    write(this.filePath, this.map_key_value)
end

StorageObject.setContentDirty = function(this)
    write(this.filePath, this.map_key_value or {})
end

StorageObject.flush = function()
    doWrite()
end

return StorageObject