StringUtils = {}


-- @brief 数字转字符串 并根据情况添加逗号、点等符号
-- @param
-- @param forceInteger 强制转为整数
function StringUtils.numToString(number, forceInteger, showComma)

    local formatted
    if forceInteger then
        formatted = string.format("%d", number)
    else
        formatted = string.format("%f", number)
    end

    -- 显示逗号
    if showComma then
        local k
        while true do
            formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
            if k == 0 then break end
        end
    end

    return formatted
end

-- @param 固定小数位
--        如str为0.1        固定位数为3   则返回0.100
--        如str为100.1456   固定位数为0   则返回100
-- @param str: string
-- @param decimalPlaces: number 小数位
function StringUtils.fixedDecimalPlaces(str, decimalPlaces)
    local dp1 = StringUtils.getDecimalPlaces(str)
    -- 小数位数一致
    if dp1 == decimalPlaces then
        return str
    end

    if dp1 > decimalPlaces then
        if decimalPlaces == 0 then
            return string.sub(str, 1, -(dp1 - decimalPlaces + 2))
        end
        return string.sub(str, 1, -(dp1 - decimalPlaces + 1))
    else
        if dp1 == 0 then
            str = str .. "."
        end

        return str .. string.rep("0", decimalPlaces - dp1)
    end
end

-- @brief 获取小数点后面位数
--        如str为100.1456   返回4
-- @param str: string
function StringUtils.getDecimalPlaces(str)
    -- 小数点后面的位数
    local decimalPlaces = 0

    local s, e = string.find(str, "%.%d*")
    if s then
        decimalPlaces = e - s
    else
        decimalPlaces = 0
    end
    return decimalPlaces
end

function StringUtils.fmtBytes(count)
    if count > 1024 * 1024 then
        return string.format("%.1fMB", count / 1024 / 1024)
    else
        return string.format("%dKB", count / 1024)
    end
end

function StringUtils.formatTime(seconds)
    local sec = seconds % 60
    local min = math.floor(seconds / 60) % 60
    local hour = math.floor(seconds / 3600)
    return string.format("%02d:%02d:%02d", hour, min, sec)
end

-- @brief 将纳秒转换为秒
function StringUtils.nanoToSeconds(nanoSeconds)
    return math.floor(nanoSeconds / 10000000)
end

-- @brief 将纳秒数格式化为年月日时分秒字符串
function StringUtils.formatNanoTime(nanoSeconds)
    local year, month, day, hour, min, second, _, _  = game_utils.i64_to_datetime(nanoSeconds)
	local time_day_fmt = "%04d-%02d-%02d"
    local time_hour_fmt = "%02d:%02d:%02d"
	local time_day = time_day_fmt:format(year, month, day)
    local time_hour = time_hour_fmt:format(hour, min, second)
	return time_day .. " " .. time_hour
end

-- @brief 将秒数格式化为天、小时、分钟、秒的字符串
function StringUtils.formatTimeDiff(seconds)
    if seconds <= 0 then
        return "00:00"
    end

    local days = math.floor(seconds / (24 * 60 * 60))
    seconds = seconds % (24 * 60 * 60)
    
    if days > 0 then
        -- email_14:	%d天
        return string.format(TR("email_14"), days)
    else
        local hours = math.floor(seconds / 3600)
        seconds = seconds % 3600
        local minutes = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        
        -- 根据是否有小时来决定显示格式
        if hours > 0 then
            return string.format("%02d:%02d:%02d", hours, minutes, secs)
        else
            return string.format("%02d:%02d", minutes, secs)
        end
    end
end

-- @brief 获取传入时间到当前时间的差值字符串
function StringUtils.getTimeDiffToNowString(pastTime)
    local utc_timestamp = os.time()
    local diff = utc_timestamp - pastTime
    return StringUtils.formatTimeDiff(diff)
end

-- @brief 获取当前时间到传入时间的差值字符串
function StringUtils.getTimeDiffFromNowString(futureTime)
    local utc_timestamp = os.time()
    local diff = futureTime - utc_timestamp
    return StringUtils.formatTimeDiff(diff)
end

-- @brief 格式化倒计时秒数
-- 30秒 -> 30秒
-- 59秒 -> 59秒
-- 60秒 -> 1分钟
-- 90秒 -> 1分钟30秒
-- 120秒 -> 2分钟
-- 3500秒 -> 58分钟20秒
-- 3600秒 -> 1小时
-- 3660秒 -> 1小时1分钟
-- 7200秒 -> 2小时
-- 86399秒 -> 23小时59分钟
-- 86400秒 -> 1天
-- 86401秒 -> 1天
-- 90000秒 -> 1天1小时
-- 172800秒 -> 2天
-- 176400秒 -> 2天1小时
function StringUtils.formatCountdown(seconds)
    -- 多语言:
    -- lobby_130   {0}天
    -- lobby_131   {0}小时
    -- lobby_132   {0}分钟
    -- lobby_133   {0}秒
    -- lobby_134   {0}天{1}小时
    -- lobby_135   {0}小时{1}分钟
    -- lobby_136   {0}分钟{1}秒

    if not seconds or seconds < 0 then
        return fmt(TR("lobby_133"), 0)
    end
    
    -- 将秒数转换为整数
    seconds = math.floor(seconds)
    
    -- 如果小于1分钟
    if seconds < 60 then
        return fmt(TR("lobby_133"), seconds)
    end
    
    -- 如果小于1小时
    if seconds < 3600 then
        local minutes = math.floor(seconds / 60)
        local remainingSeconds = seconds % 60
        
        if remainingSeconds == 0 then
            return fmt(TR("lobby_132"), minutes)
        else
            return fmt(TR("lobby_136"), minutes, remainingSeconds)
        end
    end
    
    -- 如果小于24小时
    if seconds < 86400 then
        local hours = math.floor(seconds / 3600)
        local remainingMinutes = math.floor((seconds % 3600) / 60)
        
        if remainingMinutes == 0 then
            return fmt(TR("lobby_131"), hours)
        else
            return fmt(TR("lobby_135"), hours, remainingMinutes)
        end
    end
    
    -- 24小时及以上
    local days = math.floor(seconds / 86400)
    local remainingHours = math.floor((seconds % 86400) / 3600)
    
    if remainingHours == 0 then
        return fmt(TR("lobby_130"), days)
    else
        return fmt(TR("lobby_134"), days, remainingHours)
    end
end



















for k, v in pairs(require("framework.utils.StringUtils")) do
    if StringUtils[k] == nil then
        StringUtils[k] = v
    end
end
