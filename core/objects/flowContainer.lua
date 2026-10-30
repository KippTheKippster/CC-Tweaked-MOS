---@return FlowContainer
return function(container)
---@class FlowContainer : Container
local FlowContainer = container:newClass()
FlowContainer.__type = "FlowContainer"

function FlowContainer:sort()
	local w = 0
	local h = 0
	local nextH = 0
	for i = 1, #self.children do
		local c = self.children[i]
		c.x = w
		c.y = h
		w = w + c.w
		nextH = math.max(nextH, h + c.h)
		if w >= self.w then
			w = 0
			h = nextH
			self._h = h
		end
	end
end

return FlowContainer
end