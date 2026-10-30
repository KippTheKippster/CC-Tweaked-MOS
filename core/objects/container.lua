---@return Container
return function(control)
---@class Container : Control
local Container = control:newClass()
Container.__type = "Container"

Container.mouseIgnore = false
Container.rendering = false
Container._fitToText = false
Container._sortQueued = false
Container._sortIgnore = false


function Container:queueSort()
    if not self._sortIgnore then
        self._sortQueued = true
    end
end

function Container:update()
	control.update(self)
    if self._sortQueued then
        self._sortIgnore = true
		self._sortQueued = false
	    self:callDeferred(function ()
			self._sortIgnore = false
		end)
	    self:sort()
	end
end

function Container:sizeChanged()
	self:queueSort()
end

local function childSortHint(self)
	self:queueSort()
	self:onSortHint()
	self:emitSignal(self.sortHintSignal)
end

function Container:childAdded(c)
	c:connectSignal(c.sortHintSignal, childSortHint, self)
end

function Container:childRemoved(c)
	c:disconnectSignal(c.sortHintSignal, childSortHint)
end

function Container:childrenChanged()
	self:queueSort()
end

function Container:sort() end
function Container:onSortHint() end

return Container
end
