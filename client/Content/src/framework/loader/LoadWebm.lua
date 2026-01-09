
local Task = import(".Task")

----------------------------------------------------------------
-- webm资源加载任务
local LoadWebm = class("LoadWebm", Task)

function LoadWebm:ctor()
	self.items = {}
end 

function LoadWebm:addFile(fileName)
    table.insert(self.items, fileName)
    self.progressWeight = #self.items
end

function LoadWebm:run(taskFlowPipe)
    local curTime = 0
    self.curProgress = 0
    local callback = function()
        self.curProgress = self.curProgress + 1
        curTime = 0
    end

    for k,v in pairs(self.items) do
        ax.Webm:preloadAsync(v, callback)
    end
    
    -- 循环等待异步资源加载
    repeat
        curTime = curTime + taskFlowPipe:yield()
        if self.curProgress >= #self.items then
            break
        end
        -- 异步加载数量长时间未变化，,还是让程序回调(防止程序一直卡在界面)
        if curTime > 15 then
            break
        end
    until(false)
end

return LoadWebm