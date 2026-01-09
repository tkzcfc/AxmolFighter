local ActivityLogic = require("logic.ui.activity_list.ActivityLogic")
local LobbyView = class("LobbyView", ViewBase)

propertyReadOnly(LobbyView, "pFlyingLayer")

function LobbyView:ctor()
    LobbyView.super.ctor(self)

    self.pFlyingLayer = cc.Node:create()
    self.pFlyingLayer:setName("FlyingLayer")
    self:addChild(self.pFlyingLayer, 0xFFFF + 1)

    local spriteFrameCache = cc.SpriteFrameCache:getInstance()
    for _, plistFile in  pairs(gNeedKeepPlist or {}) do
        if not spriteFrameCache:isSpriteFramesWithFileLoaded(plistFile) then
            spriteFrameCache:addSpriteFrames(plistFile)
        end
    end

    self:loadUI("views/LobbyView")

    self:initUI()
end

function LobbyView:initUI()
    -- 游戏列表
    self.gameList = require("logic.ui.home.game.GameList").new():addTo(self.ui.root)
    
    -- -- 底部菜单栏
    performWithDelay(self, function()
        require("logic.ui.home.BottomLayer").new(self.game_list):addTo(self.ui.root, 1)
    end, 0.5)
    
    -- 顶部菜单栏
    performWithDelay(self, function()
        require("logic.ui.home.TopLayer").new():addTo(self.ui.root, 2)
    end, 0.8)

    -- 悬浮菜单栏
    performWithDelay(self, function()
        require("logic.ui.home.HoverLayer").new():addTo(self.ui.root, 3)
    end, 0.8)

    gLobbyData.fetchExpConfig:fetch()
end

function LobbyView:onEnterTransitionFinish()
    gSound:playBgm("sound/bgm_lobby.mp3")

    local lastViewName = gViewManager:getLastViewName()
    if lastViewName == "LaunchView" then
        gSysEventEmitter:emit(SysEvent.ON_MSG_LOBBY_DO_FADEIN_ACTION)
    else
        -- 请求用户信息
        -- gLobbyData:updateUserdata()
        gSysEventEmitter:emit(SysEvent.ON_MSG_LOBBY_DO_FADEIN_ACTION)
    end

    performWithDelay(self, function()
        -- 活动自动弹出
        self:popActivity()
    end, 0.5)
end

function LobbyView:onExit()
    LobbyView.super.onExit(self)
    self:destroyActivityLogic()
end

function LobbyView:popActivity()
    -- if gConfigData["DisableActivityPopup"] then return end
    self:destroyActivityLogic()
    self.activityLogic = ActivityLogic.new()
    self.activityLogic:popActivity()
end

function LobbyView:destroyActivityLogic()
    if self.activityLogic then
        self.activityLogic:destroy()
        self.activityLogic = nil
    end
end

-- @brief 优化操作,隐藏场景子节点
function LobbyView:onHideNodes()
    LobbyView.super.onHideNodes(self)
end

-- @brief 优化操作,显示场景子节点
function LobbyView:onShowNodes()
    LobbyView.super.onShowNodes(self)

    if gUIManager:getCurUICount() <= 1 then
        gSysEventEmitter:emit(SysEvent.ON_MSG_LOBBY_DO_FADEIN_ACTION)
    end
end

return LobbyView