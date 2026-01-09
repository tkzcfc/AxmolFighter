local Helper = require("boot.src.update.Helper")
local Downloader = require("boot.src.update.Downloader")

-- 通用下载器
local universalDownloader = require("boot.src.update.xhttp")

local ManifestDownloadRootDir = cc.FileUtils:getInstance():getWritablePath() .. "manifest/"
local TAG = ".txt"
local DOWNLOAD_TAG = "x"

local Module = class("Module")

function Module:ctor(mgr, name, remoteName)
    self.mgr = mgr
    -- 当前模块名称
    self.moduleName = name
    -- 当前模块下载名称
    self.remoteModuleName = remoteName or name
    -- 正在更新标记
    self.bUpdating = false
    -- 是否已经更新完成
    self.bUpdated = false

    -- 检查成功回调
    self.arrOnCheckCallbacks = {}
    
    self.needDownloadFileList = {}
    self.totalBytes = 0
    self.curBytesMap = {}
    self.fileBytesMap = {}

    self.rootDir = mgr.rootDir
    Helper.createDirectory(ManifestDownloadRootDir)

    -- 清单文件
    self.cacheManifestFile = ManifestDownloadRootDir .. self.remoteModuleName .. TAG
    self.cacheManifestData = Helper.decodeJsonFile(self.cacheManifestFile) or {}
end

-- @brief 判断此模块是否需要下载(不需要下载不代表不需要更新)
function Module:isNeedDownload()
    return not cc.FileUtils:getInstance():isFileExist(self.cacheManifestFile .. DOWNLOAD_TAG)
end

-- @brief 是否已经更新完毕了
function Module:isUpdated()
    return self.bUpdated
end

-- @brief 预下载清单文件
function Module:preCheck()
    self:checkUpdate(nil, true)
end

-- @breif 通过简要清单信息判断模块是否是最新的
-- @version 3
-- 2023-9-9 14:23:38
function Module:isLatestWithBriefManifest()
    -- 禁用热更
    if gConfigData["DebugDisableUpdate"] or gConfigData["DisableHotfix"] then
        return true
    end

    local localBriefManifest = self.mgr.localBriefManifest
    local remoteBriefManifest = self.mgr.briefManifest

    if localBriefManifest and remoteBriefManifest then
        -- 远程模块里面没有此模块
        if not remoteBriefManifest[self.remoteModuleName] then
            self.bUpdated = true
            print("no remote module", self.remoteModuleName)
            return true
        end
        if localBriefManifest[self.remoteModuleName] and remoteBriefManifest[self.remoteModuleName] then
            local localMd5 = localBriefManifest[self.remoteModuleName].md5
            local remoteMd5 = remoteBriefManifest[self.remoteModuleName].md5
            if localMd5 ~= nil and localMd5 == remoteMd5 then
                self.bUpdated = true
                return true
            end
        end
        return false
    else
        -- 信息不足，无法判断
        print("no brief manifest info", tostring(localBriefManifest), tostring(remoteBriefManifest))
        return false
    end
end

-- @brief 设置独立下载器
function Module:setIndependentDownloader()
    if self.downloader then return end

    self.downloader = Downloader.new({
        countOfMaxProcessingTasks = 2,
    })
end

-- @brief 检测模块是否需要更新
function Module:checkUpdate(callback, noCallback)
    -- 将回调函数加入回调数组中
    if not noCallback then
        table.insert(self.arrOnCheckCallbacks, callback)
    end

    -- 正在检查中
    if self.bIsChecking then
        return
    end

    -- 已经是最新的模块了，或者已经获取到清单信息
    if self:isLatestWithBriefManifest() or self.manifest then
        self:emitCheckCallback(true)
        return
    end

    -- 正在检查中...
    self.bIsChecking = true

    local url = string.format("%sv%d/%s.json", self.mgr.rootURL, self.mgr:getVersion(), self.remoteModuleName)

    self.mgr:fetchManifestFile(url, function(data)
        -- 重置正在检查中标记
        self.bIsChecking = false

        local ok = false
        self.manifest = data
        

        -- 文件获取可能被劫持，校验下json字段合法性
        if type(self.manifest) == "table" and type(self.manifest.files) == "table" then
            ok = true

            for k, v in pairs(self.manifest.files or {}) do
                if v.name == nil or v.md5 == nil or v.bytes == nil then
                    ok = false
                    break
                end
            end
            for k, v in pairs(self.manifest.zips or {}) do
                if v.name == nil or v.md5 == nil or v.bytes == nil then
                    ok = false
                    break
                end
            end
        end

        if not ok then
            self.manifest = nil
        end

        self:emitCheckCallback(ok)
    end)
end

-- @brief 开始更新模块
function Module:updateModule(resultCallback, percentCallback)
    self.onResultCallback = resultCallback
    self.onPercentCallback = percentCallback

    -- 已经更新过了
    if self.bUpdated or self:isLatestWithBriefManifest() then
        self:emitResultCallback(true, true)
        return
    end

    -- 正在更新
    if self.bUpdating then return end
    self.bUpdating = true

    
    self.needDownloadFileList = {}
    self.totalBytes = 0
    self.curBytesMap = {}
    self.fileBytesMap = {}
    
    self:collectNeedDownloadFileList(function(list)
        self.needDownloadFileList = list

        -- 不需要下载任何文件，更新完毕
        if #self.needDownloadFileList <= 0 then
            self:emitResultCallback(true, true)
            return
        end

        -- 下载zip时，zip内的散文件就不下载了
        local zipFileMap = {}
        local newList = {}
        for k, v in pairs(self.manifest.zips or {}) do
            local needDownload, needDownloadList = self:isNeedDownloadZipFile(self.needDownloadFileList, v)
            if needDownload then
                -- 添加zip文件
                table.insert(newList, v)
                for _, vv in pairs(needDownloadList) do
                    zipFileMap[vv.name] = true
                end
            end
        end

        for k, v in pairs(self.needDownloadFileList) do
            if not zipFileMap[v.name] then
                table.insert(newList, v)
            end
        end
        self.needDownloadFileList = newList

        -- 统计下载文件信息
        for k, v in pairs(self.needDownloadFileList) do
            self.totalBytes = self.totalBytes + v.bytes
            self.curBytesMap[v.name] = 0
            self.fileBytesMap[v.name] = v.bytes
        end


        local count = 0
        local hasError = false

        for k, v in pairs(self.needDownloadFileList) do

            -- 进度回调
            local function onPercent(percent)
                self.curBytesMap[v.name] = self.fileBytesMap[v.name] * percent
                self.mgr:emit("module_update_progress", self)
            end

            -- 结果回调
            local function onResult(ok)
                if not self.mgr then return end

                count = count + 1
                if ok then
                    self.curBytesMap[v.name] = self.fileBytesMap[v.name]

                    if v.content_hash then
                        for _, file in pairs(self:getZipFiles(v)) do
                            self:updateCacheManifest(file)
                        end
                    else
                        self:updateCacheManifest(v)
                    end
                    self:saveCacheManifest()
                else
                    hasError = true
                end            

                -- 文件下载完成
                if count >= #self.needDownloadFileList then
                    self:emitResultCallback(not hasError, false)
                end
            end


            if v.content_hash then
                -- zip 文件下载+解压
                self:fetchZipFile(v, onResult, onPercent)
            else
                -- 散文件下载
                local url = string.format("%sv%s/%s", self.mgr.rootURL, tostring(v.ver), v.name)
                local fullPath = self.rootDir .. v.name
                if type(v.to) == "string" then
                    fullPath = self.rootDir .. v.to
                end

                Helper.removeFile(fullPath)
                self:fetchFile(url, fullPath, onResult, onPercent, v.md5)
            end
        end

        -- 降低进度更新频率
        self:unscheduleProgressRefresh()
        self.progressRefreshScheduleHandler = cc.Director:getInstance():getScheduler():scheduleScriptFunc(function (dt)
            if self.onPercentCallback then
                self.onPercentCallback(self)
            end
        end, 1 / 20, false)
    end)
end

-- @brief 获取zip内的文件列表
function Module:getZipFiles(zipInfo)
    local inZipFiles = {}
    for k, v in pairs(self.manifest.files) do
        if v.inzip == zipInfo.name then
            table.insert(inZipFiles, v)
        end
    end
    return inZipFiles
end

function Module:collectNeedDownloadFileList(callback)
    self:unscheduleCollect()

    local curCount = 1
    local needDownloadFileList = {}

    self.collectScheduleHandler = cc.Director:getInstance():getScheduler():scheduleScriptFunc(function (dt)
        local start = NowEpochMS()
        for i = 1, 200 do
            local file = self.manifest.files[curCount]
            if not file then
                self:unscheduleCollect()
                if callback then callback(needDownloadFileList) end
                return
            end

            if i % 30 == 0 and NowEpochMS() - start > 25 then
                break
            end

            if self:needUpdateFile(file) then
                table.insert(needDownloadFileList, file)
            end
            curCount = curCount + 1
        end
    end, 0, false)
end


-- @brief 判断是否需要下载zip文件
-- @param needDownloadFileList 需要更新的文件列表
-- @param zipInfo zip信息
function Module:isNeedDownloadZipFile(needDownloadFileList, zipInfo)
    -- zip中的总文件数量
    local inZipCount = 0
    for k, v in pairs(self.manifest["files"] or {}) do
        if v.inzip == zipInfo.name then
            inZipCount = inZipCount + 1
        end
    end

    -- 统计需要下载的文件数量在zip中的数量
    local needDownloadInZipCount = 0
    local needDownloadInZipBytes = 0
    local inzipList = {}
    for k, v in pairs(needDownloadFileList) do
        if v.inzip == zipInfo.name then
            needDownloadInZipBytes = needDownloadInZipBytes + v.bytes
            needDownloadInZipCount = needDownloadInZipCount + 1
            table.insert(inzipList, v)
        end
    end

    if needDownloadInZipCount <= 0 or inZipCount <= 0 then
        return false
    end

    -- 脏文件数量占比阈值
    local threshold = zipInfo.update_policy_threshold or 0.2
    -- 脏文件大小占比阈值
    local file_size_threshold = zipInfo.update_policy_file_size_threshold or 0.8

    -- 根据脏文件数量占比评估是否下载zip
    local needDownload = threshold <= (needDownloadInZipCount / inZipCount)

    -- 根据脏文件大小占比评估是否下载zip
    if file_size_threshold and not needDownload and zipInfo.bytes > 0 then
        needDownload = file_size_threshold <= (needDownloadInZipBytes / zipInfo.bytes)
    end

    print("needDownload zip:", zipInfo.name, needDownload)
    print("file number", threshold, needDownloadInZipCount, inZipCount)
    print("file bytes", file_size_threshold, needDownloadInZipBytes, zipInfo.bytes)

    if needDownload then
        return needDownload, inzipList
    end
end

-- @brief 获取当前模块需要下载的总字节数
function Module:getTotalBytes()
    return self.totalBytes
end

-- @brief 获取当前模块已下载的字节数
function Module:getCurrentBytes()
    local bytes = 0
    for k, v in pairs(self.curBytesMap or {}) do
        bytes = bytes + v
    end
    return bytes
end

-- @brief 派发结果回调
function Module:emitResultCallback(ok, noFileUpdate)
    self.bUpdating = false
    self.bUpdated = ok

    -- 将模块md5值存档
    if ok and self.mgr and self.mgr.localBriefManifest then
        if self.manifest and self.manifest.md5 then
            self.mgr.localBriefManifest[self.remoteModuleName] = {
                md5 = self.manifest.md5
            }
            self.mgr:saveLocalBriefManifest()
        end
    end
    -- 存档本模块清单
    self:saveCacheManifest(ok and self:isNeedDownload())
    if ok and self:isNeedDownload() then
        cc.FileUtils:getInstance():writeStringToFile("{}", self.cacheManifestFile .. DOWNLOAD_TAG)
    end

    self.onPercentCallback = nil

    if self.onResultCallback then
        self.onResultCallback(ok, noFileUpdate)
        self.onResultCallback = nil
    end
    self:unscheduleProgressRefresh()

    self.mgr:emit("module_update_result", self, ok, noFileUpdate)

    -- 下载完成，销毁下载器
    if ok and self.downloader then
        self.downloader:destroy()
        self.downloader = nil
    end
end

-- @brief 派发检查更新回调
function Module:emitCheckCallback(ok)
    for k, v in pairs(self.arrOnCheckCallbacks or {}) do
        if type(v) == "function" then
            v(ok)
        end
    end
    self.arrOnCheckCallbacks = {}
end

function Module:unscheduleProgressRefresh()
    if self.progressRefreshScheduleHandler then
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(self.progressRefreshScheduleHandler)
        self.progressRefreshScheduleHandler = nil
    end
end

function Module:unscheduleCollect()
    if self.collectScheduleHandler then
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(self.collectScheduleHandler)
        self.collectScheduleHandler = nil
    end
end

function Module:destroy()
    self:unscheduleProgressRefresh()
    self:unscheduleCollect()
    self.onResultCallback = nil
    self.onPercentCallback = nil
    self.mgr = nil
end

function Module:fetchZipFile(zipFileInfo, onResult, onPercent)
    local url = string.format("%sv%s/%s", self.mgr.rootURL, tostring(zipFileInfo.ver), zipFileInfo.name)

    local fullPath = self.rootDir .. zipFileInfo.md5 .. ".zip"

    -- 解压占总进度的百分比
    local unzipPercent = 0.1

    local function onResultCall(ok)
        if ok then
            game_utils.unzip(fullPath, self.rootDir, "", function(success)
                print("unzip", success, zipFileInfo.name)
                if success then
                    onPercent(1)
                    onResult(true)
                    Helper.removeFile(fullPath)
                else
                    onResult(false)
                end
            end, function(percent)
                -- 解压进度
                onPercent((1 - unzipPercent) + percent * unzipPercent)
            end)
        else
            onResult(false)
        end
    end

    local function onPercentCall(percent)
        onPercent(percent * (1 - unzipPercent))
    end

    self:fetchFile(url, fullPath, onResultCall, onPercentCall, zipFileInfo.md5)
end

function Module:fetchFile(url, tofile, onResult, onPercent, checksum)
    local downloader = self.downloader
    if not downloader then
        downloader = universalDownloader
    end

    downloader:download(url, tofile, function()
        print("[Module:fetchFile] download success:", url)
        onResult(true)
    end, function()
        print("[Module:fetchFile] download failed:", url)
        onResult(false)
    end, onPercent, 5, checksum)
end

function Module:saveCacheManifest(force)
    if force then self.cacheManifestDataDirty = true end

    if not self.cacheManifestDataDirty then return end
    self.cacheManifestDataDirty = false
    
    Helper.writeTabToFile(self.cacheManifestData, self.cacheManifestFile)    
end

function Module:updateCacheManifest(fileInfo)
    self.cacheManifestDataDirty = true
    self.cacheManifestData[fileInfo.name] = fileInfo
end

function Module:needUpdateFile(fileInfo)
    local cacheInfo = self.cacheManifestData[fileInfo.name]
    if cacheInfo and cacheInfo.name == fileInfo.name then
        if cacheInfo.md5 == fileInfo.md5 then
            -- 不需要下载
            return false
        end
    end

    if self.mgr:needUpdateFile(fileInfo) then
        return true
    end

    self:updateCacheManifest(fileInfo)
    return false
end

return Module
