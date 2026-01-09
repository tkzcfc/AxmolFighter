Utils = {}

Utils.lastTimeOnShowLoading = 0

function Utils:showMsgBox(content, onConfirmCallback, onCancelCallback, title, textHorizontalAlignment)
    title = title or ""
    return require("logic.ui.common.MessageBox").new(title, content, onConfirmCallback, onCancelCallback, textHorizontalAlignment):show()
end

function Utils:showMsgBoxWithSystemFont(content, onConfirmCallback, onCancelCallback, title, textHorizontalAlignment)
    title = title or ""
    return require("logic.ui.common.MessageBox").new(title, "", onConfirmCallback, onCancelCallback, textHorizontalAlignment):setContentWithSystemFont(content):show()
end

-- @brief 是否正在显示提示文本
function Utils:isShowToastText()
    return gMainScene:getToastRoot():isShowToastText()
end

-- @brief 显示提示文本
function Utils:showToastText(text)
    gMainScene:getToastRoot():showText(tostring(text))
end

-- @brief
function Utils:showLoading(visible, delayTime)
    gMainScene:getLoadingLayer():showMask(visible, delayTime or 1)
    if visible then
        self.lastTimeOnShowLoading = os.time()
    end
end

-- @brief
function Utils:isShowLoading()
    return gMainScene:getLoadingLayer():isShowMask()
end

function Utils:showConnectLoading(visible, delayTime)
    if visible then
        self:showLoading(false)
    end
    print("showConnectLoading", visible and "显示" or "隐藏")
    gMainScene:getConnectingLayer():showMask(visible, delayTime or 1)
end

function Utils:showLoginLoading(visible, delayTime)
    print("showLoginLoading", visible and "显示" or "隐藏")
    gMainScene:getConnectingLayer():showMask(visible, delayTime or 1)
end

function Utils:showPayLoading(visible, delayTime)
    print("showPayLoading", visible and "显示" or "隐藏")
    gMainScene:getPayLayer():showMask(visible, delayTime or 0)
end

-- @brief 获取游戏映射后的id
function Utils:getMapGameId(id)
    if map_game.Param[id] then
        return map_game.Param[id]
    end
    return id
end

function Utils:setStringAndAutoScale(ui, text, maxWidth)
    ui:setString(text)

    local width = ui:getContentSize().width
    if width > maxWidth then
        ui:setScale(maxWidth / width)
    else
        ui:setScale(1)
    end
end

-- Move a node to a new parent, keeping the same screen position
-- node       : the node to move
-- newParent  : the new parent node
-- zorder     : optional z-order
-- tag        : optional tag
function Utils:resetNodeParent(node, newParent, zorder, tag)
    if not node or not newParent then
        print("resetNodeParent: node and newParent are required")
        return
    end

    if node:getParent() == newParent then
        return
    end

    local worldPos = node:getParent():convertToWorldSpace(cc.p(node:getPosition()))
    node:retain()
    node:removeFromParent(false)

    local newPos = newParent:convertToNodeSpace(worldPos)
    if zorder and tag then
        newParent:addChild(node, zorder, tag)
    elseif zorder then
        newParent:addChild(node, zorder)
    else
        newParent:addChild(node)
    end
    node:setPosition(newPos)
    node:release()
end

function Utils:replaceNode(node, new_node)
    new_node:setAnchorPoint(cc.p(node:getAnchorPoint()))
    new_node:setContentSize(node:getContentSize())
    new_node:setScale(node:getScale())
    new_node:setPosition(cc.p(node:getPosition()))
    new_node:setLocalZOrder(node:getLocalZOrder())
    new_node:setName(node:getName())
    node:getParent():addChild(new_node)
    node:removeFromParent()
    return new_node
end

function Utils:replaceEdit(node,key)
    local edit = ccui.EditBox:create(node:getContentSize(), "")
    -- 兼容以前的NewEditBox用法
    edit.onEvent = function(this, callback)
        this:registerScriptEditBoxHandler(function(name, sender)
            callback(name, sender)
        end)
    end
    edit.setString = function(this, str)
        this:setText(str)
    end
    edit.getString = function(this)
        return this:getText()
    end

    --翻译的键值 避免创建的editbox 切换翻译找不到key值
    if key then
        editBox.__no_transition = true
        editBox.__origin_text = key
        edit:setPlaceHolder(TR(key))
    end
    return Utils:replaceNode(node, edit)
end

-- @brief 将ccui.TextField 转换为 ccui.EditBox
function Utils:convertToEditBox(textField, fontName)
    local editBox = ccui.EditBox:create(textField:getContentSize(), "")
    if textField:isMaxLengthEnabled() then
        editBox:setMaxLength(textField:getMaxLength())
    end
    editBox:setTextHorizontalAlignment(textField:getTextHorizontalAlignment())
    -- editBox:setFontColor(textField:getTextColor())
    -- editBox:setPlaceholderFontColor(textField:getPlaceHolderColor())
    editBox:setPlaceHolder(textField:getPlaceHolder())
    editBox:setPlaceholderFontName(textField:getFontName())
    editBox:setPlaceholderFontSize(textField:getFontSize())
    editBox:setFontSize(textField:getFontSize())

    if fontName then
        editBox:setFontName(fontName)
    end

    if textField:isPasswordEnabled() then
        editBox:setInputFlag(0)
    end

    editBox.getString = function(this) return this:getText() end
    editBox.setString = function(this, text) return this:setText(text) end

    editBox.__no_transition = textField.__no_transition
    editBox.__origin_text = textField.__origin_text

    self:replaceNode(textField, editBox)

    -- 占位文本设置为裁减
    Utils:setEditBoxPlaceHolderRenderOverflowToClamp(editBox)

    return editBox
end

-- @brief 占位文本设置为裁减
function Utils:setEditBoxPlaceHolderRenderOverflowToClamp(editBox)
    local placeHolderRender = editBox:getChildren()[2]
    if placeHolderRender and placeHolderRender.setOverflow then
        local size = editBox:getContentSize()
        -- cc.LabelOverflow.CLAMP
        -- cc.LabelOverflow.SHRINK
        placeHolderRender:setOverflow(cc.LabelOverflow.SHRINK)
        placeHolderRender:setDimensions(size.width, size.height)
    end
end

-- @brief 递归设置 CascadeOpacityEnabled
function Utils:recursionSetCascadeOpacityEnabled(node, value)
    node:setCascadeOpacityEnabled(value)
    for k, v in pairs(node:getChildren()) do
        self:recursionSetCascadeOpacityEnabled(v, value)
    end
end

-- @brief 图片自适应大小
function Utils:imageAdaptive(image,max_size)
	local real_size = image:getVirtualRendererSize()
	local size = real_size

    if max_size.width == -1 then --适配高
        if max_size.height and real_size.height > max_size.height then
            size.height =  max_size.height
            size.width  = real_size.width * max_size.height / real_size.height
        end
    elseif max_size.height == -1 then  --适配宽
        if max_size.width and real_size.width > max_size.width then
            size.width  =  max_size.width
            size.height = real_size.height * max_size.width / real_size.width
        end
    else --宽高都适配
        if real_size.width > max_size.width or real_size.height > max_size.height  then
            local scale_w = max_size.width / real_size.width
            local scale_h = max_size.height / real_size.height
            local scale_m = math.min(scale_w,scale_h)
            size.width  = real_size.width * scale_m
            size.height = real_size.height * scale_m
        end
    end
	image:setContentSize(size)
    return size
end

function Utils:getCenterPosBySize(size)
    return cc.p(size.width * 0.5,size.height * 0.5)
end

-- @brief 设置滚动文本
-- @param uiText 必须是 scrollView的子节点
-- @param isToCenter 文本内容较少时是否居中
function Utils:setScrollText(scrollView, uiText, content, isToCenter)
    local overload = false

    local size = scrollView:getContentSize()
    uiText:setTextAreaSize(cc.size(size.width, 0))
    uiText:setString(content)

    local text_size = uiText:getContentSize()
    local diff_val = text_size.height - size.height
    if diff_val > 0 then
        size.height = text_size.height + 4
        overload = true
    end

    scrollView:setScrollBarEnabled(false)
    scrollView:setClippingEnabled(overload)
    scrollView:setTouchEnabled(overload)
    scrollView:setInnerContainerSize(size)

    if not overload and isToCenter then
        scrollView:setInnerContainerPosition(cc.p(0, 0))
        uiText:setAnchorPoint(cc.p(0.5, 0.5))
        uiText:setPosition(size.width * 0.5, size.height * 0.5)
    else
        scrollView:jumpToPercentVertical(0)
        uiText:setAnchorPoint(cc.p(0, 1))
        uiText:setPosition(0, size.height)
    end

    return diff_val
end

-- @brief 设置滚动的虚拟富文本
-- @param uiText 必须是 scrollView的子节点
-- @param isToCenter 文本内容较少时是否居中
function Utils:setScrollVirtualRichText(scrollView, uiText, content, isToCenter)
    local overload = false

    local size = scrollView:getContentSize()
    uiText:setTextAreaSize(cc.size(size.width, 0))

    Utils:setVirtualRichText(uiText, content)

    local text_size = uiText:getContentSize()
    local diff_val = text_size.height - size.height
    if diff_val > 0 then
        size.height = text_size.height + 4
        overload = true
    end

    scrollView:setScrollBarEnabled(false)
    scrollView:setClippingEnabled(overload)
    scrollView:setTouchEnabled(overload)
    scrollView:setInnerContainerSize(size)

    if not overload and isToCenter then
        scrollView:setInnerContainerPosition(cc.p(0, 0))
        uiText:setAnchorPoint(cc.p(0.5, 0.5))
        uiText:setPosition(size.width * 0.5, size.height * 0.5)
    else
        scrollView:jumpToPercentVertical(0)
        uiText:setAnchorPoint(cc.p(0, 1))
        uiText:setPosition(0, size.height)
    end

    return diff_val
end

-- @brief 设置虚拟富文本文字
function Utils:setVirtualRichText(label, text)
    local parsedtable = require("framework.ui.rich_label.labelparser").parse(text)
    if not parsedtable then
        label:setString("")
        return
    end

    text = ""
    local elements = {}
    for k, v in pairs(parsedtable) do
        if v.labelname == "div" and type(v.content) == "string" and v.content ~= "" then
            text = text .. v.content

            local color = cc.WHITE
            if v.fontcolor then
               color = StringUtils.hexToRgb(v.fontcolor)
            end
            for i = 1, utf8.len(v.content) do
                table.insert(elements, color)
            end
        elseif v.labelname == "br" then
            text = text .. "\n"
            table.insert(elements, cc.WHITE)
        end
    end

    label:setString(text)

    for i, color in pairs(elements) do
        local letter = label:getLetter(i - 1)
        if letter then
            letter:setColor(color)
        end
    end
end

function Utils:setRichText(scrollView, text, isToCenter)
    scrollView:removeAllChildren()

    local container_size = scrollView:getContentSize()
    
    local label = require("framework.ui.rich_label.RichLabel").new({
        maxWidth = container_size.width,
        lineSpace = 0,
        charSpace = 0,
    })

    label:setHorizontalAlignment(cc.TEXT_ALIGNMENT_CENTER)
    label:setString(text)
    
    local text_size = label:getContentSize()

    local diff_val = text_size.height - container_size.height
    local overload = diff_val > 0
    if diff_val > 0 then
        container_size.height = text_size.height + 4
    end

    scrollView:setSwallowTouches(false)
    scrollView:setScrollBarEnabled(false)
    scrollView:setClippingEnabled(overload)
    scrollView:setTouchEnabled(overload)
    scrollView:setInnerContainerSize(container_size)

    if not overload and isToCenter then
        scrollView:setInnerContainerPosition(cc.p(0, 0))
        label:setPosition(0, container_size.height + diff_val / 2)
    else
        scrollView:jumpToPercentVertical(0)
        label:setPosition(0, container_size.height)
    end
    
    scrollView:addChild(label)
end

-- @brief 设置单行滚动文本
-- @param panel 裁剪节点
-- @param text 文本显示节点
-- @param content 文本内容
-- @param scrollSpace 滚动间距
-- @param showCenter 能完整显示下时,是否将文本居中
-- @param speed 滚动速度, 默认50像素/秒
function Utils:setSingleLineScrollText(panel, text, content, scrollSpace, showCenter, speed)
    scrollSpace = scrollSpace or 50
    speed = speed or 50

    if text:getString() == content then
        -- 内容没有变化，不需要重新设置
        return
    end

    local ACTION_TAG = 0xfcfc

    text:stopAllActionsByTag(ACTION_TAG)
    text:setString(content)
    text:setPositionX(0)

    local panel_size = panel:getContentSize()
    local text_size = text:getContentSize()

    -- 文本内容是否超出裁剪范围
    local overload = text_size.width > panel_size.width
    panel:setClippingEnabled(overload)

    local copy_text = panel.__copy_text

    if overload then
        -- 复制一份一样的文本用于滚动显示
        if copy_text == nil then
            copy_text = text:clone()
            panel:addChild(copy_text)
            panel.__copy_text = copy_text
        else
            copy_text:setVisible(true)
            copy_text:stopAllActionsByTag(ACTION_TAG)
        end

        copy_text:setString(content)
        copy_text:setPositionX(text:getPositionX() + text_size.width + scrollSpace)

        -- 文字滚动
        local function doScroll(node, otherText)
            -- 移动距离
            local distance = text_size.width + node:getPositionX()
            local time = distance / speed

            local sequence = cc.Sequence:create(
                cc.MoveBy:create(time, cc.p(-distance, 0)),
                cc.CallFunc:create(function()
                    node:setPositionX(otherText:getPositionX() + text_size.width + scrollSpace)
                    doScroll(node, otherText)
                end)
            )
            sequence:setTag(ACTION_TAG)
            node:runAction(sequence)
        end

        text:runAction(cc.Sequence:create(
            cc.DelayTime:create(1),
            cc.CallFunc:create(function()
                doScroll(copy_text, text)
                doScroll(text, copy_text)
            end)
        )):setTag(ACTION_TAG)
    else
        if copy_text then
            copy_text:setVisible(false)
            copy_text:stopAllActionsByTag(ACTION_TAG)
        end

        -- 将文本居中展示
        if showCenter then
            text:setPositionX((panel_size.width - text_size.width) * 0.5)
        end
    end
end

-- @brief 把num均分count份
function Utils:getAverageNums(totalNum, count)
    local ret = {}

    local average = math.floor(totalNum / count)

    for i = 1, count - 1 do
        table.insert(ret, average)
        totalNum = totalNum - average
    end
    table.insert(ret, totalNum)

    return ret
end

-- @brief 把num均分count份,每个上下浮动20%
-- @param totalNum 总数
-- @param count 分成多少份
-- @return 返回一个数组，长度为count
function Utils:getAverageFloatNums(totalNum, count)
    local ret = {}

    local average = math.floor(totalNum / count)
    local float = math.floor(average * 0.2)

    for i = 1, count - 1 do
        local num = average
        if float ~= 0 then
            num = num + math.random(float * 2) - float
        end
        num = math.floor(num)
        table.insert(ret, num)
        totalNum = totalNum - num
    end
    table.insert(ret, totalNum)

    return ret
end

-- @brief 绑定骨骼跟随目标
-- @param skeletonAnimation 骨骼对象
-- @param boneName 骨骼名称
-- @param followNode 跟随的节点
-- @param callback 回调函数
-- @return bone 骨骼对象(结构类型 {x = 0, y = 0, scaleX = 1, scaleY = 1, rotation = 0, worldX = 0, worldY = 0})
function Utils:spineFollowBoneWithCallback(skeletonAnimation, boneName, followNode, callback)
    local bone = skeletonAnimation:findBone(boneName)
    if bone.x == nil then
        print("骨骼不存在:", boneName)
        return
    end

    followNode:onUpdate(function()
        callback(skeletonAnimation:findBone(boneName))
    end)

    callback(bone)

    return bone
end

-- @brief 创建带有语言适配的Spine动画
function Utils:createSpineWithLang(spineName, animationName, parent)
    local localName = "lang/spine/" .. gLocalization:getLang() .. "/" .. spineName

    if not cc.FileUtils:getInstance():isFileExist(localName .. ".json") then
        localName = "lang/spine/cn/" .. spineName
    end
    
	local node = sp.SkeletonAnimation:create(localName .. ".json", localName .. ".atlas")
    if not node then
        print("创建Spine失败:", localName)
        return nil
    end
    
	node:setUpdateOnlyIfVisible(true)
    node:setCascadeOpacityEnabled(true)
    
    if animationName then
	    node:setAnimation(0, animationName, true)
    end

    if parent then
        local size = parent:getContentSize()
        node:addTo(parent)
        node:setPosition(size.width * 0.5, size.height * 0.5)
    end
    return node
end
