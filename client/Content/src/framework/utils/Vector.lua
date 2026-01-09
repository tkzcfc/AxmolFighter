local Vector = {}

local function retain(obj)
	if obj and type(obj) == "userdata" and obj.retain then
		obj:retain()
	end
end

local function release(obj)
	if obj and type(obj) == "userdata" and obj.release then
		obj:release()
	end
end


function Vector:new(needRetain)
	local object = setmetatable({}, self)
	self.__index = self

	object.__data_arr = {}
	object.__need_retain = needRetain or false

	return object
end

function Vector:insert(index, obj)
	assert(index > 0 and index <= #self.__data_arr + 1)
	table.insert(self.__data_arr, index, obj)
	if self.__need_retain then
		retain(obj)
	end
end

function Vector:at(index)
	return self.__data_arr[index]
end

function Vector:back()
	return self.__data_arr[#self.__data_arr]
end

function Vector:front()
	return self.__data_arr[1]
end
	
function Vector:size()
	return #self.__data_arr
end

function Vector:empty()
	return #self.__data_arr <= 0
end

function Vector:popFront()
	local obj = table.remove(self.__data_arr, 1)
	if self.__need_retain then
		release(obj)
	end
	return obj
end

function Vector:popBack()
	local obj = table.remove(self.__data_arr)
	if self.__need_retain then
		release(obj)
	end
	return obj
end

function Vector:clear()
	if self.__need_retain then
		for i = 1, #self.__data_arr do
			release(self.__data_arr[i])
		end
	end
	self.__data_arr = {}
end

function Vector:pushBack(obj)
	table.insert(self.__data_arr, obj)
	if self.__need_retain then
		retain(obj)
	end
end

function Vector:contains(obj)
	for key, var in ipairs(self.__data_arr) do
		if (var == obj) then
			return true
		end
	end
	return false
end

function Vector:getIndex(obj)
	for key, var in ipairs(self.__data_arr) do
		if (var == obj) then
			return key
		end
	end
end

function Vector:erase(index)
	if self.__need_retain then
		release(self.__data_arr[index])
	end
	table.remove(self.__data_arr, index)
end

function Vector:eraseObject(obj)
	for key, var in ipairs(self.__data_arr) do
		if (var == obj) then
			if self.__need_retain then
				release(self.__data_arr[key])
			end
			table.remove(self.__data_arr, key)
			return true
		end
	end
	return false
end

function Vector:__gc()
	self:clear()
end

function Vector:data()
	return self.__data_arr
end

return Vector

