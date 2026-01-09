-- @Author: 
-- @Date  : 2019-10-17 21:26:05
-- @remark: 异步资源加载


local PackageItemType = {
	IMAGE = 0,
	MOVIECLIP = 1,
	SOUND = 2,
	COMPONENT = 3,
	ATLAS = 4,
	FONT = 5,
	SWF = 6,
	MISC = 7,
	UNKNOWN = 8,
	SPINE = 9,
	DRAGONBONES = 10,
}

local TaskFlowPipe = import(".TaskFlowPipe")
local LoadSpine = import(".LoadSpine")
local LoadTexture = import(".LoadTexture")
local LoadWebm = import(".LoadWebm")
local LoadFGUIItem = import(".LoadFGUIItem")

-- 异步加载
local LoadAsync = class("LoadAsync")

function LoadAsync:ctor()
	self.pipe = TaskFlowPipe.new()

	-- 纹理资源加载任务
	self.textureLoadTask = LoadTexture.new()
	self.textureLoadTask.weightScale = 10
	self.pipe:pushTask(self.textureLoadTask)

	-- spine加载任务
	self.loadSpine = LoadSpine.new()
	self.pipe:pushTask(self.loadSpine)

	-- webm加载任务
	self.loadWebm = LoadWebm.new()
	self.loadWebm.weightScale = 20
	self.pipe:pushTask(self.loadWebm)

	-- fgui item加载
	self.loadFGUIItem = LoadFGUIItem.new()
	self.pipe:pushTask(self.loadFGUIItem)
end

function LoadAsync:loadTextures(files)
	for k, v in pairs(files) do
		self.textureLoadTask:addTextureFile(v)
	end
end

function LoadAsync:loadPlistFiles(files)
	for k, v in pairs(files) do
		local textureFile = string.gsub(v, "%.(.-)$", ".png")
		self.textureLoadTask:addTextureFile(textureFile)
		self.textureLoadTask:addSpriteFramesFile(v)
	end
end

function LoadAsync:loadFGUIItems(items)
	self.loadFGUIItem:setItems(items)
	
	local useSkeletonCache = true
	fairygui.UIConfig.useSkeletonCache = useSkeletonCache
	
	for k, v in pairs(items) do
		local itemType = v.type
		local itemFile = v.file

		if itemType == PackageItemType.ATLAS then
			self.textureLoadTask:addTextureFile(itemFile)
		elseif itemType == PackageItemType.SPINE and useSkeletonCache then
			self.loadSpine:addFile(itemFile)
			itemFile = string.gsub(itemFile, "%.(.-)$", ".png")
			if cc.FileUtils:getInstance():isFileExist(itemFile) then
				self.textureLoadTask:addTextureFile(itemFile)
			end
		end
	end
end

function LoadAsync:loadWebms(webms)
	for k, v in pairs(webms) do
		self.loadWebm:addFile(v)
	end
end

-- @brief 加载开始
-- @param processCallback 加载进度回调
-- @param finishCallback 加载完成回调
-- @param errorCallback 错误回调
function LoadAsync:start(processCallback, finishCallback, errorCallback)
	self.pipe:start(processCallback, finishCallback, errorCallback)
end

-- @brief 中断
function LoadAsync:abort()
	self.pipe:done()
end

-- @brief 获取管道
function LoadAsync:getPipe()
	return self.pipe
end

return LoadAsync
