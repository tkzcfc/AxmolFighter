gConfigData = gConfigData or {}

-- 导航配置
gConfigData["NavUrl"]   = "http://999.h5navi.com:7500/api/global"
-- 包名
gConfigData["PackageName"] = "com.neon.arcade"

-- 默认语言
gConfigData["DefaultLanguage"] = "en"

gConfigData["ResourceBranch"] = "main"

gConfigData["DisableHotfix"] = false
gConfigData["DebugDisableUpdate"] = true
gConfigData["ShowDebugInfo"] = true
gConfigData["DisableActivityPopup"] = true
gConfigData["PrintDebugLog"] = true


local ok = pcall(function()
    require("boot.src.build_config")
end)

if not ok then
    print("\n\n\nload 'boot/src/build_config.lua' failed\n\n\n")
end