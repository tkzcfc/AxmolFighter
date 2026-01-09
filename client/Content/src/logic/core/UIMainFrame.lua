-- @Author: 
-- @Date:   2020-03-11 21:11:22
-- @remark: 全屏类型UI

local UIMainFrame = class("UIMainFrame", UIBase)

-- @brief 打开动画
local function UIMainFrameOpenAction(this, call)
	local actNode = this.pContentView or this
	
	actNode:setVisible(false)
	
    local action = cc.Sequence:create(
    	cc.DelayTime:create(1 / 20),
		cc.Show:create(),
    	cc.CallFunc:create(call)
    )
    actNode:runAction(action)
end


-- @brief 关闭动画
local function UIMainFrameCloseAction(this, call)
	local actNode = this.pContentView or this

    local action = cc.Sequence:create(
    	cc.CallFunc:create(call)
    )
    actNode:runAction(action)
end

function UIMainFrame:ctor()
	UIMainFrame.super.ctor(self)

	self:setAutoDismiss(false)
	self:setIsFullScreen(true)
	self:setHasMask(false)

	self:setOpenActionType(UIActionType.FADE_IN)
	self:setCloseActionType(UIActionType.NO_ACTION)

	-- self:setOpenActionCall(UIMainFrameOpenAction)
	-- self:setCloseActionCall(UIMainFrameCloseAction)
end


return UIMainFrame
