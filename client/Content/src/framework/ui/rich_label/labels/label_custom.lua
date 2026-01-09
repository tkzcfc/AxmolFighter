--
-- <custom/> 标签解析
--

return function (self, params, default)
	local node = self:doCustomSpawn(params)
	if not node then
		self:printf("<custom> - create node failed")
		return
	end
	
    node:setAnchorPoint(cc.p(0.5, 0.5))

	local contentSize = node:getBoundingBox()
	self._leftSpaceWidth = self._leftSpaceWidth - contentSize.width

	return {node}
end