---@return Icon
return function(control)
---@class Icon : Control
local Icon = control:newClass()
Icon.__type = "Icon"

---@type table
Icon.texture = nil
Icon._texture = nil


---@type boolean
Icon.centered = nil
Icon._centered = false
Icon.offsetX = 0
Icon.offsetY = 0

Icon:defineProperty('texture', {
    get = function(o) return o._texture end,
    ---@param o Icon
    ---@param value table
    set = function(o, value)
        local same = o._texture == value
        o._texture = value
        if same == false then
            o:resize()
            o:queueDraw()
        end
    end
})

Icon:defineProperty('centered', {
    get = function(o) return o._centered end,
    set = function(o, value)
        local same = o._centered == value
        o._centered = value
        if same == false then
            o:centerPosition()
        end
    end
})

function Icon:treeEntered()
    control.treeEntered(self)
    if self.centered == true then
        self:centerPosition()
    end
end

function Icon:render()
    if self.texture == nil then return end
	paintutils.drawImage(self.texture, self.gx + 1 + self.offsetX, self.gy + 1 + self.offsetY)
end

function Icon:getTextureSize()
    if self.texture == nil then
        return 0, 0
    end
	local w = 0
	local h = #self.texture
	for i = 1, #self.texture do
		w = math.max(w, #self.texture[i])
	end

	return w, h
end

function Icon:getMinimumSize()
    local minW, minH = control.getMinimumSize(self)
    local tW, tH = self:getTextureSize()
    return math.max(minW, tW), math.max(minH, tH)
end

function Icon:centerPosition()
    if self.parent == nil then return end
    local pW, pH = self.parent.w, self.parent.h
    self.x = (pW - self.w) / 2.0 + self.offsetX
    self.y = (pH - self.h) / 2.0 + self.offsetY
end

function Icon:transformChanged()
    if self.centered  == true then
        self:centerPosition()
    end
end

return Icon
end