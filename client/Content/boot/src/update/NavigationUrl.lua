local Helper = require("boot.src.update.Helper")
local json = require("cjson")

local NavigationUrl = class("NavigationUrl")

local function key(url)
    return game_utils.md5(tostring(url)) .. "_priority"
end

local function fmtUrl(url, packageName)
    if string.sub(url, -1) ~= "/" then
        url = url .. "/"
    end
    return url .. packageName
end

function NavigationUrl:ctor(navUrl, backupNavUrls, packageName)
    local urlSet = {}

    if type(navUrl) == "string" and navUrl ~= "" then
        urlSet[fmtUrl(navUrl, packageName)] = { priority = 0 }
    end

    for k, v in pairs(backupNavUrls or {}) do
        if type(v) == "string" then
            urlSet[fmtUrl(v, packageName)] = { 
                priority = 1000 * 60 + k
            }
        end
    end

    self.urls = {}

    local userDefault = cc.UserDefault:getInstance()
    for url, data in pairs(urlSet) do
        local priority = userDefault:getIntegerForKey(key(url), -1)
        if priority > 0 then
            data.priority = priority
        end

        data.url = url
        table.insert(self.urls, data)
    end

    table.sort(self.urls, function(a, b) return a.priority < b.priority end)

    -- dump(self.urls)

    self.requestUUID = 0
end

function NavigationUrl:fetch(callback)
    self.callback = callback
    self.isFinish = false
    self.backCount = 0
    self.requestUUID = self.requestUUID + 1

    local uuid = self.requestUUID
    local totalCount = #self.urls

    if totalCount <= 0 then
        self:delay(callback, 0)
        return
    end

    for k, v in pairs(self.urls) do
        self:delay(function()
            self:doRequest(uuid, v, function(data)
                self.backCount = self.backCount + 1
                if data then
                    callback(data)
                    self:cancelAll()
                    return
                else
                    if self.backCount >= totalCount then
                        callback()
                    end
                end
            end)
        end, (k - 1) * 2)
    end
end

function NavigationUrl:retry()
    self.isRetry = true
    if self.callback then
        self:fetch(self.callback)
    end
end

function NavigationUrl:cancelAll()
    self.requestUUID = self.requestUUID + 1    
end

function NavigationUrl:delay(callback, time)
    time = time or 0
    local sharedScheduler = cc.Director:getInstance():getScheduler()
    local handle
    handle = sharedScheduler:scheduleScriptFunc(function(dt)
        sharedScheduler:unscheduleScriptEntry(handle)
        if callback then callback() end
    end, time, false)
end

function NavigationUrl:doRequest(uuid, requestData, callback)
    if uuid ~= self.requestUUID then return end

    local httpReadFunc = Helper.httpRead
    if self.isRetry then
        httpReadFunc = Helper.curlRead
    end

    local url = requestData.url
    local priority = requestData.priority or 0

    local start = NowEpochMS()
    httpReadFunc(url, function(ok, content)
        if uuid ~= self.requestUUID then return end

        local status, data = pcall(json.decode, content)
        if ok and status and type(data) == "table" then
            local dfftime = NowEpochMS() - start
            print("导航信息获取成功", url, dfftime)

            -- 记录本次请求时间,用于下次请求优先级排序
            cc.UserDefault:getInstance():setIntegerForKey(key(url), dfftime)

            callback(data)
        else
            if ok then
                print("导航json解析失败", url, content)
            end

            -- 失败一次，优先级向后挪一点
            priority = priority + 1000
            cc.UserDefault:getInstance():setIntegerForKey(key(url), priority)

            callback()
        end
    end)
end

return NavigationUrl