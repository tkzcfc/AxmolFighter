local Helper = require("plugins.fairy_gui_tree.Helper")

local collapsingHeaderDefaultFlags = 0
local function collapsingHeader(node, typeName)
    return tolua.iskindof(node, typeName) and imgui.collapsingHeader(typeName, collapsingHeaderDefaultFlags)
end

local treeNodeFlags = bit.bor(imgui.ImGuiTreeNodeFlags.OpenOnArrow, imgui.ImGuiTreeNodeFlags.SpanAvailWidth)
treeNodeFlags = bit.bor(treeNodeFlags, imgui.ImGuiTreeNodeFlags.OpenOnDoubleClick)
-- treeNodeFlags = bit.bor(treeNodeFlags, imgui.ImGuiTreeNodeFlags.DefaultOpen)




local PackageItemTypeOptions = {
    { "IMAGE",       0 },
    { "MOVIECLIP",   1 },
    { "SOUND",       2 },
    { "COMPONENT",   3 },
    { "ATLAS",       4 },
    { "FONT",        5 },
    { "SWF",         6 },
    { "MISC",        7 },
    { "UNKNOWN",     8 },
    { "SPINE",       9 },
    { "DRAGONBONES", 10 },
};

local ObjectTypeOptions = {
    { "IMAGE",       0 },
    { "MOVIECLIP",   1 },
    { "SWF",         2 },
    { "GRAPH",       3 },
    { "LOADER",      4 },
    { "GROUP",       5 },
    { "TEXT",        6 },
    { "RICHTEXT",    7 },
    { "INPUTTEXT",   8 },
    { "COMPONENT",   9 },
    { "LIST",        10 },
    { "LABEL",       11 },
    { "BUTTON",      12 },
    { "COMBOBOX",    13 },
    { "PROGRESSBAR", 14 },
    { "SLIDER",      15 },
    { "SCROLLBAR",   16 },
    { "TREE",        17 },
    { "LOADER3D",    18 },
};

local ChildrenRenderOrderOptions = {
    { "ASCENT",  0 },
    { "DESCENT", 1 },
    { "ARCH",    2 },
}

local FlipTypeOptions = {
    { "NONE",       0 },
    { "HORIZONTAL", 1 },
    { "VERTICAL",   2 },
    { "BOTH",       3 },
};

local FillMethodOptions = {
    { "None",       0 },
    { "Horizontal", 1 },
    { "Vertical",   2 },
    { "Radial90",   3 },
    { "Radial180",  4 },
    { "Radial360",  5 },
};

local FillOriginOptions = {
    { "Top",    0 },
    { "Bottom", 1 },
    { "Left",   2 },
    { "Right",  3 }
};

local GroupLayoutTypeOptions = {
    { "NONE",       0 },
    { "HORIZONTAL", 1 },
    { "VERTICAL",   2 },
};

local ListLayoutTypeOptions = {
    { "SINGLE_COLUMN",   0 },
    { "SINGLE_ROW",      1 },
    { "FLOW_HORIZONTAL", 2 },
    { "FLOW_VERTICAL",   3 },
    { "PAGINATION",      4 },
};

local TextVAlignmentOptions = {
    { "TOP",    0 },
    { "CENTER", 1 },
    { "BOTTOM", 2 },
};

local TextHAlignmentOptions = {
    { "LEFT",   0 },
    { "CENTER", 1 },
    { "RIGHT",  2 },
};

local ListSelectionModeOptions = {
    { "SINGLE",               0 },
    { "MULTIPLE",             1 },
    { "MULTIPLE_SINGLECLICK", 2 },
    { "NONE",                 3 },
};

local LoaderFillTypeOptions = {
    { "NONE",               0 },
    { "SCALE",              1 },
    { "SCALE_MATCH_HEIGHT", 2 },
    { "SCALE_MATCH_WIDTH",  3 },
    { "SCALE_FREE",         4 },
    { "SCALE_NO_BORDER",    5 },
};

local ProgressTitleTypeOptions = {
    { "PERCENT",   0 },
    { "VALUE_MAX", 1 },
    { "VALUE",     2 },
    { "MAX",       3 },
};

local AutoSizeTypeOptions = {
    { "NONE",   0 },
    { "BOTH",   1 },
    { "HEIGHT", 2 },
    { "SHRINK", 3 },
};


local M = {

    {
        "fairygui.GObject",
        function(node)
            Helper.renderPropertyStr(node, "id", nil, false)
            Helper.renderPropertyStr(node, "name")
            Helper.renderPropertyVec2(node, "xy")
            Helper.renderPropertyVec2(node, "size")
            Helper.renderPropertyFloat(node, "rotation")
            Helper.renderPropertyVec2(node, "scale")
            Helper.renderPropertySliderFloat(node, "alpha", 0, 1)
            Helper.renderPropertyVec2(node, "pivot")
            Helper.renderPropertyVec2(node, "skew")
            Helper.renderPropertyStr(node, "text")
            Helper.renderPropertyStr(node, "icon")
            Helper.renderPropertyStr(node, "tooltips")
            Helper.renderPropertyFloat(node, "xMin")
            Helper.renderPropertyFloat(node, "yMin")
            Helper.renderPropertyBool(node, "visible")
            Helper.renderPropertyBool(node, "pivotAsAnchor")
            Helper.renderPropertyBool(node, "draggable")
            Helper.renderPropertyBool(node, "touchable")
            Helper.renderPropertyBool(node, "grayed")
            Helper.renderPropertyBool(node, "pixelSnapping")
            Helper.renderPropertyBool(node, "enabled")
            Helper.renderPropertyInt(node, "sortingOrder")
            Helper.renderPropertyStr(node, "resourceURL", nil, false)
            Helper.renderPropertyFloat(node, "sourceWidth", nil, false)
            Helper.renderPropertyFloat(node, "sourceHeight", nil, false)
            Helper.renderPropertyFloat(node, "initWidth", nil, false)
            Helper.renderPropertyFloat(node, "initHeight", nil, false)
            Helper.renderPropertyFloat(node, "minWidth", nil, false)
            Helper.renderPropertyFloat(node, "minHeight", nil, false)
            Helper.renderPropertyFloat(node, "maxWidth", nil, false)
            Helper.renderPropertyFloat(node, "maxHeight", nil, false)

            local packageItem = node.packageItem
            if packageItem then
                if imgui.treeNodeEx("packageItem", treeNodeFlags, "packageItem") then
                    Helper.renderPropertyStr(packageItem, "id##packageItem", "id", false)
                    Helper.renderPropertyStr(packageItem, "name##packageItem", "name", false)
                    Helper.renderPropertyInt(packageItem, "width##packageItem", "width", false)
                    Helper.renderPropertyInt(packageItem, "height##packageItem", "height", false)
                    Helper.renderPropertyStr(packageItem, "file##packageItem", "file", false)
                    -- Helper.renderPropertyOption(packageItem, "type", PackageItemTypeOptions, nil, false)
                    -- Helper.renderPropertyOption(packageItem, "objectType", ObjectTypeOptions, nil, false)

                    imgui.separatorText("spriteFrame")
                    if packageItem.spriteFrame then
                        imgui.image(packageItem.spriteFrame)
                    else
                        imgui.text("nullptr")
                    end

                    imgui.treePop()
                end
            end
        end,
    },
    {
        "fairygui.GComponent",
        function(node)
            Helper.renderPropertyBool(node, "opaque")
            Helper.renderPropertyOption(node, "childrenRenderOrder", ChildrenRenderOrderOptions)
            Helper.renderPropertyFloat(node, "viewWidth")
            Helper.renderPropertyFloat(node, "viewHeight")
            Helper.renderPropertyInt(node, "apexIndex")
            Helper.renderPropertyMargin(node, "margin")
            Helper.renderPropertyController(node)
        end,
    },

    {
        "fairygui.GButton",
        function(node)
            Helper.renderPropertyBool(node, "changeStateOnClick")
            Helper.renderPropertyBool(node, "selected")
            Helper.renderPropertyStr(node, "selectedTitle")
            Helper.renderPropertyStr(node, "selectedIcon")
            Helper.renderPropertyStr(node, "title")
            Helper.renderPropertyInt(node, "titleFontSize")
            Helper.renderPropertyColor3B(node, "titleColor")
        end,
    },
    {
        "fairygui.GImage",
        function(node)
            Helper.renderSpriteTooltip("texture (?)", node.displayObject)
            Helper.renderPropertyColor3B(node, "color")
            Helper.renderPropertyOption(node, "flip", FlipTypeOptions)
            Helper.renderPropertyOption(node, "fillMethod", FillMethodOptions)
            Helper.renderPropertyOption(node, "fillOrigin", FillOriginOptions)
            Helper.renderPropertyBool(node, "fillClockwise")
            Helper.renderPropertyFloat(node, "fillAmount")
        end,
    },
    {
        "fairygui.FUISprite",
        function(node)
            Helper.renderSpriteTooltip("texture (?)", node)
            Helper.renderPropertyOption(node, "fillMethod", FillMethodOptions)
            Helper.renderPropertyOption(node, "fillOrigin", FillOriginOptions)
            Helper.renderPropertyBool(node, "fillClockwise")
            Helper.renderPropertyFloat(node, "fillAmount")
            Helper.renderPropertyBool(node, "scaleByTile")
        end,
    },
    {
        "fairygui.GComboBox",
        function(node)
            Helper.renderPropertyStr(node, "title")

            local r1, r2 = imgui.combo("value", node.value, node.values)
            if r1 then
                node.value = r2
            end
        end,
    },
    {
        "fairygui.GGraph",
        function(node)
            Helper.renderPropertyColor3B(node, "color")
        end,
    },
    {
        "fairygui.GGroup",
        function(node)
            Helper.renderPropertyInt(node, "columnGap")
            Helper.renderPropertyInt(node, "lineGap")
            Helper.renderPropertyBool(node, "excludeInvisibles")
            Helper.renderPropertyBool(node, "autoSizeDisabled")
            Helper.renderPropertyInt(node, "mainGridIndex")
            Helper.renderPropertyInt(node, "mainGridMinSize")
            Helper.renderPropertyOption(node, "layout", GroupLayoutTypeOptions)
        end,
    },
    {
        "fairygui.GLabel",
        function(node)
            Helper.renderPropertyStr(node, "text")
            Helper.renderPropertyStr(node, "title")
            Helper.renderPropertyColor3B(node, "titleColor")
            Helper.renderPropertyInt(node, "titleFontSize")
        end,
    },
    {
        "fairygui.GList",
        function(node)
            Helper.renderPropertyOption(node, "layout", ListLayoutTypeOptions)
            Helper.renderPropertyBool(node, "foldInvisibleItems")
            Helper.renderPropertyBool(node, "scrollItemToViewOnClick")
            Helper.renderPropertyInt(node, "columnGap")
            Helper.renderPropertyInt(node, "lineGap")
            Helper.renderPropertyInt(node, "lineCount")
            Helper.renderPropertyInt(node, "columnCount")
            Helper.renderPropertyInt(node, "numItems")
            Helper.renderPropertyOption(node, "align", TextHAlignmentOptions)
            Helper.renderPropertyOption(node, "verticalAlign", TextVAlignmentOptions)
            Helper.renderPropertyBool(node, "autoResizeItem")
            Helper.renderPropertyBool(node, "isVirtual", nil, false)
            Helper.renderPropertyInt(node, "selectedIndex")
            Helper.renderPropertyOption(node, "selectionMode", ListSelectionModeOptions)
        end,
    },
    {
        "fairygui.GLoader",
        function(node)
            Helper.renderPropertyStr(node, "url")
            Helper.renderPropertyBool(node, "playing")
            Helper.renderPropertyColor3B(node, "color")
            Helper.renderPropertyOption(node, "align", TextHAlignmentOptions)
            Helper.renderPropertyOption(node, "verticalAlign", TextVAlignmentOptions)
            Helper.renderPropertyInt(node, "frame")
            Helper.renderPropertyOption(node, "fill", LoaderFillTypeOptions)
            Helper.renderPropertyBool(node, "autoSize")
            Helper.renderPropertyBool(node, "shrinkOnly")
            Helper.renderPropertyOption(node, "fillMethod", FillMethodOptions)
            Helper.renderPropertyOption(node, "fillOrigin", FillOriginOptions)
            Helper.renderPropertyBool(node, "fillClockwise")
            Helper.renderPropertyFloat(node, "fillAmount")
        end,
    },
    {
        "fairygui.GLoader3D",
        function(node)
            Helper.renderPropertyStr(node, "url")
            Helper.renderPropertyStr(node, "icon")
            Helper.renderPropertyBool(node, "playing")
            Helper.renderPropertyBool(node, "forceReplaySpine")
            Helper.renderPropertyBool(node, "loop")
            Helper.renderPropertyColor3B(node, "color")
            Helper.renderPropertyOption(node, "align", TextHAlignmentOptions)
            Helper.renderPropertyOption(node, "verticalAlign", TextVAlignmentOptions)
            Helper.renderPropertyInt(node, "frame")
            Helper.renderPropertyOption(node, "fill", LoaderFillTypeOptions)
            Helper.renderPropertyBool(node, "autoSize")
            Helper.renderPropertyBool(node, "shrinkOnly")
            Helper.renderPropertyStr(node, "animationName")
            Helper.renderPropertyStr(node, "skinName")
        end,
    },
    {
        "fairygui.GMovieClip",
        function(node)
            Helper.renderPropertyBool(node, "playing")
            Helper.renderPropertyInt(node, "frame")
            Helper.renderPropertyColor3B(node, "color")
            Helper.renderPropertyOption(node, "flip", FlipTypeOptions)
            Helper.renderPropertySliderFloat(node, "timeScale", 0, 10)
        end,
    },
    {
        "fairygui.GProgressBar",
        function(node)
            Helper.renderPropertyOption(node, "titleType", ProgressTitleTypeOptions)
            Helper.renderPropertyFloat(node, "min")
            Helper.renderPropertyFloat(node, "max")
            Helper.renderPropertyFloat(node, "value")
        end,
    },
    {
        "fairygui.GTextField",
        function(node)
            Helper.renderPropertyOption(node, "autoSize", AutoSizeTypeOptions)
            Helper.renderPropertyFloat(node, "fontSize")
            Helper.renderPropertyColor3B(node, "color")
            Helper.renderPropertyBool(node, "singleLine")
            Helper.renderPropertyBool(node, "UBBEnabled")
        end,
    },
    {
        "fairygui.GRichTextField",
        function(node)
        end,
    },
    {
        "fairygui.GTextInput",
        function(node)
        end,
    },
    {
        "fairygui.GScrollBar",
        function(node)
            Helper.renderPropertyFloat(node, "minSize", nil, false)
        end,
    },
    {
        "fairygui.GSlider",
        function(node)
            Helper.renderPropertyBool(node, "changeOnClick")
            Helper.renderPropertyBool(node, "canDrag")
            Helper.renderPropertyBool(node, "wholeNumbers")
            Helper.renderPropertyOption(node, "titleType", ProgressTitleTypeOptions)
            Helper.renderPropertyFloat(node, "min")
            Helper.renderPropertyFloat(node, "max")
            Helper.renderPropertyFloat(node, "value")
        end,
    },
    {
        "fairygui.GTree",
        function(node)
            Helper.renderPropertyInt(node, "indent")
            Helper.renderPropertyInt(node, "clickToExpand")
        end,
    },
    {
        "fairygui.Window",
        function(node)
            Helper.renderPropertyBool(node, "enableCustomAnimation")
            Helper.renderPropertyBool(node, "modal")
        end,
    },
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
