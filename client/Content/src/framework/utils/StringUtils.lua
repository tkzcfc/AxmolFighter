local StringUtils = {}

local DefaultKeyValuePairs = {
    GetString = function(key, default)
        return default
    end,
    GetBool = function(key, default)
        return default
    end,
    GetNumber = function(key, default)
        return default
    end
}


function StringUtils.parseStringToTable(str)
    local result = {}
    local pos = 1
    local len = #str

    while pos <= len do
        -- 找到键的起始位置（跳过空格）
        local key_start = pos
        while key_start <= len and str:sub(key_start, key_start) == ' ' do
            key_start = key_start + 1
        end
        if key_start > len then break end

        -- 找到键的结束位置（=之前）
        local key_end = key_start
        while key_end <= len and str:sub(key_end, key_end) ~= '=' do
            key_end = key_end + 1
        end
        if key_end > len then break end
        local key = str:sub(key_start, key_end - 1)

        -- 找到值的起始位置（=之后）
        local value_start = key_end + 1
        if value_start > len then break end

        -- 找到值的结束位置（空格或字符串末尾）
        local value_end = value_start
        while value_end <= len and str:sub(value_end, value_end) ~= ' ' do
            value_end = value_end + 1
        end
        local value = str:sub(value_start, value_end - 1)

        -- 存入结果表
        result[key] = value

        -- 移动到下一个键值对
        pos = value_end
    end

    return result
end

function StringUtils.parseKeyValuePairs(text)
    -- local pairs = {}
    -- for key, value in string.gmatch(text, "(%w+)%s*[:=]%s*([#%w%/%-%._]+)") do
    --     pairs[key] = value
    -- end

    local pairs = StringUtils.parseStringToTable(text)

    local keyValuePairs = {}

    keyValuePairs.GetString = function(key, default)
        return pairs[key] or default
    end
    keyValuePairs.GetBool = function(key, default)
        local value = pairs[key]
        if value ~= nil then return value == "true" end
        return default
    end
    keyValuePairs.GetNumber = function(key, default)
        local value = pairs[key]
        if value ~= nil then return tonumber(value) end
        return default
    end

    return keyValuePairs
end

function StringUtils.parseKeyValuePairsFromNode(node)
    if node.cache_extensionData then
        return node.cache_extensionData
    end

    node.cache_extensionData = DefaultKeyValuePairs

    local extDataComponent = node:getComponent("ComExtensionData")
    if extDataComponent then
        local propertyData = extDataComponent:getCustomProperty()
        if propertyData ~= "" then
            node.cache_extensionData = StringUtils.parseKeyValuePairs(propertyData)
        end
    end

    return node.cache_extensionData
end

function StringUtils.hexToRgb(hex)
    hex = hex:gsub("#", "")
    return {
        r = tonumber(hex:sub(1, 2), 16),
        g = tonumber(hex:sub(3, 4), 16),
        b = tonumber(hex:sub(5, 6), 16),
        a = 255,
    }
end

return StringUtils