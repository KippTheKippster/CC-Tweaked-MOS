---@param container Container
---@return ArrayContainer
return function(container)
---@class ArrayContainer : Container
local ArrayContainer = container:newClass()
ArrayContainer.__type = "ArrayContainer"

ArrayContainer.separation = 0
ArrayContainer.fitToChildrenW = true
ArrayContainer.fitToChildrenH = true
ArrayContainer._maxFillW = -1
ArrayContainer._maxFillH = -1
ArrayContainer._minSizeW = -1
ArrayContainer._minSizeH = -1
ArrayContainer.alignmentMode = "vertical"
ArrayContainer._resetPending = false

local function errorMode(mode)
	local level = 1
	if type(mode) == "string" then
		error("Invalid alignmentMode " .. mode, level)
	else
		error("Invalid alignmentMode, not string!", level)
	end
end

local function ret(a, b, mode)
	if mode == "vertical" then
		return a
	elseif mode == "horizontal" then
		return b
	else
		errorMode(mode)
	end
end

local function h(o, mode)
	return ret(o:getH(), o:getW(), mode)
end


local function minH(o, mode)
	local _w, _h = o:getMinSize()
	return ret(o:toPaddedH(_h), o:toPaddedW(_w), mode)
end

local function minW(o, mode)
	local _w, _h = o:getMinSize()
	return ret(o:toPaddedW(_w), o:toPaddedH(_h), mode)
end

local function desiredSizeH(o, mode)
	local _w, _h = o:getDesiredSize()
	return ret(_h, _w, mode)
end

local function toPaddedH(o, v, mode)
	return ret(o:toPaddedH(v), o:toPaddedW(v), mode)
end

local function setOy(o, value, mode)
	if mode == "vertical" then
		o.y = value
	elseif mode == "horizontal" then
		o.x = value
	else
		errorMode(mode)
	end
end

---@param alignmentMode string
function ArrayContainer:init(alignmentMode)
	self.alignmentMode = alignmentMode
	container.init(self)
end

function ArrayContainer:childrenChanged()
	self._maxFillW, self._maxFillH = -1, -1
	self._minSizeW, self._minSizeH = -1, -1
	self:queueRetransform()
	container.childrenChanged(self)
end

function ArrayContainer:sizeChanged()
    container.sizeChanged(self)
	self._maxFillW, self._maxFillH = -1, -1 -- TODO CHECK
end

function ArrayContainer:containerPreSort()
    self._minSizeW, self._minSizeH = -1, -1
    self._maxFillW, self._maxFillH = -1, -1
end

function ArrayContainer:sort()
	local _w = 0
	local _h = 0
	local expand = false
	for i, c in ipairs(self.children) do
        if c.visible then
            c:containerPreSort()
			setOy(c, _h, self.alignmentMode)
			_h = _h + toPaddedH(c, desiredSizeH(c, self.alignmentMode), self.alignmentMode) + self.separation -- TODO FIX SEPERATION
		end
	end
end

function ArrayContainer:getMinSize()
	local mw, mh = self._minSizeW, self._minSizeH
	if self._minSizeW == -1 or self._minSizeH == -1 then
		mw, mh = container.getMinSize(self)
		local _h = 0
		local _w = 0
		for i, c in ipairs(self.children) do
			if c.visible then
				_h = _h + minH(c, self.alignmentMode) + self.separation
				_w = math.max(_w, minW(c, self.alignmentMode))
			end
		end

		mw, mh = math.max(_w, mw), math.max(_h, mh)
		self._minSizeW, self._minSizeH = mw, mh
	end

	if self.alignmentMode == "vertical" then
		return mw, mh
	else
		return mh, mw
	end
end

function ArrayContainer:getMaxSize()
	return self:getMinSize()
end

function ArrayContainer:getFillSize()
	if self._maxFillW > -1 and self._maxFillH > -1 then
		return self._maxFillW, self._maxFillH
	end

    local _w, _h = container.getFillSize(self)
	if #self.children == 0 then
		return _w, _h
	end

	local expandCount = 0
	if self.alignmentMode == "vertical" then
		for i, c in ipairs(self.children) do
			local minW, minH = c:getMinSize()
			if c.fillH then
				expandCount = expandCount + 1
			else
				_h = _h - c:toPaddedH(minH) - self.separation
			end
		end

		if expandCount > 0 then
			_h = (_h - self.separation * math.max(0, expandCount-1)) / expandCount -- math.floor(h / expandCount)
		end
	else
		for i, c in ipairs(self.children) do
			local minW, minH = c:getMinSize()
			if c.fillW then
				expandCount = expandCount + 1
			else
				_w = _w - c:toPaddedW(minW) - self.separation
			end
		end

		if expandCount > 0 then
			_w = (_w - self.separation * math.max(0, expandCount-1)) / expandCount -- math.floor(h / expandCount)
		end
	end

	_w, _h = math.max(_w, 1), math.max(_h, 1)
	self._maxFillW, self._maxFillH = _w, _h

	return _w, _h
end

return ArrayContainer
end
