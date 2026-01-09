-- @Author: 
-- @Date:   2020-11-08 14:36:29
-- @remark: view管理器

local Vector = import("..utils.Vector")
local ViewManager = class("ViewManager")

require("framework.utils.Logger").attachTo(ViewManager)
property(ViewManager, "pViewRoot")
propertyReadOnly(ViewManager, "sLastViewName")

function ViewManager:ctor()
    self.viewStack = Vector:new(true)
    self.sLastViewName = ""
end

-- @brief run view
function ViewManager:runView(view)
    local curView = self.viewStack:back()
    if curView then
        gUIManager:pop()
        curView:removeFromParent()
        self.sLastViewName = curView.__cname
        self:logI("移除view:", curView.__cname, tostring(curView))
        self.viewStack:popBack()
    end

    self:logI("运行view:", view.__cname, tostring(view), self.viewStack:size())
    self:pushBackView(view)
end

-- @brief pop view
function ViewManager:popView()
    local curView = self.viewStack:back()

    if curView == nil then
        return
    end

    gUIManager:pop()
    curView:removeFromParent()
    self.sLastViewName = curView.__cname
    self.viewStack:popBack()

    curView = self.viewStack:back()
    if curView then
        curView:setVisible(true)
    end

    return true
end

-- @brief push view
function ViewManager:pushView(view)
    local curView = self.viewStack:back()
    if curView then
        curView:setVisible(false)
        self.sLastViewName = curView.__cname
    end
    self:pushBackView(view)
end

-- @brief 获取view栈深度
function ViewManager:getStackDepth()
    return self.viewStack:size()
end

-- @brief 
function ViewManager:getCurView()
    return self.viewStack:back()
end

-- @brief 清理所有view
function ViewManager:clear()
    repeat
        if self.viewStack:empty() then break end
        self:popView()
    until(false)
end

-- @brief 获取当前view的名称
function ViewManager:getCurViewName()
    local curView = self:getCurView()
    if curView then
        return curView.__cname
    end
end

-- @brief 是否处于某个界面
-- @param viewName 界面名称
function ViewManager:isInView(viewName)
    local curView = self:getCurView()
    if curView then
        return curView.__cname == viewName
    end
    return false
end

------------------------------------------------- private -------------------------------------------------
function ViewManager:pushBackView(view)
    gUIManager:push()
    gUIManager:curContext():setDefaultRootNode(view:getUIRoot())
    
    self.pViewRoot:addChild(view)
    self.viewStack:pushBack(view)
end

return ViewManager

