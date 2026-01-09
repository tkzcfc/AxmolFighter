local EventEmitter = import(".EventEmitter")
local ModuleManager = class("ModuleManager", EventEmitter)
local json = require("cjson")
local Helper = import(".Helper")
local Module = import(".Module")
local ConfigurationInfo = import(".ConfigurationInfo")
local SpeedCalculator = import(".SpeedCalculator")

-- apk包内内置清单文件
local BuiltinManifestFile = "boot/src/filelist.manifest"

-- apk包内置模块信息文件
local BuiltinModuleInfoManifestFile = "boot/src/builtin_module_info.manifest"


function ModuleManager:ctor(mgr)
    ModuleManager.super.ctor(self)
    self.fileUtilsInstance = cc.FileUtils:getInstance()

    -- 本地目录根目录
    self.rootDir = self.fileUtilsInstance:getWritablePath() .. "download/"
    -- 保证根目录存在
    Helper.createDirectory(self.rootDir)

    self:initialize()
    if mgr then
        self:merge(mgr)
    end
end

function ModuleManager:resetRootURL(url)
    if string.sub(url, -1, -1) ~= "/" then
        url = url .. "/"
    end
    -- 清单根路径
    self.rootURL = url
    
    for k, v in pairs(self.moduleMap or {}) do
        v:destroy()
    end
    self.moduleMap = {}

    self.isBusy = false

    self.briefManifest = nil
end

function ModuleManager:isNeedDownload(names)
    -- 禁用热更
    if gConfigData["DebugDisableUpdate"] or gConfigData["DisableHotfix"] then
        return false
    end
    for k, v in pairs(names) do
        if self:get(v):isNeedDownload() then
            return true
        end
    end
    return false
end

function ModuleManager:preDownload(names, isDownloadInBackground)
    -- 禁用热更
    if gConfigData["DebugDisableUpdate"] or gConfigData["DisableHotfix"] then
        return
    end
    
    names = Helper.table_unique(names, true)
    if #names <= 0 then
        return
    end

    for _, v in pairs(names) do
        local module = self:get(v)
        
        -- 后台下载的模块使用单独的下载器
        if isDownloadInBackground and not module.bUpdating then
            module:setIndependentDownloader()
        end

        module:checkUpdate(function(ok)
            if ok and not module.bUpdating then
                module:updateModule(function()end, function() end, isDownloadInBackground)
            end
        end)
    end
end

function ModuleManager:isNeedUpdate(names)
    -- 禁用热更
    if gConfigData["DebugDisableUpdate"] or gConfigData["DisableHotfix"] then
        return false
    end
    for k, v in pairs(names) do
        if self:get(v):isNeedDownload() or not self:get(v):isLatestWithBriefManifest() then
            return true
        end
    end
    return false
end

function ModuleManager:updateModules(names, resultCallback, percentCallback)
    if self.isBusy then return false end
    self.isBusy = true

    self.onResultCallback = resultCallback
    self.onPercentCallback = percentCallback 

    -- 禁用热更
    if gConfigData["DebugDisableUpdate"] or gConfigData["DisableHotfix"] then
        self:emitResultCallback(true, true)
        return
    end

    names = Helper.table_unique(names, true)
    local t = {}
    for _, v in pairs(names) do
        if not self:get(v):isUpdated() then
            table.insert(t, v)
        end
    end
    names = t
    if #names <= 0 then
        self:emitResultCallback(true, true)
        return
    end

    self.fileUtilsInstance:purgeCachedEntries()

    local checkCount = 0
    local hasError = false

    for _, v in pairs(names) do
        self:get(v):checkUpdate(function(ok)
            checkCount = checkCount + 1
            if not ok then hasError = true end

            if checkCount >= #names then
                if hasError then
                    self:emitResultCallback(false, false)
                else
                    self:_updateModulesEx(names)
                end
            end
        end)
    end

    return true
end

function ModuleManager:busy()
    return self.isBusy
end

function ModuleManager:setUpdateFinishCallback(onUpdateFinishCallback)
    self.onUpdateFinishCallback = onUpdateFinishCallback
end

-- @brief 预检查模块
function ModuleManager:preCheck(names)
    for _, v in pairs(names or {}) do
        self:get(v):preCheck()
    end
end

-- @brief 是否有简要清单信息
function ModuleManager:hasBriefManifest()
    return self.briefManifest ~= nil
end

function ModuleManager:getVersion()
    if self.briefManifest then
        return self.briefManifest.cur_version or 0
    end
    return 0
end

--------------------------------------------------------------- private ---------------------------------------------------------------

function ModuleManager:initialize()
    -- apk包内内置清单数据
    self.builtinList = Helper.decodeJsonFile(BuiltinManifestFile) or {}
    self.builtinModuleInfo = Helper.decodeJsonFile(BuiltinModuleInfoManifestFile) or {}

    self.builtinHashMap = {}
    for k, v in pairs(self.builtinList) do
        self.builtinHashMap[v.name] = v
    end

    -- 本地简要信息清单名称
    self.localBriefManifestFile = self.rootDir .. "local_brief.manifest"
    self.localBriefManifest = Helper.decodeJsonFile(self.localBriefManifestFile)
    if not self.localBriefManifest then
        self.localBriefManifest = {}
        self:saveLocalBriefManifest()
    end
end

function ModuleManager:merge(mgr)
    -- 去除版本信息
    -- "https://yindinixiya.oss-ap-southeast-5.aliyuncs.com/v100/" -> "https://yindinixiya.oss-ap-southeast-5.aliyuncs.com/"
    local url = string.gsub(mgr.rootURL, "(.+)(v%d+/)$", "%1")

    if mgr.rootURL == url then
        self:resetRootURL(url)
        self.briefManifest = mgr.briefManifest
    else
        self:resetRootURL(url)
    end
end

function ModuleManager:fetchBriefManifest(callback)
    if self:hasBriefManifest() then return end

    local ManifestDownloadRootDir = self.fileUtilsInstance:getWritablePath() .. "manifest/"
    Helper.createDirectory(ManifestDownloadRootDir)

    local url = self.rootURL .. "brief_manifest.json"

    self.briefManifest = nil
    self:fetchManifestFile(url, function(data)
        if data then
            data.cur_version = tonumber(data.cur_version)
            if type(data.cur_version) ~= "number" then
                print("清单文件格式错误")
                dump(data)
                data = nil
            end
        end
        self.briefManifest = data
        if callback then callback(self:hasBriefManifest()) end
    end, true)
end

function ModuleManager:destroy()
    for k, v in pairs(self.moduleMap) do
        v:destroy()
    end
    self.moduleMap = {}
    self.isDestroyed = true
end

function ModuleManager:needUpdateFile(info)
    local builtinInfo = self.builtinHashMap[info.name]
    if builtinInfo and builtinInfo.md5 == info.md5 then
        -- 删除热更下载的文件
        Helper.removeFile(self.rootDir .. info.name)

        -- 创建对应目录
        local dirName = string.match(self.rootDir .. info.name, "(.+)/[^/]*$")
        Helper.createDirectory(dirName)

        -- 拷贝包内文件到外部
        local data = self.fileUtilsInstance:getDataFromFile(info.name, true)
        if data and self.fileUtilsInstance:writeStringToFile(data, self.rootDir .. info.name) then
            return false
        end
    end

    return true
end

function ModuleManager:getBuiltinModuleInfo(moduleName)
    return self.builtinModuleInfo[moduleName]
end

function ModuleManager:get(name)
    local m = self.moduleMap[name]
    if not m then
        -- 支持astc的客户端，去下载astc格式的资源
        local remoteName = name

        if not self:getBuiltinModuleInfo(name) then
            local astcName = name .. "_astc"
            if self.briefManifest and type(self.briefManifest[astcName]) == "table" and ConfigurationInfo:isSupportsASTC() then
                remoteName = astcName
            end
        else
            print("Built in module, download original resources:", name)
        end
        m = Module.new(self, name, remoteName)
        self.moduleMap[name] = m
    end
    return m
end

function ModuleManager:saveLocalBriefManifest()
    if not self.localBriefManifestFile then return end
    Helper.writeTabToFile(self.localBriefManifest, self.localBriefManifestFile)
end

function ModuleManager:_updateModulesEx(names)
    local count = 0
    local hasError = false
    local noFileUpdateCount = 0
    local calculator = SpeedCalculator.new()

    local function result(ok, noFileUpdate)
        count = count + 1
        if not ok then hasError = true end
        if noFileUpdate then noFileUpdateCount = noFileUpdateCount + 1 end

        if count >= #names then
            -- 清理一下路径缓存
            if not hasError then
                self.fileUtilsInstance:purgeCachedEntries()
            end
            self:emitResultCallback(not hasError, noFileUpdateCount == count)
        end
    end

    local function percent()
        local cur, total = 0, 0

        for k, v in pairs(names) do
            local m = self.moduleMap[v]
            cur = cur + m:getCurrentBytes()
            total = total + m:getTotalBytes()
        end

        calculator:collectData(cur)
        
        local percent = 1
        if total > 0 then percent = cur / total end

        self:emitPercentCallback(cur, total, calculator:getSpeed(), percent)
    end

    for k, v in pairs(names) do
        self:get(v):updateModule(result, percent)
    end
end

function ModuleManager:emitResultCallback(ok, noFileUpdate)
    if self.onResultCallback then
        xpcall(self.onResultCallback, __G__TRACKBACK__, ok, noFileUpdate)
        self.onResultCallback = nil
    end
    self.onPercentCallback = nil
    self.isBusy = false

    if self.onUpdateFinishCallback then
        xpcall(self.onUpdateFinishCallback, __G__TRACKBACK__)
    end
end

function ModuleManager:emitPercentCallback(currentBytes, totalBytes, speed, totalPercent)
    if self.onPercentCallback then
        xpcall(self.onPercentCallback, __G__TRACKBACK__, currentBytes, totalBytes, speed, totalPercent)
    end
end

function ModuleManager:fetchManifestFile(url, callback, cacheToMemory)
    local quantity = 2
    local curCount = 0

    for i = 1, quantity do
        self:delay(function()
            if self.isDestroyed then return end
            -- 已经下完啦
            if curCount >= quantity then return end

            local readFunc = Helper.curlRead
            local reTryCount = 0

            if i % 2 == 0 then
                readFunc = Helper.httpRead
                -- httpRead 表示超时时间
                reTryCount = 10
            end

            readFunc(url, function(ok, content)
                if self.isDestroyed then return end
                if curCount >= quantity then return end
                
                if not ok then content = "null" end

                local status, data = pcall(json.decode, content)
                if ok and status and type(data) == "table" then
                    curCount = quantity
                    if callback then callback(data) end
                else
                    curCount = curCount + 1
                    if curCount >= quantity and callback then callback() end
                end
            end, reTryCount)

        end, (i - 1) * 3)
    end
end

function ModuleManager:delay(callback, time)
    time = time or 0
    local sharedScheduler = cc.Director:getInstance():getScheduler()
    local handle
    handle = sharedScheduler:scheduleScriptFunc(function(dt)
        sharedScheduler:unscheduleScriptEntry(handle)
        if self.isDestroyed then return end
        if callback then callback() end
    end, time, false)
end

return ModuleManager
