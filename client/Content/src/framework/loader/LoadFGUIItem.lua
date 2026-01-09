
local Task = import(".Task")

----------------------------------------------------------------
-- fgui加载任务
local LoadFGUIItem = class("LoadFGUIItem", Task)

function LoadFGUIItem:ctor()
	self.items = {}
end 

function LoadFGUIItem:setItems(items)
    self.items = items
    self.progressWeight = #self.items
end

function LoadFGUIItem:run(taskFlowPipe)
    for k,v in pairs(self.items) do
        v:Load()
        self.curProgress = k
    
        if k % 20 == 0 then
            taskFlowPipe:yield()
        end
    end
end

return LoadFGUIItem