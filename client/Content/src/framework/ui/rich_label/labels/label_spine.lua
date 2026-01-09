--
-- <spine/> 标签解析
--

return function (self, params, default)
	if not params.src then
		return 
	end

	local spine = self:getSpine(params.src)
	if not spine then
		self:printf("<spine> - create spine failde")
		return
	end
	if params.scale then
		spine:setScale(params.scale)
	end
	if params.rotate then
		spine:setRotation(params.rotate)
	end
	if params.visible ~= nil then
		spine:setVisible(params.visible)
	end
	if params.anim then
		spine:setAnimation(0, "animation", true)
	end
	if params.offsetx then
		spine:setPositionX(params.offsetx)
	end
	if params.offsety then
		spine:setPositionY(params.offsety)
	end

	local contentSize = spine:getBoundingBox()
	
	if params.width then
		contentSize.width = params.width
	end
	if params.height then
		contentSize.height = params.height
	end

	contentSize.width = contentSize.width * (params.scale or 1)
	contentSize.height = contentSize.height * (params.scale or 1)
	spine:setPosition(contentSize.width / 2 + spine:getPositionX(), contentSize.height / 2 + spine:getPositionY())


	self._leftSpaceWidth = self._leftSpaceWidth - contentSize.width

	local node = cc.Node:create()
	node:addChild(spine)
    node:setAnchorPoint(cc.p(0.5, 0.5))
	node:setContentSize(contentSize)
	node:setCascadeOpacityEnabled(true)
	
	return {node}
end