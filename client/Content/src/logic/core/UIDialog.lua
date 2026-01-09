-- @Author: 
-- @Date:   2021-05-07 21:48:33
-- @remark: 弹窗类型UI

local UIDialog = class("UIDialog", UIBase)

function UIDialog:ctor()
	UIDialog.super.ctor(self)

	-- 点击空白自动关闭
	self:setAutoDismiss(true)
end

-- @brief 点击空白处关闭前置条件
function UIDialog:onClickBlankToClosePreconditions()
	if Utils:isShowLoading() then
		if self.__lastLoadingId == Utils.lastTimeOnShowLoading then

			local lastTime = self.__lastLoadingQueryTime
			if lastTime == nil then
				self.__lastLoadingQueryTime = NowEpochMS()
				return false
			end

			-- 超时则不阻止玩家手动关闭
			if NowEpochMS() - lastTime > 5000 then
				return true
			end
		else
			-- 重置查询时间
			self.__lastLoadingId = Utils.lastTimeOnShowLoading
			self.__lastLoadingQueryTime = NowEpochMS()
		end

		return false
	end

	return true
end

return UIDialog

