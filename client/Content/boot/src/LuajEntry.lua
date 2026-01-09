local json = require("cjson")

local bxor = function(a, b)
    return a ~ b
end

if LuaJavaBridge then
    rawCallStaticMethod = LuaJavaBridge.callStaticMethod
    rawCheckStaticMethod = LuaJavaBridge.checkStaticMethod
end

local function luaj_entry_init()
    local luaj_class_name = "dev/axmol/app/Interface"
    local entry_mp = {}
    local found_mp = false

    local fu = ax.FileUtils:getInstance()
    local df = fu:getDefaultResourceRootPath()

    local files_ = fu:listFiles(df)
    for _,f in ipairs(files_) do
        if string.find(f, ".mp") then
            release_print("found .mp at:" .. f)
            local str_ = fu:getDataFromFile(f)
            
            -- 使用二进制解码
            local first = string.byte(str_, 1, 1)
            if first ~= 0xFF then
                print("not begin with 0xFF, not a valid BINARY .mp file")
                break
            end
            local key = string.byte(str_, 2, 2)
            local dst = ""

            for i=3,string.len(str_) do
                local val = bxor(string.byte(str_, i, i), key)
                dst = dst .. string.char(val)
            end

            local success, data_ = pcall(json.decode, dst)
            if not success then
                print(".mp is not a valid json file.")
                break
            end

            dump(data_, " **** data_ ***** ")
            luaj_class_name = data_.class

            for i,v in ipairs(data_.methods) do
                entry_mp[v[1]] = v[2]
            end
            found_mp = true
            break
        end
    end

    if not found_mp then
        release_print(".mp file not found or invalid.")
        -- 有些很老的包没有 mp 文件，需要做兼容。
        return
    end 

    dump(entry_mp, "*********  entry_mp ***********")
    dump(luaj_class_name, "*********  luaj_class_name ***********")

    local targetPlatform = ax.Application:getInstance():getTargetPlatform()
    if targetPlatform == ax.PLATFORM_ANDROID then -- PLATFORM_ANDROID
        if rawCallStaticMethod then
            LuaJavaBridge.callStaticMethod = function(className, methodName, args, sig)
                local new_method_name = entry_mp[methodName]
                if new_method_name == nil then new_method_name = methodName end
                return rawCallStaticMethod(luaj_class_name, new_method_name, args, sig)
            end
        end

        if rawCheckStaticMethod then
            LuaJavaBridge.checkStaticMethod = function(className, methodName, sig)
                local new_method_name = entry_mp[methodName]
                if new_method_name == nil then new_method_name = methodName end
                print("checkStaticMethod:" .. methodName .. " ==>>  " .. new_method_name)
                return rawCheckStaticMethod(luaj_class_name, new_method_name, sig)
            end
        end
    end
end

luaj_entry_init()