---@return Checkbox
return function(button)
---@class Checkbox : Button
local Checkbox = button:newClass()
Checkbox.__type = "Checkbox"
Checkbox._checked = false
---@type boolean
Checkbox.checked = nil
Checkbox:defineProperty('checked', {
    get = function (o)
        return o._checked
    end,
    set = function (o, value)
        o._checked = value
        o:queueDraw()
    end
})

function Checkbox:init(text, checked)
    button.init(self, text)
    self.marginR = math.min(3, #self.text)
    self.minW = 3
    self._checked = checked
    self:resize()
    self.w = 3
end

function Checkbox:render()
    local s = self.style
    --SHADOW
    self:drawShadow(s)
    --PANEL
    local l, u, r, d = self:getBorders()
    self:drawPanel(l, u, r, d, s)
    --TEXT
    self:write(self.text, s)
    s = self:getStyle()
    term.setCursorPos(self.gx + self.w - 2, self.gy + 1)
    term.setTextColor(s.textColor)
    term.setBackgroundColor(s.backgroundColor)
    if self.checked then
        term.write("[x]")
    else
        term.write("[ ]")
    end
end

function Checkbox:pressed()
    self.checked = self.checked == false
end

return Checkbox
end
