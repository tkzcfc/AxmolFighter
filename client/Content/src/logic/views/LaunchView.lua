local LaunchView = class("LaunchView", ViewBase)

function LaunchView:ctor()
    LaunchView.super.ctor(self)

    self:loadUI("views/LaunchView", self)
    
    local world = af.GameWord.new()
    world:init()

    for i = 1, 5 do
        world:update(0)
    end

    world = nil
end

return LaunchView