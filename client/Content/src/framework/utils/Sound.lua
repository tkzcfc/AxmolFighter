local Sound = class("Sound")

Sound.sMusic        = "sMusic"         --背景
Sound.sEffect       = "sEffect"        --音效

Sound.bMusic        = true
Sound.bEffect       = true

local bgmSoundID     = -1
local soundPath      = ""

function Sound:ctor()
    self.curAudioInfos = {}

    self.bMusic = cc.UserDefault:getInstance():getBoolForKey(self.sMusic, self.bMusic)
    self.bEffect = cc.UserDefault:getInstance():getBoolForKey(self.sEffect, self.bEffect)
    
    cc.Director:getInstance():getScheduler():scheduleScriptFunc(function()
        if #self.curAudioInfos <= 0 then return end

        local validInfos = {}
        for _, info in pairs(self.curAudioInfos) do
            if cc.AudioEngine:getState(info.id) ~= -1 then
                table.insert(validInfos, info)
            end
        end
        self.curAudioInfos = validInfos
    end, 1, false)
end

--@brief 设置背景音效开关
function Sound:setMusicSwitch(bOpen)
    self.bMusic = bOpen
    if bOpen then
        self:resumeBgm()
    else
        self:pauseBgm()
    end
end

--@brief 设置音效开关
function Sound:setSoundSwitch(bOpen)
    if self.bEffect == bOpen then return end
    self.bEffect = bOpen

    local volume = 0
    if bOpen then volume = 1 end

    for _, info in pairs(self.curAudioInfos) do
        cc.AudioEngine:setVolume(info.id, volume)
    end
end

--@brief 播放音乐
function Sound:playBgm(path, loop)
    if loop == nil then loop = true end
    if path == nil then path = soundPath end

    -- 相同音效不重新播放了
    if soundPath == path and bgmSoundID ~= -1 then
        return bgmSoundID
    end

    if bgmSoundID ~= -1 then
        cc.AudioEngine:stop(bgmSoundID)
    end

    bgmSoundID = cc.AudioEngine:play2d(path, loop)
    self:setMusicSwitch(self.bMusic)
    soundPath = path

    return bgmSoundID
end

--@brief 获取当前背景音乐id
function Sound:getBgmSoundID()
    return bgmSoundID
end

function Sound:resumeBgm()
    cc.AudioEngine:setVolume(bgmSoundID,1)
end

function Sound:pauseBgm()
    cc.AudioEngine:setVolume(bgmSoundID,0)
end

--@brief 停止音乐
function Sound:stopBgm()
    cc.AudioEngine:stop(bgmSoundID)
    bgmSoundID = -1
    soundPath = ""
end

--@brief 播放音效
function Sound:playEffect(path, loop)
    if loop == nil then loop = false end
    --音效
    local id = cc.AudioEngine:play2d(path, loop)
    table.insert(self.curAudioInfos, {id = id, path = path, loop = loop})

    if not self.bEffect then
        cc.AudioEngine:setVolume(id, 0)
    end
    return id
end

--@brief 关闭音效
function Sound:stopEffect(id)
    if id then
        cc.AudioEngine:stop(id)
    end
end

function Sound:isEffectPlaying(path)
    -- enum class AudioState
    -- {
    --     ERROR = -1,
    --     INITIALIZING,
    --     PLAYING,
    --     PAUSED
    -- };
    for _, info in pairs(self.curAudioInfos) do
        if info.path == path and cc.AudioEngine:getState(info.id) ~= -1 then
            return true
        end
    end
    return false
end

function Sound:stopAll()
    self.curAudioInfos = {}
    Sound:stopBgm()
    cc.AudioEngine:stopAll()
end

function Sound:saveCfg()
    cc.UserDefault:getInstance():setBoolForKey(self.sMusic, self.bMusic)
    cc.UserDefault:getInstance():setBoolForKey(self.sEffect, self.bEffect)
end

--@brief 点击音效
function Sound:clickSound()
    -- if self.clickSoundId and cc.AudioEngine:getState(self.clickSoundId) ~= -1 then
    --     return
    -- end
    self.clickSoundId = self:playEffect("sound/click.mp3")
end

function Sound:stopClickSound()
    self:stopEffect(self.clickSoundId)
    self.clickSoundId = nil
end

return Sound