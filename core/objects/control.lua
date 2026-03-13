---@return Control
---@param object Object
---@param engine Engine
---@param style Style
return function(object, engine, style)
---@class Control : Object
local Control = object:newClass()
Control.__type = "Control"

---Global X, the x offset in the term irrelevant of the parent's position
---@type number
Control.gx = nil
Control._gx = 0

---Global Y, the y position in the term irrelevant of the parent's position
---@type number
Control.gy = nil
Control._gy = 0

---Local X, the x offset from the parent
---@type number
Control.x = nil
Control._x = 0

---Local Y, the y offset from the parent
---@type number
Control.y = nil
Control._y = 0

---Width
---@type number
Control.w = nil
Control._w = 1

---Height
---@type number
Control.h = nil
Control._h = 1

---Minimum Width, the absolute minimum width of the object, note that the actual minimum width can be higher (see control.getMinimumSize)
---@type number
Control.minW = nil
Control._minW = 1

---Minimum Height, the absolute minimum height of the object, note that the actual minimum height can be higher (see control.getMinimumSize)
---@type number
Control.minH = nil
Control._minH = 1

---@type boolean
Control.expandW = nil
Control._expandW = false

---@type boolean
Control.expandH = nil
Control._expandH = false

---@type boolean
Control.fitToText = nil
Control._fitToText = true

---@type string
Control.text = nil
Control._text = ""

---@type Style
Control.style = style

---@type boolean
Control.visible = nil
Control._visible = true

Control.inheritStyle = false
Control.centerText = false
Control.focus = false
Control.propogateFocusUp = false
Control.clipText = true
Control.mouseIgnore = false
Control.rendering = true
Control.draggable = false
Control.dragSelectable = false
Control.topLevel = false
---@type table
Control.children = {}
---@type Control
Control.parent = nil
Control._marginL = 0
---@type number
Control.marginL = nil
Control._marginR = 0
---@type number
Control.marginR = nil
Control.offsetTextX = 0

---@enum Anchor
Control.Anchor = { LEFT = 0, RIGHT = 1, UP = 2, DOWN = 3, CENTER = 4 }

---@type Anchor
Control.anchorW = nil
---@type Anchor
Control.anchorH = nil

---@type Anchor
Control._anchorW = Control.Anchor.LEFT
---@type Anchor
Control._anchorH = Control.Anchor.UP

Control.visibilityChangedSignal = Control:createSignal()
Control.focusChangedSignal = Control:createSignal()

Control:defineProperty('gx', {
    get = function(o) return o._gx end,
    set = function(o, value)
        local same = o._gx == value
        o._gx = value
        if same == false then
            o:updateGlobalPosition()
            o:transformChanged()
            o._x = o._gx - o.parent._gx
        end
    end
})

Control:defineProperty('gy', {
    get = function(o) return o._gy end,
    set = function(o, value)
        local same = o._gy == value
        o._gy = value
        if same == false then
            o:updateGlobalPosition()
            o:transformChanged()
            o._y = o._gy - o.parent._gy
        end
    end
})

function Control:updateGlobalPosition()
    for i = 1, #self.children do
        local c = self:getChild(i)
        c.gx = self.gx + c.x
        c.gy = self.gy + c.y
    end

    --self._x = self.parent.globalX - self.globalX
    --self._y = self.parent.globalY - self.globalY

    self:queueDraw()
end

Control:defineProperty('x', {
    get = function(o)
        return o._x end,
    set = function(o, value)
        local same = o._x == value
        o._x = value
        if same == false then
            o:updatePosition()
            o:transformChanged()
        end
    end
})

Control:defineProperty('y', {
    get = function(o) return o._y end,
    set = function(o, value)
        local same = o._y == value
        o._y = value
        if same == false then
            o:updatePosition()
            o:transformChanged()
        end
    end
})

function Control:updatePosition()
    if self.parent == nil then
        error("Unable to update position control with no parent! __name: " .. self.__name, 4)
    end

    self.gx = self.parent.gx + self.x
    self.gy = self.parent.gy + self.y
    self:queueDraw()
end

Control:defineProperty('w', {
    get = function(o) return o._w end,
    set = function(o, value)
        local same = o._w == value
        o._w = value
        if same == false then
            o:queueDraw()
            o:transformChanged()
            o:expandChildren()
            o:sizeChanged()
        end
    end
})

Control:defineProperty('h', {
    get = function(o) return o._h end,
    set = function(o, value)
        local same = o._h == value
        o._h = value
        if same == false then
            o:queueDraw()
            o:transformChanged()
            o:expandChildren()
            o:sizeChanged()
        end
    end
})

Control:defineProperty('minW', {
    get = function(o) return o._minW end,
    set = function(o, value)
        local same = o._minW == value
        o._minW = value
        if same == false then
            o:resize()
        end
    end
})

Control:defineProperty('minH', {
    get = function(o) return o._minH end,
    set = function(o, value)
        local same = o._minH == value
        o._minH = value
        if same == false then
            o:resize()
        end
    end
})


Control:defineProperty('expandW', {
    get = function(o) return o._expandW end,
    set = function(o, value)
        local same = o._expandW == value
        o._expandW = value
        if same == false and o._expandW == true then
            o:resize()
        end
    end
})

Control:defineProperty('expandH', {
    get = function(o) return o._expandH end,
    set = function(o, value)
        local same = o._expandH == value
        o._expandH = value
        if same == false then
            o:resize()
        end
    end
})

Control:defineProperty('marginL', {
    get = function(o) return o._marginL end,
    set = function(o, value)
        local same = o._marginL == value
        o._marginL = value
        if same == false then
            o:resize()
            --o:expandChildren()
        end
    end
})

Control:defineProperty('marginR', {
    get = function(o) return o._marginR end,
    set = function(o, value)
        local same = o._marginR == value
        o._marginR = value
        if same == false then
            o:resize()
            --o:expandChildren()
        end
    end
})

---@param text string?
function Control:init(text)
    object.init(self, text)
    self.children = {}
    if text then
        self._text = text
    end
end

function Control:expandChildren()
    for i, _ in ipairs(self.children) do
        self:getChild(i):resize()
    end
end

function Control:resize()
    local minW, minH = self:getMinimumSize()
    local c = self
    local p = c.parent
    if not p then
        return
    end

    local w, h = 0, 0
    if c.expandW then
        w = p.w - p.marginR - c.x
    elseif not c.fitToText then
        w = self.w
    end

    if c.expandH then
        h = p.h - c.y
    elseif not c.fitToText then
        h = self.h
    end

    c.w, c.h = math.max(minW, w), math.max(minH, h)

    -- HACK! rework anchor
    if c.anchorW == Control.Anchor.RIGHT then
        c.x = p.w - c.w
    elseif c.anchorW == Control.Anchor.CENTER then
        c.x = math.floor(p.w / 2 + 0.5) - math.floor(c.w / 2 + 0.5)
    end

    if c.anchorH == Control.Anchor.DOWN then
        c.y = p.h - c.h
    elseif c.anchorH == Control.Anchor.CENTER then
        c.y = math.floor(p.h / 2 + 0.5) - math.floor(c.h / 2 + 0.5)
    end
end

function Control:getMinimumSize()
    if not self.visible then
        return 0, 0
    end

    local m = self.marginL + self.marginR
    local minW = self.minW + m
    local minH = self.minH
    if self.fitToText then
        minW = math.max(#self.text + m, minW)
        minH = math.max(1, minH)
    end

    return minW, minH
end

Control:defineProperty('fitToText', {
    get = function(o) return o._fitToText end,
    set = function(o, value)
        o._fitToText = value
        o:resize()
    end
})

Control:defineProperty('text', {
    get = function(o) return o._text end,
    set = function(o, value)
        local same = o._text == value
        o._text = value
        if same == false then
            o:resize()
            o:queueDraw()
            o:textChanged()
        end
    end
})

---@param o Control
local function propogateVisiblity(o)
    for i = 1, #o.children do
        local c = o.children[i]
        if c.visible == true then
            c:visibilityChanged()
            c:emitSignal(o.visibilityChangedSignal)
            propogateVisiblity(c)
        end
    end
end

Control:defineProperty('visible', {
    get = function(o) return o._visible end,
    set = function(o, value)
        local same = o._visible == value
        o._visible = value
        if same == false then
            o:visibilityChanged()
            o:emitSignal(o.visibilityChangedSignal)
            propogateVisiblity(o)
            o:queueDraw()
        end
    end
})

Control:defineProperty('anchorW', {
    get = function(o) return o._anchorW end,
    set = function(o, value)
        local same = o._anchorW == value
        o._anchorW = value
    end
})

Control:defineProperty('anchorH', {
    get = function(o) return o._anchorH end,
    set = function(o, value)
        local same = o._anchorH == value
        o._anchorH = value
        if same == false then


        end
    end
})

Control.shadow = false -- Change this to style

function Control:queueFree()
    table.insert(engine.freeQueue, self)
    if self:inFocus() then
        self:releaseFocus()
    end
end

function Control:queueDraw()
    engine.queueRedraw = true
end

function Control:getBorders()
    local left = self._gx + 1
    local up = self._gy + 1
    local right = self._gx + self._w
    local down = self._gy + self._h
    return left, up, right, down
end

function Control:getStyle()
    if self.inheritStyle then
        return self.parent:getStyle()
    else
        return self.style
    end
end

-- Determines how the control object is drawn
function Control:render()
    local s = self:getStyle()
    --SHADOW
    self:drawShadow(s)
    --PANEL
    local l, u, r, d = self:getBorders()
    self:drawPanel(l, u, r, d, s)
    --TEXT
    self:write(self.text, s)
end

-- Draws the control object if it is valid, NOTE this should not be used to redraw object, use 'queueDraw' instead
function Control:draw()
    if self.visible == false or self.rendering == false or self.parent == nil then
        return
    end

    self:render()
end

local function writeShadow(x, y)
    local char = engine.getChar(x, y)
    if not char then
        return
    end

    term.setCursorPos(x, y)
    term.setTextColor(char.textColor)
    term.setBackgroundColor(char.backgroundColor)
    term.write(string.char(127))
end

---@param style Style?
function Control:drawShadow(style)
    if self.shadow ~= true then return end
    if self.w == 0 or self.h == 0 then return end
    local s = style or self:getStyle()
    for i = 1 - s.shadowOffsetU, self.h do
        writeShadow(self.gx + self.w + 1, self.gy + i)
    end

    for i = 1 - s.shadowOffsetU, self.h do
        writeShadow(self.gx, self.gy + i)
    end

    for i = 0, self.w + 1 do
        writeShadow(self.gx + i, self.gy + self.h + 1)
    end
end

---@param left number
---@param up number
---@param right number
---@param down number
---@param style Style?
function Control:drawPanel(left, up, right, down, style)
    local s = style or self:getStyle()
    if s.background == true or s.background == nil then
        paintutils.drawFilledBox(
            left,
            up,
            right,
            down,
            s.backgroundColor
        )
    end

    if s.border then
        paintutils.drawBox(
            left,
            up,
            right,
            down,
            s.borderColor
        )
    end
end

local function getTextPosition(_x, _y, _w, _h, center, text)
    local x = 0
    local y = 0
    if center == false then
        x = _x
        y = _y
    else
        x = _x + math.ceil((_w - #text) / 2)
        y = _y + math.floor((_h) / 2)
    end

    return x + 1, y + 1
end

function Control:getTextPosition(text)
    return getTextPosition(self._gx, self._gy, self._w, self._h, self.centerText, text)
end

---@param text string
---@param style Style?
function Control:write(text, style)
    if text == "" or text == nil then
        return
    end

    local st = style or self:getStyle()
    local m = self.marginR + self.marginL
    local l = #text - m
    if self.clipText == true then
        l = math.min(#text, self.w - m - 1)
    end
    local s = self.offsetTextX + 1

    local _x, _y = self:getTextPosition(text)
    _x = _x + self.marginL

    term.setCursorPos(_x, _y)
    term.setTextColor(st.textColor)
    term.setBackgroundColor(st.backgroundColor)

    local x, y = term.getCursorPos()
    local t = text:sub(s, s + l)
    for i = 1, #t do
        term.write(t:sub(i, i))
        x = x + 1
        term.setCursorPos(x, y)
    end
end

---Add the Control object 'o' as a child
---@param o Control
function Control:add(o)
    if o.parent then
        error("Attempting to add a child that already has a parent! __name: " .. o.__name, 2)
    end

    table.insert(self.children, o)
    o.parent = self
    o.gx = self.gx + o.x
    o.gy = self.gy + o.y
    o.treeEntered(o) -- TODO Maybe make recursive
    o:resize()
    self:childrenChanged()
    --self:expandChildren()
    self:queueDraw()
end

---@return Control
---@param i integer
function Control:getChild(i)
    return self.children[i]
end

---Removes the Control object 'o' from the parent, NOTE if you want to delete the object use queueFree instead
---@param o Control
function Control:remove(o)
    for i = 1, #self.children do
        if self.children[i] == o then
            table.remove(self.children, i)
            break
        end
    end

    o.parent = nil
    self:childrenChanged()
    self:queueDraw()
end

function Control:freeChildren()
    for i, b in ipairs(self.children) do
        b:queueFree()
    end
    self.children = {}
end

---@param button integer
---@param rx number
---@param ry number
---@param x number
---@param y number
function Control:drag(button, x, y, rx, ry)
    if not self.draggable then return end
    self.gx = self.gx + rx
    self.gy = self.gy + ry
end

function Control:toFront()
    if self.parent.children[#self.parent.children] == self then return end
    engine.utils.pushBottom(self.parent.children, self)
    self:queueDraw()
end

function Control:toBack()
    if self.parent.children[1] == self then return end
    engine.utils.pushTop(self.parent.children, self)
    self:queueDraw()
end

---@return boolean
function Control:inFocus()
    if self.focus == true then return true end

    for i = 1, #self.children do
        if self.children[i]:inFocus() then
            return true
        end
    end

    return false
end

---@return boolean
function Control:isVisible()
    if self.visible == false then return false end
    if self.parent == nil then return true end
    return self.parent:isVisible()
end

---@return boolean
function Control:isOnScreen()
    local w, h = engine.screenBuffer.getSize()
    return (
        self.gx >= 0 and
        self.gy >= 0 and
        self.gx + self.w <= w and
        self.gy + self.h <= h
    )
end

function Control:grabFocus()
    engine.input.grabControlFocus(self)
end

function Control:releaseFocus()
    engine.input.releaseControlFocus(self)
end

function Control:grabCursor()
    engine.input.setCursorControl(self)
    self:updateCursor()
end

function Control:releaseCursor()
    engine.input.setCursorControl(nil)
end

function Control:grabInput()
    engine.input.setInputControl(self)
end

function Control:releaseInput()
    engine.input.setInputControl(nil)
end

--Event Functions that can be overwritten
function Control:treeEntered() end
function Control:childrenChanged() end
function Control:down(button, x, y) end
function Control:up(button, x, y) end
function Control:pressed(button, x, y) end
function Control:doublePressed(button, x, y) end
function Control:scroll(dir, x, y) end
function Control:focusChanged() end
function Control:updateCursor() end
function Control:input(data) end

function Control:textChanged() end
function Control:sizeChanged() end
function Control:transformChanged() end
function Control:visibilityChanged() end

---@param p Control
---@param c Control
local function addControl(p, c, ...)
    local child = c:new(...)
    p:add(child)
    return child
end

---@param text string?
---@return Control
function Control:addControl(text)
    return addControl(self, engine.Control, text)
end

---@param text string?
---@return Button
function Control:addButton(text)
    return addControl(self, engine.Button, text)
end

---@param text string?
---@return Button
function Control:addCheckbox(text, checked)
    return addControl(self, engine.Checkbox, text, checked)
end

---@param text string
---@param color number
---@return ColorPicker
function Control:addColorPicker(text, color)
    return addControl(self, engine.ColorPicker)
end

---@return Container
function Control:addContainer()
    return addControl(self, engine.Container)
end

---@param text string?
---@return Dropdown
function Control:addDropdown(text)
    return addControl(self, engine.Dropdown, text)
end

---@return FlowContainer
function Control:addFlowContainer()
    return addControl(self, engine.FlowContainer)
end

---@return HContainer
function Control:addHContainer()
    return addControl(self, engine.HContainer)
end

---@return Icon
function Control:addIcon()
    return addControl(self, engine.Icon)
end

---@return LineEdit
function Control:addLineEdit()
    return addControl(self, engine.LineEdit)
end

---@return ScrollContainer
function Control:addScrollContainer()
    return addControl(self, engine.ScrollContainer)
end

---@return VContainer
function Control:addVContainer()
    return addControl(self, engine.VContainer)
end

---@param text string?
---@return WindowControl
function Control:addWindowControl(text)
    return addControl(self, engine.WindowControl, text)
end

return Control
end
