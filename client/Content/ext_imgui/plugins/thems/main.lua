local style = require("plugins.thems.style")
local store = require("utils.StorageObject").new("thems.json")

local thems = {
    -- {"Default", style.styleVarsDefault},
    {"Microsoft", style.Microsoft},
    {"JetBrainsDarcula", style.JetBrainsDarcula},
    {"CherryTheme", style.CherryTheme},
    {"LightGreen", style.LightGreen},
    {"AdobeDark", style.AdobeDark},
    {"CorporateGrey", style.CorporateGrey},
    {"DarkTheme2", style.DarkTheme2},
}

local themIndex = store:get("index", #thems)
if not thems[themIndex] then
    themIndex = 1
end
thems[themIndex][2]()
style.BackupStyle()
imguiEventEmitter:emit("event_imgui_them_change")

imguiEventEmitter:on("imgui_render_tools_menu_bar", function()
    if imgui.beginMenu("thems") then
        for k, v in pairs(thems) do
            if imgui.menuItem(v[1], "", themIndex == k, true) then
                themIndex = k
                store:set("index", themIndex)
                thems[themIndex][2]()
                style.BackupStyle()
                imguiEventEmitter:emit("event_imgui_them_change")
            end
        end
        imgui.endMenu()
    end
end, uniqueEventTag())
