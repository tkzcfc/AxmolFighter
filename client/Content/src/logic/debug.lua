
gDebugStorage = require("framework.utils.StorageObject").new("debug.json")
gDebugStorage:setDefaultValue("show_game_id", device.platform == "windows")
gDebugStorage:setDefaultValue("show_fps", device.platform == "windows")
gDebugStorage:setDefaultValue("show_debug_btn", gConfigData["ShowDebugInfo"])

ax.Director:getInstance():setStatsDisplay(gDebugStorage:getValue("show_fps") == true)