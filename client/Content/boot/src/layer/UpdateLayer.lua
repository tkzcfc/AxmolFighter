
local Helper = require("boot.src.update.Helper")
local utils = require("boot.src.utils")
require("boot.src.config")
local ConfigurationInfo = require("boot.src.update.ConfigurationInfo")
local json = require("cjson")

local function fmtBytes(count)
    if count > 1024 * 1024 then
        return string.format("%.1fMB", count / 1024 / 1024)
    else
        return string.format("%dKB", count / 1024)
    end
end

local UpdateLayer = class("UpdateLayer", function()
    return cc.Node:create()
end)

function UpdateLayer:ctor()    
    self.loadingLayer = require("boot.src.layer.LoadingLayer").new()
    self:addChild(self.loadingLayer)

    self:fetchConfig()
end

-- 1-1 获取一级导航服配置
function UpdateLayer:fetchConfig()
    self.loadingLayer:reset()
    self.loadingLayer:setLoadBarVisible(false)
    self.loadingLayer:setTipText("CONNECTING...", true)


    local nav = require("boot.src.update.NavigationUrl").new(gConfigData["NavUrl"], gConfigData["BackupNavUrls"], gConfigData["PackageName"])

    local cfgFile = cc.FileUtils:getInstance():getWritablePath() .. "global_nav_neon.json"
    local localCfg = Helper.decodeJsonFile(cfgFile)

    if localCfg and localCfg.data then
        self:onConfigResponse(localCfg.data, false, cfgFile)

        -- 后台请求一级导航服信息,下次启动就用最新的导航配置
        nav:fetch(function(data)
            if data then
                _G["gLatestNavigationData"] = data
                Helper.writeTabToFile({
                    data = data
                }, cfgFile)
            end
        end)
    else
        nav:fetch(function(data)
            if data then
                -- 导航信息获取成功
                utils:delay(function()
                    self:onConfigResponse(data, true, cfgFile)
                end)
            else
                -- 如果是IOS，首次启动玩家没有授权网络权限也是会失败的，这个时候不弹出弹窗 自动继续请求
                if device.platform == "ios" then
                    utils:delay(function()
                        nav:retry()
                    end, 0.5)
                else
                    utils:showMsgBox(utils:langText("获取导航信息失败, 是否重试？"), function()
                        nav:retry()
                    end, function()
                        utils:exit()
                    end)
                end
            end
        end)
    end
end

-- 1-2 导航服配置获取成功
function UpdateLayer:onConfigResponse(data, isRemote, localFileName)
    if isRemote then
        local cfg = {
            data = data
        }
        Helper.writeTabToFile(cfg, localFileName)
    end

    local url = data["login_download_url"]

    if string.sub(url, -1, -1) ~= "/" then
        url = url .. "/"
    end

    -- 如果热更地址为： "https://yindinixiya.oss-ap-southeast-5.aliyuncs.com/"    资源分支为test
    -- 则转换后的热更地址为： "https://yindinixiya.oss-ap-southeast-5.aliyuncs.com/test/"
    if type(gConfigData["ResourceBranch"]) == "string" and gConfigData["ResourceBranch"] ~= "" then
        if string.sub(url, -1, -1) ~= "/" then
            url = url .. "/"
        end
        url = url .. gConfigData["ResourceBranch"] .. "/"
    end
    self.hotfixURL = url

    -- 网关地址重定向
    gNavConfigData = data
    gHotfixURL     = self.hotfixURL

    ax.UserDefault:getInstance():setStringForKey("boot_hotfix_url", gHotfixURL)

    self:doUpdate()
end

function UpdateLayer:setDefaultSearchPath()
    local writablePath = cc.FileUtils:getInstance():getWritablePath()
    cc.FileUtils:getInstance():addSearchPath(writablePath .. "download", true)
    cc.FileUtils:getInstance():addSearchPath("src", true)
    cc.FileUtils:getInstance():addSearchPath(writablePath .. "download/src", true)
    cc.FileUtils:getInstance():addSearchPath("res", true)
    cc.FileUtils:getInstance():addSearchPath(writablePath .. "download/res", true)
end

-- 开始热更逻辑
function UpdateLayer:doUpdate()
    print("doUpdate: start")
    
    if gModuleManager == nil then
        gModuleManager = require("boot.src.update.ModuleManager").new()
        gModuleManager:resetRootURL(self.hotfixURL)
    end

    local needFetchBriefManifest = not gModuleManager:hasBriefManifest()
    -- 禁用热更
    if gConfigData["DebugDisableUpdate"] or gConfigData["DisableHotfix"] then
        needFetchBriefManifest = false
    end

    if needFetchBriefManifest then
        -- 获取清单信息
        gModuleManager:fetchBriefManifest(function(ok)
            if ok then
                print("fetchBriefManifest success(2)")
                utils:delay(function()
                    self:doUpdate()
                end)
            else
                print("fetchBriefManifest failed(2)")
                utils:showMsgBox(utils:langText("版本更新失败, 是否重试？"), function()
                    self:doUpdate()
                end, function()
                    utils:exit()
                end)
            end
        end)
    else
        print("update base module")

        self.showDownloadingTip = false
        self.loadingLayer.normalSpeed = self.loadingLayer.quickSpeed / 4

        local modules = {"base", "lang_cn"}

        for _, v in pairs(utils:getLangs()) do
            if v ~= "cn" then
                table.insert(modules, "lang_" .. tostring(v))
            end
        end
        dump(modules, "modules")

        gModuleManager:updateModules(modules, function(ok)
            self.loadingLayer:setPercent(100, true)
            self.loadingLayer:setFinishCallback(function()
                if ok then
                    print("doUpdate: success")
                    self:onUpdateFinish()
                else
                    print("doUpdate: failed")
                    utils:showMsgBox(utils:langText("版本更新失败, 是否重试？"), function()
                        self.showDownloadingTip = false
                        self.loadingLayer:reset()
                        self:doUpdate()
                    end, function()
                        utils:exit()
                    end)
                end
            end)
        end, function(currentBytes, totalBytes, speed, totalPercent)
            if not self.showDownloadingTip then
                self.showDownloadingTip = true
                self.loadingLayer:setLoadBarVisible(true)
                self.loadingLayer:setTipText("DOWNLOADING...", true)
            end
            self.loadingLayer:setPercent(totalPercent * 100)
            -- self.loadingLayer:setSpeedText(string.format("%s / %s (%s/s)", fmtBytes(currentBytes), fmtBytes(totalBytes), fmtBytes(speed)))
            self.loadingLayer:setSpeedText(string.format("%s / %s", fmtBytes(currentBytes), fmtBytes(totalBytes)))
        end)
    end
end

function UpdateLayer:onUpdateFinish()
    self:setDefaultSearchPath()
    print("onUpdateFinish ======>")

    xpcall(function()
        if device.platform == "android" then
            local luaj = require("axmol.core.luaj")
            local ok, ret = luaj.callStaticMethod("dev/axmol/app/AppActivity", "getAvailableMemory", {}, "()I")
            if ok then
                G_AvailableMemory = ret
                print("availableMemory:", ret)
                -- 可用内存容量小于2G使用GRBA4444格式渲染
                if ret < 1024 * 2 then
                    if ConfigurationInfo:isSupportsETC2() then
                        print("use GRBA8, supportsETC2")
                    else
                        print("use GRBA4")
                        cc.Texture2D:setDefaultAlphaPixelFormat(cc.TEXTURE_PF_RGBA4)
                    end
                else
                    print("use GRBA8")
                end
            else
                print("get available memory failed")
                if ConfigurationInfo:isSupportsETC2() then
                    print("use GRBA8, supportsETC2")
                else
                    print("use GRBA4")
                    cc.Texture2D:setDefaultAlphaPixelFormat(cc.TEXTURE_PF_RGBA4)
                end
            end
        end
    end, __G__TRACKBACK__)

    game_utils.load_chunks("chunks/base.chunk")
    require("logic.main")
end

return UpdateLayer
