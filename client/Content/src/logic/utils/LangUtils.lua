
LangUtils = {}

local fileUtils = cc.FileUtils:getInstance()
local LangTextDirName = "neon_lang_text"
local LangTextDownloadDirName = fileUtils:getWritablePath() .. LangTextDirName .. "/"

local function keepTextureRefrence(fileName)
    local scene = gMainScene--cc.Director:getInstance():getRunningScene()
    if scene == nil then return end

    local keepNode = scene:getChildByName("resource_keep_ref")
    if not keepNode then
        keepNode = cc.Node:create()
        keepNode:setName("resource_keep_ref")
        keepNode:setVisible(false)
        scene:addChild(keepNode)
    end

    if keepNode:getChildByName(fileName) == nil then
        local spr = cc.Sprite:create(fileName)
        if spr then
            spr:setName(fileName)
            keepNode:addChild(spr)

            -- 对plist子图添加引用
            local plistFileName = string.gsub(fileName, "%.(.-)$", ".plist")
            cc.SpriteFrameCache:getInstance():addSpriteFrames(plistFileName)
            local valueMap = cc.FileUtils:getInstance():getValueMapFromFile(plistFileName)
            for frameName, _ in pairs(valueMap.frames or {}) do
                local nodeName = plistFileName .. "@" .. frameName
                if keepNode:getChildByName(nodeName) == nil then
                    local spr = cc.Sprite:createWithSpriteFrameName(frameName)
                    if spr then
                        spr:setName(nodeName)
                        keepNode:addChild(spr)
                        break
                    end
                end
            end
        end
    end
    return true
end

local function removeKeepTextureRefrence(fileName)
    local scene = gMainScene--cc.Director:getInstance():getRunningScene()
    if scene == nil then return end
    
    local keepNode = scene:getChildByName("resource_keep_ref")
    if not keepNode then
        return
    end

    local node = keepNode:getChildByName(fileName)
    if node then
        node:removeFromParent()
    end
end

function LangUtils:init()
    -- 获取当前多语言
    local lang = cc.UserDefault:getInstance():getStringForKey("lang", gConfigData.DefaultLanguage)
    if not table.indexof(gConfigData.Languages, lang) then
        lang = gConfigData.DefaultLanguage
    end

    self:changeLang(lang)
end

function LangUtils:changeLang(lang)
    if not const_def.LangList[lang] then
        lang = "en"
    end
    cc.UserDefault:getInstance():setStringForKey("lang", lang)
    
    local fileName = self:getLangTextFileName(lang)
    local fileNameInInternal = self:getLangTextFileNameInInternal(lang)

    local data = Crypto.decodeJsonFile(fileName, true)
    if fileName ~= fileNameInInternal and data ~= nil then
        local dataInternal = Crypto.decodeJsonFile(fileNameInInternal, true)
        for k, v in pairs(dataInternal or {}) do
            if data[k] == nil then
                data[k] = v
            end
        end
    end

    if gLocalization:getLang() ~= lang and gLocalization:getLang() ~= "cn" then
        removeKeepTextureRefrence(string.format("lang/%s.png", gLocalization:getLang()))
    end
    
    gLocalization:setLang(lang, data)

    if gLocalization:loadLocalizedResources() then
        local pngFile = string.format("lang/%s.png", gLocalization:getLang())
        if not keepTextureRefrence(pngFile) then
            go(function()
                sleep(0.1)
                keepTextureRefrence(pngFile)
            end)
        end
    end
end

function LangUtils:getLangTextFileName(lang)
    -- 先从下载路径找
    local fileName = LangTextDownloadDirName .. lang .. ".json"
    if fileUtils:isFileExist(fileName) then
        return fileName
    end

    return self:getLangTextFileNameInInternal(lang)
end

function LangUtils:getLangTextFileNameInInternal(lang)
    -- 包内文件
    return string.format("advance/lang_text/%s.json", tostring(lang))
end

LangUtils:init()