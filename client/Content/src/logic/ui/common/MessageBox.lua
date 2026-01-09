-- 通用弹窗

local MessageBox = class("MessageBox", UIDialog)

function MessageBox:ctor(title, content, onConfirmCallback, onCancelCallback, textHorizontalAlignment)
    MessageBox.super.ctor(self)
    self:loadUI("ui/common/MessageBox")

    self.ui.text_title:setString(title)
    
    self.ui.txt_content:setString("")
    self.ui.txt_content:setTextHorizontalAlignment(textHorizontalAlignment or cc.TEXT_ALIGNMENT_CENTER)
    self:setContent(content)

    self.onConfirmCallback = onConfirmCallback
    self.onCancelCallback = onCancelCallback


    -- 只显示一个按钮
    if onCancelCallback == nil then
        self.ui.btn_confirm:setPositionX(0)
        self.ui.btn_cancel:setVisible(false)
    else
        -- 点击空白处不自动关闭弹窗
        self:setAutoDismiss(false)
    end
end

-- @brief 设置内容文本
function MessageBox:setContent(content)
    self.ui.scroll_content_systemfont:setVisible(false)
    self.ui.scroll_content:setVisible(true)
    self.ui.txt_content:setFontName(gLocalization:getCurFontName())
    Utils:setScrollText(self.ui.scroll_content, self.ui.txt_content, content, true)
    return self
end

-- @brief 设置系统文本内容
function MessageBox:setContentWithSystemFont(content)
    self.ui.scroll_content_systemfont:setVisible(true)
    self.ui.scroll_content:setVisible(false)
    Utils:setScrollText(self.ui.scroll_content_systemfont, self.ui.txt_content_systemfont, content, true)
    return self
end

-- @brief UI界面关闭后的回调
function MessageBox:iAfterClosed()
    local callback = self.onConfirmCallback
    if callback then
        self.onConfirmCallback = nil
        xpcall(callback, __G__TRACKBACK__)
    end
    
    callback = self.onCancelCallback
    if callback then
        self.onCancelCallback = nil
        xpcall(callback, __G__TRACKBACK__)
    end
end

function MessageBox:onClickConfirm()
    self.onCancelCallback = nil
    self:dismiss()
end

function MessageBox:onClickCancel()
    self.onConfirmCallback = nil
    self:dismiss()
end

return MessageBox