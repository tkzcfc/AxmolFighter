local utils = require("boot.src.utils")

local MsgBoxLayer = class("MsgBoxLayer", function()
	return cc.CSLoader:createNode("boot/resource/MsgBoxLayer.csb")
end)

function MsgBoxLayer:ctor()
    local panel_bg      = self:getChildByName("panel_bg")
    panel_bg:setPosition(utils.layout.center)
    panel_bg:setContentSize(utils.layout.size)

    local content_box   = self:getChildByName("content_box")
    content_box:setPosition(utils.layout.center)
    content_box:setScale(0.1)
    content_box:runAction(cc.ScaleTo:create(0.2, utils.layout.scaleMin))

    self.content_box = content_box

    self.ui_text        = content_box:getChildByName("content_txt")
    self.ui_btn_confirm = content_box:getChildByName("btn_confirm")
    self.ui_btn_cancel  = content_box:getChildByName("btn_cancel")

    -- 多语言文本
    self.ui_btn_confirm:getChildByName("_lang_txt"):setString(utils:langText("确定"))
    self.ui_btn_cancel:getChildByName("_lang_txt"):setString(utils:langText("取消"))

    local text_title = content_box:getChildByName("text_title")
    if text_title then
        text_title:setString(utils:langText("提示"))
    end

    self.ui_btn_confirm:setVisible(false)
    self.ui_btn_cancel:setVisible(false)

    self.ui_btn_confirm:addClickEventListener(function(sender)
        self:onClickConfirm(sender)
    end)
    self.ui_btn_cancel:addClickEventListener(function(sender)
        self:onClickCancel(sender)
    end)
end

function MsgBoxLayer:onClickConfirm()
    if self.bClosed then return end
    self.on_cancel = nil
    self:onClickClose()
end

function MsgBoxLayer:onClickCancel()
    if self.bClosed then return end
    self.on_confirm = nil
    self:onClickClose()
end

function MsgBoxLayer:onClickClose()
    if self.bClosed then return end
    self.bClosed = true
    self.content_box:runAction(cc.Sequence:create(
        cc.ScaleTo:create(0.15,0.1),
        cc.CallFunc:create(function()

            if self.on_cancel then
                self.on_cancel()
            end
            if self.on_confirm then
                self.on_confirm()
            end
            self:removeFromParent()
        end)
    ))
end

-----------------------------------------------------------------

function MsgBoxLayer:showMsgBox(text, on_confirm, on_cancel)
    self.ui_text:setString(tostring(text))

    if on_confirm and on_cancel then
        self.ui_btn_confirm:setVisible(true)
        self.ui_btn_cancel:setVisible(true)
    else
        self.ui_btn_confirm:setVisible(true)
        self.ui_btn_cancel:setVisible(false)
        self.ui_btn_confirm:setPositionX(self.ui_btn_confirm:getParent():getContentSize().width * 0.5)
    end

    self.on_confirm = on_confirm
    self.on_cancel = on_cancel
end

return MsgBoxLayer
