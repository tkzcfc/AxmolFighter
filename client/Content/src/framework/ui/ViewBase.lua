-- @Author : fc
-- @Date   : 2021-10-29 15:35:44
-- @remark :


local ViewBase = class("ViewBase", cc.Node)

require("framework.utils.Logger").attachTo(ViewBase)
property(ViewBase, "pUIRoot")

function ViewBase:ctor()
    -- UI根节点
    self.pUIRoot = cc.Node:create()
    self.pUIRoot:setName("uiRoot")
    self:addChild(self.pUIRoot, 0xFFFF)

    self:setNodeEventEnabled(true)
    self:setName(tostring(self.__cname))

    self.goCtxs = {}

    gLocalization:loadLocalizedResources()
end

function ViewBase:loadUI(path)
    self.ui = loadStudioFile(path, self)
    self.ui.root:setContentSize(gAdaptive.size)
    ccui.Helper:doLayout(self.ui.root)
    self:addChild(self.ui.root)

    -- 适配背景图片
    local bg = self.ui.root:getChildByName("bg")
    if bg then
        bg:setScale(gAdaptive.scaleMax)
    end
end

-- @brief 监听网络消息
-- @param msgID 消息ID
-- @param call 回调
-- @param priority 监听优先级
function ViewBase:onNetMsg(msgID, call, priority)
    gNetEventEmitter:on(msgID, call, self, priority)
end

-- @brief 监听系统消息
-- @param msgID 消息ID
-- @param call 回调
-- @param priority 监听优先级
function ViewBase:onSysMsg(msgID, call, priority)
    gSysEventEmitter:on(msgID, call, self, priority)
end

function ViewBase:onEnter()
    self.bCurIsHide = false
    self:onSysMsg(SysEvent.UPDATE_VIEW_VISIBLE, function(show)
        local hide = not show
        if self.bCurIsHide == hide then
            return
        end
        self.bCurIsHide = hide
        if hide then
            self:onHideNodes()
        else
            self:onShowNodes()
        end
    end)
end

function ViewBase:onExit()
    gNetEventEmitter:offByTag(self)
    gSysEventEmitter:offByTag(self)
    for _, v in pairs(self.goCtxs) do
        kill(v)
    end
    self.goCtxs = {}
end

-- @brief 优化操作,隐藏场景子节点
function ViewBase:onHideNodes()
    if self.ui == nil then return end
    self.ui.root:setVisible(false)
    self:logD("hide me------------>>>")
end

-- @brief 优化操作,显示场景子节点
function ViewBase:onShowNodes()
    if self.ui == nil then return end
    self.ui.root:setVisible(true)
    self:logD("show me------------>>>")
end

function ViewBase:spawn(func)
    table.insert(self.goCtxs, go(func))
end

return ViewBase
