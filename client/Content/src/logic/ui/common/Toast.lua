local MAX_WIDTH = 600

local Toast = class("Toast", cc.Node)

function Toast:ctor()
    self:setName(self.__cname)
    self.ui = loadStudioFile("ui/common/Toast")
    self.ui.root:setVisible(false)
    self.ui.root:setCascadeOpacityEnabled(true)
    self:addChild(self.ui.root)

    self.imgBgSizeRaw = self.ui.img_bg:getContentSize()

    gSysEventEmitter:on(SysEvent.UPDATE_SCREEN_ORIENTATION, handler(self, self.onSwitchScreenOrientation), self)
    self:enableNodeEvents()
    self:onSwitchScreenOrientation()
end

function Toast:onExit()
    gSysEventEmitter:offByTag(self)
end

function Toast:onSwitchScreenOrientation()
    if gAdaptive:isOrientationPortrait() then
        self:setPosition(gAdaptive.size.width * 0.5, 250)
    else
        self:setPosition(gAdaptive.size.width * 0.5, gAdaptive.size.height * 0.15)
    end
end

-- @brief 是否正在显示提示文本
function Toast:isShowToastText()
    return self.ui.root:isVisible()
end

-- @brief 显示提示文本
function Toast:showText(text)
    self.ui.text_tip:setString("")
    self.ui.text_tip:setFontName(gLocalization:getCurFontName())
    self.ui.text_tip:setTextAreaSize(cc.p(0, 0))
    self.ui.text_tip:setString(text)
    
    local textSize = self.ui.text_tip:getContentSize()
    if textSize.width > MAX_WIDTH then
        self.ui.text_tip:setTextAreaSize(cc.p(MAX_WIDTH, 0))
        textSize = self.ui.text_tip:getContentSize()      
    end

    textSize.width = math.max(textSize.width + 30, self.imgBgSizeRaw.width)
    textSize.height = math.max(textSize.height + 30, self.imgBgSizeRaw.height)
    self.ui.img_bg:setContentSize(textSize)

    self.ui.root:stopAllActions()
    self.ui.root:setScale(0)
    self.ui.root:setOpacity(255)
    self.ui.root:setVisible(true)
    self.ui.root:runAction(cc.Sequence:create(
        cc.ScaleTo:create(0.25, 1.1, 1.1),
        cc.ScaleTo:create(0.1, 1, 1),
        cc.DelayTime:create(1.5),
        cc.FadeOut:create(0.3),
        cc.Hide:create()
    ))
end

return Toast