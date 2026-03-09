---@return Container
return function(control)
---@class Container : Control
local Container = control:newClass()
Container.__type = "Container"

Container.mouseIgnore = false
Container._visible = true
Container.rendering = false
Container.sortOnResize = true
Container._fitToText = false
Container._sortQueued = false

function Container:childrenChanged()
	self:queueSort()
end

function Container:sizeChanged()
	if self.sortOnResize == true then
		self:queueSort()
	end
end

function Container:queueSort()
	self._sortQueued = true
end

function Container:draw()
	if self._sortQueued then
		self._sortQueued = false
		self:sort()
	end
	control.draw(self)
end

function Container:sort() end

return Container
end
