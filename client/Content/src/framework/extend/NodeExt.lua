local Node = cc.Node

function Node:findChild(name)
    local children = self:getChildren()
    for idx, child in ipairs(children) do
        if child:getName() == name then
            return child
        end
        local node = child:findChild(name)
        if node then
            return node
        end
    end
    return nil
end

--扩展版本的 getChildByName, 支持 root/child1/child2 的方式索引子节点
function Node:getChild(name)
    local item = self
    for n in name:gmatch("[%w_]+") do
        item = item:getChildByName(n)
        if not item then
            return nil
        end
    end
    return item
end

local AddChild = Node.addChild
function Node:addChild(node,zorder,tag)
    if node == nil then
        logW("Node:addChild == nil")
        logW(debug.traceback())
        return
    end
	if tag then
		return AddChild(self, node, zorder, tag)
	end
	
	if zorder then
		return AddChild(self, node, zorder)
	end
	
    return AddChild(self, node)
end

-- 拿到所有type类型的节点
-- type:节点类型
-- retNodes :返回的节点数组
function Node:getChildrenByType(type,retNodes)
    if not retNodes then
        logW("getChildrenByType retNodes nil")
        logW(debug.traceback())
        return
    end
    local _type = tolua.type(self)
    if _type == type then
        self._name = self:getName()
        table.insert(retNodes,self)
    end
    local children = self:getChildren()
    for _, child in ipairs(children) do
        child:getChildrenByType(type,retNodes)
    end
end

-- 添加模拟定时毁掉函数
function Node:schedule(delay,callback)
    local sequence = cc.Sequence:create(cc.DelayTime:create(delay), cc.CallFunc:create(callback))
    local action = cc.RepeatForever:create(sequence)
    self:runAction(action)
    return action
end