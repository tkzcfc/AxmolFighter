
local Task = import(".Task")

----------------------------------------------------------------
-- spine资源加载任务
local LoadSpine = class("LoadSpine", Task)

function LoadSpine:ctor()
	self.spineFileArr = {}
end 

function LoadSpine:addFile(fileName)
    table.insert(self.spineFileArr, fileName)
    self.progressWeight = #self.spineFileArr
end

function LoadSpine:run(taskFlowPipe)
    for k,v in pairs(self.spineFileArr) do
		local atlas = string.gsub(v, "%.(.-)$", ".atlas")
		fairygui.GCache.GetInstance():PreloadSkeletonData(v, atlas)
        self.curProgress = k
        taskFlowPipe:yield()
    end
end

return LoadSpine