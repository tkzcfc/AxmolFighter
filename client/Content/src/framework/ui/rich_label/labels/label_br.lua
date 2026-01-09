--
-- <br/> 标签解析
--

return function (self, params, default)
	local node = cc.Node:create()
	if not node then
		self:printf("<br> - create node failed")
		return
	end

	local contentSize = cc.size(default.fontSize, default.fontSize)
    node:setAnchorPoint(cc.p(0.5, 0.5))
	node:setContentSize(contentSize)
	node.autoBreakLine = true

	self:addNewLine()

	return {node}
end