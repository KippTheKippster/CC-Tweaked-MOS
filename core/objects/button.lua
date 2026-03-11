---@return Button
return function(control, styleDown, styleDisabled)
---@class Button : Control
local Button = control:newClass()
Button.__type = "Button"
Button.isClicked = false
Button.disabled = false

Button.styleDown = styleDown
Button.styleDisabled = styleDisabled

function Button:getStyle()
    if self.disabled then
        return self.styleDisabled
    elseif self.isClicked then
        return self.styleDown
    elseif self.inheritStyle then
        return self.parent:getStyle()
    else
        return self.style
    end
end

function Button:down(b, x, y)
    self.isClicked = true
    self:queueDraw()
end

function Button:up(b, x, y)
    self.isClicked = false
    self:queueDraw()
end

return Button
end
