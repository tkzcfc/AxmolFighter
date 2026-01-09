-- @Author : 
-- @Date   : 2020-02-29 21:23:48
-- @remark : UI管理

local Vector = require("framework.utils.Vector")
local UIContext = require("framework.ui.UIContext")

local UIManager = class("UIManager")

function UIManager:ctor()
	self.contextStack = Vector:new(false)
	self:push()
end

function UIManager:pop()
	self.contextStack:back():destroyAllUI()
	self.contextStack:popBack()
end

function UIManager:push()
	self.contextStack:pushBack(UIContext.new())
end

function UIManager:curContext()
	return self.contextStack:back()
end

function UIManager:pushUI(ui, unique, zorder)
	self:curContext():pushUI(ui, unique, zorder)
end

function UIManager:popTopUI()
	self:curContext():popTopUI()
end

function UIManager:popUI(ui)
	return self:curContext():popUI(ui)
end

function UIManager:getUI(ui)
	return self:curContext():getUI(ui)
end

function UIManager:hasUI(ui)
	return self:curContext():hasUI(ui)
end

function UIManager:destroyUI(ui)
	self:curContext():destroyUI(ui)
end

function UIManager:destroyAllUI()
	self:curContext():destroyAllUI()
end

function UIManager:getCurUICount()
	return self:curContext():getCurUICount()
end

function UIManager:getTopUI()
	return self:curContext():getTopUI()
end

return UIManager