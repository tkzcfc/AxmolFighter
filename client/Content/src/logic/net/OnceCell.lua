
local EventEmitter = require("framework.utils.EventEmitter")

local OnceCell = class("OnceCell", EventEmitter)

function OnceCell:ctor(task)
    OnceCell.super.ctor(self)

    self.task = task
    self.isFetching = false
    self.isExpired = false
    self.asyncFetchHandler = nil
end

function OnceCell:syncFetch()
    return self.cacheData
end

function OnceCell:tryFetch()
    local done = false
    local tag = self.tagSeed or 0
    self.tagSeed = tag + 1

    self:fetch(function()
        done = true
    end, tag)

    -- timeout 10s
    local timeout = NowEpochMS() + 10000
    while not done do
        sleep(0.1) -- 等待fetch完成
        if NowEpochMS() > timeout then
            done = true
        end
    end

    self:cancelFetch(tag)
    return self:syncFetch()
end

function OnceCell:fetch(callback, tag)
    -- 有缓存数据，直接返回
    if self.cacheData then
        if callback then callback(self.cacheData) end

        if not self.isExpired then
            return
        end
    else
        if callback then
            self:once("fetch_result", callback, tag)
        end
    end

    -- 防止多次调用
    if self.asyncFetchHandler then return end

    self.asyncFetchHandler = go(function()
        while true do
            local data = self.task()

            if data then
                self:setData(data)
                break
            -- else
            --     -- 如果之前有数据，新的请求失败也无所谓
            --     if self.cacheData then
            --         self:setData(self.cacheData)
            --         break
            --     end
            end

           sleep(5) -- 等待一段时间后重试
        end
    end)
end

function OnceCell:cancelFetch(tag)
    self:offByTag(tag)
end

-- @brief 设置过期
function OnceCell:setExpired(cleanData)
    self.isExpired = true
    if cleanData then
        self.cacheData = nil
    end
end

-- @brief 是否有有效数据
-- @return true 有有效数据
function OnceCell:hasValidData()
    return self.cacheData ~= nil and not self.isExpired
end

-- @brief 是否有数据
function OnceCell:hasData()
    return self.cacheData
end

-- @brief 设置数据
function OnceCell:setData(data)
    local oldData = self.cacheData
    self.cacheData = data
    self.isExpired = false

    if self.asyncFetchHandler then
        kill(self.asyncFetchHandler)
        self.asyncFetchHandler = nil
    end
    
    self:emit("fetch_result", self.cacheData)

    if oldData and table.equals(oldData, self.cacheData) then
        print("数据一致，不更新")
    else
        -- 通知外部更新数据
        self:emit("update", self.cacheData)
    end
end

return OnceCell