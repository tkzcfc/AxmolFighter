
local demos = {
    {false, "DemoWindow", imgui.showDemoWindow},
    {false, "AboutWindow", imgui.showAboutWindow},
    {false, "MetricsWindow", imgui.showMetricsWindow},
}

imguiEventEmitter:on("imgui_render_tools_menu_bar", function()
    if imgui.beginMenu("demos") then
        for k, v in pairs(demos) do
            if imgui.menuItem(v[2], "", v[1], true) then
                v[1] = not v[1]
            end
        end
        imgui.endMenu()
    end
end, uniqueEventTag())

imguiEventEmitter:on("imgui_render_main_loop", function()
    for k, v in pairs(demos) do
        if v[1] then
            v[3]()
        end
    end
end, uniqueEventTag())
