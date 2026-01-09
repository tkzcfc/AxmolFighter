FeatureManager = {}

-- 退出登录
FeatureManager.Logout = "Logout"

function FeatureManager:attachTo(cls)
    cls.onClickOpenFeature = function(this, sender)
        local feature_name = StringUtils.parseKeyValuePairsFromNode(sender).GetString("feature")
        if feature_name then
            FeatureManager:open(feature_name)
        else
            print("未指定功能名称")
        end
    end
end

function FeatureManager:open(feature_name, on_finish_callback, ...)
    local funcName = "onOpen_" .. tostring(feature_name)

    if type(self[funcName]) == "function" then
        self[funcName](self, on_finish_callback, ...)
    else
        print("找不到模块:", tostring(feature_name))
        if on_finish_callback then on_finish_callback() end
    end
end

-- @brief 退出登录
function FeatureManager:onOpen_Logout(on_finish_callback)
    gLobbyData:doLogout()
    if on_finish_callback then on_finish_callback() end
end

return FeatureManager
