-- 错误日志上传

function isShowDebugInfo()
    return gConfigData and gConfigData["ShowDebugInfo"]
end

-- 按钮创建
local function newButton(parent, pos, size, color, text, callback)
    local colorPanel = ccui.Layout:create()
    colorPanel:setContentSize(size)
    colorPanel:setAnchorPoint(cc.p(0.5, 0.5))
    colorPanel:setPosition(pos)
    colorPanel:setBackGroundColorType(1)
    colorPanel:setBackGroundColor(color)
    colorPanel:setBackGroundColorOpacity(255)
    parent:addChild(colorPanel)

    -- 文本创建
    local label = cc.Label:create()
    label:setSystemFontSize(30)
    label:setString(text)
    label:setAnchorPoint(cc.p(0.5, 0.5))
    label:setPosition(cc.p(size.width * 0.5, size.height * 0.5))
    colorPanel:addChild(label)

    colorPanel:setTouchEnabled(true)
    colorPanel:addClickEventListener(callback)
    colorPanel:addTouchEventListener(function(_, eventType)
        -- BEGAN
        if eventType == 0 then
            colorPanel:setBackGroundColorOpacity(200)
        -- ENDED
        -- CANCELED
        elseif eventType == 2 or eventType == 3 then
            colorPanel:setBackGroundColorOpacity(255)
        end
    end)
end

local function showDebugInfo(message)
    if isShowDebugInfo() then
        xpcall(function()
            local winSize =  cc.Director:getInstance():getVisibleSize()

            local panel = ccui.Layout:create()
            panel:setContentSize(winSize)
            panel:setBackGroundColorType(ccui.LayoutBackGroundColorType.solid)
            panel:setBackGroundColor(cc.c3b(0, 0, 0))
            panel:setBackGroundColorOpacity(220)
            panel:setTouchEnabled(true)
            panel:setAnchorPoint(0, 0)

            local label = cc.Label:create()
            label:setSystemFontSize(30)
            label:setString(message)
            label:setAnchorPoint(cc.p(0, 1))

            local scrollView = ccui.ScrollView:create()
            scrollView:setClippingEnabled(false)
            scrollView:setContentSize(cc.size(winSize.width, winSize.height - 100))
            scrollView:setAnchorPoint(cc.p(0.5, 0.5))
            scrollView:setPosition(winSize.width * 0.5, winSize.height * 0.5)
            scrollView:setDirection(3)
            scrollView:setBounceEnabled(true)
            scrollView:setInnerContainerSize(label:getContentSize())
            scrollView:addChild(label)
            panel:addChild(scrollView)
            
            label:setPosition(0, scrollView:getInnerContainerSize().height)
            
            cc.Director:getInstance():getRunningScene():addChild(panel, 0xffff)

            newButton(panel, cc.p(winSize.width * 0.3, 200), cc.size(140, 50), cc.c4b(100, 200, 100), "复制", function()
                gDeviceData:setClipboardData(message)
            end)
            newButton(panel, cc.p(winSize.width * 0.7, 200), cc.size(140, 50), cc.c4b(210, 80, 80), "关闭", function()
                panel:removeFromParent()
            end)
        end, function(msg)
            local message = ""
            message = message .. "----------------------------------------\n"
            message = message .. "LUA ERROR: " .. tostring(msg) .. "\n"
            message = message .. debug.traceback()
            message = message .. "\n----------------------------------------\n"
            print(message)
        end)

        return true
    end
end

local httpCount = 0
local logMap = {}

local httpPost
httpPost = function(postData, callback, retryCount)
    retryCount = retryCount or 0

    local xhr = cc.XMLHttpRequest:new()
    xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON
    xhr:open("POST", "http://47.236.131.154:85/api/upload_log")
    xhr:registerScriptHandler(function()
        if xhr.readyState == 4 and (xhr.status >= 200 and xhr.status < 207) then -- 成功
            if callback then callback(true) end
        else
            if retryCount <= 0 then
                if callback then callback(false) end
            else
                httpPost(postData, callback, retryCount - 1)
            end
        end
    end)
    xhr:setRequestHeader("Content-Type", "application/json")
    xhr:setRequestHeader("Accept", "application/json")
    xhr:send(postData)
end

function LuaErrorReportSend(errMsg, callback, debugModeDisableReporting, errMsgDetails)
    -- 同一错误只上传一次
    if logMap[errMsg] then 
        if callback then callback() end
        return
    end
    logMap[errMsg] = true
    if debugModeDisableReporting and showDebugInfo(errMsg) then
        return
    end

    -- 当前这个包还是以马甲包模式运行，不上报马甲包的错误
    if gConfigData.DisableHotfix then
        return
    end
    
    -- 限制最大请求数量
    if httpCount > 5 then 
        if callback then callback() end
        return
    end

    httpCount = httpCount + 1

    local versionInfo = {
        hotfix = tostring(gConfigData.AssetsUrl) .. "v" .. tostring(gModuleManager:getVersion()),
        branch = "h_main",
        patch_time = "2024-9-20",
    }

    -- 当前场景信息
    if gViewManager then
        local curView = gViewManager:getCurView()
        if curView then
            versionInfo.viewName = tostring(curView.__cname)
            if curView.__cname == "GameCasinoView" then
                versionInfo.game_id = curView.gameRealId
            end
        end
    end
    -- 当前UI信息
    if gUIManager and gUIManager:curContext() then
        local uiStack = {}
        local uis = gUIManager:curContext().tCurrentUIs
        for i = 1, uis:size() do
            table.insert(uiStack, uis:at(i):getName())
        end
        versionInfo.uiStack = uiStack
    end

    local data = {
        log_type = "error",
        message = errMsg,
        user = "no login",
        package = tostring(gConfigData["PackageName"]),
        nav_url = tostring(gConfigData["NavUrl"]),
        version = require("cjson").encode(versionInfo),
        logs = "",
    }
    
    if gLobbyData and gLobbyData:getUserData() then
        data.user = tostring(gLobbyData:getUserData().id or 0)
    end

    if errMsgDetails then
        data.logs = errMsgDetails
    else
        if GetLastLogs then
            local logs = GetLastLogs()
            if #logs > 0 then
                data.logs = table.concat(logs, "\n")
            end
        end
    end

    httpPost(require("cjson").encode(data), function(ok)
        httpCount = httpCount - 1
        if not ok then
            logMap[errMsg] = nil
        end
        if callback then callback(true) end
    end, 3)
end

function __G__TRACKBACK__(msg)
    gIsCatchLuaException = true
    local message = ""
    message = message .. "LUA ERROR: " .. tostring(msg) .. "\n"
    message = message .. debug.traceback()

    local ok, err = pcall(LuaErrorReportSend, message, nil, true)
    if not ok then
        print("LuaErrorReportSend error:", err)
    end
    print(message)
end


local function delay_call(callback, time)
    time = time or 0
    local sharedScheduler = cc.Director:getInstance():getScheduler()
    local handle
    handle = sharedScheduler:scheduleScriptFunc(function(dt)
        sharedScheduler:unscheduleScriptEntry(handle)
        if callback then callback() end
    end, time, false)
end

-- 上报机器对各个格式支持情况
local first_upload = nil
first_upload = function()
    if isShowDebugInfo() then
        return
    end
    if cc.UserDefault:getInstance():getBoolForKey("analysis_first_up", false) then
        return
    end

    if gLobbyData and gLobbyData:getUserData() then
        local postData = {
            cli_type = "h5",
            user = tostring(gLobbyData:getUserData().id or 0),
            package = tostring(gConfigData["PackageName"]),
            region = tostring(gConfigData.Region),
            configuration_info = ""
        }
        
        if game_utils and game_utils.get_engine_cfg_info then
            postData.configuration_info = game_utils.get_engine_cfg_info()
        end

        local xhr = cc.XMLHttpRequest:new()
        xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON
        xhr:open("POST", "http://47.236.131.154:85/api/upload_statistics_cli_cfg")
        xhr:registerScriptHandler(function()
            if xhr.readyState == 4 and (xhr.status >= 200 and xhr.status < 207) then -- 成功
                cc.UserDefault:getInstance():setBoolForKey("analysis_first_up", true)
            end
        end)
        xhr:setRequestHeader("Content-Type", "application/json")
        xhr:setRequestHeader("Accept", "application/json")
        xhr:send(require("cjson").encode(postData))
    else
        delay_call(first_upload, 5)
    end
end

delay_call(first_upload, 5)
