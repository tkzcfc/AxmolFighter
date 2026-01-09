local Helper = {}

local cjson = require("cjson")
require("boot.src.update.xhttp")

local curlCacheDir = cc.FileUtils:getInstance():getWritablePath() .. "tmp_cache/"
cc.FileUtils:getInstance():removeDirectory(curlCacheDir)

function Helper.decodeJsonFile(fileName)
    local fileUtilsInstance = cc.FileUtils:getInstance()
    if not fileUtilsInstance:isFileExist(fileName) then
        return
    end

    return Helper.decodeJson(fileUtilsInstance:getStringFromFile(fileName))
end

function Helper.decodeJson(text)
    local status, result = pcall(cjson.decode, text)
    if status and type(result) == "table" then
        return result
    end
end

function Helper.encodeJson(var)
    local status, result = pcall(cjson.encode, var)
    if status then return result end
end

function Helper.removeFile(fileName)
    local fileUtilsInstance = cc.FileUtils:getInstance()
    if fileUtilsInstance:isFileExist(fileName) then
        return fileUtilsInstance:removeFile(fileName)
    end
end

function Helper.createDirectory(dirName)
    local fileUtilsInstance = cc.FileUtils:getInstance()
    if not fileUtilsInstance:isDirectoryExist(dirName) then
        return fileUtilsInstance:createDirectory(dirName)
    end
end

function Helper.writeTabToFile(tab, fileName)
    local text = Helper.encodeJson(tab) or "{}"
    
    if not cc.FileUtils:getInstance():writeStringToFile(text, fileName) then
        print("写入文件失败：", fileName)
    end
end

function Helper.fetchFile(url, tofile, onResult, onPercent, checksum, retryCount)
    if not retryCount then
        retryCount = 5
    end

    xhttp_request(url, tofile, function()
        print("[Helper.fetchFile] download success:", url)
        onResult(true)
    end, function()
        print("[Helper.fetchFile] download failed:", url)
        onResult(false)
    end, onPercent, retryCount, checksum)
end

function Helper.curlRead(url, callback, retryCount)
    if not retryCount then retryCount = 0 end

    Helper.createDirectory(curlCacheDir)
    local tofile = curlCacheDir .. game_utils.md5(url .. tostring(NowEpochMS()))

    Helper.fetchFile(url, tofile, function(ok)
        if ok then
            local fileUtilsInstance = cc.FileUtils:getInstance()
            if fileUtilsInstance:isFileExist(tofile) then
                callback(true, fileUtilsInstance:getDataFromFile(tofile))
                fileUtilsInstance:removeFile(tofile)
            else
                callback(false)
            end
        else
            callback(false)
        end
    end, nil, nil, retryCount)
end

function Helper.httpRead(url, callback, timeout)
    print("http read:", url)
    local xhr = nil
    xhr = cc.XMLHttpRequest:new()
    xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON
    xhr.timeout = timeout or 4
    xhr:open("GET", url)
    xhr:registerScriptHandler(function()
        print("readyState:" .. xhr.readyState)
        print("status:" .. xhr.status)
        if xhr.readyState == 4 and (xhr.status >= 200 and xhr.status < 207) then
            callback(true, xhr.response)
        else
            print("response:" .. tostring(xhr.response))
            callback(false)
        end
    end)
    xhr:send()
end

function Helper.table_unique(t, bArray)
    local check = {}
    local n = {}
    local idx = 1
    for k, v in pairs(t) do
        if not check[v] then
            if bArray then
                n[idx] = v
                idx = idx + 1
            else
                n[k] = v
            end
            check[v] = true
        end
    end
    return n
end

return Helper