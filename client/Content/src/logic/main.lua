
package.path = "?.lua"

game_utils.clear_batching_spine_sache()
ccui.Text:setCustomLocalizationEnabled(true)

-- if ccui.Text.setDefaultFontName ~= nil then
--     -- ccui.Text:setDefaultFontName("Arial")
--     ccui.Text:setDefaultFontName("Helvetica")
-- end

ax.FontEngine:getInstance():setAutoMatchSystemFontsByCharacter(true)

-- 清理搜索路径
if cc.FileUtils:getInstance():isFileExist("chunks/base.chunk") then
    local searchPaths = cc.FileUtils:getInstance():getOriginalSearchPaths()
    local writablePath = cc.FileUtils:getInstance():getWritablePath()

    table.removebyvalue(searchPaths, "src")
    table.removebyvalue(searchPaths, writablePath .. "download/src")

    cc.FileUtils:getInstance():setSearchPaths(searchPaths)
end

-- 导入框架
require("framework.init")

-- 常用类导出
cjson = require("cjson")
UIDialog = require("logic.core.UIDialog")
UIMainFrame = require("logic.core.UIMainFrame")

--导入常用定义
require("logic.const.const_def")

require("logic.debug")

go(function()
    require("data.ConfigData")

    require("logic.utils.LangUtils")
    require("logic.utils.Utils")
    require("logic.utils.StringUtils")
    require("logic.utils.StorageUtils")


    gDeviceData = require("data.DeviceData").new()


    -- 数据模型
    -- gModel = require("logic.model.Model").new()

    -- 运行游戏场景
    gMainScene = require("logic.core.MainScene").new()

    display.runScene(gMainScene, "FADE", 0.5)

    gViewManager:runView(require("logic.views.LaunchView").new())
end)
