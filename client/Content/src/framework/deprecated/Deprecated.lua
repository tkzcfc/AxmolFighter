
sp.SkeletonAnimation.createWithJsonFile = sp.SkeletonAnimation.create
sp.SkeletonAnimation.createWithBinaryFile = sp.SkeletonAnimation.create

ccexp = ccexp or {}
ccexp.AudioEngine = cc.AudioEngine

local setSpriteFrame_C = cc.Sprite.setSpriteFrame
cc.Sprite.setSpriteFrame = function(this, value)
    assert(value ~= nil)
    setSpriteFrame_C(this, value)
end


cc.Node.setNodeEventEnabled = function(this, value)
    if value then
        this:enableNodeEvents()
    else
        this:disableNodeEvents()
    end
end