local ScrollViewExAction = {}


local ACTION_TAG = 0xfcfc
ScrollViewExAction.ACTION_TAG = ACTION_TAG


-- @brief 递归设置 CascadeOpacityEnabled
local function recursionSetCascadeOpacityEnabled(node, value)
    node:setCascadeOpacityEnabled(value)
    for k, v in pairs(node:getChildren()) do
        recursionSetCascadeOpacityEnabled(v, value)
    end
end

-- @brief 执行scrollView入场动画-从右飞向左
-- @param flyTime 飞行时间
-- @param delay 间隔时间
-- @param bounceTime 回弹时间
-- @param bounceDis 回弹距离
function ScrollViewExAction:playItemAction_FlyRightToLeft(callback, flyTime, delay, bounceTime, bounceDis)
    if self.bPlayFlyAction then return end

    self:getAllShowItems(true)
    
    local itemCount = #self.tShowItems
    if itemCount <= 0 then
        if callback then callback() end
        return
    end

    -- 飞行时间
    flyTime = flyTime or 0.2
    -- 间隔时间
    delay = delay or 0.05
    -- 回弹时间
    bounceTime = bounceTime or 0.2
    -- 回弹距离
    bounceDis = bounceDis or 10

    -- 移动距离
    local MovePos = self:getContentSize().width

    for k, item in ipairs(self.tShowItems) do
        item:stopAllActionsByTag(ACTION_TAG)
        item:setPositionX(item:getPositionX() + MovePos)
        recursionSetCascadeOpacityEnabled(item, true)
        item:setOpacity(0)

        local move_by1 = cc.MoveBy:create(flyTime, cc.p(-(MovePos + bounceDis), 0))
        local move_by2 = cc.MoveBy:create(bounceTime, cc.p(bounceDis, 0))

        local actions = 
        {
            cc.DelayTime:create((k - 1) * delay),
            cc.Spawn:create(
                cc.EaseSineOut:create(move_by1),
                cc.FadeIn:create(flyTime)
            ),
            cc.EaseSineOut:create(move_by2),
        }

        if k == itemCount then
            table.insert(actions, cc.CallFunc:create(function()
                self:playItemActionFinish()
                if callback then
                    callback()
                end
            end))
        end
        item:runAction(cc.Sequence:create(actions)):setTag(ACTION_TAG)
    end

    self:startPlayItemAction()
end



-- @brief 执行scrollView入场动画-从下飞向上
-- @param flyTime 飞行时间
-- @param delay 间隔时间
-- @param bounceTime 回弹时间
-- @param bounceDis 回弹距离
function ScrollViewExAction:playItemAction_FlyBottomToTop(callback, flyTime, delay, bounceTime, bounceDis)
    if self.bPlayFlyAction then return end

    self:getAllShowItems(true)
    
    local itemCount = #self.tShowItems
    if itemCount <= 0 then
        if callback then callback() end
        return
    end

    -- 飞行时间
    flyTime = flyTime or 0.25
    -- 间隔时间
    delay = delay or 0.05
    -- 回弹时间
    bounceTime = bounceTime or 0.2
    -- 回弹距离
    bounceDis = bounceDis or 20

    -- 移动距离
    local MovePos = self:getContentSize().height

    for k, item in pairs(self.tShowItems) do
        item:stopAllActionsByTag(ACTION_TAG)
        item:setPositionY(item:getPositionY() - MovePos)
        recursionSetCascadeOpacityEnabled(item, true)
        item:setOpacity(0)

        local move_by1 = cc.MoveBy:create(flyTime, cc.p(0, MovePos + bounceDis))
        local move_by2 = cc.MoveBy:create(bounceTime, cc.p(0, -bounceDis))

        local actions = 
        {
            cc.DelayTime:create((k - 1) * delay),
            cc.Spawn:create(
                cc.EaseSineOut:create(move_by1),
                cc.FadeIn:create(flyTime)
            ),
            cc.EaseSineOut:create(move_by2),
        }

        if k == itemCount then
            table.insert(actions, cc.CallFunc:create(function()
                self:playItemActionFinish()
                if callback then
                    callback()
                end
            end))
        end
        item:runAction(cc.Sequence:create(actions)):setTag(ACTION_TAG)
    end

    self:startPlayItemAction()
end

-- @brief 执行scrollView奖励item入场动画-从小变大
-- @param scaleTime 缩放时间
-- @param delay 间隔时间
function ScrollViewExAction:playItemAction_Scale(callback, scaleTime, delay)
    if self.bPlayFlyAction then return end

    self:getAllShowItems(true)
    
    local itemCount = #self.tShowItems
    if itemCount <= 0 then
        if callback then callback() end
        return
    end

    -- 缩放执行时间
    scaleTime = scaleTime or 0.3
    -- 间隔时间
    delay = delay or 0.05

    for k, item in pairs(self.tShowItems) do
        local rawScale = item:getScaleX()

        item:stopAllActionsByTag(ACTION_TAG)
        item:setVisible(false)
        item:setScale(0.2 * rawScale)

        local actions = 
        {
            cc.DelayTime:create((k - 1) * delay),
            cc.Show:create(),
            cc.EaseBackOut:create(cc.ScaleTo:create(scaleTime, rawScale))
        }

        if k == itemCount then
            table.insert(actions, cc.CallFunc:create(function()
                self:playItemActionFinish()
                if callback then
                    callback()
                end
            end))
        end
        item:runAction(cc.Sequence:create(actions)):setTag(ACTION_TAG)
    end

    self:startPlayItemAction()
end

-- @brief 默认动画
function ScrollViewExAction:playItemAction_Default(callback)

    if self.bPlayFlyAction then return end

    self:getAllShowItems(true)
    
    local itemCount = #self.tShowItems
    if itemCount <= 0 then
        if callback then callback() end
        return
    end

    local MovePos = 40
    for k, item in ipairs(self.tShowItems) do
        recursionSetCascadeOpacityEnabled(item, true)
        item:setOpacity(0)
        item:stopAllActionsByTag(ACTION_TAG)
        item:setPositionY(item:getPositionY() - MovePos)

        local move_by = cc.EaseSineIn:create(cc.MoveBy:create(0.1, cc.p(0, MovePos)))
        local fade_in = cc.FadeIn:create(0.3)

        local actions = 
        {
            cc.DelayTime:create((k - 1) * 0.03),
            cc.Spawn:create(fade_in, move_by)
        }

        if k == itemCount then
            table.insert(actions, cc.CallFunc:create(function()
                self:playItemActionFinish()
                if callback then
                    callback()
                end
            end))
        end
        item:runAction(cc.Sequence:create(actions)):setTag(ACTION_TAG)
    end

    self:startPlayItemAction()
end

-- -- @brief 执行listView入场动画-从下飞向上
-- -- @param flyTime 飞行时间
-- -- @param delay 间隔时间
-- -- @param bounceTime 回弹时间
-- -- @param bounceDis 回弹距离
-- function ScrollViewExAction:runListViewAction_FlyBottomToTop(listView, callback, flyTime, delay, bounceTime, bounceDis)
--     if listView.bPlayFlyAction then return end

--     listView:requestDoLayout()
--     listView:doLayout()
--     local items = listView:getItems()
    
--     local itemCount = #items
--     if itemCount <= 0 then
--         if callback then callback() end
--         return
--     end

--     local ACTION_TAG = 0xffee

--     -- 飞行时间
--     flyTime = flyTime or 0.25
--     -- 间隔时间
--     delay = delay or 0.05
--     -- 回弹时间
--     bounceTime = bounceTime or 0.2
--     -- 回弹距离
--     bounceDis = bounceDis or 20

--     -- 移动距离
--     local MovePos = listView:getContentSize().height

--     for k, item in pairs(items) do

--         for j, child in pairs(item:getChildren()) do
--             child:stopAllActionsByTag(ACTION_TAG)
--             child:setPositionY(child:getPositionY() - MovePos)
--             child:setOpacity(0)

--             local move_by1 = cc.MoveBy:create(flyTime, cc.p(0, MovePos + bounceDis))
--             local move_by2 = cc.MoveBy:create(bounceTime, cc.p(0, -bounceDis))

--             local actions = 
--             {
--                 cc.DelayTime:create((k - 1) * delay),
--                 cc.Spawn:create(
--                     cc.EaseSineOut:create(move_by1),
--                     cc.FadeIn:create(flyTime)
--                 ),
--                 cc.EaseSineOut:create(move_by2),
--             }

--             if k == itemCount and j == 1 then
--                 table.insert(actions, cc.CallFunc:create(function()
--                     listView:setTouchEnabled(true)
--                     listView.bPlayFlyAction = false
--                     if callback then
--                         callback()
--                     end
--                 end))
--             end
--             child:runAction(cc.Sequence:create(actions)):setTag(ACTION_TAG)
--         end


--         -- item:stopAllActionsByTag(ACTION_TAG)
--         -- item:setPositionY(item:getPositionY() - MovePos)
--         -- item:setOpacity(0)

--         -- local move_by1 = cc.MoveBy:create(flyTime, cc.p(0, MovePos + bounceDis))
--         -- local move_by2 = cc.MoveBy:create(bounceTime, cc.p(0, -bounceDis))

--         -- local actions = 
--         -- {
--         --     cc.DelayTime:create((k - 1) * delay),
--         --     cc.Spawn:create(
--         --         cc.EaseSineOut:create(move_by1),
--         --         cc.FadeIn:create(flyTime)
--         --     ),
--         --     cc.EaseSineOut:create(move_by2),
--         -- }

--         -- if k == 1 then
--         --     table.insert(actions, cc.CallFunc:create(function()
--         --         listView:setTouchEnabled(true)
--         --         listView.bPlayFlyAction = false
--         --         if callback then
--         --             callback()
--         --         end
--         --     end))
--         -- end
--         -- item:runAction(cc.Sequence:create(actions)):setTag(ACTION_TAG)
--     end

--     listView:setTouchEnabled(false)
--     listView.bPlayFlyAction = true
-- end

return ScrollViewExAction