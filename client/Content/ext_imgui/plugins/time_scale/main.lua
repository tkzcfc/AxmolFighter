local BasePlugin = require("plugins.BasePlugin")

local M = class("M", BasePlugin)

local director = cc.Director:getInstance()
local scheduler = director:getScheduler()
local timeScale = 1

-- local scheduleScriptFuncRaw = scheduler.scheduleScriptFunc

-- scheduler.scheduleScriptFunc = function(this, handler, interval, pause)
--     if FCasinoCtx then
--         return scheduleScriptFuncRaw(this, function(dt)
--             handler(dt * timeScale)
--         end, interval, pause)
--     else
--         return scheduleScriptFuncRaw(this, handler, interval, pause)
--     end
-- end

local scaleCfg = {
    {"0.1x", 0.1},
    {"0.2x", 0.2},
    {"0.5x", 0.5},
    {"1x"  , 1  },
    {"2x"  , 2  },
    {"4x"  , 4  },
    {"8x"  , 8  },
    {"16x" , 16 },
}

local cfgCount = #scaleCfg

function M:ctor(pluginName)
    M.super.ctor(self, pluginName)
    self.cfgIndex = self.store:get("cfg_index", 4)
    if self.cfgIndex < 2 then self.cfgIndex = 2 end

    self:updateTimeScale()
end

function M:render()
    for k, v in pairs(scaleCfg) do
        if imgui.radioButton(v[1], self.cfgIndex == k) then
            self.cfgIndex = k
            self:updateTimeScale()
        end

        if k ~= cfgCount then imgui.sameLine() end
    end
end

function M:updateTimeScale()
    local cfg = scaleCfg[self.cfgIndex]
    if not cfg then
        self.cfgIndex = 4
        cfg = scaleCfg[self.cfgIndex]
    end

    self.store:set("cfg_index", self.cfgIndex)

    if cfg then
        scheduler:setTimeScale(cfg[2])
        timeScale = cfg[2]
    end
end

return M
