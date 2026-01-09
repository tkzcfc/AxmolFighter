local style = require("plugins.thems.style")
local BasePlugin = require("plugins.BasePlugin")


-- DPI缩放规则
-- DPI    缩放因子
-- 96        100%
-- 120       125%
-- 144       150%
-- 192       200%
local DPI_SCALE_FACTOR = {
    {96, 1},
    {120, 1.25},
    {144, 1.5},
    {192, 2},
}
local function lerp(p1, p2, alpha)
    return p1 * (1 - alpha) + p2 * alpha
end

local M = class("M", BasePlugin)

function M:ctor(pluginName)
    M.super.ctor(self, pluginName)

    self.uiScale = self.store:get("ui_scale", nil)
    self.fontScale = self.store:get("font_scale", nil)

    if type(self.uiScale) ~= "number" or type(self.fontScale) ~= "number" then
        self:autoScale()
    end

    imguiEventEmitter:on("event_imgui_them_change", function()
        self:scaleUI(self.uiScale)
        self:scaleFont(self.fontScale)
    end, self)
end

function M:render()
    local ok, value = imgui.dragFloat("UI Scale", self.uiScale, 0.1, 1, 4)
    if ok then
        self:scaleUI(value)
    end

    local ok, value = imgui.dragFloat("Font Scale", self.fontScale, 0.1, 0.5, 5)
    if ok then
        self:scaleFont(value)
    end

    if imgui.button("Auto Scale") then
        self:autoScale()
    end
end

function M:scaleUI(value)
    self.uiScale = value
    self.store:set("ui_scale", value)

    local imStyle = imgui.getStyle()
    for k, v in pairs(style.GetLastStyleData() or {}) do
        imStyle[k] = v
    end
    imStyle:scaleAllSizes(value)
end

function M:scaleFont(value)
    self.fontScale = value
    self.store:set("font_scale", value)

    imgui.getIO().FontGlobalScale = value
end

function M:autoScale()
    local dpi = ax.Device:getDPI()

    local scaleFactorMin = DPI_SCALE_FACTOR[#DPI_SCALE_FACTOR]
    local scaleFactorMax = DPI_SCALE_FACTOR[#DPI_SCALE_FACTOR]

    -- 找到合适的缩放规则
    for k, v in pairs(DPI_SCALE_FACTOR) do
        if dpi <= v[1] then
            scaleFactorMax = v
            if k == 1 then
                scaleFactorMin = v
            else
                scaleFactorMin = DPI_SCALE_FACTOR[k - 1]
            end
            break
        end
    end

    local scale = scaleFactorMax[2]

    -- 根据dpi值自动缩放
    if scaleFactorMax[1] ~= scaleFactorMin[1] then
        local alpha = (dpi - scaleFactorMin[1]) / (scaleFactorMax[1] - scaleFactorMin[1])
        scale = lerp(scaleFactorMin[2], scaleFactorMax[2], alpha)
    end
    
    -- 保留两位小数
    scale = math.floor(scale * 100) / 100
    self:scaleUI(scale)
    self:scaleFont(scale)
end

return M
