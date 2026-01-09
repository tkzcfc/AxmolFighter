-- @Author : 
-- @Date   : 2020-07-22 16:44:57
-- @remark : 全局函数定义

local LuaExtend = require("framework.utils.LuaExtend")
local StringUtils = require("framework.utils.StringUtils")

local co_resume = coroutine.resume
local co_yield = coroutine.yield
local sharedScheduler = cc.Director:getInstance():getScheduler()

yield = coroutine.yield

-- @brief 异步任务执行
-- @param job 任务函数
--[[ 
    example:

    go(function()
        for i = 1, 10 do
            print("i = ", i)
            -- 挂起一秒
            sleep(1)
        end
    end)

    结果：每隔5秒输出一次i的值
]]
local currentRunHandle = nil
function go(job, final)
    assert(type(job) == "function", "job must be a function")

    local handle, finish

    local worker = coroutine.create(function()
        xpcall(job, __G__TRACKBACK__)
        finish = true
    end)

    handle = sharedScheduler:scheduleScriptFunc(function(dt)
        currentRunHandle = handle
        local result, err = co_resume(worker)

        -- 任务出错或任务结束,停止任务
        if not result or finish == true then
            sharedScheduler:unscheduleScriptEntry(handle)
            if final then
                xpcall(final, __G__TRACKBACK__)
            end
        end
        currentRunHandle = nil
    end, 0, false)

    return handle
end

function join_all(...)
    local jobs = {...}
    local num_jobs = #jobs
    if num_jobs == 0 then return end

    if type(jobs[1]) == "table" then
        jobs = jobs[1]
        num_jobs = #jobs
        if num_jobs == 0 then return end
    end

    local num_finished = 0

    for i = #jobs, 1, -1 do
        go(jobs[i], function() num_finished = num_finished + 1 end)
    end

    while num_finished < num_jobs do
        co_yield()
    end
end

-- @brief 异步任务挂起
-- @param duration 挂起时间,为空则默认挂起一帧
function sleep(duration)
    co_yield()

    if duration == nil then
        return
    end

    local timeout = NowEpochMS() + duration * 1000
    while timeout > NowEpochMS() do 
		co_yield()
	end
end

-- @brief 取消异步任务
-- @param handle 异步任务句柄
function kill(handle)
    if handle == nil then return end
    sharedScheduler:unscheduleScriptEntry(handle)
end

function killSelf()
    if currentRunHandle then
        kill(currentRunHandle)
        currentRunHandle = nil
        co_yield()
    end
end

-- @brief 字符串格式化
-- @param format 格式化字符串
-- @example
--  fmt("hello {0}, today is {1}", "world", "friday") => "hello world, today is friday"
--  fmt("hello ${name}, today is ${day}", {name="world", day="friday"}) => "hello world, today is friday"
function fmt(format, ...)
    local args = {...}
    if type(args[1]) == "table" and #args == 1 then
        args = args[1]

        format = format:gsub("%$%{([^}]*)%}", args)
        return format
    end

    format = string.gsub(format, "({%d+})", function(arg)
        local idx = string.match(arg, "{(%d+)}")
        idx = idx + 1
        return tostring(args[idx])
    end)

    format = string.gsub(format, "%%{%%", "{")
    format = string.gsub(format, "%%}%%", "}")

    return format
end

-- @brief 枚举定义
function enum(et)
    local t = {}
    local s, i = 0, 0

    for k, v in pairs(et) do
        if type(v) == 'number' then
            s = v
            i = 0
        else
            t[v] = s + i
            i = i + 1
        end
    end
    return t
end

-- @brief 属性定义
function property(t, name, defaultVal)
    local funcName = string.sub(name, 2)
    t["get" .. funcName] = function(this)
        return this[name]
    end
    t["set" .. funcName] = function(this, value)
        this[name] = value
    end

    if defaultVal ~= nil then
        t[name] = defaultVal
    end
end

-- @brief 只读属性定义
function propertyReadOnly(t, name, defaultVal)
    local funcName = string.sub(name, 2)
    t["get" .. funcName] = function(this)
        return this[name]
    end

    if defaultVal ~= nil then
        t[name] = defaultVal
    end
end

---------------------------------------------------------------  bindUIClickListener ---------------------------------------------------------------

BindUIClickEffectParams = {
    default = {
        scale = true,
        touchdown = 0.95,
        touchup = 1,
    },
    scale = {
        scale = true,
        touchdown = 0.95,
        touchup = 1,
    },
    color = {
        color = true,
        touchdown = cc.c3b(200, 200, 200),
        touchup = cc.c3b(255, 255, 255),
    },
    none = {
    },
}

local function bindUIClickListenerImpl(widget, onClickCallback, onChangeState, limitDistance)
    onChangeState(false)

    widget:addTouchEventListener(function (sender, eventType)
        if eventType == ccui.TouchEventType.began then
            sender.isMovingTag = false
            sender.lastHighlighted = sender:isHighlighted()
            onChangeState(true)
        elseif eventType == ccui.TouchEventType.moved then
            if limitDistance and not sender.isMovingTag then
                if cc.pDistanceSQ(sender:getTouchBeganPosition(), sender:getTouchMovePosition()) > limitDistance then
                    sender.isMovingTag = true
                end
            end

            local isHighlighted = sender:isHighlighted()
            if sender.lastHighlighted ~= isHighlighted then
                sender.lastHighlighted = isHighlighted
                onChangeState(isHighlighted)
            end
        elseif eventType == ccui.TouchEventType.ended or eventType == ccui.TouchEventType.canceled then
            onChangeState(false)

            local now = NowEpochMS()
            local lastClickTime = sender.lastClickTime or 0
            local isMovingTag = sender.isMovingTag

            sender.isMovingTag = false

            -- 间隔时间过短
            if now - lastClickTime > 500 then
                if eventType == ccui.TouchEventType.ended and not isMovingTag then
                    sender.lastClickTime = now
                    gSound:clickSound()
                    
                    xpcall(function()
                        onClickCallback(sender)
                    end, __G__TRACKBACK__)
                end
            end
        end
    end)
end


-- @brief 当Button作为ScrollView的间接节点时会影响到ScrollView的滑动以及button点击效果
--        这里监听touch事件来确定button是否点击，以及设定不吞没事件来保证ScrollView的正常滑动
-- @param widget widget以及其子类
-- @param listener 回调函数
function bindUIClickListener(widget, listener, params, render, limitDistance)
    render = render or widget
    params = params or BindUIClickEffectParams["default"]

    local rawScaleX, rawScaleY = render:getScaleX(), render:getScaleY()
    
    local nodeNormalArr = {}
    local nodePressedArr = {}

    local titleChangeEnabled = StringUtils.parseKeyValuePairsFromNode(render).GetBool("titleChangeEnabled", false)
    if titleChangeEnabled then
        for _, v in ipairs(render:getChildren()) do
            if string.endsWith(v:getName(), "_normal") then
                table.insert(nodeNormalArr, v)
            elseif string.endsWith(v:getName(), "_pressed") then
                table.insert(nodePressedArr, v)
            end
        end
    end

    bindUIClickListenerImpl(widget, listener, function(isHighlighted)
        if titleChangeEnabled then
            for _, v in ipairs(nodeNormalArr) do
                v:setVisible(not isHighlighted)
            end
            for _, v in ipairs(nodePressedArr) do
                v:setVisible(isHighlighted)
            end
        end

        if params.color then
            if isHighlighted then
                render:setColor(params.touchdown)
            else
                render:setColor(params.touchup)
            end
        elseif params.opacity then
            if isHighlighted then
                render:setOpacity(params.touchdown)
            else
                render:setOpacity(params.touchup)
            end
        elseif params.scale then
            local scale = isHighlighted and params.touchdown or params.touchup
            render:stopAllActionsByTag(0xeffa)
            render:runAction(cc.ScaleTo:create(0.06, scale * rawScaleX, scale * rawScaleY)):setTag(0xeffa)
        end
    end, limitDistance)
end

---------------------------------------------------------------  loadStudioFile ---------------------------------------------------------------

local function createSpineWithUserdata(node)
    local keyValuePairs = StringUtils.parseKeyValuePairsFromNode(node)

    -- spine动画文件名称
    local file = keyValuePairs.GetString("file")
    if file == nil then return end

    -- 创建动画
    local anim = sp.SkeletonAnimation:createWithJsonFile(file .. ".json", file .. ".atlas")
    if anim == nil then
        logE("spine animation create failed, file = ", file)
        return
    end
    anim:setUpdateOnlyIfVisible(keyValuePairs.GetBool("update_only_if_visible", true))
    
    local nodeSize = node:getContentSize()

    -- 播放动画名称
    local animation = keyValuePairs.GetString("animation")
    -- 循环播放
    local loop = keyValuePairs.GetBool("loop", true)
    -- 播放间隔
    local interval = keyValuePairs.GetNumber("interval")
    -- zorder
    local zorder = keyValuePairs.GetNumber("zorder", 0)
    -- x
    local x = keyValuePairs.GetNumber("x", nodeSize.width * 0.5)
    -- y
    local y = keyValuePairs.GetNumber("y", nodeSize.height * 0.5)
    
    local name = node:getName()
    if name == "" then
        name = "anim"
    else
        name = name .. "_anim"
    end

    if animation then
        if interval and interval > 0 then
            anim:setAnimation(0, animation, false)
            anim:schedule(interval, function()
                anim:setAnimation(0, animation, false)
            end)
        else
            anim:setAnimation(0, animation, loop)
        end
    end
    anim:setPosition(x, y)
    anim:setName(name)
    node:addChild(anim, zorder)
end

local function setupGradientColorWithUserdata(node)
    if node.enableGradientColor == nil then
        return
    end

    local gradientColor = StringUtils.parseKeyValuePairsFromNode(node).GetString("gradientColor")
    if gradientColor == nil then return end

    local arrColor = string.split(gradientColor, "-")
    if #arrColor == 2 then
        local color1 = StringUtils.hexToRgb(arrColor[1])
        local color2 = StringUtils.hexToRgb(arrColor[2])
        
        node:setGradientColor(color1, 0)
        node:setGradientColor(color1, 1)
        node:setGradientColor(color2, 2)
        node:setGradientColor(color2, 3)
        node:enableGradientColor(true)
    elseif #arrColor == 4 then
        local color1 = StringUtils.hexToRgb(arrColor[1])
        local color2 = StringUtils.hexToRgb(arrColor[2])
        local color3 = StringUtils.hexToRgb(arrColor[3])
        local color4 = StringUtils.hexToRgb(arrColor[4])
        
        node:setGradientColor(color1, 0)
        node:setGradientColor(color2, 1)
        node:setGradientColor(color3, 2)
        node:setGradientColor(color4, 3)
        node:enableGradientColor(true)
    else
        logE("setupGradientColorWithUserdata: invalid gradientColor format, expected 'color1-color2' or 'color1-color2-color3-color4', got ", gradientColor)
    end
end

function recursionSetCascadeColorEnabled(node, value)
    node:setCascadeColorEnabled(value)
    for k, v in pairs(node:getChildren()) do
        recursionSetCascadeColorEnabled(v, value)
    end
end

-- @brief 加载cocostduio文件
function loadStudioFile(fileName, target)
    if string.sub(fileName, -4) ~= ".csb" then
        fileName = fileName .. ".csb"
    end
    
    local root = cc.CSLoader:createNode(fileName, function(node)
        -- 事件绑定
        if target and type(node.getCallbackType) == "function" then
            local cbName = node:getCallbackName()

            if type(target[cbName]) == "function" then
                local cbType = node:getCallbackType()
                if cbType == "Click" then
                    local clickEffectParams = nil
                    local effectNode = nil
                    local touchLimitDistance = nil

                    local keyValuePairs = StringUtils.parseKeyValuePairsFromNode(node)

                    
                    local effect = keyValuePairs.GetString("clickEffect")
                    if effect == "color" then
                        recursionSetCascadeColorEnabled(node, true)
                    end
                    clickEffectParams = BindUIClickEffectParams[effect]
                    
                    local effectNodeName = keyValuePairs.GetString("effectNode", "")
                    if effectNodeName ~= "" then
                        effectNode = node:getChildByName(effectNodeName)
                    end
                    
                    touchLimitDistance = keyValuePairs.GetNumber("touchLimitDistance")

                    bindUIClickListener(node, function()
                        target[cbName](target, node)
                    end, clickEffectParams, effectNode, touchLimitDistance)
                elseif cbType == "Touch" then
                    node:addTouchEventListener(function(...)
                        target[cbName](target, ...)
                    end)
                elseif cbType == "Event" then
                    node:addEventListener(function(...)
                        target[cbName](target, ...)
                    end)                    
                end
            end
        end

        -- spine动画创建
        if string.startswith(node:getName(), "spine_") then
            createSpineWithUserdata(node)
        end

        setupGradientColorWithUserdata(node)
        
        -- 多语言翻译
        gLocalization:translationNode(node, false)
    end)

    if root == nil then return end

    local ui = { root = root }
    setmetatable(ui, LuaExtend)

    return ui
end

-- @brief 判断字符串是否以指定后缀结尾
function string.endsWith(str, suffix)
    return string.sub(str, -(#suffix)) == suffix 
end

-- @brief 判断字符串是否以指定前缀开头
function string.startswith(str, suffix)
    return string.sub(str, 1, #suffix) == suffix 
end

if math.pow == nil then
    math.pow = function (x,y)
        return x ^ y
    end
end