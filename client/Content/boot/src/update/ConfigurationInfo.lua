
local M = {}

function M:init()
    local infoStr = ""
    if game_utils.get_engine_cfg_info then
        infoStr = game_utils.get_engine_cfg_info()
    end

    self.infoMap = {}

    if infoStr == "" then
        local img = nil
        -- astc支持检测
        img = cc.Image:new()
        if img:initWithImageFile("boot/resource/test_astc.data") then
            print("astc支持检测", img:getPixelFormat())
            if img:getPixelFormat() == 18 then
                self.infoMap["supports_ASTC"] = "true"
            end
        end
        
        -- etc2支持检测
        img = cc.Image:new()
        if img:initWithImageFile("boot/resource/test_etc2.data") then
            if img:getPixelFormat() == 6 then
                self.infoMap["supports_ETC2"] = "true"
            end
        end
    else
        for k,v in string.gmatch(infoStr, "([%w%._]+):%s(%w+)") do
            self.infoMap[k] = v
            -- print(k, v)
        end
    end
end

function M:isSupportsASTC()
    return self.infoMap["supports_ASTC"] == "true"
end

function M:isSupportsETC2()
    return self.infoMap["supports_ETC2"] == "true"
end

M:init()

return M