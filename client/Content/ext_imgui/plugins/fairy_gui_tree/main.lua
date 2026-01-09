local BasePlugin = require("plugins.BasePlugin")
local Property = require("plugins.fairy_gui_tree.Property")

local M = class("M", BasePlugin)


-- local baseFlags = bit.bor(imgui.ImGuiTreeNodeFlags.SpanFullWidth, imgui.ImGuiTreeNodeFlags.SpanAvailWidth)
local baseFlags = bit.bor(imgui.ImGuiTreeNodeFlags.OpenOnArrow, imgui.ImGuiTreeNodeFlags.SpanAvailWidth)
baseFlags = bit.bor(baseFlags, imgui.ImGuiTreeNodeFlags.OpenOnDoubleClick)

local leafFlags = baseFlags
leafFlags = bit.bor(leafFlags, imgui.ImGuiTreeNodeFlags.Leaf)
leafFlags = bit.bor(leafFlags, imgui.ImGuiTreeNodeFlags.NoTreePushOnOpen)

local curFlags = 0
local curSelectNode = nil

local textColor = nil
local textDisabledColor = nil
local greyTextCount = 0

local function renderTree(node, prefix)
    local name = node.name
    if name == nil or name == "" then
        name = tostring(node)
    end

    if prefix then
        name = prefix .. name
    end

    local nodeCount = node.numChildren or 0
    local hasLeaf = nodeCount > 0
    if not hasLeaf then
        if tolua.type(node) == "fairygui.GLoader" then
            hasLeaf = node.component ~= nil or node.sprite ~= nil
        end
    end

    if not hasLeaf then
        curFlags = leafFlags
    else
        curFlags = baseFlags
    end

    if curSelectNode == node then
        curFlags = bit.bor(curFlags, imgui.ImGuiTreeNodeFlags.Selected)
    end

    local showGrey = not node.visible
    if showGrey then
        greyTextCount = greyTextCount + 1
        imgui.setStyleColor(imgui.ImGuiCol.Text, textDisabledColor)
    end

    local treeOpen = imgui.treeNodeEx(tostring(node), curFlags, name)
    if imgui.isItemClicked() and not imgui.isItemToggledOpen() then
        curSelectNode = node
    end

    if treeOpen and hasLeaf then
        if nodeCount > 0 then
            -- 使用 game_utils.get_fgui_component_children 方法遍历子节点 fairygui::GComponent:GetChildren 函数如果某些节点类型没有注册到lua中 会导致无法传到lua中
            for k, v in pairs(game_utils.get_fgui_component_children(node)) do
                renderTree(v)
            end
        else
            if node.component then
                renderTree(node.component, "loader/")
            else
                renderTree(node.sprite, "loader/")
            end
        end

        imgui.treePop()
    end

    if showGrey then
        greyTextCount = greyTextCount - 1
        if greyTextCount == 0 then
            imgui.setStyleColor(imgui.ImGuiCol.Text, textColor)
        end
    end
end

local veczero = {x = 0, y = 0}
function M:render()
    if tolua.isnull(curSelectNode) then curSelectNode = nil end

    local root = nil
    if GetFairyRoot then root = GetFairyRoot() end
    if not root then return end

    greyTextCount = 0
    textColor = imgui.getStyleColorVec4(imgui.ImGuiCol.Text)
    textDisabledColor = imgui.getStyleColorVec4(imgui.ImGuiCol.TextDisabled)

    imgui.columns(2, 0, true)

        imgui.beginChild("##nodes", veczero, true, imgui.ImGuiWindowFlags.HorizontalScrollbar)
        renderTree(root)
        imgui.setStyleColor(imgui.ImGuiCol.Text, textColor)
        imgui.endChild()

    imgui.nextColumn()

        imgui.beginChild("##property", veczero, true, imgui.ImGuiWindowFlags.HorizontalScrollbar)
        Property.render(curSelectNode)
        imgui.endChild()

    imgui.columns(1)
end

return M
