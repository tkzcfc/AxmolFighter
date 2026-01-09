local NetworkErrCode = {
    -- 连接问题
    -- CURLE_COULDNT_RESOLVE_HOST (6) - 无法解析主机地址（DNS问题）
    -- CURLE_COULDNT_CONNECT (7) - 无法连接到服务器
    -- CURLE_OPERATION_TIMEDOUT (28) - 操作超时
    -- CURLE_SEND_ERROR (55) - 发送网络数据失败
    -- CURLE_RECV_ERROR (56) - 接收网络数据失败
    -- CURLE_PROXY 代理握手错误
    [curl_code.CURLE_COULDNT_RESOLVE_HOST] = true,
    [curl_code.CURLE_COULDNT_CONNECT] = true,
    [curl_code.CURLE_OPERATION_TIMEDOUT] = true,
    [curl_code.CURLE_SEND_ERROR] = true,
    [curl_code.CURLE_RECV_ERROR] = true,
    [curl_code.CURLE_PROXY] = true,

    -- SSL/TLS 连接问题
    -- CURLE_SSL_CONNECT_ERROR  SSL连接失败
    -- CURLE_SSL_CACERT_BADFILE SSL CA证书问题
    -- CURLE_SSL_CRL_BADFILE 无法加载CRL文件
    -- CURLE_SSL_ISSUER_ERROR 颁发者证书问题
    -- CURLE_SSL_PINNEDPUBKEYNOTMATCH 证书公钥不匹配
    -- CURLE_SSL_INVALIDCERTSTATUS 证书状态无效
    -- CURLE_PEER_FAILED_VERIFICATION peer's certificate or fingerprint was not verified fine
    [curl_code.CURLE_SSL_CONNECT_ERROR] = true,
    [curl_code.CURLE_SSL_CACERT_BADFILE] = true,
    [curl_code.CURLE_SSL_CRL_BADFILE] = true,
    [curl_code.CURLE_SSL_ISSUER_ERROR] = true,
    [curl_code.CURLE_SSL_PINNEDPUBKEYNOTMATCH] = true,
    [curl_code.CURLE_SSL_INVALIDCERTSTATUS] = true,
    [curl_code.CURLE_PEER_FAILED_VERIFICATION] = true,

    -- 其他问题
    -- CURLE_BAD_CONTENT_ENCODING 无法识别/编码错误
    [curl_code.CURLE_BAD_CONTENT_ENCODING] = true,
}

local ERROR_NO_ERROR<const>            = 0
local ERROR_INVALID_PARAMS<const>      = -1
local ERROR_OPEN_FILE_FAILED<const>    = -2
local ERROR_IMPL_INTERNAL<const>       = -3
local ERROR_TASK_DUPLICATED<const>     = -4
local ERROR_CREATE_DIR_FAILED<const>   = -5
local ERROR_REMOVE_FILE_FAILED<const>  = -6
local ERROR_RENAME_FILE_FAILED<const>  = -7
local ERROR_CHECK_SUM_FAILED<const>    = -8
local ERROR_ORIGIN_FILE_MISSING<const> = -9

local Downloader = class("Downloader")

function Downloader:ctor(initParams)
    self.activeRequestList = {}
    self.waitRequestList = {}
    self.downloader = nil

    self.initParams = {
        countOfMaxProcessingTasks = 10,
        timeoutInSeconds = 30,
        tempFileNameSuffix = ".tmp"
    }

    for k, v in pairs(initParams or {}) do
        if self.initParams[k] ~= nil then
            self.initParams[k] = v
        end
    end
end

-------------------------------------- public -------------------------------------------

local function urlencodechar(url)
    if type(url) ~= "string" then return url end

    local encoded_url = url:gsub("%%", "%%25")
                      :gsub(" ", "%%20")
                      :gsub("#", "%%23")
                      :gsub("&", "%%26")
                      :gsub("+", "%%2B")
                      :gsub("=", "%%3D")
                      :gsub("@", "%%40")
    return encoded_url
end

local function removeFile(path)
    local fileUtilsInstance = cc.FileUtils:getInstance()
    if fileUtilsInstance:isFileExist(path) then
        fileUtilsInstance:removeFile(path)
    end
end


local last_id = 0

function Downloader:download(url, path, onSuccess, onFailed, onPercent, retryCount, checksum)
    url = urlencodechar(url)
    print("download:", url)
    
    local request

    for k, v in pairs(self.waitRequestList) do
        if v.url == url and v.path == path then
            request = v
            break
        end
    end
    for k, v in pairs(self.activeRequestList) do
        if v.url == url and v.path == path then
            request = v
            break
        end
    end

    if request then
        table.insert(request.onSuccessCbs, onSuccess)
        table.insert(request.onFailedCbs, onFailed)
        table.insert(request.onPercentCbs, onPercent)
        return
    end

    last_id = last_id + 1

    table.insert(self.waitRequestList, {
        url = url,
        path = path,
        onSuccessCbs = {onSuccess},
        onFailedCbs = {onFailed},
        onPercentCbs = {onPercent},
        retryCount = retryCount or 1,
        checksum = checksum or "",
        identifier = tostring(last_id)
    })

    self:_doStart()
end

function Downloader:destroy()
    if self.isDestroyed then return end
    self.isDestroyed = true
    self.downloader = nil
end

-------------------------------------- private -------------------------------------------

function Downloader:_doStart()
    if self.downloader == nil then
        self:_initialize()
    end

    -- while #self.activeRequestList < 20 do
    while true do
        if #self.waitRequestList <= 0 then break end

        local task = table.remove(self.waitRequestList, 1)
        local ok = self:_createTask(task)
        if not ok then
            local request = nil

            for k, v in pairs(self.activeRequestList) do
                if v.identifier == task.identifier then
                    request = table.remove(self.activeRequestList, k)
                    break
                end 
            end

            if request then
                if request.retryCount > 0 then
                    self:delay(function()
                        table.insert(self.waitRequestList, request)
                        self:_doStart()
                    end, 0.1)
                else
                    for _, call in pairs(request.onFailedCbs) do
                        if call then
                            xpcall(call, __G__TRACKBACK__)
                        end
                    end
                end
            end
        end
    end
end

function Downloader:_initialize()
    if self.downloader then return end

    self.downloader = cc.Downloader:new(self.initParams)
    self.downloader:setOnFileTaskSuccess(function(task)
        for k, v in pairs(self.activeRequestList) do
            if v.identifier == task.identifier then
                table.remove(self.activeRequestList, k)

                -- for _, call in pairs(v.onSuccessCbs) do
                --     if call then
                --         xpcall(call, __G__TRACKBACK__)
                --     end
                -- end

                local required_sum = v.checksum
                local real_sum = game_utils.md5_file(v.path)
                if type(required_sum) == "string" and required_sum ~= "" and real_sum ~= required_sum then
                    -- md5校验失败
                    removeFile(v.path)
                    print(v.url)
                    print("md5 check failed:", v.path, "required:", required_sum, "real:", real_sum)

                    if v.retryCount <= 0 then
                        for _, call in pairs(v.onFailedCbs) do
                            if call then
                                xpcall(call, __G__TRACKBACK__)
                            end
                        end
                    else
                        if v.retryCount > 1 then v.retryCount = 1 end
                        table.insert(self.waitRequestList, v)
                    end
                else
                    removeFile(v.path .. ".tmp.digest")
                    for _, call in pairs(v.onSuccessCbs) do
                        if call then
                            xpcall(call, __G__TRACKBACK__)
                        end
                    end
                end
                
                break
            end 
        end
        self:_doStart()
    end)
    self.downloader:setOnTaskProgress(function(task, bytesReceived, totalBytesReceived, totalBytesExpected)
        local percent = 0
        if totalBytesExpected > 0 then percent = totalBytesReceived / totalBytesExpected end

        for k, v in pairs(self.activeRequestList) do
            if v.identifier == task.identifier then
                for _, call in pairs(v.onPercentCbs) do
                    if call then
                        xpcall(call, __G__TRACKBACK__, percent, bytesReceived, totalBytesReceived, totalBytesExpected)
                    end
                end
                break
            end 
        end
    end)
    self.downloader:setOnTaskError(function(task, errorCode, errorCodeInternal, errorSt)
        print(task.requestURL)
        print("download error:", errorCode, errorCodeInternal, errorSt)

        local request = nil
        for k, v in pairs(self.activeRequestList) do
            if v.identifier == task.identifier then
                request = table.remove(self.activeRequestList, k)
                break
            end 
        end

        if request then
            if errorCode == ERROR_IMPL_INTERNAL then
                if not NetworkErrCode[errorCodeInternal] then
                    removeFile(request.path)
                    removeFile(request.path .. self.initParams.tempFileNameSuffix)
                end
            elseif errorCode == ERROR_CHECK_SUM_FAILED then
                -- 校验失败，减少重试次数
                if request.retryCount > 2 then
                    request.retryCount = 2
                end
            end
            
            if request.retryCount > 0 then
                table.insert(self.waitRequestList, request)
            else
                for _, call in pairs(request.onFailedCbs) do
                    if call then
                        xpcall(call, __G__TRACKBACK__)
                    end
                end
            end
        end

        self:delay(function()
            self:_doStart()
        end, 1 / 20)
    end)
end

function Downloader:_createTask(request)
    -- print(request.url)
    -- print(request.path)
    -- print(request.identifier)
    request.retryCount = request.retryCount - 1
    table.insert(self.activeRequestList, request)
    
    removeFile(request.path)

    if self.downloader:createDownloadFileTask(request.url, request.path, request.identifier, "") then
        return true
    end

    print("createDownloadFileTask failed:", request.url, request.path, request.identifier)
    return false
end

function Downloader:delay(callback, time)
    time = time or 0
    local sharedScheduler = cc.Director:getInstance():getScheduler()
    local handle
    handle = sharedScheduler:scheduleScriptFunc(function(dt)
        sharedScheduler:unscheduleScriptEntry(handle)
        if self.isDestroyed then return end
        if callback then callback() end
    end, time, false)
end

return Downloader