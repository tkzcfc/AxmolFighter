


local add_searchPath = cc.FileUtils:getInstance().addSearchPath
function cc.FileUtils:addSearchPath(path, front)
    if path:sub(-1) ~= "/" and path:sub(-1) ~= "\\" then
        path = path .. "/"
    end

    for k, v in pairs(self:getOriginalSearchPaths()) do
        if v == path then
            return
        end
    end

    logI("addSearchPath:", path)
    
    self:purgeCachedEntries()
    add_searchPath(self, path, front)
end

function cc.FileUtils:removeSearchPath(path)
    if path:sub(-1) ~= "/" and path:sub(-1) ~= "\\" then
        path = path .. "/"
    end
    
    local searchPaths = self:getOriginalSearchPaths()
    logI("remove path", path)
    -- dump(searchPaths, "searchPaths")
    table.removebyvalue(searchPaths, path, true)
    self:setSearchPaths(searchPaths)
end

local originalSearchPaths = cc.FileUtils:getInstance():getOriginalSearchPaths()


function cc.FileUtils:saveOriginalSearchPaths()
    originalSearchPaths = cc.FileUtils:getInstance():getOriginalSearchPaths()
end

function cc.FileUtils:restoreOriginalSearchPaths()
    self:setSearchPaths(originalSearchPaths)
    self:purgeCachedEntries()
end

