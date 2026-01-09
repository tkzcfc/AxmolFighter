local yasio = require("yasio")

-- 采样间隔
local SAMPLE_INTERVAL = 0.2
-- 采样最大数量
local MAX_SAMPLE_COUNT = 8

-- 当前微秒时间
local function time_us()
    return yasio.highp_clock()
end

local SpeedCalculator = class("SpeedCalculator")

function SpeedCalculator:ctor()
    self.samples = {}
    self.lastBytes = 0
    self.lastTime = time_us()
    table.insert(self.samples, {
        downloaded = 0,
        timespent = 0
    })
end

function SpeedCalculator:collectData(curBytes)
    local count = #self.samples
    local sample = self.samples[count]

    sample.size = math.max(curBytes - self.lastBytes, 0)
    sample.us = self:timediff_us()

    if sample.us > SAMPLE_INTERVAL * 1000000 then
        self.lastBytes = self.lastBytes + sample.size
        self.lastTime = self.lastTime + sample.us
        if count >= MAX_SAMPLE_COUNT then
            table.remove(self.samples, 1)
        end

        table.insert(self.samples, {
            size = 0,
            us = 0
        })
    end
end

function SpeedCalculator:getSpeed()
    local count = 0
    local speed = 0
    for _, sample in pairs(self.samples) do
        if sample.us == 0 and sample.size == 0 then
            break
        end

        count = count + 1

        if sample.us < 1 then
            speed = speed + sample.size * 1000000
        else
            -- 暂不考虑溢出情况
            speed = speed + (sample.size * 1000000) / sample.us
        end
    end

    if count > 0 then
        return speed / count
    end
    return speed    
end

function SpeedCalculator:timediff_us()
    return time_us() - self.lastTime
end


return SpeedCalculator
