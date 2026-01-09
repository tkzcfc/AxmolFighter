local StorageObject = require("utils.StorageObject")
local BasePlugin = class("BasePlugin")

BasePlugin.winFlags = 0

function BasePlugin:ctor(pluginName)
    self.store = StorageObject.new(pluginName .. ".json")
end

return BasePlugin