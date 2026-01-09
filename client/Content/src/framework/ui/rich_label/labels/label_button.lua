
--
-- <button/> 标签解析
--

local defaultTexture = "Default/Button_Disable.png"

return function (self, params, default)
	local btn = ccui.Button:create()
	btn:setSwallowTouches(true)
	btn:loadTextureNormal(params.src or defaultTexture)

	if params.scale then
		btn:setScale(params.scale)
	end
	if params.rotate then
		btn:setRotation(params.rotate)
	end
	if params.visible ~= nil then
		btn:setVisible(params.visible)
	end
	if params.content ~= nil then
		btn:setTitleText(params.content)
	end

	local contentSize = btn:getBoundingBox()
	self._leftSpaceWidth = self._leftSpaceWidth - contentSize.width

	return {btn}
end