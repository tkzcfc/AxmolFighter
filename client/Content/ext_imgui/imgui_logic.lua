
local function __G__TRACKBACK__(msg)
    local msg = debug.traceback(msg, 3)
    print(msg)
    return msg
end

local imguiRenderEnabled = true
local imguiMenuRenderEnabled = true

local fontLoaded = false
local function loadFont()
    if not imguiRenderEnabled then return end
    if fontLoaded then return end
    fontLoaded = true
    imgui.addFont("ext_imgui/resource/font/FZZHUNYUAN.ttf", 16, 2)
end

local function init_imgui()
    ImGui = imgui

    imgui.launch()

    -- 加载保存的ini文件
    local iniFile = cc.FileUtils:getInstance():getWritablePath() .. 'imgui.ini'
    local ini = cc.FileUtils:getInstance():getStringFromFile(iniFile)
    if #ini > 0 then
        imgui.loadIniSettingsFromMemory(ini, #ini)
        print(('read %q success'):format(iniFile))
    else
        print(('read %q failed'):format(iniFile))
    end

    -- 实时保存ini配置
    local savingRate = 1 / 20
    imgui.getIO().IniSavingRate = savingRate
    cc.Director:getInstance():getScheduler():scheduleScriptFunc(function()
        -- auto save ini
        local io = imgui.getIO()
        if io.WantSaveIniSettings then
            cc.FileUtils:getInstance():writeStringToFile(imgui.saveIniSettingsToMemory(), iniFile)
            io.WantSaveIniSettings = false
        end
        -- check error
        --if imgui.error then
        --    error(imgui.error)
        --end
    end, savingRate, false)

    -- 渲染开关
    imguiRenderEnabled = cc.UserDefault:getInstance():getBoolForKey("key_imgui_lua_render_enabled", true)
    imguiMenuRenderEnabled = cc.UserDefault:getInstance():getBoolForKey("key_imgui_lua_meun_render_enabled", true)
    local listener = cc.EventListenerKeyboard:create()
    listener:registerScriptHandler(function(code, event)
            if code == cc.KeyCode.KEY_F10 then
                imguiRenderEnabled = not imguiRenderEnabled
                cc.UserDefault:getInstance():setBoolForKey("key_imgui_lua_render_enabled", imguiRenderEnabled)
                loadFont()
            -- elseif code == cc.KeyCode.KEY_F11 then
            --     imguiMenuRenderEnabled = not imguiMenuRenderEnabled
            --     cc.UserDefault:getInstance():setBoolForKey("key_imgui_lua_meun_render_enabled", imguiMenuRenderEnabled)
            end
        end, cc.Handler.EVENT_KEYBOARD_RELEASED)
    cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listener, -1)

    loadFont()

    -- imgui渲染事件派发
    imguiEventEmitter = require("utils.EventEmitter").new()
    function imgui.draw()
        if not imguiRenderEnabled then return end

        imguiEventEmitter:emit("imgui_render_main_loop")
    end

    local uniqueTag = 0
    function uniqueEventTag()
        uniqueTag = uniqueTag + 1
        return uniqueTag
    end
end


local function main()
    cc.FileUtils:getInstance():addSearchPath("ext_imgui")
    init_imgui()

    local pluginsStore = require("utils.StorageObject").new("plugins.json")

    local plugins = {}
    local files = cc.FileUtils:getInstance():listFiles("ext_imgui/plugins")
    for _, file in pairs(files) do
        if string.match(file, "[/\\]$") and cc.FileUtils:getInstance():isFileExist(file .. "main.lua") then
            local ok, cls = xpcall(dofile, __G__TRACKBACK__, file .. "main.lua")
            if ok and cls and iskindof(cls, "BasePlugin") then
                local pluginName = string.match(file, "ext_imgui[/\\]plugins[/\\](.-)[/\\]")
                local winName = string.gsub(pluginName, "_", " ")
                local data = {
                    name = pluginName,
                    winName = winName .. "##imgui_tools",
                    enable = pluginsStore:get(pluginName .. "_enable", false),
                }
                data.instance = cls.new(pluginName, data)
                table.insert(plugins, data)
            end
        end
    end

    local winSize, winSizeCond = cc.p(640, 320), imgui.ImGuiCond.FirstUseEver
    imguiEventEmitter:on("imgui_render_main_loop", function()
        if imguiMenuRenderEnabled and imgui.beginMainMenuBar() then
            if imgui.beginMenu("plugins") then
                for k, v in pairs(plugins) do
                    if imgui.menuItem(v.winName, "", v.enable, true) then
                        v.enable = not v.enable
                        pluginsStore:set(v.name .. "_enable", v.enable)
                    end
                end
                imgui.endMenu()
            end

            if imgui.beginMenu("tools") then
                if imgui.menuItem("hide me", "F10") then
                    imguiRenderEnabled = not imguiRenderEnabled
                    cc.UserDefault:getInstance():setBoolForKey("key_imgui_lua_render_enabled", imguiRenderEnabled)
                end
                imgui.endMenu()
            end

            imguiEventEmitter:emit("imgui_render_tools_menu_bar")
            imgui.endMainMenuBar()
        end

        for k, v in pairs(plugins) do
            if v.enable then
                imgui.setNextWindowSize(winSize, winSizeCond)
                local r1, r2 = imgui.begin(v.winName, v.enable, v.instance.winFlags)
                if r1 then
                    v.instance:render()
                end
                imgui.endToLua()
                if v.enable ~= r2 then
                    v.enable = r2
                    pluginsStore:set(v.name .. "_enable", v.enable)
                end
            end
        end
    end, uniqueEventTag())
end

xpcall(main, __G__TRACKBACK__)

