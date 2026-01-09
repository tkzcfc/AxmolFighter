
local Logger = {}

local LogLevel = {
    Info    = 0,
    Debug   = 1,
    Warn    = 2,
    Error   = 3,
    Fatal   = 4,
}
Logger.LogLevel = LogLevel

local logImpl = function(tag, level, ...)
    print(Logger.getLogLevelName(level) .. tostring(tag), ...)
end

-- function Logger.getLogLevelColor(level)
--     if level == LogLevel.Info then
--         return "\033[92m"
--     elseif level == LogLevel.Debug then
--         return "\033[36m"
--     elseif level == LogLevel.Warn then
--         return "\033[33m"
--     elseif level == LogLevel.Error then
--         return "\033[31m"
--     elseif level == LogLevel.Fatal then
--         return "\033[31m"
--     else
--         return "\033[37m"
--     end
-- end

function Logger.getLogLevelName(level)
    if level == LogLevel.Info then
        return "I/"
    elseif level == LogLevel.Debug then
        return "D/"
    elseif level == LogLevel.Warn then
        return "W/"
    elseif level == LogLevel.Error then
        return "E/"
    elseif level == LogLevel.Fatal then
        return "F/"
    else
        return "?/"
    end
end

function Logger.setLoggerImpl(func)
    logImpl = func
end

function Logger.attachTo(cls, TAG)
    cls.logI = function(this, ...) logImpl(this.__cname, LogLevel.Info, ...) end
    cls.logD = function(this, ...) logImpl(this.__cname, LogLevel.Debug, ...) end
    cls.logW = function(this, ...) logImpl(this.__cname, LogLevel.Warn, ...) end
    cls.logE = function(this, ...) logImpl(this.__cname, LogLevel.Error, ...) end
    cls.logF = function(this, ...) logImpl(this.__cname, LogLevel.Fatal, ...) end
end

function logI(...) logImpl("Logger", LogLevel.Info, ...) end
function logD(...) logImpl("Logger", LogLevel.Debug, ...) end
function logW(...) logImpl("Logger", LogLevel.Warn, ...) end
function logE(...) logImpl("Logger", LogLevel.Error, ...) end
function logF(...) logImpl("Logger", LogLevel.Fatal, ...) end

return Logger