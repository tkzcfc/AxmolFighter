-- @Author : 
-- @Date   : 2023-09-17 11:43:07
-- @remark : 

local cjson = require("cjson")

local Crypto = {}

function Crypto.decodeJsonFile(fileName, checkTable)
    local fileUtilsInstance = cc.FileUtils:getInstance()
    if not fileUtilsInstance:isFileExist(fileName) then
        return
    end
    return Crypto.decodeJson(fileUtilsInstance:getStringFromFile(fileName), checkTable)
end

function Crypto.decodeJson(text, checkTable)
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

    logE("\n\njson decode error------------------------>")
    logE(status, result)
    if type(text) == "string" then
        if string.len(text) == 0 then
            logE("empty text")
        elseif string.len(text) < 1024 then
            logE(text)
        else
            logE("too long text, len: " .. string.len(text))
        end
    else
        logE(type(text), tostring(text))
    end
end

function Crypto.encodeJson(var)
    local status, result = pcall(cjson.encode, var)
    if status and type(result) == "string" then return result end
end

-- @brief base64解码
function Crypto.decodeBase64(ciphertext)
    return game_utils.base64_decode(tostring(ciphertext))
end

-- @brief base64编码
function Crypto.encodeBase64(plaintext)
    return game_utils.base64_encode(tostring(plaintext))
end

-- @brief 
function Crypto.md5(input)
    return game_utils.md5(tostring(input))
end

-- @brief 
function Crypto.sha256(input)
    input = tostring(input)
    return game_utils.sha256(input)
    -- if game_utils.sha256 then
    --     return game_utils.sha256(input)
    -- else
    --     require("framework.deprecated.hash")
    --     return sha256(input)
    -- end
end

return Crypto