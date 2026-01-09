local PickerViewNode = import(".PickerViewNode")
local PickerView = class("PickerView", function()
    return ccui.Layout:create()
end)


local function lerp(p1, p2, alpha)
    return p1 * (1 - alpha) + p2 * alpha
end

local abs = math.abs

local function clock() 
    return NowEpochMS()
end

function PickerView:ctor(size)
    assert(size)

    self.touches          = {}
    -- 是否屏蔽触摸
    self.isHolding        = false
    -- 逻辑节点数组
    self.arrLogicNode = {}

    self.contentHeight = 0

    self:setContentSize(size)
    -- 裁剪开启
    self:setClippingEnabled(true)
    self:setClippingType(1)

    -- touch layer
    self.container = cc.Node:create()
    self.container:setAnchorPoint(cc.p(0, 0))
    self:addChild(self.container)

    self:setMargin(0, 0)

    -- 默认吞没事件
    self:setSwallowTouches(true)

    self:enableNodeEvents()

    self:scheduleUpdateWithPriorityLua(handler(self, self.update), 0)
end

function PickerView:onEnter()
    self:_enableTouch()
end

function PickerView:onExit()
    self:_disenableTouch()
    self.touches = {}
    for k, v in pairs(self.arrLogicNode) do
        v:onDestroy()
    end
    self.arrLogicNode = {}
end

--@brief 添加子节点到容器中
function PickerView:addUnit(u)
    self.container:addChild(u)
end

--@brief 移除容器所有
function PickerView:removeAllUnit()
    self.container:removeAllChildren()
end

--@brief 屏蔽触摸事件
function PickerView:holding()
    self.isHolding = true
end

--@brief 启用触摸事件
function PickerView:unHolding()
    self.isHolding = false
end

-- @brief 获取容器
function PickerView:getContainer()
    return self.container
end

--@brief 设置容器位置
function PickerView:setContainerPosition(posx, posy)
    local x, y = self.container:getPosition()
    self:onChangePosition(posx - x, posy - y)
end

-- @brief 设置容器滚动偏移
-- @param offset 偏移量
-- @param duration 动画持续时间
function PickerView:setContentOffsetInDuration(offset, duration)
    local curPosition = cc.p(self.container:getPosition())
    self:performedAnimatedScroll(cc.pAdd(curPosition, offset), duration)
end

-- @brief 获取容器滚动偏移
function PickerView:getContentOffset()
    return cc.p(self.container:getPosition())
end

function PickerView:setMargin(top, bottom)
    self.marginTop = top
    self.marginBottom = bottom
end

-- @brief 开启容器滚动逻辑
-- @param position 滚动的目标位置
-- @param duration 动画持续时间
function PickerView:performedAnimatedScroll(position, duration)
    self:stoppedAnimatedScroll()

    if duration and duration < 0 then
        duration = -duration
    end

    if duration == nil or duration <= 0 then
        self:setContainerPosition(position.x, position.y)
        return
    end

    local curPosition = cc.p(self.container:getPosition())
    local time = 0
    self.container:scheduleUpdateWithPriorityLua(function(dt)
        time = time + dt
        local percent = time / duration
        if percent >= 1.0 then
            self:setContainerPosition(position.x, position.y)

            self:stoppedAnimatedScroll()
        else
            local posx = lerp(curPosition.x, position.x, percent)
            local posy = lerp(curPosition.y, position.y, percent)
            self:setContainerPosition(posx, posy)
        end
    end, 0)
end

-- @brief 停止滚动逻辑
function PickerView:stoppedAnimatedScroll()
    self.container:unscheduleUpdate()
    self._autoScrolling = false
end

--@brief cell创建函数
function PickerView:setOnLoadCellCallback(call)
    self.onLoadCellCallback = call
end

-- @brief cell大小函数
function PickerView:setOnCellSizeCallback(call)
    self.onCellSizeCallback = call
end

-- @brief 设置cell数量
function PickerView:setCellCount(count)
    self.cellCount = count
end

-- @brief 停止滚动事件
function PickerView:setScrollEndCallback(call)
    self.onScrollEndCallback = call
end

-- @brief 加载列表
function PickerView:loadList(isFreeze)
    self:stoppedAnimatedScroll()

    local lastIndex = 0
    if isFreeze then
        lastIndex = math.min(self:getCurIndex(), self.cellCount)
    end
    
    -- 移除之前的逻辑节点
    for k, v in pairs(self.arrLogicNode) do
        v:onDestroy()
    end
    self.arrLogicNode = {}

    if self.cellCount == 0 then
        self.contentHeight = 0
        self.container:setPosition(0, 0)
        self:onChangePosition(0, 0)
        return
    end

    -- 内容高度
    local totalHeight = self.marginTop
    for i = 1, self.cellCount do
        totalHeight = totalHeight + self.onCellSizeCallback(i).height
    end
    totalHeight = totalHeight + self.marginBottom
    self.contentHeight = totalHeight


    -- 逻辑节点初始化
    local y = totalHeight - self.marginTop
    for i = 1, self.cellCount do
        local size = self.onCellSizeCallback(i)
        y = y - size.height

        local node = PickerViewNode.new(self, i, #self.arrLogicNode + 1)
        node:setSize(size.width, size.height)
        node:setPositionY(y)

        table.insert(self.arrLogicNode, node)
    end
    self.container:setPosition(0, self:getContentSize().height - self.contentHeight)
    self:onChangePosition(0, 0)

    if isFreeze and lastIndex ~= 0 then
        self:jumpItemToCenter(lastIndex)
    end
end

function PickerView:jumpItemToCenter(index)
    self:stoppedAnimatedScroll()
    local viewHeight = self:getContentSize().height
    local cury = self.container:getPositionY()

    local minNode, minOffset
    -- 查找距离中心最短的cell
    for k, v in pairs(self.arrLogicNode) do
        if v.index == index then
            local posYInView = v.y + cury + v.height * 0.5
            local offset = posYInView - viewHeight * 0.5
            self:onChangePosition(0, -offset)
        end
    end
end

function PickerView:scrollItemToCenter(index)
    self:stoppedAnimatedScroll()
    local viewHeight = self:getContentSize().height
    local cury = self.container:getPositionY()

    local minNode, minOffset
    -- 查找距离中心最短的cell
    for k, v in pairs(self.arrLogicNode) do
        if v.index == index then
            local posYInView = v.y + cury + v.height * 0.5
            local offset = posYInView - viewHeight * 0.5
            self:setContentOffsetInDuration(cc.p(0, -offset), math.abs(offset) / 2000)
            break
        end
    end
end

function PickerView:getCurIndex()
    local node = self:getCenterNode()
    if node then
        return node.index
    end
    return 1
end

function PickerView:getCenterNode()
    local viewHeight = self:getContentSize().height
    local cury = self.container:getPositionY()

    local minNode, minOffset
    -- 查找距离中心最短的cell
    for k, v in pairs(self.arrLogicNode) do
        if v.visible then
            local posYInView = v.y + cury + v.height * 0.5
            local offset = posYInView - viewHeight * 0.5
            if minOffset == nil or abs(offset) < abs(minOffset) then
                minOffset = offset
                minNode = v
            end
        end
    end

    return minNode, minOffset
end

-- @brief 判断是否处于自动滚动中
function PickerView:isAutoRolling()
    return self._autoScrolling
end

-- @brief 判断是否处于触摸中状态
function PickerView:isTouching()
    return #self.touches > 0
end


--------------------------------------------------------- private ---------------------------------------------------------

function PickerView:selfVisible(node)
    if node == nil then return true end

    if node:isVisible() then
        return self:selfVisible(node:getParent())
    end
    return false
end

function PickerView:_enableTouch()
    self:_disenableTouch()

    local listener = cc.EventListenerTouchOneByOne:create()
    listener:setSwallowTouches(self.swallowTouch)

    listener:registerScriptHandler(function(touch, event)
        if #self.touches == 1 then
            return false
        end

        if not self:selfVisible(self) then
            return false
        end

        local location = self:getParent():convertToNodeSpace(touch:getLocation())
        if cc.rectContainsPoint(self:getBoundingBox(), location) then
            return self:onTouchesBegan(self:_convertTouch(touch))
        end
    end, cc.Handler.EVENT_TOUCH_BEGAN)

    listener:registerScriptHandler(function(touch, event)
        self:onTouchesMoved(self:_convertTouch(touch))
    end, cc.Handler.EVENT_TOUCH_MOVED)

    listener:registerScriptHandler(function(touch, event)
        self:onTouchesEnded(self:_convertTouch(touch))
    end, cc.Handler.EVENT_TOUCH_ENDED)

    listener:registerScriptHandler(function(touch, event)
        self:onTouchesEnded(self:_convertTouch(touch))
    end, cc.Handler.EVENT_TOUCH_CANCELLED)

    self.container:getEventDispatcher():addEventListenerWithSceneGraphPriority(listener, self.container)
    self.touchListener = listener
end

function PickerView:_convertTouch(touch)
    local point = self:convertToNodeSpace(touch:getLocation())
    return {
        x = point[1],
        y = point[2],
        id = touch:getId()
    }
end

function PickerView:_disenableTouch()
    if self.touchListener then
        self:getEventDispatcher():removeEventListener(self.touchListener)
        self.touchListener = nil
    end
end

function PickerView:update(dt)
    if self._autoScrolling then
        self:processAutoScrolling(dt)
    end
end

function PickerView:onTouchesBegan(point)
    if self.isHolding then
        return false
    end
    
    if self.onTouchPreJudgment and not self.onTouchPreJudgment() then
        return false
    end
	
    point.previousPoint = cc.p(point.x, point.y)
    self.touches[#self.touches + 1] = point
    self.touchBeginPos = cc.p(point.x, point.y)
	
    self._autoScrolling = false
    
    self._touchMoveDisplacements = {}
    self._touchMoveTimeDeltas = {}
    self._touchMovePreviousTimestamp = clock()

    self:stoppedAnimatedScroll()
    return true
end

function PickerView:onTouchesMoved(point)
    if self.isHolding then
        return
    end

    for _, t in pairs(self.touches) do
        if point.id == t.id then
            t.previousPoint = cc.p(t.x, t.y)
            t.x, t.y = point.x, point.y
        end
    end

    if #self.touches == 1 then
        local touch = self.touches[1]

        local deltaPosition = cc.p(touch.x - touch.previousPoint.x, touch.y - touch.previousPoint.y)
		-- 屏蔽X轴滚动
        deltaPosition.x = 0

        self:onChangePosition(deltaPosition.x, deltaPosition.y)

        self:gatherTouchMove(deltaPosition);
    end
end

function PickerView:onTouchesEnded(point)
    for _, t in pairs(self.touches) do
        if point.id == t.id then
            t.previousPoint = cc.p(t.x, t.y)
            t.x, t.y = point.x, point.y
        end
    end

    if #self.touches == 1 then
        local touch = self.touches[1]
        local deltaPosition = cc.p(touch.x - touch.previousPoint.x, touch.y - touch.previousPoint.y)
		-- 屏蔽X轴滚动
        deltaPosition.x = 0
        self:gatherTouchMove(deltaPosition);
    end

    for k, t in pairs(self.touches) do
        if point.id == t.id then
            table.remove(self.touches, k)
            break
        end
    end

    if self.isHolding then
        return
    end

	if #self.touches == 0 then
        local touchMoveVelocity = self:calculateTouchMoveVelocity()
        self:startInertiaScroll(touchMoveVelocity)

        -- 滑动太慢了，将时间缩短点
        local factor = 0.5
        self._autoScrollTotalTime = self._autoScrollTotalTime * factor * 0.5
        self._autoScrollTargetDelta.x = self._autoScrollTargetDelta.x * factor
        self._autoScrollTargetDelta.y = self._autoScrollTargetDelta.y * factor

        ------------------------ 
        -- 限制滚动距离，让最后滚动完毕一定是将某个cell停靠在视图中间
        ------------------------ 
        local maxContainerPosy = 0
        local minContainerPosy = self:getContentSize().height - self.contentHeight
        if minContainerPosy >= 0 then
            minContainerPosy = 0
        end

        local curContainerPosy = self.container:getPositionY()

        local maxDeltay = maxContainerPosy - curContainerPosy
        local minDeltay = minContainerPosy - curContainerPosy
        
        local scrollTargetDeltay = self._autoScrollTargetDelta.y
        if scrollTargetDeltay > maxDeltay then scrollTargetDeltay = maxDeltay end
        if scrollTargetDeltay < minDeltay then scrollTargetDeltay = minDeltay end

        -- 模拟滚动结束后,获取距离视图中央最近的cell
        self.container:setPositionY(curContainerPosy + scrollTargetDeltay)
        local minNode, minOffset = self:getCenterNode()

        -- 新的偏移量
        scrollTargetDeltay = scrollTargetDeltay - minOffset

        -- 重新计算自动滚动时间
        if abs(self._autoScrollTargetDelta.y) > 0.0001 then
            self._autoScrollTotalTime = self._autoScrollTotalTime * (abs(scrollTargetDeltay) / abs(self._autoScrollTargetDelta.y))
        else
            self._autoScrollTotalTime = 0.1
        end
        self._autoScrollTargetDelta.y = scrollTargetDeltay
        
        -- 还原偏移值
        self.container:setPositionY(curContainerPosy)
	end
end

function PickerView:onChangePosition(offsetx, offsety)
    local viewHeight = self:getContentSize().height

    local maxValue = 0
    local minValue = viewHeight - self.contentHeight
    if minValue >= 0 then
        minValue = 0
    end

    local ret = false

    -- 越界计算
	local cury = self.container:getPositionY() + offsety
    if cury > maxValue then
        ret = true
        cury = maxValue
    end
    if cury < minValue then
        ret = true
        cury = minValue
    end
	self.container:setPositionY(cury)

    -- 
	local offset, curNode
	for i = 1, self.cellCount do
		curNode = self.arrLogicNode[i]
        offset = curNode.y + cury + curNode.height

        if offset < 0 or offset > viewHeight + curNode.height then
			curNode:onHide()
        else
            curNode:onShow()
        end
	end

    return ret
end

--------------------------------------------------------  惯性滚动逻辑 --------------------------------------------------------
-- 以下划线开头的变量都是惯性滚动相关变量


local NUMBER_OF_GATHERED_TOUCHES_FOR_MOVE_SPEED = 5

local function calculateAutoScrollTimeByInitialSpeed(initialSpeed)
    --  Calculate the time from the initial speed according to quintic polynomial.
    local time = math.sqrt(math.sqrt(initialSpeed / 5))
    return time
end

local function quintEaseOut(time)
    time = time - 1
    return (time * time * time * time * time + 1)
end

function PickerView:gatherTouchMove(delta)
    while (#self._touchMoveDisplacements >= NUMBER_OF_GATHERED_TOUCHES_FOR_MOVE_SPEED) do
        table.remove(self._touchMoveDisplacements, 1)
        table.remove(self._touchMoveTimeDeltas, 1)
    end
    table.insert(self._touchMoveDisplacements, delta)
    
    local timestamp = clock()
    table.insert(self._touchMoveTimeDeltas, (timestamp - self._touchMovePreviousTimestamp) / 1000)
    self._touchMovePreviousTimestamp = timestamp;
end

function PickerView:calculateTouchMoveVelocity()
    local totalTime = 0

    for k, v in pairs(self._touchMoveTimeDeltas) do
        totalTime = totalTime + v
    end

    if totalTime == 0 or totalTime >= 0.5 then
        return cc.p(0, 0)
    end

    local totalMovement = cc.p(0, 0)
    for k, v in pairs(self._touchMoveDisplacements) do
        totalMovement.x = totalMovement.x + v.x
        totalMovement.y = totalMovement.y + v.y
    end

    return cc.p(totalMovement.x / totalTime, totalMovement.y / totalTime)
end

function PickerView:startInertiaScroll(touchMoveVelocity)
    local MOVEMENT_FACTOR = 0.7
    local inertiaTotalMovement  = cc.pMul(touchMoveVelocity, MOVEMENT_FACTOR)
    self:startAttenuatingAutoScroll(inertiaTotalMovement, touchMoveVelocity);
end

function PickerView:startAttenuatingAutoScroll(deltaMove, initialVelocity)
    local time = calculateAutoScrollTimeByInitialSpeed(cc.pGetLength(initialVelocity))
    
    self._autoScrolling                  = true
    self._autoScrollTargetDelta          = deltaMove
    self._autoScrollStartPosition        = cc.p(self.container:getPosition())
    self._autoScrollTotalTime            = time
    self._autoScrollAccumulatedTime      = 0
end

function PickerView:processAutoScrolling(deltaTime)
    -- Elapsed time
    self._autoScrollAccumulatedTime = self._autoScrollAccumulatedTime + deltaTime

    -- Calculate the progress percentage
    local percentage = math.min(1, self._autoScrollAccumulatedTime / self._autoScrollTotalTime)

    percentage = quintEaseOut(percentage)

    -- Calculate the new position
    -- local newPosition = cc.pAdd(self._autoScrollStartPosition, cc.pMul(self._autoScrollTargetDelta, percentage))
    local newPositionY = self._autoScrollStartPosition.y + self._autoScrollTargetDelta.y * percentage
    local reachedEnd  = abs(percentage - 1) <= 0.0001

    if reachedEnd then
        -- newPosition = cc.pAdd(self._autoScrollStartPosition, self._autoScrollTargetDelta)
        newPositionY = self._autoScrollStartPosition.y + self._autoScrollTargetDelta.y
    end

    -- Finish auto scroll if it ended
    if reachedEnd then
        self._autoScrolling = false
        -- print("滚动完成================>>")
    end

    -- 自动滚动到中心位置
    local moveDeltay = newPositionY - self.container:getPositionY()
    self:onChangePosition(0, moveDeltay)

    if not self._autoScrolling and self.onScrollEndCallback then
        self.onScrollEndCallback()
    end
end

return PickerView