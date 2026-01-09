-- 本地化

local StringUtils = require("framework.utils.StringUtils")
local Localization = class("Localization")

propertyReadOnly(Localization, "sCurFontName", "")
propertyReadOnly(Localization, "sLang", "unknown")
propertyReadOnly(Localization, "tLangTextData", {})

require("framework.utils.Logger").attachTo(Localization)

local curResourcePrefix = ""
local spriteFrameCache = cc.SpriteFrameCache:getInstance()

function Localization:ctor()
    self.sLang = "unknown"
    self.tLangTextData = {}
    self.sCurFontName = string.format("lang/font/%s/%s_neon_arcade.ttf", self.sLang, self.sLang)
    curResourcePrefix = string.format("lang/plist/%s/", self.sLang)
end

-- @brief 设置当前语言
function Localization:setLang(lang, tLangTextData)
    self:logI("Localization lang", lang, self.sLang ~= lang)
    self.tLangTextData = tLangTextData or {}
    if self.sLang ~= lang then
        self.sLang = lang
        self.sCurFontName = string.format("lang/font/%s/%s_neon_arcade.ttf", self.sLang, self.sLang)
        curResourcePrefix = string.format("lang/plist/%s/", self.sLang)
        gSysEventEmitter:emit(SysEvent.UPDATE_LANG)
    
        self:loadLocalizedResources()
        local scene = display.getRunningScene()
        if scene then
            self:translationNode(scene, true)
        end
    else
        -- 语言没有变化，只翻译文本
        local scene = display.getRunningScene()
        if scene then
            self:translationText(scene)
        end
    end    
end

function Localization:loadLocalizedResources()
    local plistFile = string.format("lang/%s.plist", self:getLang())
    local pngFile = string.format("lang/%s.png", self:getLang())
    if cc.FileUtils:getInstance():isFileExist(plistFile) and cc.FileUtils:getInstance():isFileExist(pngFile) then
        if not spriteFrameCache:isSpriteFramesWithFileLoaded(plistFile) then
            spriteFrameCache:addSpriteFrames(plistFile)
        end
        return true
    end
end

function Localization:getText(key)
    local value = self.tLangTextData[key]
    if type(value) == "string" then
        return value
    end
    return key
end

-- @brief 翻译节点文本
function Localization:translationText(node)
    local objType = tolua.type(node)

    self:resetFontName(node, objType)

    if not node.__no_transition then
        local func = self.transitionTextFuncs[objType]
        if func then
            func(node)
        end
    end
    
    for k, v in pairs(node:getChildren()) do
        self:translationText(v)
    end
end

-- @brief 翻译节点文本和图片
function Localization:translationNode(node, recursion)
    local objType = tolua.type(node)

    self:resetFontName(node, objType)

    if not node.__no_transition then
        local func = self.transitionFuncs[objType]
        if func then
            func(node)
        else
            node.__no_transition = true
        end
    end

    if not recursion then return end

    for k, v in pairs(node:getChildren()) do
        self:translationNode(v, true)
    end
end

function Localization:resetFontName(node, objType)
    if objType == "axui.Text" or objType == "axui.TextField" then
        local fontName = node:getFontName()
        if string.startswith(fontName, "lang/font/") then
            if node:getName():sub(1, 5) == "_lang" then
                node:setString("")
            end
            node:setFontName(self.sCurFontName)
        end
    elseif objType == "axui.Button" then
        local fontName = node:getTitleFontName()
        if string.startswith(fontName, "lang/font/") then
            if node:getName():sub(1, 5) == "_lang" then
                node:setTitleText("")
            end
            node:setTitleFontName(self.sCurFontName)
        end
    elseif objType == "axui.EditBox" then
        local fontName = node:getFontName()
        if string.startswith(fontName, "lang/font/") then
            node:setFontName(self.sCurFontName)
        end
        
        fontName = node:getPlaceholderFontName()
        if string.startswith(fontName, "lang/font/") then
            node:setPlaceholderFontName(self.sCurFontName)
        end
    end
end

local function changeResourceData(data)
    -- plist文件
    if data.type == 1 then
        local file, count = string.gsub(data.file, "lang/plist/.-/", curResourcePrefix)

        if file and count == 1 then
            -- 是当前语言图片
            if data.file == file then return end

            data.file = file
            return data
        end
    end
end

local function setHtmlText(label, text)
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

local function transition_Button(node)
    local normalData = changeResourceData(node:getNormalFile())
    local pressedData = changeResourceData(node:getPressedFile())
    local disabledData = changeResourceData(node:getDisabledFile())

    if normalData then
        node:loadTextureNormal(normalData.file, normalData.type)
    end
    if pressedData then
        node:loadTexturePressed(pressedData.file, pressedData.type)
    end
    if disabledData then
        node:loadTextureDisabled(disabledData.file, disabledData.type)
    end
    
    -- 以_lang开头的UI需要翻译文本
    if node:getName():sub(1, 5) == "_lang" then
        -- 设置翻译键值
        if node.__origin_text == nil then
            local keyValuePairs = StringUtils.parseKeyValuePairsFromNode(node)
            local lang = keyValuePairs.GetString("lang")
            node.__origin_text = lang
        end

        if node.__origin_text == nil then return end
        node:setTitleText(gLocalization:getText(node.__origin_text))
    end
end

local function transition_ImageView(node)
    local renderData = changeResourceData(node:getRenderFile())
    if renderData then
        -- SpriteFrame不存在
        if renderData.type == 1 and spriteFrameCache:getSpriteFrame(renderData.file) == nil then
            return
        end
        node:loadTexture(renderData.file, renderData.type)
        node:ignoreContentAdaptWithSize(true)
        
        if node.__read_custom_data == nil then
            node.__read_custom_data = true
            node.__raw_scalex = node:getScaleX()
            node.__raw_scaley = node:getScaleY()
            
            local keyValuePairs = StringUtils.parseKeyValuePairsFromNode(node)
            node.__max_width = keyValuePairs.GetNumber("maxWidth")
            node.__max_height = keyValuePairs.GetNumber("maxHeight")
        end

        if node.__max_width or node.__max_height then
            local size = node:getContentSize()
            local scalex = node.__raw_scalex
            local scaley = node.__raw_scaley

            if node.__max_width and size.width > node.__max_width then
                local sv = node.__max_width / size.width
                scalex = scalex * sv
                scaley = scaley * sv
            end
            if node.__max_height and size.height > node.__max_height then
                local sv = node.__max_height / size.height
                scalex = scalex * sv
                scaley = scaley * sv
            end
            node:setScaleX(scalex)
            node:setScaleY(scaley)
        else
            node:setScaleX(node.__raw_scalex or 1)
            node:setScaleY(node.__raw_scaley or 1)
        end
    end
end

local function transition_Text(node)
    -- C++底层已修改实现此功能
    -- -- 设置超框自动收缩
    -- if not node:isIgnoreContentAdaptWithSize() then
    --     local label = node:getVirtualRenderer()
    --     if label:getOverflow() == 0 then
    --         label:setOverflow(cc.LabelOverflow.SHRINK)
    --     end
    --     node:setTextAreaSize(node:getContentSize())
    -- end

    -- 以_lang开头的UI需要翻译文本
    if node:getName():sub(1, 5) == "_lang" then
        -- 设置翻译键值
        if node.__origin_text == nil then
            local keyValuePairs = StringUtils.parseKeyValuePairsFromNode(node)
            local lang = keyValuePairs.GetString("lang")
            if lang then
                node.__origin_text = lang
            else
                node.__no_transition = true
                node:setString(node:getRawString())
            end
        end
        if node.__origin_text == nil then return end

        local text = gLocalization:getText(node.__origin_text)
        if string.match(text, "</") or string.match(text, "/>") then
            setHtmlText(node, text)
        else
            node:setString(text)
        end
    else
        node.__no_transition = true
    end
end

local function transition_TextField(node)
    -- TextField 默认可翻译
    if node.__origin_text == nil then
        local keyValuePairs = StringUtils.parseKeyValuePairsFromNode(node)
        local lang = keyValuePairs.GetString("lang")
        if lang then
            node.__origin_text = lang
        else
            node.__no_transition = true
            return
        end
    end

    if node.__origin_text == nil then return end
    node:setPlaceHolder(gLocalization:getText(node.__origin_text))
end

local function transition_ExidBox(node)
    -- ExidBox 默认可翻译
    if node.__origin_text == nil then
        local keyValuePairs = StringUtils.parseKeyValuePairsFromNode(node)
        local lang = keyValuePairs.GetString("lang")
        if lang then
            node.__origin_text = lang
        else
            node.__no_transition = true
            return
        end
    end

    if node.__origin_text == nil then return end
    node:setPlaceHolder(gLocalization:getText(node.__origin_text))
end

local function transition_Sprite(node)
    local spriteFrame = node:getSpriteFrame()
    if spriteFrame then
        local spriteFrameName, count = string.gsub(spriteFrameCache:getSpriteFrameName(spriteFrame), "lang/plist/.-/", curResourcePrefix)
        if spriteFrameName and count == 1 then
            if spriteFrameCache:getSpriteFrame(spriteFrameName) then
                node:setSpriteFrame(spriteFrameName)
            end
        else
            node.__no_transition = true
        end
    end
end

Localization.transitionFuncs = {
    ["axui.Button"]    = transition_Button,
    ["axui.ImageView"] = transition_ImageView,
    ["axui.Text"]      = transition_Text,
    ["axui.EditBox"]   = transition_ExidBox,
    ["axui.TextField"] = transition_TextField,
    ["ax.Sprite"]      = transition_Sprite,
}


Localization.transitionTextFuncs = {
    ["axui.Button"]    = transition_Button,
    ["axui.Text"]      = transition_Text,
    ["axui.EditBox"]   = transition_ExidBox,
    ["axui.TextField"] = transition_TextField,
}

return Localization