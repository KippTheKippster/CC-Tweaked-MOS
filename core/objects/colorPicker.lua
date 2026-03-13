---@param control Control
---@param input Input
---@param style Style
---@return ColorPicker
return function(control, input, style)
---@class ColorPicker : Control
local ColorPicker = control:newClass()
ColorPicker.__type = "ColorPicker"
ColorPicker.list = nil
ColorPicker._h = 1
ColorPicker.list = nil
ColorPicker.open = false
ColorPicker.dragSelectable = true
ColorPicker.listQueue = nil
ColorPicker.shortcutSelection = nil
ColorPicker.optionShadow = false
ColorPicker.inheritStyle = false
ColorPicker.style = style:unique()
ColorPicker._color = 1
---@type integer
ColorPicker.color = nil
ColorPicker:defineProperty('color', {
    get = function (o)
        return o._color
    end,
    set = function (o, value)
        o._color = value
        o.style.backgroundColor = value
        o:queueDraw()
    end
})

---@param p ColorPicker
---@param color integer
local function addColor(p, color)
    ---@type Control
    local b = p.list:addControl()
    local colorStyle = style:unique()
    colorStyle.backgroundColor = color
    colorStyle.textColor = colors.black
    b.inheritStyle = false
    b.style = colorStyle
    b.w = 1
    b.h = 1
    b.text = ""
    b.dragSelectable = true
    b.propogateFocusUp = true
    b.down = function (self)
        p.color = color
        p:queueDraw()
    end
    b.pressed = function (self)
        p:colorPressed(self.style.backgroundColor)
    end
end

function ColorPicker:init(text, color)
    control.init(self, text)

    self.style = style:unique()
    self.color = color
    ---@type FlowContainer
    self.list = self:addFlowContainer()
    self.list.topLevel = true
    self.list.expandW = true
    self.list.h = 1
    self.list.visible = false
    self.list.rendering = false
    self.list.propogateFocusUp = true
    self.list.mouseIgnore = true

    self.list.y = 1
    for i = 0, 15 do
        addColor(self, 2 ^ i)
    end

    input.addRawEventListener(self)
    self:expandChildren()
    self.list:expandChildren()
end

function ColorPicker:queueFree()
    input.removeRawEventListener(self)
    control.queueFree(self)
end

function ColorPicker:sizeChanged()
    self.list:queueSort()
end

function ColorPicker:down()
    self.list.visible = true
end

function ColorPicker:focusChanged()
    if self.focus == false then
        self.list.visible = false
    end
end

function ColorPicker:rawEvent(data)
    if data[1] == "mouse_up" then
        self.list.visible = false
    end
end

function ColorPicker:colorPressed(color) end

return ColorPicker
end