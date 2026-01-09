
-- 单个日志文件最大大小
local LOG_FILE_MAX_SIZE<const> = 3 * 1024 * 1024
-- 保留日志文件最大数量
local LOG_FILE_MAX_NUM<const> = 5

local MAX_NUM_OF_LAST_LOG<const> = 120

local str_len = string.len
local pairs = pairs
local tostring = tostring


local fileUtilsInstance = cc.FileUtils:getInstance()
local logRootDir = fileUtilsInstance:getWritablePath() .. "logs/"

-- 创建日志收集目录
if not fileUtilsInstance:isDirectoryExist(logRootDir) then
    fileUtilsInstance:createDirectory(logRootDir)
end

-- 扫描日志目录下的所有.log文件
local logFiles = {}
for k, v in pairs(fileUtilsInstance:listFiles(logRootDir)) do
    local fileName = string.sub(v, string.len(logRootDir) + 1)
    local fileIndex = string.match(fileName, "(%d+)%.log")

    if not fileIndex then
        fileUtilsInstance:removeFile(v)
    else
        -- 日志文件太大，直接清理
        if fileUtilsInstance:getFileSize(v) > 1024 * 1024 * 5 then
            fileUtilsInstance:removeFile(v)
        else
            table.insert(logFiles, v)
        end
    end
end

-- 日志文件排序
table.sort(logFiles, function(a, b)
    local aIndex = string.match(a, "(%d+)%.log")
    local bIndex = string.match(b, "(%d+)%.log")
    aIndex = tonumber(aIndex) or 0
    bIndex = tonumber(bIndex) or 0
    return aIndex < bIndex
end)

-- 删除多余log文件
while #logFiles > LOG_FILE_MAX_NUM do
    fileUtilsInstance:removeFile(table.remove(logFiles, 1))    
end



local lastPrintLogs = {}

local log_queue = {
    "\n\n\n#################start time:" .. tostring(os.date("[%Y/%m/%d %H:%M:%S]", os.time()))
}
local logIndex = 0
local fp = nil
local curLogFileSize = 0
if #logFiles > 0 then
    logIndex = string.match(logFiles[#logFiles], "(%d+)%.log")
    logIndex = tonumber(logIndex) or 0
end


local function openLogFile()
    -- 当前文件名
    local logFileName = logRootDir .. string.format("%d.log", logIndex)

    if fileUtilsInstance:isFileExist(logFileName) then
        curLogFileSize = fileUtilsInstance:getFileSize(logFileName)
    else
        curLogFileSize = 0
    end

    if curLogFileSize > LOG_FILE_MAX_SIZE then
        logIndex = logIndex + 1
        curLogFileSize = 0
        logFileName = logRootDir .. string.format("%d.log", logIndex)
    end

    if fp then
        fp:close()
        fp = nil
    end

    fp = io.open(logFileName, "a+")
end

openLogFile()


local function logWorker()
    if #log_queue <= 0 then return end

    local que = log_queue
    log_queue  ={}
    
    if not fp then return end

    for k, v in pairs(que or {}) do
        curLogFileSize = curLogFileSize + str_len(v) + 1
        fp:write(v)
        fp:write("\n")
    end
    fp:flush()

    if curLogFileSize > LOG_FILE_MAX_SIZE then
        openLogFile()
    end
end
cc.Director:getInstance():getScheduler():scheduleScriptFunc(logWorker, 1, false)


local isWindows = cc.Application:getInstance():getTargetPlatform() == 0
local isPrintLog = false
if gConfigData then
    isPrintLog = gConfigData["PrintDebugLog"]
end

local lastTime = 0
local lastTimeStr = ""
print = function (...)
    if not ... then return end
    
    local args = {...}
    local s = ""
    for __ , v in pairs(args) do
        s = s .. tostring(v) .. "    "
    end

    if isWindows or isPrintLog then
        release_print(s)
    end

    -- 添加时间
    local now = os.time()
    if lastTime ~= now then
        lastTime = now
        lastTimeStr = os.date("[%Y/%m/%d %H:%M:%S]", lastTime)
    end
    s = lastTimeStr .. s

    table.insert(log_queue, s)

    if #lastPrintLogs > MAX_NUM_OF_LAST_LOG * 2 then
        local t = {}
        for i = MAX_NUM_OF_LAST_LOG, #lastPrintLogs do
            table.insert(t, lastPrintLogs[i])
        end
        lastPrintLogs = t
    end
    table.insert(lastPrintLogs, s)
end

function GetLastLogs()
    local logs = lastPrintLogs
    local logNum = #logs

    if logNum > MAX_NUM_OF_LAST_LOG then
        logs = {}
        for i = logNum - MAX_NUM_OF_LAST_LOG + 1, logNum do
            table.insert(logs, lastPrintLogs[i])
        end
    end
    return logs
end

function FlushLogFile()
    logWorker()
end

