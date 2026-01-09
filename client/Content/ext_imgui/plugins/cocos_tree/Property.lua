local Helper = require("plugins.cocos_tree.Helper")

local function getterPosition(node)
    return cc.p(node:getPosition())
end

local function setterBackGroundStartColor(node, color)
    node:setBackGroundColor(color, node:getBackGroundEndColor())
end

local function setterBackGroundEndColor(node, color)
    node:setBackGroundColor(node:getBackGroundStartColor(), color)
end

local function setterDimensions(node, value)
    node:setDimensions(value.x, value.y)
end

local function setterContentSize(node, value)
    node:setContentSize(value.x, value.y)    
end

local collapsingHeaderDefaultFlags = imgui.ImGuiTreeNodeFlags.DefaultOpen
local function collapsingHeader(node, typeName)
    return tolua.iskindof(node, typeName) and imgui.collapsingHeader(typeName, collapsingHeaderDefaultFlags)
end

local OptionOverflow = {
    {"NONE", 0},
    {"CLAMP", 1},
    {"SHRINK", 2},
    {"RESIZE_HEIGHT", 3},
}

local OptionTextHAlignment = {
    {"LEFT", 0},
    {"CENTER", 1},
    {"RIGHT", 2},
}

local OptionTextVAlignment = {
    {"TOP", 0},
    {"CENTER", 1},
    {"BOTTOM", 2},    
}

local OptionLayoutBackGroundColorType = {
    {"NONE", 0},
    {"SOLID", 1},
    {"GRADIENT", 2},    
}

local OptionLayoutClippingType = {
    {"STENCIL", 0},
    {"SCISSOR", 1},
}

local OptionLayoutType = {
    {"ABSOLUTE", 0},
    {"VERTICAL", 1},
    {"HORIZONTAL", 2},
    {"RELATIVE", 3},
    {"CENTER_VERTICAL", 4},
    {"CENTER_HORIZONTAL", 5},
}

local OptionLoadingBarDirection = {
    {"LEFT", 0},
    {"RIGHT", 1},
}

local OptionScrollViewDirection = {
    {"NONE", 0},
    {"VERTICAL", 1},
    {"HORIZONTAL", 2},
    {"BOTH", 3},
}

local OptionListViewGravity = {
    {"LEFT", 0},
    {"RIGHT", 1},
    {"CENTER_HORIZONTAL", 2},
    {"TOP", 3},
    {"BOTTOM", 4},
    {"CENTER_VERTICAL", 5},
}
local OptionListViewMagneticType = {
    {"NONE", 0},
    {"CENTER", 1},
    {"BOTH_END", 2},
    {"LEFT", 3},
    {"RIGHT", 4},
    {"TOP", 5},
    {"BOTTOM", 6},
}

local OptionPageViewTouchDirection = {
    {"LEFT", 0},
    {"RIGHT", 1},
    {"UP", 2},
    {"DOWN", 3},
}


local LabelType = {
    TTF = 0,
    BMFONT = 1,
    CHARMAP = 2,
    STRING_TEXTURE = 3
}

local M = {
    {
        "ax.Object",
        function(node)
            Helper.renderPropertyInt(node, "ReferenceCount", nil, false)
        end,
    },
    {
        "ax.Node",
        function(node)
            Helper.renderPropertyBool(node, "Visible", "isVisible")
            Helper.renderPropertyStr(node, "Name")
            Helper.renderPropertyVec2(node, "Position", getterPosition)
            Helper.renderPropertyVec2(node, "AnchorPoint")
            Helper.renderPropertyVec2(node, "AnchorPointInPoints", nil, false)
            Helper.renderPropertyBool(node, "IgnoreAnchorPointForPosition", "isIgnoreAnchorPointForPosition")
            Helper.renderPropertyVec2(node, "ContentSize", nil, setterContentSize)
            Helper.renderPropertyFloat(node, "ScaleX")
            Helper.renderPropertyFloat(node, "ScaleY")
            Helper.renderPropertyFloat(node, "SkewX")
            Helper.renderPropertyFloat(node, "SkewY")
            Helper.renderPropertyFloat(node, "Rotation")
            Helper.renderPropertyVec3(node, "Rotation3D")
            Helper.renderPropertySliderInt(node, "Opacity", 0, 255)
            Helper.renderPropertyInt(node, "DisplayedOpacity", nil, false)
            Helper.renderPropertyBool(node, "CascadeOpacityEnabled", "isCascadeOpacityEnabled")
            Helper.renderPropertyColor3B(node, "Color")
            Helper.renderPropertyBool(node, "CascadeColorEnabled", "isCascadeColorEnabled")
            Helper.renderPropertyBool(node, "OpacityModifyRGB", "isOpacityModifyRGB")
            Helper.renderPropertyInt(node, "LocalZOrder")
            Helper.renderPropertyInt(node, "GlobalZOrder")
            Helper.renderPropertyInt(node, "Tag")
        end,
    },
    {
        "ax.Camera",
        function(node)
            Helper.renderPropertyFloat(node, "Depth")
            Helper.renderPropertyFloat(node, "FOV")
            Helper.renderPropertyFloat(node, "FarPlane")
            Helper.renderPropertyFloat(node, "NearPlane")
            Helper.renderPropertyFloat(node, "Zoom")
        end,
    },
    {
        "ax.Sprite",
        function(node)
            Helper.renderSpriteTooltip("texture (?)", node)
            Helper.renderPropertyBool(node, "FlippedX", "isFlippedX")
            Helper.renderPropertyBool(node, "FlippedY", "isFlippedY")
            Helper.renderPropertyBool(node, "StretchEnabled", "isStretchEnabled")
            Helper.renderPropertyInt(node, "ResourceType", nil, false)
            Helper.renderPropertyStr(node, "ResourceName", nil, false)
        end,
    },
    {
        "ax.Label",
        function(node)
            local labelType = node:getLabelType()
            Helper.renderPropertyStr(node, "SystemFontName")
            Helper.renderPropertyFloat(node, "SystemFontSize")
            Helper.renderPropertyStr(node, "String")
            Helper.renderPropertyFloat(node, "MaxLineWidth")
            Helper.renderPropertyFloat(node, "BMFontSize")
            Helper.renderPropertyBool(node, "WrapEnabled", "isWrapEnabled", "enableWrap")
            Helper.renderPropertyVec2(node, "Dimensions", nil, setterDimensions)
            Helper.renderPropertyFloat(node, "LineSpacing")

            if labelType == LabelType.TTF or labelType == LabelType.STRING_TEXTURE then
                Helper.renderPropertyColor4B(node, "TextColor")
            end

            if labelType ~= LabelType.STRING_TEXTURE then
                Helper.renderPropertyFloat(node, "LineHeight")
                Helper.renderPropertyFloat(node, "AdditionalKerning")
            end

            Helper.renderPropertyOption(node, "Overflow", OptionOverflow)
            Helper.renderPropertyOption(node, "HorizontalAlignment", OptionTextHAlignment)
            Helper.renderPropertyOption(node, "VerticalAlignment", OptionTextVAlignment)            
        end,
    },
    {
        "axui.Widget",
        function(node)
            Helper.renderPropertyBool(node, "Enabled", "isEnabled")
            Helper.renderPropertyBool(node, "Bright", "isBright")
            Helper.renderPropertyBool(node, "TouchEnabled", "isTouchEnabled")
            Helper.renderPropertyBool(node, "Highlighted", "isHighlighted")
            Helper.renderPropertyFloat(node, "LeftBoundary", nil, false)
            Helper.renderPropertyFloat(node, "BottomBoundary", nil, false)
            Helper.renderPropertyFloat(node, "RightBoundary", nil, false)
            Helper.renderPropertyFloat(node, "TopBoundary", nil, false)
            Helper.renderPropertyVec2(node, "PositionPercent")
            Helper.renderPropertyBool(node, "FlippedX", "isFlippedX")
            Helper.renderPropertyBool(node, "FlippedY", "isFlippedY")
            Helper.renderPropertyBool(node, "IgnoreContentAdaptWithSize", "isIgnoreContentAdaptWithSize", "ignoreContentAdaptWithSize")
            Helper.renderPropertyBool(node, "PropagateTouchEvents", "isPropagateTouchEvents")
            Helper.renderPropertyBool(node, "SwallowTouches", "isSwallowTouches")
            Helper.renderPropertyBool(node, "Focused", "isFocused")
            Helper.renderPropertyBool(node, "FocusEnabled", "isFocusEnabled")
            Helper.renderPropertyBool(node, "UnifySizeEnabled", "isUnifySizeEnabled")
            Helper.renderPropertyBool(node, "LayoutComponentEnabled", "isLayoutComponentEnabled")
            -- Helper.renderPropertyStr(node, "CallbackName")
            -- Helper.renderPropertyStr(node, "CallbackType")
        end,
    },
    {
        "axui.ImageView",
        function(node)
            Helper.renderSpriteTooltip("texture (?)", node:getVirtualRenderer())
            Helper.renderPropertyBool(node, "Scale9Enabled", "isScale9Enabled")
            Helper.renderPropertyResourceData(node, "RenderFile")
        end,
    },
    {
        "axui.Button",
        function(node)
            Helper.renderPropertyBool(node, "Scale9Enabled", "isScale9Enabled")
            Helper.renderPropertyStr(node, "TitleText")
            Helper.renderPropertyColor3B(node, "TitleColor")
            Helper.renderPropertyFloat(node, "TitleFontSize")
            Helper.renderPropertyStr(node, "TitleFontName")
            Helper.renderPropertyFloat(node, "ZoomScale")
            Helper.renderPropertyResourceData(node, "NormalFile")
            Helper.renderPropertyResourceData(node, "PressedFile")
            Helper.renderPropertyResourceData(node, "DisabledFile")
        end,
    },
    {
        "axui.Text",
        function(node)
            Helper.renderPropertyStr(node, "String")
            Helper.renderPropertyFloat(node, "FontSize")
            Helper.renderPropertyStr(node, "FontName")
            Helper.renderPropertyBool(node, "TouchScaleChangeEnabled", "isTouchScaleChangeEnabled")
            Helper.renderPropertyVec2(node, "TextAreaSize")
            Helper.renderPropertyColor4B(node, "TextColor")
            Helper.renderPropertyOption(node, "TextHorizontalAlignment", OptionTextHAlignment)
            Helper.renderPropertyOption(node, "TextVerticalAlignment", OptionTextVAlignment)
        end,
    },
    {
        "axui.TextBMFont",
        function(node)
            Helper.renderPropertyStr(node, "String")
            Helper.renderPropertyResourceData(node, "RenderFile")
        end,
    },
    {
        "axui.TextAtlas",
        function(node)
            Helper.renderPropertyStr(node, "String")
            Helper.renderPropertyResourceData(node, "RenderFile")
        end,
    },
    {
        "axui.TextField",
        function(node)
            Helper.renderPropertyVec2(node, "TouchSize")
            Helper.renderPropertyStr(node, "PlaceHolder")
            Helper.renderPropertyColor4B(node, "PlaceHolderColor")
            Helper.renderPropertyColor4B(node, "TextColor")
            Helper.renderPropertyInt(node, "FontSize")
            Helper.renderPropertyStr(node, "FontName")
            Helper.renderPropertyStr(node, "String")
            Helper.renderPropertyBool(node, "MaxLengthEnabled", "isMaxLengthEnabled")
            Helper.renderPropertyInt(node, "MaxLength")
            Helper.renderPropertyBool(node, "PasswordEnabled", "isPasswordEnabled")
            Helper.renderPropertyStr(node, "PasswordStyleText")
            -- Helper.renderPropertyBool(node, "AttachWithIME")
            -- Helper.renderPropertyBool(node, "DetachWithIME")
            Helper.renderPropertyBool(node, "InsertText")
            Helper.renderPropertyBool(node, "DeleteBackward")
            Helper.renderPropertyOption(node, "TextHorizontalAlignment", OptionTextHAlignment)
            Helper.renderPropertyOption(node, "TextVerticalAlignment", OptionTextVAlignment)
        end,
    },
    {
        "axui.Layout",
        function(node)
            Helper.renderPropertyBool(node, "ClippingEnabled", "isClippingEnabled")
            Helper.renderPropertyOption(node, "ClippingType", OptionLayoutClippingType)
            Helper.renderPropertyOption(node, "BackGroundColorType", OptionLayoutBackGroundColorType)
            Helper.renderPropertyOption(node, "LayoutType", OptionLayoutType)

            local bgColorType = node:getBackGroundColorType()
            -- 纯色背景
            if bgColorType == 1 then
                Helper.renderPropertyColor3B(node, "BackGroundColor")
                Helper.renderPropertySliderInt(node, "BackGroundColorOpacity", 0, 255)
            -- 渐变背景
            elseif bgColorType == 2 then
                Helper.renderPropertyColor3B(node, "BackGroundStartColor", nil, setterBackGroundStartColor)
                Helper.renderPropertyColor3B(node, "BackGroundEndColor", nil, setterBackGroundEndColor)
                Helper.renderPropertyVec2(node, "BackGroundColorVector")
                Helper.renderPropertySliderInt(node, "BackGroundColorOpacity", 0, 255)
            end
        end,
    },
    {
        "axui.LoadingBar",
        function(node)
            Helper.renderPropertyOption(node, "Direction", OptionLoadingBarDirection)
            Helper.renderPropertySliderInt(node, "Percent", 0, 100)
            Helper.renderPropertyBool(node, "Scale9Enabled", "isScale9Enabled")
            Helper.renderPropertyResourceData(node, "RenderFile")
        end,
    },
    {
        "axui.CheckBox",
        function(node)
            Helper.renderPropertyBool(node, "Selected", "isSelected")
            Helper.renderPropertyFloat(node, "ZoomScale")
            Helper.renderPropertyResourceData(node, "BackNormalFile")
            Helper.renderPropertyResourceData(node, "BackPressedFile")
            Helper.renderPropertyResourceData(node, "BackDisabledFile")
            Helper.renderPropertyResourceData(node, "CrossNormalFile")
            Helper.renderPropertyResourceData(node, "CrossDisabledFile")
        end,
    },
    {
        "axui.Slider",
        function(node)
            Helper.renderPropertyBool(node, "Scale9Enabled", "isScale9Enabled")
            Helper.renderPropertySliderInt(node, "Percent", 0, 100)
            Helper.renderPropertyFloat(node, "ZoomScale")
            Helper.renderPropertyResourceData(node, "BackFile")
            Helper.renderPropertyResourceData(node, "ProgressBarFile")
            Helper.renderPropertyResourceData(node, "BallNormalFile")
            Helper.renderPropertyResourceData(node, "BallPressedFile")
            Helper.renderPropertyResourceData(node, "BallDisabledFile")
        end,
    },
    {
        "axui.ScrollView",
        function(node)
            Helper.renderPropertyOption(node, "Direction", OptionScrollViewDirection)
            Helper.renderPropertyBool(node, "BounceEnabled", "isBounceEnabled")
            Helper.renderPropertyBool(node, "InertiaScrollEnabled", "isInertiaScrollEnabled")
            Helper.renderPropertyBool(node, "ScrollBarEnabled", "isScrollBarEnabled")
            Helper.renderPropertyVec2(node, "InnerContainerPosition")

            if node:isScrollBarEnabled() then
                Helper.renderPropertyFloat(node, "ScrollBarWidth")
                Helper.renderPropertyColor3B(node, "ScrollBarColor")
                Helper.renderPropertySliderInt(node, "ScrollBarOpacity", 0, 255)
                Helper.renderPropertyBool(node, "ScrollBarAutoHideEnabled", "isScrollBarAutoHideEnabled")
                Helper.renderPropertyFloat(node, "ScrollBarAutoHideTime")
            end
            Helper.renderPropertyFloat(node, "TouchTotalTimeThreshold")
        end,
    },
    {
        "axui.ListView",
        function(node)
            Helper.renderPropertyOption(node, "MagneticType", OptionListViewMagneticType)
            Helper.renderPropertyBool(node, "MagneticAllowedOutOfBoundary")
            Helper.renderPropertyFloat(node, "ItemsMargin")
            Helper.renderPropertyFloat(node, "LeftPadding")
            Helper.renderPropertyFloat(node, "RightPadding")
            Helper.renderPropertyFloat(node, "TopPadding")
            Helper.renderPropertyFloat(node, "BottomPadding")
            Helper.renderPropertyFloat(node, "ScrollDuration")
        end,
    },
    {
        "axui.PageView",
        function(node)
            -- Helper.renderPropertyOption(node, "Direction", OptionPageViewTouchDirection)
            Helper.renderPropertyBool(node, "IndicatorEnabled")
            if node:getIndicatorEnabled() then
                Helper.renderPropertyVec2(node, "IndicatorPositionAsAnchorPoint")
                Helper.renderPropertyVec2(node, "IndicatorPosition")
                Helper.renderPropertyFloat(node, "IndicatorSpaceBetweenIndexNodes")
                Helper.renderPropertyColor3B(node, "IndicatorSelectedIndexColor")
                Helper.renderPropertySliderInt(node, "IndicatorSelectedIndexOpacity", 0, 255)
                Helper.renderPropertyColor3B(node, "IndicatorIndexNodesColor")
                Helper.renderPropertySliderInt(node, "IndicatorIndexNodesOpacity", 0, 255)
                Helper.renderPropertyFloat(node, "IndicatorIndexNodesScale")
            end
        end,
    },
    {
        "sp.SkeletonRenderer",
        function(node)
            Helper.renderPropertyFloat(node, "TimeScale")
            Helper.renderPropertyBool(node, "DebugBoundingRectEnabled")
            Helper.renderPropertyBool(node, "DebugBonesEnabled")
            Helper.renderPropertyBool(node, "DebugSlotsEnabled")
            Helper.renderPropertyBool(node, "DebugMeshesEnabled")
            
            Helper.renderPropertyBool(node, "TwoColorTint", "isTwoColorTint")
        end,
    },
    {
        "sp.SkeletonAnimation",
        function(node)
        end,
    },

    -- {
    --     "axui.",
    --     function(node)
    --     end,
    -- },
}

local Property = {}

function Property.render(node)
    if not node then return end
    imgui.text(tolua.type(node))
    for k, v in pairs(M) do
        if collapsingHeader(node, v[1]) then
            v[2](node)
        end
    end
end

return Property
