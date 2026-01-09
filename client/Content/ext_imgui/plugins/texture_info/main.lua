local BasePlugin = require("plugins.BasePlugin")

local M = class("M", BasePlugin)

function M:ctor(pluginName)
    M.super.ctor(self, pluginName)

    self.isSupport = false
    if ax.Texture2D.getTextureCount then
        self.isSupport = true
    end

    self.winFlags = imgui.ImGuiWindowFlags.HorizontalScrollbar
end

local showLeakTexture = false
local cacheTextures = {}

function M:render()
    if not self.isSupport then return end

    if game_utils.start_collecting then
        if imgui.button("startCollecting") then
            game_utils.start_collecting()
        end
        if imgui.button("stopCollecting") then
            game_utils.stop_collecting()
        end
        if imgui.button("printDifferenceSnapshot") then
            game_utils.print_difference_snapshot()
        end
    end

    local textureCache = cc.Director:getInstance():getTextureCache()
    local textures = textureCache:getTextures()

    imgui.text(string.format("RefObject count: %d", ax.Object:getRefObjectCount()))
    imgui.text(string.format("Texture count: %d", ax.Texture2D:getTextureCount()))
    imgui.text(string.format("TextureCache count: %d", #textures))


    local r1, r2 = imgui.checkbox("Show Leak Texture", showLeakTexture)
    if r1 then
        showLeakTexture = r2
    end


    for _, v in pairs(textures) do
        local texture = textureCache:getTextureForKey(v)
        if texture and imgui.collapsingHeader(v, 0) then
            imgui.text(string.format("Size: %d x %d", texture:getPixelsWide(), texture:getPixelsHigh()))
            imgui.text(string.format("ReferenceCount: %d", texture:getReferenceCount()))
            imgui.image(texture)
        end

        if showLeakTexture then
            cacheTextures[tostring(texture)] = true
        end
    end

    if showLeakTexture then
        local textures = ax.Texture2D:getAllTextures()
        local index = 0
        for _, texture in pairs(textures) do
            if not cacheTextures[tostring(texture)] then
                index = index + 1
                if imgui.collapsingHeader(string.format("[Leak]%d %s", index, texture:getPath()), 0) then
                    imgui.text(string.format("Size: %d x %d", texture:getPixelsWide(), texture:getPixelsHigh()))
                    imgui.text(string.format("ReferenceCount: %d", texture:getReferenceCount()))
                    imgui.image(texture)
                end
            end
        end
        cacheTextures = {}
    end
end

return M
