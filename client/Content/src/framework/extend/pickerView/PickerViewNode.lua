
local PickerViewNode = class("PickerViewNode")

function PickerViewNode:ctor(pickerView, index)
	self.x, self.y, self.width, self.height = 0, 0, 0, 0
	self.pickerView = pickerView
	self.index = index
	self.visible = true
end

function PickerViewNode:setSize(width, height)
    self.width = width
    self.height = height
end

-- @brief 逻辑节点位置设置
function PickerViewNode:setPositionY(y)
	self.y = y
	if self.render then self.render:setPositionY(y) end
end

-- @brief 逻辑节点显示
function PickerViewNode:onShow()
	self.visible = true
	if self.render == nil then
		self:loadRender()
	end
	self.render:setVisible(true)
end

-- @brief 逻辑节点隐藏
function PickerViewNode:onHide()
	self.visible = false
	if self.render then
		self.render:setVisible(false)
	end
end

-- @brief 逻辑节点销毁
function PickerViewNode:onDestroy()
	self:onHide()
	if self.render then
		self.render:removeFromParent()
		self.render = nil
	end
	self.pickerView = nil
end

function PickerViewNode:loadRender()
	if not self.render then
		local render = self.pickerView.onLoadCellCallback(self.index)
		render:setVisible(false)
		render:setPosition(self.x, self.y)
        self.pickerView:addUnit(render)

		self.render = render
	end
end

return PickerViewNode