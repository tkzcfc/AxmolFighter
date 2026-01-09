-- @Author: 
-- @Date:   2021-05-07 21:49:27
-- @remark: UI基类

local UIPanel = import(".UIPanel")
local UIBase = class("UIBase", UIPanel)

function UIBase:ctor()
	UIBase.super.ctor(self)
	self:setNodeEventEnabled(true)
	self:eventOn(SysEvent.UI_BEFORE_OPENED, handler(self, self.iBeforeOpened), self)
	self:eventOn(SysEvent.UI_AFTER_OPENED, handler(self, self.iAfterOpened), self)
	self:eventOn(SysEvent.UI_WILL_CLOSE, handler(self, self.iWillClose), self)
	self:eventOn(SysEvent.UI_AFTER_CLOSED, handler(self, self.iAfterClosed), self)
end

function UIBase:loadUI(path)
	self.ui = loadStudioFile(path, self)
    self:addChild(self.ui.root)

	local frame = self.ui.root:getChildByName("frame")
	self:setContentView(frame or self.ui.root)

    local name = self.ui.root:getName()
    if name == "Node" then
	    -- 适配
	    self.ui.root:setScale(gAdaptive.scaleMin)
	    self.ui.root:setPosition(gAdaptive.center)
    else
	    self.ui.root:setContentSize(gAdaptive.size)
	    ccui.Helper:doLayout(self.ui.root)

		-- 适配背景图片
		local bg = self.ui.root:getChildByName("bg")
		if bg then
			bg:setScale(gAdaptive.scaleMax)
		end
    end
end

-- @brief 监听网络消息
-- @param msgID 消息ID
-- @param call 回调
-- @param priority 监听优先级
function UIBase:onNetMsg(msgID, call, priority)
	gNetEventEmitter:on(msgID, call, self, priority)
end

-- @brief 监听系统事件
-- @param msgID 消息ID
-- @param call 回调
-- @param priority 监听优先级
function UIBase:onSysMsg(msgID, call, priority)
	gSysEventEmitter:on(msgID, call, self, priority)
end

-- @override UI界面销毁前的回调
function UIBase:onDestroy()
	UIBase.super.onDestroy(self)
	gNetEventEmitter:offByTag(self)
	gSysEventEmitter:offByTag(self)
end

-- @brief UI界面打开之前的回调
function UIBase:iBeforeOpened()
end

-- @brief UI界面打开后的回调
function UIBase:iAfterOpened()
end

-- @brief UI界面关闭前的回调
function UIBase:iWillClose()
end

-- @brief UI界面关闭后的回调
function UIBase:iAfterClosed()
end

function UIBase:dismissAfterOpened()
	self:eventOnce(SysEvent.UI_AFTER_OPENED, handler(self, self.dismiss), self)
	self:dismiss()
end

return UIBase

