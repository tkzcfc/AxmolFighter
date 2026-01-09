local LaunchView = class("LaunchView", ViewBase)

function LaunchView:ctor()
    LaunchView.super.ctor(self)

    self:loadUI("views/LaunchView", self)
    
    self:runAction(cc.CallFunc:create(function()
        self:initUI()
    end))
end

function LaunchView:initUI()

    local world = af.GameWord.new()
    world:init()

    local ecsManager = world.ecsManager

    local player1 = ecsManager:newEntity()
    local player2 = ecsManager:newEntity()

    player1:addComponent("Component_Move")
    player1:addComponent("Component_Render")
    player1:addComponent("Component_AI")

    player2:addComponent("Component_Render")
     player2:addComponent("Component_AI")
    ecsManager:addSystem("RenderSystem")

    print("---------------------------------------------------[1]")

    ecsManager:removeComponent(player1, "Component_Move")
    player1:destroy()
    player2:addComponent("Component_Move")
    print("---------------------------------------------------[2]")


    for i = 1, 5 do
        world:update(0)
    end

    world = nil
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")

    -- player1:addComponent("Component_Render")
end

return LaunchView