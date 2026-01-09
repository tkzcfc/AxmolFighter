-- 各种全局定时任务

local ScheduledTasks = class("ScheduledTasks")

function ScheduledTasks:ctor()
    local scheduler = cc.Director:getInstance():getScheduler()
    
    -- lua垃圾回收
    scheduler:scheduleScriptFunc(function()
        collectgarbage("collect")
    end, 60, false)
end

return ScheduledTasks