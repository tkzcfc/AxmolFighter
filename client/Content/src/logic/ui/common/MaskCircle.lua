local MaskCircle = class("MaskCircle", cc.Node)

function MaskCircle:ctor()
    self:setName(self.__cname)
    self.ui = loadStudioFile("ui/common/MaskCircle")
    self:addChild(self.ui.root)

    self.lastShowTime = 0

    self:enableNodeEvents()
    self:showMask(false)
    
	local listener = cc.EventListenerTouchOneByOne:create()
	listener:setSwallowTouches(true)
	listener:registerScriptHandler(function() return self:isVisible() end, cc.Handler.EVENT_TOUCH_BEGAN)
	self:getEventDispatcher():addEventListenerWithSceneGraphPriority(listener, self)
end

function MaskCircle:onEnter()
    self:onSwitchScreenOrientation()
    gSysEventEmitter:on(SysEvent.UPDATE_SCREEN_ORIENTATION, handler(self, self.onSwitchScreenOrientation), self)
end

function MaskCircle:onExit()
    gSysEventEmitter:offByTag(self)
end

function MaskCircle:onSwitchScreenOrientation()
    self.ui.node_center:setPosition(gAdaptive.center)
    self.ui.node_center:setScale(gAdaptive.scaleMin)

    self.ui.panel_bg:setContentSize(gAdaptive.size)
end

function MaskCircle:isShowMask()
    return self:isVisible()
end

function MaskCircle:showMask(visible, delayTime)
    self:setVisible(visible)
    if self.ui.spine_loading_anim then
        self.ui.spine_loading_anim:setVisible(visible)
    end

    if visible then
        if NowEpochMS() - self.lastShowTime < 100 then
            delayTime = 0
        end

        if delayTime == nil then delayTime = 0 end

        self.ui.root:stopAllActions()

        if delayTime <= 0 then
            self.ui.root:setVisible(true)
        else
            self.ui.root:setVisible(false)
            self.ui.root:runAction(cc.Sequence:create(
                cc.DelayTime:create(delayTime),
                cc.Show:create()
            ))
        end
    else
        if self.ui.root:isVisible() then
            self.lastShowTime = NowEpochMS()
        end
    end
end

function MaskCircle:setText(text)
    self.ui.text_title:setString(text)
end

return MaskCircle