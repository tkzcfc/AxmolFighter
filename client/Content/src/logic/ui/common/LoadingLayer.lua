
local LoadingLayer = class("LoadingLayer", cc.Node)

local DefaultSpeed = 10

function LoadingLayer:ctor()
    self.ui = loadStudioFile("ui/common/LoadingLayer")
    self:addChild(self.ui.root)

	self.ui.content_panel:setLocalZOrder(1)
    
    self:onUpdate(handler(self, self.onLogicUpdate))
    self:reset()

	if gConfigData.IsGoogle then
		local loadingFile = "boot/resource/loading.jpg"
		if cc.FileUtils:getInstance():isFileExist(loadingFile) then
			self:setBackGroundImage(loadingFile, ccui.TextureResType.localType)
		end
	end

    self:enableNodeEvents()
end

-- @brief 设置完成回调
function LoadingLayer:setFinishCallback(callback)
	self.onFinishCallback = callback
end

-- @brief 设置假进度占比
function LoadingLayer:setFakePercent(value)
	self.fakePercent = value
end 

function LoadingLayer:reset()
	self.onFinishCallback = nil
	self.isFinish = false
    self.disableUpdate = false

	self.fakePercent = 0

	self.finishFrame = 0

	-- 真实百分比
	self.realPercentValue = 0

	-- 当前假百分比
	self.curFakePercent = 0
	-- 当前真实百分比
	self.curRealPercent = 0
	-- 显示百分比
	self.curShowPercent = 0

	
	self.normalSpeed = DefaultSpeed
	self.quickSpeed = DefaultSpeed * 20
    
    self.ui.loading_bar:setPercent(0)
    self.ui.text_speed:setString("")
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

-- @brief 重新设置背景图片
-- @param path 资源路径
-- @param resType 资源类型
-- @param fillMode 填充模式
-- fill: 内容拉伸填满整个屏幕, 不保证保持原有的比例。
-- contain: 保持原有尺寸比例。长度和高度中短的那条边跟容器大小一致，长的那条等比缩放，可能会有留白。
-- cover: 保持原有尺寸比例。宽度和高度中长的那条边跟容器大小一致，短的那条等比缩放。可能会有部分区域不可见。
-- none: 保持原有尺寸比例。同时保持替换内容原始尺寸大小。
function LoadingLayer:setBackGroundImage(path, resType, fillMode)
	fillMode = fillMode or "cover"

	self.ui.bg:setVisible(true)
    self.ui.bg:ignoreContentAdaptWithSize(true)
    self.ui.bg:loadTexture(path, resType)
    self.ui.bg:setPosition(gAdaptive.center)
	self.ui.bg:removeAllChildren()
	
	local screenSize = gAdaptive.size
    local imgSize = self.ui.bg:getContentSize()

	local scalex = screenSize.width / imgSize.width
	local scaley = screenSize.height / imgSize.height

	if fillMode == "fill" then
		self.ui.bg:setScaleX(scalex) 
		self.ui.bg:setScaleY(scaley)
	elseif fillMode == "contain" then
		self.ui.bg:setScale(math.min(scalex, scaley))
	elseif fillMode == "cover" then
		self.ui.bg:setScale(math.max(scalex, scaley))
	end
	
    return self.ui.bg
end

function LoadingLayer:setBackGroundAnimation(path, animationName)
	local fileUtils = cc.FileUtils:getInstance()

	if fileUtils:isFileExist(path .. ".png") and 
	fileUtils:isFileExist(path .. ".atlas") and
	fileUtils:isFileExist(path .. ".json") then
		local anim = sp.SkeletonAnimation:createWithJsonFile(path .. ".json", path .. ".atlas")
		if anim then
			anim:setAnimation(0, animationName, true)
			anim:setPosition(gAdaptive.center)
			anim:setScaleX(gAdaptive.scaleX)
			anim:setScaleY(gAdaptive.scaleY)
			self.ui.root:addChild(anim)
			self.ui.bg:setVisible(false)
		end
		return anim
	end
end
---------------------------------------------------------- private ----------------------------------------------------------

function LoadingLayer:onEnter()
    self:onSwitchScreenOrientation()
    gSysEventEmitter:on(SysEvent.UPDATE_SCREEN_ORIENTATION, handler(self, self.onSwitchScreenOrientation), self)
end

function LoadingLayer:onExit()
    gSysEventEmitter:offByTag(self)
end

function LoadingLayer:onSwitchScreenOrientation()
    self.ui.bg:setPosition(gAdaptive.center)
    self.ui.bg:setScale(gAdaptive.scaleMax)

	self.ui.content_panel:setPosition(gAdaptive.cx, 0)
    self.ui.content_panel:setScale(gAdaptive.scaleMin)

	if self.ui.mask_panel then
		self.ui.mask_panel:setContentSize(gAdaptive.size)
	end
end

function LoadingLayer:onLogicUpdate(dt)
    if self.disableUpdate then return end

	if self.realPercentValue >= 100 and self.isFinish then
		self:updatePercent(self.curShowPercent + dt * self.quickSpeed)

		if self.curShowPercent >= 100 then
			self.finishFrame = self.finishFrame + 1

			if self.finishFrame >= 2 then
				self.disableUpdate = true
				if self.onFinishCallback then
					local callback = self.onFinishCallback
					self.onFinishCallback = nil
					callback()
				end
			end
		end
		return
	end


	if self.realPercentValue > self.curRealPercent then
		self.curRealPercent = math.min(self.curRealPercent + dt * self.normalSpeed, self.realPercentValue)
	else
        dt = dt / 2
		self.curFakePercent = self.curFakePercent + dt * self.normalSpeed

		if self.curFakePercent > 100 then
			self.curFakePercent = 100
		end
	end

	local maxFakeValue = self.fakePercent / 100
	local maxRealValue = 1 - maxFakeValue
	self:updatePercent(maxRealValue * self.curRealPercent + maxFakeValue * self.curFakePercent)
end

function LoadingLayer:updatePercent(percent)
	self.curShowPercent = percent
	self.ui.loading_bar:setPercent(percent)
end

return LoadingLayer