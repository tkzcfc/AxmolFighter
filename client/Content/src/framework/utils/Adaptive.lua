local Adaptive = class("Adaptive")

require("framework.utils.Logger").attachTo(Adaptive)

function Adaptive:ctor()
    self:updateDesignedSize()
end

function Adaptive:updateDesignedSize()
    local maxVal = math.max(DESIGNED_RESOLUTION_W, DESIGNED_RESOLUTION_H)
    local minVal = math.min(DESIGNED_RESOLUTION_W, DESIGNED_RESOLUTION_H)
    
    local glview    = cc.Director:getInstance():getRenderView()
    local frameSize = glview:getFrameSize()

    if frameSize.width < frameSize.height then
        self.designedX, self.designedY =  minVal, maxVal
    else
        self.designedX, self.designedY =  maxVal, minVal
    end
    
    self:reset()
end

-- @brief 是否处于竖屏状态
function Adaptive:isOrientationPortrait()
    return self.size.width < self.size.height
end

function Adaptive:setOrientationPortrait(isPortrait)
    local glview    = cc.Director:getInstance():getRenderView()
    local frameSize = glview:getFrameSize()
    local winSize   = cc.Director:getInstance():getWinSize()

    local frameW = math.max(frameSize.width, frameSize.height)
    local frameH = math.min(frameSize.width, frameSize.height)

    local sizeW = math.max(winSize.width, winSize.height)
    local sizeH = math.min(winSize.width, winSize.height)

    -- 计算设计分辨率
    local adaptiveDesignedW = math.max(DESIGNED_RESOLUTION_W, DESIGNED_RESOLUTION_H)
    local adaptiveDesignedH = math.min(DESIGNED_RESOLUTION_W, DESIGNED_RESOLUTION_H)

    -- 竖屏状态下将宽高颠倒
    if isPortrait then
        frameW, frameH = frameH, frameW
        sizeW, sizeH = sizeH, sizeW
        adaptiveDesignedW, adaptiveDesignedH = adaptiveDesignedH, adaptiveDesignedW
    end

    glview:setFrameSize(frameW, frameH)

    -- 限制高分辨率
    local scale = math.max(adaptiveDesignedW / sizeW, adaptiveDesignedH / sizeH)
    sizeW = math.ceil(sizeW * scale)
    sizeH = math.ceil(sizeH * scale)

    -- 根据设备比例进行不同适配
    local autoscale = self:getScaleType(cc.size(sizeW, sizeH), cc.size(adaptiveDesignedW, adaptiveDesignedH))

    if autoscale == "FIXED_WIDTH" then
        glview:setDesignResolutionSize(sizeW, sizeH, cc.ResolutionPolicy.FIXED_WIDTH)
    elseif autoscale == "FIXED_HEIGHT" then
        glview:setDesignResolutionSize(sizeW, sizeH, cc.ResolutionPolicy.FIXED_HEIGHT)
    else
        glview:setDesignResolutionSize(sizeW, sizeH, cc.ResolutionPolicy.EXACT_FIT)
    end

    self:updateDesignedSize()

    gSysEventEmitter:emit(SysEvent.UPDATE_SCREEN_ORIENTATION)
end

function Adaptive:getScaleType(frameSize, designedResolution)
    local designedMin = math.min(designedResolution.width, designedResolution.height)
    local designedMax = math.max(designedResolution.width, designedResolution.height)
    local frameSizeMin = math.min(frameSize.width, frameSize.height)
    local frameSizeMax = math.max(frameSize.width, frameSize.height)

    local designedRatio = designedMax / designedMin
    local frameSizeRatio = frameSizeMax / frameSizeMin

    if frameSizeRatio < designedRatio then
        return "SCALE_ALL"
    else
        if frameSize.width > frameSize.height then
            return "FIXED_HEIGHT"
        else
            return "FIXED_WIDTH"
        end
    end
end

function Adaptive:reset()
    self.size =  cc.Director:getInstance():getVisibleSize()
    self.cx   =  self.size.width * 0.5
    self.cy   =  self.size.height * 0.5
    self.center =  cc.p(self.cx,self.cy)
    self.scaleX            =   self.size.width  / self.designedX
    self.scaleY            =   self.size.height / self.designedY
    self.scaleMax          =   math.max(self.scaleX, self.scaleY)
    self.scaleMin          =   math.min(self.scaleX, self.scaleY)
    self:logI("Adaptive width", self.size.width)
    self:logI("Adaptive height", self.size.height)
end

return Adaptive
