-- @Author : fc
-- @Date   : 2021-10-12 10:46:43
-- @remark : 


local ScrollViewBaseItem = class("ScrollViewBaseItem", ccui.Widget)
-- local ScrollViewBaseItem = class("ScrollViewBaseItem", ccui.Layout)

function ScrollViewBaseItem:initItem(render)
    render:setAnchorPoint(0.5, 0.5)
    render:setPosition(self.itemSize.width * 0.5, self.itemSize.height * 0.5)
    render:setScale(self.itemScale * render:getScaleX())
    render:setVisible(true)
    self:addChild(render)

    -- self:setAnchorPoint(0.5, 0.5)
    -- self:setBackGroundColorType(1)

    self.render = render
end

function ScrollViewBaseItem:iItemWillCreate(itemSize, itemRawSize, itemScale)
    self:setContentSize(itemSize)
    self.itemSize = itemSize
    self.itemScale = itemScale
end

function ScrollViewBaseItem:iItemWillUpdate(index, datas)
end

function ScrollViewBaseItem:getRender()
    return self.render
end

return ScrollViewBaseItem
