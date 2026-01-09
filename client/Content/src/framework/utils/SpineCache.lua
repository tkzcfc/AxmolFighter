local SpineCache = setmetatable({}, {
    __gc = function(this)
        this:clean()
    end
})

SpineCache.pools = {}


local function makeKey(skeletonDataFile, atlasFile)
    return tostring(skeletonDataFile) .. tostring(atlasFile)
end


-- @brief 查询对象池是否有某个动画
function SpineCache:contain(skeletonDataFile, atlasFile)
    local key = makeKey(skeletonDataFile, atlasFile)
    local pool = self:getPool(key)
    if #pool > 0 then
        return true
    end    
    return false
end

-- @brief 预加载
function SpineCache:load(skeletonDataFile, atlasFile)
    local key = makeKey(skeletonDataFile, atlasFile)
    local pool = self:getPool(key)
    if #pool > 0 then
        return
    end

    if not cc.FileUtils:getInstance():isFileExist(skeletonDataFile) then
        return
    end
    
    local node = sp.SkeletonAnimation:create(skeletonDataFile, atlasFile)
    if not node then return end

    node:setUpdateOnlyIfVisible(true)
    node:setVisible(false)
    node._cache_key = key
    
    self:put(node)
end

-- @brief 获取/创建缓存对象
function SpineCache:fetch(skeletonDataFile, atlasFile)
    self:load(skeletonDataFile, atlasFile)

    local key = makeKey(skeletonDataFile, atlasFile)
    local pool = self:getPool(key)
    if #pool > 0 then
        local node = table.remove(pool, 1)
        node:setVisible(true)
        return node
    end
end

-- @brief 归还对象到对象池
function SpineCache:put(node)
    if not node then return end
    local key = node._cache_key
    if not key then return end
    
    node:retain()
    node:removeFromParent()
    table.insert(self:getPool(key), node)
end

function SpineCache:getPool(key)
    local pool = self.pools[key]
    if not pool then
        pool = {}
        self.pools[key] = pool
    end
    return pool
end

-- @brief 清理缓存
function SpineCache:clean()
    for _,pool in pairs(self.pools or {}) do
        for __, v in pairs(pool) do
            v:release()
        end
    end
    self.pools = {}
end

return SpineCache