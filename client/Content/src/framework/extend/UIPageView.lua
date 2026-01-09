local UIScrollView = import(".UIScrollView")
local UIPageViewNode = import(".UIPageViewNode")
local UIPageView = class("UIPageView", UIScrollView)

local abs = math.abs

function UIPageView:ctor(size)
    UIPageView.super.ctor(self, size)
    self.containerSize = clone(size)
    self.viewSize = clone(size)
    -- 逻辑节点数组
    self.arrLogicNode = {}

    self.pageCount = 0

    self:setDirection(UIPageView.Direction.HORIZONTAL)
end

function UIPageView:onExit()
    UIPageView.super.onExit(self)
    for k, v in pairs(self.arrLogicNode) do
        v:onDestroy()
    end
    self.arrLogicNode = {}
end

function UIPageView:setOnCreatePageCallback(callback)
    self.onCreatePageCallback = callback
end

function UIPageView:setOnUpdatePageCallback(callback)
    self.onUpdatePageCallback = callback
end

function UIPageView:setOnScrollCallback(callback)
    self.onScrollCallback = callback
end

function UIPageView:getPageCount()
    return self.pageCount
end

function UIPageView:load(pageCount, freeze)
    self:stoppedAnimatedScroll()

    self.pageCount = pageCount
    
    for k, v in pairs(self.arrLogicNode) do
        v:reset()
    end

    -- 删除多余的
    for i = 1, #self.arrLogicNode - pageCount do
		local node = table.remove(self.arrLogicNode)
		node:onDestroy()
	end
	-- 添加缺少的逻辑节点
	for i = #self.arrLogicNode + 1, pageCount do
		local node = UIPageViewNode.new(self, i)
		table.insert(self.arrLogicNode, node)
	end

    local viewSize = self.viewSize
    self.containerSize = clone(viewSize)
    if pageCount == 0 then
        self.container:setPosition(0, 0)
        self:onChangePosition(0, 0)
        return
    end

    for i = 1, self.pageCount do
        local node = self.arrLogicNode[i]
        if self.direction == UIPageView.Direction.HORIZONTAL then
            node:setPositionX((i - 1) * self.viewSize.width)
            node:setPositionY(0)
        else
            node:setPositionX(0)
            node:setPositionY((i - 1) * self.viewSize.height)
        end
    end

    if self.direction == UIPageView.Direction.HORIZONTAL then
        local width = math.max(viewSize.width, pageCount * viewSize.width)
        self.containerSize.width = width
    else
        local height = math.max(viewSize.height, pageCount * viewSize.height)
        self.containerSize.height = height
    end
    
    if freeze then
        local x, y = self.container:getPosition()
        self.container:setPosition(0, 0)
        self:onChangePosition(x, y)
    else
        self.container:setPosition(0, 0)
        self:onChangePosition(0, 0)
    end
end

function UIPageView:updateAllPage()
    for _, node in pairs(self.arrLogicNode) do
        node:updatePage()
    end
end

function UIPageView:onChangePosition(offsetx, offsety)
    local x, y = self.container:getPositionX() + offsetx, self.container:getPositionY() + offsety

    local maxValue = 0
    local minValue = math.min(self.viewSize.width - self.containerSize.width, 0)
    x = math.max(x, minValue)
    x = math.min(x, maxValue)

    maxValue = 0
    minValue = math.min(self.viewSize.height - self.containerSize.height, 0)    
    y = math.max(y, minValue)
    y = math.min(y, maxValue)
    
	self.container:setPosition(x, y)

       
	local boundMinValue, boundMaxValue
	if self.direction == UIPageView.Direction.HORIZONTAL then
        boundMinValue = -x
		boundMinValue = boundMinValue - self.viewSize.width
		boundMaxValue = boundMinValue + self.viewSize.width + self.viewSize.width
	else
        boundMinValue = -y
		boundMinValue = boundMinValue - self.viewSize.height
		boundMaxValue = boundMinValue + self.viewSize.height + self.viewSize.height
	end

	local curValue, curNode
	for i = 1, self.pageCount do
		curNode = self.arrLogicNode[i]
		if self.direction == UIPageView.Direction.HORIZONTAL then
			curValue = curNode.x
		else
			curValue = curNode.y
		end
		if curValue < boundMinValue or curValue > boundMaxValue then
			curNode:onHide()
		else
			curNode:onShow()
		end
	end

    if self.onScrollCallback then
        self.onScrollCallback()
    end
end

function UIPageView:onTouchesBegan(point)
    if not UIPageView.super.onTouchesBegan(self, point) then
        return false
    end

    local node, offset = self:getCenterNode()

    if node then
        self.touchBeganPageIndex = node.index
    else
        self.touchBeganPageIndex = 1
    end

    return true
end

function UIPageView:onTouchesEnded(point)
    UIPageView.super.onTouchesEnded(self, point)
    if self.isHolding then
        return
    end
    
    local touchMoveVelocity = self:calculateTouchMoveVelocity()
    local moveVelocity = 0
    if self.direction == UIPageView.Direction.HORIZONTAL then
        touchMoveVelocity.y = 0
        moveVelocity = touchMoveVelocity.x
    else
        touchMoveVelocity.x = 0
        moveVelocity = touchMoveVelocity.y
    end

    local toPageIndex = self.touchBeganPageIndex
    if abs(point.x - self.touchBeginPos.x) > 60 then
        if moveVelocity > 0 then
            toPageIndex = math.max(toPageIndex - 1, 1)
        else
            toPageIndex = math.min(toPageIndex + 1, self.pageCount)
        end
    end

    local node = self.arrLogicNode[toPageIndex]
    if not node then
        return
    end
    
    self._autoScrollTotalTime = self._autoScrollTotalTime * 0.5
    if self.direction == UIPageView.Direction.HORIZONTAL then
        local scrollTargetDelta = -node.x - self.container:getPositionX()
        self._autoScrollTargetDelta.x = scrollTargetDelta
        self._autoScrollTotalTime = abs(scrollTargetDelta) / 1500
    else
        local scrollTargetDelta = -node.y - self.container:getPositionY()
        self._autoScrollTargetDelta.y = scrollTargetDelta
        self._autoScrollTotalTime = abs(scrollTargetDelta) / 1500
    end
end

function UIPageView:getCurrentPageIndex()
    local node = self:getCenterNode()
    if node then
        return node.index
    end
    return 0
end

function UIPageView:getPage(index)
    for k, v in pairs(self.arrLogicNode) do
        if v.index == index then
            return v.render
        end
    end
end

function UIPageView:getCenterNode()
    if self.direction == UIPageView.Direction.HORIZONTAL then
        local curx = self.container:getPositionX()

        local minNode, minOffset
        -- 查找距离中心最短的cell
        for k, v in pairs(self.arrLogicNode) do
            if k > self.pageCount then break end

            if v.visible then
                local offset = v.x + curx
                if minOffset == nil or abs(offset) < abs(minOffset) then
                    minOffset = offset
                    minNode = v
                end
            end
        end

        return minNode, minOffset
    else
        local cury = self.container:getPositionY()

        local minNode, minOffset
        -- 查找距离中心最短的cell
        for k, v in pairs(self.arrLogicNode) do
            if k > self.pageCount then break end

            if v.visible then
                local offset = v.y + cury
                if minOffset == nil or abs(offset) < abs(minOffset) then
                    minOffset = offset
                    minNode = v
                end
            end
        end

        return minNode, minOffset
    end
end

return UIPageView