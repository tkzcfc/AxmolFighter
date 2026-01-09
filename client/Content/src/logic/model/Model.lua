local Model = class("Model")

function Model:ctor()
    -- 服务器推送消息监听
    self.serverPushHandler = require("logic.model.ServerPushHandler").new()
    -- 全局定时任务
    require("logic.model.ScheduledTasks").new()
    
    require("logic.model.FeatureManager")

    self.game = require("logic.model.Game").new()
end

return Model