
local Task = import(".Task")

-- 纹理加载是否使用多线程
local USE_IMAGE_ASYNC = true



----------------------------------------------------------------
-- 纹理资源加载任务
local LoadTexture = class("LoadTexture", Task)

function LoadTexture:ctor()
	self.textureFileArr = {}
	self.spriteFrameFileArr = {}

	self.cache_LoadTexture = {}
end 

function LoadTexture:addTextureFile(fileName)
	if not self.cache_LoadTexture[fileName] then
		self.cache_LoadTexture[fileName] = true
		table.insert(self.textureFileArr, fileName)
        self:updateProgressWeight()
	end
end

function LoadTexture:addSpriteFramesFile(fileName)
	table.insert(self.spriteFrameFileArr, fileName)
    self:updateProgressWeight()
end

function LoadTexture:updateProgressWeight()
	self.progressWeight = #self.textureFileArr + #self.spriteFrameFileArr
end

function LoadTexture:loadTexture(taskFlowPipe)
	local totalLoadCount = #self.textureFileArr
	local curLoadCount = 0

	if USE_IMAGE_ASYNC then
		local textureCache = cc.Director:getInstance():getTextureCache()

		local curTime = 0
		local callback = function()
			curLoadCount = curLoadCount + 1
			curTime = 0
			self.curProgress = curLoadCount
		end
	
		for k,v in pairs(self.textureFileArr) do
			textureCache:addImageAsync(v, callback)
		end
		
		-- 循环等待异步资源加载
		repeat
			curTime = curTime + taskFlowPipe:yield()
			if curLoadCount >= totalLoadCount then
				break
			end
			
			-- 异步加载数量长时间未变化，,还是让程序回调(防止程序一直卡在界面)
			-- 其实后面直接加载资源也是一样的,只是可能卡点点而已
			if curTime > 5.0 then
				break
			end
		until(false)
	else
		for k,v in pairs(self.textureFileArr) do
			textureCache:addImage(v)
			self.curProgress = k
			taskFlowPipe:yield()
		end
	end

	self.curProgress = totalLoadCount
end

function LoadTexture:run(taskFlowPipe)
	self:loadTexture(taskFlowPipe)

	local spriteFrameCache = cc.SpriteFrameCache:getInstance()
	local count = 0
	for k,v in pairs(self.spriteFrameFileArr) do
		spriteFrameCache:addSpriteFrames(v)
		self.curProgress = self.curProgress
		count = count + 1
		if count > 3 then
			count = 0
			taskFlowPipe:yield()
		end
	end
end

return LoadTexture