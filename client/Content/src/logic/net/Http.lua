local Crypto = Crypto

local Http = {}

-- windows平台才显示log
local showLogInfo = false--device.platform == "windows"

local function logI(...)
    if not showLogInfo then return end
    print(...)
end

local logE = print

-- @brief 文件下载
-- @param url
-- @param callback 完成回调
-- @param tofile 下载之后的文件位置,可选.为空则默认储存在.cache目录
-- @return token
function Http:fetch(url, callback, tofile)
	self:initCacheDir()

	if tofile == nil then
		tofile = self:getCacheFileName(url)
	end

	local token = self.eventEmitter:once(url, callback, self)

	-- 请求已创建
	if self.eventEmitter:listeners(url) > 1 then
		return token
	end

	-- 本地有缓存
	if cc.FileUtils:getInstance():isFileExist(tofile) then
        go(function()
            self.eventEmitter:emit(url, true, tofile)
        end)
		return token
	end
    
    logI("[Http-Fetch]", url, tofile)

    xhttp_request(url, tofile, function()
        self.eventEmitter:emit(url, true, tofile)
    end, function()
        self.eventEmitter:emit(url, false)
    end, nil, 1)

	return token
end

-- @brief 取消下载文件
-- @param token fetch返回的token
function Http:cancelFetch(token)
	if token == nil then return end
	self.eventEmitter:off(token)
end

-- @brief 缓存目录初始化
function Http:initCacheDir()
	if self.isInitDirTag then
		return
	end

    local fileUtils = cc.FileUtils:getInstance()
	local cacheDir = fileUtils:getWritablePath() .. '.cache/'
	if not fileUtils:isDirectoryExist(cacheDir) then
		if not fileUtils:createDirectory(cacheDir) then
			cacheDir = fileUtils:getWritablePath()
		end
	end

	self.isInitDirTag = true
	self.cacheDir = cacheDir
    self.eventEmitter = require("framework.utils.EventEmitter").new()
end

function Http:getCacheFileName(url)
	self:initCacheDir()
    return self.cacheDir .. Crypto.md5(url)
end

function Http:setImageUploadUrl(url)
    if url == nil then return end
    
    if string.sub(url, -1) ~= "/" then
        url = url .. "/"
    end

    self.imageUploadUrl = url
    -- 不保存到本地，都使用服务器配置路径
    -- cc.UserDefault:getInstance():setStringForKey("img_upload_url", url)
end

function Http:getImageUploadUrl()
    -- if self.imageUploadUrl == nil then
    --     self.imageUploadUrl = cc.UserDefault:getInstance():getStringForKey("img_upload_url", "")
    -- end

    return self.imageUploadUrl or ""
end

-- @brief 图片上传
function Http:uploadImage(base64Data, callback, url)
    -- if self.imageUploadUrl == nil then
    --     self.imageUploadUrl = cc.UserDefault:getInstance():getStringForKey("img_upload_url", "")
    -- end
    if self.imageUploadUrl == nil then
        self.imageUploadUrl = ""
    end
    
    local data = {
        base64 = base64Data,
        size = string.len(base64Data),
    }

    -- 默认使用传入的路径，如果为空则使用配置路径
    if url == nil then
        url = self.imageUploadUrl
    else
        if string.sub(url, -1) ~= "/" then
            url = url .. "/"
        end
    end

    local xhr = cc.XMLHttpRequest:new()
    xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON
    xhr:open("POST", url)
    xhr:registerScriptHandler(function()
        if xhr.readyState == 4 and (xhr.status >= 200 and xhr.status < 207) then -- 成功
            local response = xhr.response

            print("上传图片返回", response)

            if string.sub(tostring(response), -4) == ".png" then
                local imageUrl = url .. response
                -- 上传成功，将图片数据缓存到本地
                local cacheFileName = Http:getCacheFileName(imageUrl)
                cc.FileUtils:getInstance():writeStringToFile(Crypto.decodeBase64(base64Data), cacheFileName)

                if callback then callback(true, response, imageUrl) end
            else
                if callback then callback() end
            end
        else
            print("上传图片失败", xhr.status, xhr.response)
            if callback then callback() end
        end
    end)
    xhr:setRequestHeader("Accept", "application/json")
    xhr:send(Crypto.encodeJson(data))
end

return Http