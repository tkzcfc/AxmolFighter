require("axmol.init")
require("axmol.core.deprecated")
require("boot.src.config")
require("boot.src.LuajEntry")


-- imgui
xpcall(function()
    local platform = cc.Application:getInstance():getTargetPlatform()
    if platform == ax.PLATFORM_WIN32 then
        require "ext_imgui.imgui_logic"
    end
end, __G__TRACKBACK__)

local scene = display.newScene()
display.runScene(scene)

require("boot.src.utils"):init(scene)

scene:addChild(require("boot.src.layer.UpdateLayer").new())
