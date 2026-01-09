local UIScrollView = class("UIScrollView", function()
    return ccui.Layout:create()
end)


local function lerp(p1, p2, alpha)
    return p1 * (1 - alpha) + p2 * alpha
end

local abs = math.abs

local function clock() 
    return NowEpochMS()
end

local Direction = {
    NONE = 0,
    VERTICAL = 1,
    HORIZONTAL = 2,
    BOTH = 3
}
UIScrollView.Direction = Direction

function UIScrollView:ctor(size)
    assert(size)

    self.touches          = {}
    -- 是否屏蔽触摸
    self.isHolding        = false

    self.direction = Direction.BOTH

    self:setContentSize(size)
    -- 裁剪开启
    self:setClippingEnabled(true)
    self:setClippingType(1)

    -- touch layer
    self.container = cc.Node:create()
    self.container:setAnchorPoint(cc.p(0, 0))
    self:addChild(self.container)

    -- 默认吞没事件
    self:setSwallowTouches(true)

    self:enableNodeEvents()

    self:scheduleUpdateWithPriorityLua(handler(self, self.update), 0)
end

function UIScrollView:onEnter()
    self:_enableTouch()
end

function UIScrollView:onExit()
    self:_disenableTouch()
    self.touches = {}
end

--@brief 添加子节点到容器中
function UIScrollView:addUnit(u)
    self.container:addChild(u)
end

--@brief 移除容器所有
function UIScrollView:removeAllUnit()
    self.container:removeAllChildren()
end

--@brief 屏蔽触摸事件
function UIScrollView:holding()
    self.isHolding = true
end

--@brief 启用触摸事件
function UIScrollView:unHolding()
    self.isHolding = false
end

-- @brief 设置滚动方向
function UIScrollView:setDirection(value)
    self.direction = value
end

-- @brief 获取容器
function UIScrollView:getContainer()
    return self.container
end

--@brief 设置容器位置
function UIScrollView:setContainerPosition(posx, posy)
    local x, y = self.container:getPosition()
    self:onChangePosition(posx - x, posy - y)
end

-- @brief 设置容器滚动偏移
-- @param offset 偏移量
-- @param duration 动画持续时间
function UIScrollView:setContentOffsetInDuration(offset, duration)
    local curPosition = cc.p(self.container:getPosition())
    self:performedAnimatedScroll(cc.pAdd(curPosition, offset), duration)
end

-- @brief 获取容器滚动偏移
function UIScrollView:getContentOffset()
    return cc.p(self.container:getPosition())
end

-- @brief 开启容器滚动逻辑
-- @param position 滚动的目标位置
-- @param duration 动画持续时间
function UIScrollView:performedAnimatedScroll(position, duration)
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
function UIScrollView:stoppedAnimatedScroll()
    self.container:unscheduleUpdate()
    self._autoScrolling = false
end

-- @brief 停止滚动事件
function UIScrollView:setScrollEndCallback(call)
    self.onScrollEndCallback = call
end

--------------------------------------------------------- private ---------------------------------------------------------

function UIScrollView:selfVisible(node)
    if node == nil then return true end
    
    if node:isVisible() then
        return self:selfVisible(node:getParent())
    end
    return false
end

function UIScrollView:_enableTouch()
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

function UIScrollView:_convertTouch(touch)
    local point = self:convertToNodeSpace(touch:getLocation())
    return {
        x = point[1],
        y = point[2],
        id = touch:getId()
    }
end

function UIScrollView:_disenableTouch()
    if self.touchListener then
        self:getEventDispatcher():removeEventListener(self.touchListener)
        self.touchListener = nil
    end
end

function UIScrollView:update(dt)
    if self._autoScrolling then
        self:processAutoScrolling(dt)
    end
end

function UIScrollView:onTouchesBegan(point)
    if self.isHolding then
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

function UIScrollView:onTouchesMoved(point)
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
        if self.direction == Direction.VERTICAL then
            deltaPosition.x = 0
        elseif self.direction == Direction.HORIZONTAL then
            deltaPosition.y = 0
        end

        self:onChangePosition(deltaPosition.x, deltaPosition.y)

        self:gatherTouchMove(deltaPosition)
    end
end

function UIScrollView:onTouchesEnded(point)
    for _, t in pairs(self.touches) do
        if point.id == t.id then
            t.previousPoint = cc.p(t.x, t.y)
            t.x, t.y = point.x, point.y
        end
    end

    if #self.touches == 1 then
        local touch = self.touches[1]
        local deltaPosition = cc.p(touch.x - touch.previousPoint.x, touch.y - touch.previousPoint.y)
        if self.direction == Direction.VERTICAL then
            deltaPosition.x = 0
        elseif self.direction == Direction.HORIZONTAL then
            deltaPosition.y = 0
        end

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
	end
end

function UIScrollView:onChangePosition(offsetx, offsety)
	self.container:setPosition(self.container:getPositionX() + offsetx, self.container:getPositionY() + offsety)
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

function UIScrollView:gatherTouchMove(delta)
    while (#self._touchMoveDisplacements >= NUMBER_OF_GATHERED_TOUCHES_FOR_MOVE_SPEED) do
        table.remove(self._touchMoveDisplacements, 1)
        table.remove(self._touchMoveTimeDeltas, 1)
    end
    table.insert(self._touchMoveDisplacements, delta)
    
    local timestamp = clock()
    table.insert(self._touchMoveTimeDeltas, (timestamp - self._touchMovePreviousTimestamp) / 1000)
    self._touchMovePreviousTimestamp = timestamp;
end

function UIScrollView:calculateTouchMoveVelocity()
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

function UIScrollView:startInertiaScroll(touchMoveVelocity)
    local MOVEMENT_FACTOR = 0.7
    local inertiaTotalMovement  = cc.pMul(touchMoveVelocity, MOVEMENT_FACTOR)
    self:startAttenuatingAutoScroll(inertiaTotalMovement, touchMoveVelocity);
end

function UIScrollView:startAttenuatingAutoScroll(deltaMove, initialVelocity)
    local time = calculateAutoScrollTimeByInitialSpeed(cc.pGetLength(initialVelocity))
    
    self._autoScrolling                  = true
    self._autoScrollTargetDelta          = deltaMove
    self._autoScrollStartPosition        = cc.p(self.container:getPosition())
    self._autoScrollTotalTime            = time
    self._autoScrollAccumulatedTime      = 0
end

function UIScrollView:processAutoScrolling(deltaTime)
    -- Elapsed time
    self._autoScrollAccumulatedTime = self._autoScrollAccumulatedTime + deltaTime

    -- Calculate the progress percentage
    local percentage = math.min(1, self._autoScrollAccumulatedTime / self._autoScrollTotalTime)

    percentage = quintEaseOut(percentage)

    -- Calculate the new position
    local newPosition = cc.pAdd(self._autoScrollStartPosition, cc.pMul(self._autoScrollTargetDelta, percentage))
    local reachedEnd  = abs(percentage - 1) <= 0.0001

    if reachedEnd then
        newPosition = cc.pAdd(self._autoScrollStartPosition, self._autoScrollTargetDelta)
    end

    -- Finish auto scroll if it ended
    if reachedEnd then
        self._autoScrolling = false
        -- AUTOSCROLL_ENDED
    end
    -- 自动滚动到中心位置
    local moveDeltax = newPosition.x - self.container:getPositionX()
    local moveDeltay = newPosition.y - self.container:getPositionY()
    
    self:onChangePosition(moveDeltax, moveDeltay)

    -- 滚动完毕
    if centerIndex and self.onScrollEndCallback then
        self.onScrollEndCallback(centerIndex)
    end
end

return UIScrollView