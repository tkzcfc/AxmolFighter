local DeviceData = class("DeviceData")

local targetPlatform = cc.Application:getInstance():getTargetPlatform()
DeviceData.IsWindows = cc.PLATFORM_OS_WINDOWS == targetPlatform
DeviceData.IsAndroid = cc.PLATFORM_ANDROID == targetPlatform
DeviceData.IsIos = cc.PLATFORM_IOS == targetPlatform
DeviceData.IsMac = cc.PLATFORM_MACOS == targetPlatform

local luaj, luaoc
if DeviceData.IsAndroid then
    luaj = require "axmol.core.luaj"
elseif DeviceData.IsIos then
    luaoc = require("axmol.core.luaoc")
end

local javaClassName = "dev/axmol/app/AppActivity"

function DeviceData:ctor()
end

function DeviceData:getClipboardData()
    if game_utils.is_pc then
        return native_utils.get_clipboard_string()
    elseif self.IsAndroid then
        local ok, ret = luaj.callStaticMethod(javaClassName, "getClipboardData", {}, "()Ljava/lang/String;")
        if not ok then
            return ""
        end
        return ret
    elseif self.IsIos then
        local clipboardData = ""
        luaoc.callStaticMethod("PlatBridge", "getClipboardData", {
            callback = function(result)
                print("回调函数结果：", result)
                clipboardData = result
            end
        })
        return clipboardData
    end
end

function DeviceData:setClipboardData(str)
    if game_utils.is_pc then
        return native_utils.set_clipboard_string(str)
    elseif self.IsAndroid then
        local ok,ret = luaj.callStaticMethod(javaClassName, "copyString", {str}, "(Ljava/lang/String;)V")
        return ok
    elseif self.IsIos then
        luaoc.callStaticMethod("PlatBridge", "setClipboardData", {text = tostring(str)})
        return true
    end
end

function DeviceData:getLastCallSetScreenTypeTime()
    return self.lastCallSetScreenTypeTime or 0
end

function DeviceData:sleepForChangeScreen()
    -- 防止 gDeviceData:setScreenType 调用间隔时间过短
    local interval = NowEpochMS() - self:getLastCallSetScreenTypeTime()
    local minInterval = 1000
    if interval < minInterval then
        sleep((minInterval - interval) / 1000)
    end
end

function DeviceData:resetLobbyScreenType()
    if DESIGNED_RESOLUTION_W > DESIGNED_RESOLUTION_H then
        -- 横屏
        self:setScreenType(1)
    else
        -- 竖屏
        self:setScreenType(2)
    end
end

function DeviceData:setScreenType(screenType)
    local isPortrait = screenType ~= const_def.H_Screen_Type
    -- 当前横竖屏相同，不需要切换
    if isPortrait == gAdaptive:isOrientationPortrait() then
        return
    end

    self.lastCallSetScreenTypeTime = NowEpochMS()

    -- if self.IsAndroid then
    --     local args = {screenType}
    --     local sigs = "(I)V"
    --     local ok, ret = luaj.callStaticMethod("dev/axmol/app/AppActivity", "setOrientation", args, sigs)
    -- end

    if isPortrait then
        ax.Device:setPreferredOrientation(1)
    else
        ax.Device:setPreferredOrientation(6)
    end

    gAdaptive:setOrientationPortrait(screenType ~= const_def.H_Screen_Type)
end

function DeviceData:getSystemModel()
    if self.platform == nil then
        if self.IsWindows then
            self.platform = "windows"
        elseif self.IsMac then
            self.platform = "windows"
        elseif self.IsAndroid then
            local ok, ret = luaj.callStaticMethod(javaClassName, "getSystemModel", {}, "()Ljava/lang/String;")
            self.platform = ret
        elseif self.IsIos then
            luaoc.callStaticMethod("PlatBridge", "getSystemModel", {
                callback = function(info)
                    self.platform = info.machine
                end
            })
        end
    end
    return self.platform
end

function DeviceData:getMachineType()
	if self.IsMac or self.IsIos then
		return 2
	elseif self.IsAndroid then
		return 1
	elseif self.IsWindows then
		return 3
	end
	return 0
end

function DeviceData:getDeviceID()
    if self.deviceID == nil then
        if self.IsWindows then
            self.deviceID = ""
        elseif self.IsAndroid then
            local ok,ret = luaj.callStaticMethod(javaClassName, "getDeviceIDInd", {}, "()Ljava/lang/String;")

            assert(ok)
            self.deviceID = ret
        elseif self.IsIos then
            self.deviceID = ""
        end
    end
    return self.deviceID
end

function DeviceData:getPhoneType()
    if self.IsWindows then
        return 3
    elseif self.IsAndroid then
        return 1
    elseif self.IsIos then
        return 2
    end

    return -1
end


-- @brief 打开相册
function DeviceData:popAlbum(callback)
    require("logic.sdk.PhotoAlbum"):popAlbum(callback)
end

-- @brief 保存图片到相册
function DeviceData:savePhotoToAlbum(imagePath, title, description)
    return require("logic.sdk.PhotoAlbum"):savePhotoToAlbum(imagePath, title, description)
end

-- @breif 是否存在 "保存图片到相册" 调用
function DeviceData:canSavePhoto()
    return true
end

function DeviceData:getUsedMemory()
	if DeviceData.IsAndroid then
		local className = "dev/axmol/app/AppActivity"

		if luaj.checkStaticMethod(className, "getUsedMemory", "()I") then
			local ok, value = luaj.callStaticMethod(className, "getUsedMemory", {}, "()I")
			if ok then
				return value
			end
		else
			print("no function getUsedMemory")
		end
	end
end

-- 逻辑包名
function DeviceData:getPackageName()
    return gConfigData["PackageName"]
end

-- 原生包名，某些情况需要和原生系统交互的情况需要这个：比如支付等
function DeviceData:getNativePackageName()
    if self.nativePackageName ~= nil then
        return self.nativePackageName
    end

    local packagename = nil
    if self.IsAndroid then
        local ok, ret = luaj.callStaticMethod(javaClassName, "getPackageNameEx", {}, "()Ljava/lang/String;")
        if not ok then return nil end
        packagename = ret
    else
        packagename = self:getPackageName()
    end

    self.nativePackageName = packagename
    return packagename
end

function DeviceData:getSafeAreaInsets()
    local safeAreaInsets = nil

    if DeviceData.IsIos then
        luaoc.callStaticMethod("PlatBridge", "getSafeAreaInsets", {callback = function(insets)
            safeAreaInsets = insets
        end})
    end

    if safeAreaInsets == nil then
        safeAreaInsets = {top = 0, bottom = 0, left = 0, right = 0}
    end

    return safeAreaInsets
end

return DeviceData
