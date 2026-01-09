local MainScene = class("MainScene", function()
    return display.newScene("mainScene")
end)

propertyReadOnly(MainScene, "pViewRoot")
propertyReadOnly(MainScene, "pLoadingLayer")
propertyReadOnly(MainScene, "pConnectingLayer")
propertyReadOnly(MainScene, "pPayLayer")
propertyReadOnly(MainScene, "pToastRoot")

local Z_VIEW_ROOT = 5
local Z_NOTICE_LAYER = 50
local Z_MASK_ROOT = 100
local Z_TOAST_ROOT = 200

function MainScene:ctor()
    local listener = cc.EventListenerKeyboard:create()
    listener:registerScriptHandler(function(code, event)
            if code == cc.KeyCode.KEY_F1 then
                gNetMgr:disconnect()
            elseif code == cc.KeyCode.KEY_F5 then
                gDeviceData:resetLobbyScreenType()
                cc.Director:getInstance():restart()
            end
        end, cc.Handler.EVENT_KEYBOARD_RELEASED)
    cc.Director:getInstance():getEventDispatcher():addEventListenerWithFixedPriority(listener, -1)

    self:initUI()

    -- 初始化界面管理
    gViewManager:clear()
    gViewManager:setViewRoot(self.pViewRoot)

    gSysEventEmitter:on(SysEvent.UI_WILL_DESTROY, function()
        if gViewManager:isInView("LobbyView") then
            go(function()
                cc.SpriteFrameCache:getInstance():removeUnusedSpriteSheets()
                cc.Director:getInstance():getTextureCache():removeUnusedTextures()
            end)
        end
    end, self)

    go(function()
        local usedMemory = gDeviceData:getUsedMemory()
        if usedMemory then
            print("UsedMemory", tostring(usedMemory))
            local sharedScheduler = cc.Director:getInstance():getScheduler()
            sharedScheduler:scheduleScriptFunc(function()
                print("UsedMemory", tostring(gDeviceData:getUsedMemory()))
            end, 60 * 5, false)
        end
    end)
end

function MainScene:initUI()
    -- 界面根节点
    self.pViewRoot = cc.Node:create()
    self.pViewRoot:setName("viewRoot")
    self:addChild(self.pViewRoot, Z_VIEW_ROOT)

    self.pLoadingLayer = require("logic.ui.common.MaskCircle").new()
    self:addChild(self.pLoadingLayer, Z_MASK_ROOT)

    self.pConnectingLayer = require("logic.ui.common.MaskCircle").new()
    self.pConnectingLayer:setText("Connecting...")
    self:addChild(self.pConnectingLayer, Z_MASK_ROOT)

    -- 提示层
    self.pToastRoot = require("logic.ui.common.Toast").new()
    self:addChild(self.pToastRoot, Z_TOAST_ROOT)
end

return MainScene
