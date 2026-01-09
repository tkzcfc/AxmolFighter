
local UIPageViewNode = class("UIPageViewNode")

function UIPageViewNode:ctor(view, index)
    self.x, self.y = 0, 0
	self.view = view
	self.index = index
	self.visible = true
end

function UIPageViewNode:setSize(width, height)
    self.width = width
    self.height = height
end

-- @brief 逻辑节点位置设置
function UIPageViewNode:setPositionY(y)
	self.y = y
	if self.render then self.render:setPositionY(y) end
end

-- @brief 逻辑节点位置设置
function UIPageViewNode:setPositionX(x)
	self.x = x
	if self.render then self.render:setPositionX(x) end
end

-- @brief 逻辑节点显示
function UIPageViewNode:onShow()
	self.visible = true
	if self.render == nil then
		self:loadRender()
	end
	self.render:setVisible(true)
end

-- @brief 逻辑节点隐藏
function UIPageViewNode:onHide()
	self.visible = false
	if self.render then
		self.render:setVisible(false)
	end
end

function UIPageViewNode:reset()
    if self.render then
        self.render:setVisible(false)
        self.freeRender = self.render
        self.render = nil
    end
	self.visible = false
end

-- @brief 逻辑节点销毁
function UIPageViewNode:onDestroy()
	self:onHide()
	if self.render then
		self.render:removeFromParent()
		self.render = nil
	end
    if self.freeRender then
        self.freeRender:removeFromParent()
        self.freeRender = nil
    end
	self.view = nil
end

function UIPageViewNode:loadRender()
	if not self.render then
        if self.freeRender then
            self.render = self.freeRender
			self.freeRender = nil
			self.view.onUpdatePageCallback(self.render, self.index)
        else
            local render = self.view.onCreatePageCallback(self.index)
            self.view:addUnit(render)
            self.render = render
        end
        
        self.render:setPosition(self.x, self.y)
	end
end

function UIPageViewNode:updatePage()
	if self.render then
		self.view.onUpdatePageCallback(self.render, self.index)
	end
end

return UIPageViewNode