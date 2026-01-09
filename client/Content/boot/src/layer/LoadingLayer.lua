local utils = require("boot.src.utils")

local LoadingLayer = class("LoadingLayer", function()
	return cc.CSLoader:createNode("boot/resource/LoadingLayer.csb")
end)

local DefaultSpeed = 8

function LoadingLayer:ctor()
    -- self:setContentSize(utils.layout.size)
    -- ccui.Helper:doLayout(self)

    local bg = self:getChildByName("bg")
	local content_panel = self:getChildByName("content_panel")

	self.ui = {
		bg_bar = content_panel:getChildByName("bg_bar"),
		loading_bar = content_panel:getChildByName("loading_bar"),
		text_tip = content_panel:getChildByName("text_tip"),
		text_tip_ttf = content_panel:getChildByName("text_tip_ttf"),
		text_speed = content_panel:getChildByName("text_speed"),
	}


	local loadingFile = "boot/resource/loading.jpg"
	if gConfigData["MJ_APK_MODE"] and gConfigData["DisableHotfix"] and cc.FileUtils:getInstance():isFileExist(loadingFile) then
	    bg:ignoreContentAdaptWithSize(true)
	    bg:loadTexture(loadingFile, ccui.TextureResType.localType)
	    bg:removeAllChildren()
	end
	
    bg:setPosition(utils.layout.center)
    bg:setScale(utils.layout.scaleMax)
    content_panel:setPosition(utils.layout.size.width * 0.5, 0)
    content_panel:setScale(utils.layout.scaleMin)

    self.contentPanelSize = content_panel:getContentSize()

	self:reset()
    self:onUpdate(handler(self, self.onLogicUpdate))
end

-- @brief 设置完成回调
function LoadingLayer:setFinishCallback(callback)
	self.onFinishCallback = callback
end

function LoadingLayer:reset()
	self.onFinishCallback = nil
	self.isFinish = false
    self.disableUpdate = false

	-- 真实百分比
	self.realPercentValue = 0

	-- 当前真实百分比
	self.curRealPercent = 0
	-- 显示百分比
	self.curShowPercent = 0

	self.normalSpeed = DefaultSpeed
	self.quickSpeed = DefaultSpeed * 20

    self.ui.loading_bar:setPercent(0)
    self.ui.text_speed:setString("")
    self.ui.text_tip:enableOutline(cc.c3b(26, 26, 26), 4)
    self:setTipText("LOADING...", true)

    self:setLoadBarVisible(true)
end

-- percent : [0, 100] 范围的浮点数
function LoadingLayer:setPercent(percent, isFinish)
	self.realPercentValue = percent
	if percent >= 100 and not self.isFinish then
		self.isFinish = isFinish
	end
end

-- @brief 设置提示文本
-- @param useTTF 是否使用TTF字体显示
function LoadingLayer:setTipText(text, useTTF)
    if useTTF then
        self.ui.text_tip:setString("")
        self.ui.text_tip_ttf:setString(text)
    else
        self.ui.text_tip:setString(text)
        self.ui.text_tip_ttf:setString("")
    end
end

-- @brief 设置速度文本
function LoadingLayer:setSpeedText(text)
    self.ui.text_speed:setString(text)
end

function LoadingLayer:setLoadBarVisible(visible)
	self.ui.bg_bar:setVisible(visible)
	self.ui.loading_bar:setVisible(visible)
end


---------------------------------------------------------- private ----------------------------------------------------------

function LoadingLayer:onLogicUpdate(dt)
    if self.disableUpdate then return end

	if self.realPercentValue >= 100 and self.isFinish then
		if self.curShowPercent >= 100 then
            self.disableUpdate = true
			if self.onFinishCallback then
				local callback = self.onFinishCallback
				self.onFinishCallback = nil
				callback()
			end
			return
		end
		self:updatePercent(self.curShowPercent + dt * self.quickSpeed)
		return
	end


	if self.realPercentValue > self.curRealPercent then
		self.curRealPercent = math.min(self.curRealPercent + dt * self.normalSpeed, self.realPercentValue)
	end

	self:updatePercent(self.curRealPercent)
end

function LoadingLayer:updatePercent(percent)
	if percent > 100 then percent = 100 end
	self.curShowPercent = percent
	self.ui.loading_bar:setPercent(percent)
end

return LoadingLayer