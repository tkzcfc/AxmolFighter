-- @Author : fc
-- @Date   : 2022-03-21 14:58:47
-- @remark : 

local UIAction = {}

UIActionType = enum {
	1,
	"SCALE_TO",
	"FADE_IN",
	"NO_ACTION"
}

local openActions = {}
local closeActions = {}

UIAction.openActions = openActions
UIAction.closeActions = closeActions


-------------------------------------------- SCALE_TO --------------------------------------------

-- @brief 打开动画
openActions[UIActionType.SCALE_TO] = function (this, call)
	local actNode = this.pContentView or this

	local rawScale = actNode:getScaleX()
	
	actNode.rawScale = rawScale
	actNode:setVisible(false)
	actNode:setScale(0.3 * rawScale)
	
    local action = cc.Sequence:create(
    	cc.DelayTime:create(1 / 60),
		cc.Show:create(),
		cc.ScaleTo:create(0.14, 1.1 * rawScale),
		cc.ScaleTo:create(0.1, 1 * rawScale),
    	cc.CallFunc:create(call)
    )

	actNode:runAction(action)

	-- local soundAction = cc.Sequence:create(
	-- 	cc.DelayTime:create(1 / 60),
	-- 	cc.CallFunc:create(function()
	-- 		gSound:playEffect("sound/dialog_open.mp3")
	-- 	end))

    -- actNode:runAction(cc.Spawn:create(action, soundAction))

	-- gSound:stopClickSound()
end


-- @brief 关闭动画
closeActions[UIActionType.SCALE_TO] = function(this, call)
	local actNode = this.pContentView or this
	
	local rawScale = actNode.rawScale or 1

    actNode:setScale(rawScale)

    local action = cc.Sequence:create(
    	cc.EaseSineIn:create(cc.ScaleTo:create(0.15,0)),
    	cc.CallFunc:create(call)
    )
    actNode:runAction(action)
	
	-- gSound:playEffect("sound/dialog_close.mp3")
	-- gSound:stopClickSound()
end


-------------------------------------------- FADE_IN --------------------------------------------
local FADE_IN_TIME_1  = 0.25
local FADE_IN_TIME_2  = 0.25
local FADE_OUT_TIME_1 = 0.25
local FADE_OUT_TIME_2 = 0.25

local function getMaskLayer()
	local scene = display.getRunningScene()
	if not scene then return end
	
	local maskLayer = scene:getChildByName("_ui_fade_mask_")
	if not maskLayer then
		maskLayer = ccui.Layout:create()
		maskLayer:setContentSize(gAdaptive.size)
		maskLayer:setName("_ui_fade_mask_")
		maskLayer:setBackGroundColorType(ccui.LayoutBackGroundColorType.solid)
		maskLayer:setBackGroundColor(cc.c3b(20, 20, 20))
		maskLayer:setBackGroundColorOpacity(200)
		maskLayer:setVisible(false)
		maskLayer:setTouchEnabled(true)
		scene:addChild(maskLayer, 0xffffff)
	end
	maskLayer:setContentSize(gAdaptive.size)

	return maskLayer
end

-- @brief 打开动画
openActions[UIActionType.FADE_IN] = function (this, call)
	local maskLayer = getMaskLayer()
	if maskLayer == nil then
		call()
		return
	end

	this:eventOn(SysEvent.UI_WILL_DESTROY, function()
		maskLayer:stopAllActions()
		maskLayer:setVisible(false)
	end, this)

    this:setVisible(false)
    maskLayer:setVisible(true)
    maskLayer:stopAllActions()
    maskLayer:setOpacity(0)

    local action = cc.Sequence:create(
    	cc.FadeIn:create(FADE_IN_TIME_1),
    	cc.CallFunc:create(function()
    		this:setVisible(true)
    	end),
    	cc.FadeOut:create(FADE_IN_TIME_2),
    	cc.Hide:create(),
    	cc.CallFunc:create(call)
    )
    maskLayer:runAction(action)
end


-- @brief 关闭动画
closeActions[UIActionType.FADE_IN] = function(this, call)
	local maskLayer = getMaskLayer()
	if maskLayer == nil then
		call()
		return
	end

	this:eventOn(SysEvent.UI_WILL_DESTROY, function()
		maskLayer:stopAllActions()
		maskLayer:setVisible(false)
	end, this)

    maskLayer:setVisible(true)
    maskLayer:stopAllActions()
    maskLayer:setOpacity(0)

    local action = cc.Sequence:create(
    	cc.FadeIn:create(FADE_OUT_TIME_1),
    	cc.CallFunc:create(call),
    	cc.FadeOut:create(FADE_OUT_TIME_2),
    	cc.Hide:create()
    )
    maskLayer:runAction(action)
end

-------------------------------------------- NO_ACTION --------------------------------------------

-- @brief 打开动画
openActions[UIActionType.NO_ACTION] = function (this, call)
	local actNode = this.pContentView or this
	actNode:runAction(cc.CallFunc:create(call))
end


-- @brief 关闭动画
closeActions[UIActionType.NO_ACTION] = function(this, call)
	local actNode = this.pContentView or this
	actNode:runAction(cc.CallFunc:create(call))
end

return UIAction

