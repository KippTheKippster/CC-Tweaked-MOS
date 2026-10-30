local expect = require"cc.expect"
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

---Local X, the x position relative to the parent's position
---@type number
Control.x = nil
Control._x = 0

---Local Y, the y position relative to the parent's position
---@type number
Control.y = nil
Control._y = 0

---Offset X, the x offset from the parent (respects margin and anchor)
Control._ox = 0

---Offset Y, the y offset from the parent (respects margin and anchor)
Control._oy = 0

---Base Width, the base width of the control (does not include padding, see control.toPaddedW)
---@type number
Control.w = nil
Control._w = 1

---Base Height, the base height of the control (does not include padding, see control.toPaddedH)
---@type number
Control.h = nil
Control._h = 1

---Minimum Width, the absolute minimum width of the control, note that the actual minimum width can be higher (see control.getMinSize)
---@type number
Control.minW = nil
Control._minW = 1

---Minimum Height, the absolute minimum height of the control, note that the actual minimum height can be higher (see control.getMinSize)
---@type number
Control.minH = nil
Control._minH = 1

---@type boolean
Control.fillW = nil
Control._fillW = false

---@type boolean
Control.fillH = nil
Control._fillH = false

---TODO RENAME
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
Control._textAlignW = "left"
---@type string
Control.textAlignW = nil
Control.focus = false
Control.propagateFocusUp = false
Control.clipText = true
--- Determines how mouse input interacts with the control
--- stop   - input will be received (default)
--- pass   - input will be received and passed to the parent control
--- ignore - input will be ignored  and passed to the parent control
Control.mouseFilter = "stop"
Control.rendering = true
Control.dragSelectable = false
Control.topLevel = false
---@type Control[]
Control.children = {}
---@type Control?
Control.parent = nil

Control._marginL = 0
---@type number
Control.marginL = nil
Control._marginR = 0
---@type number
Control.marginU = nil
Control._marginU = 0
---@type number
Control.marginD = nil
Control._marginD = 0
---@type number
Control.marginR = nil

Control._paddingL = 0
---@type number
Control.paddingL = nil
Control._paddingR = 0
---@type number
Control.paddingU = nil
Control._paddingU = 0
---@type number
Control.paddingD = nil
Control._paddingD = 0
---@type number
Control.paddingR = nil


Control.offsetTextX = 0

---@type string
Control.anchorW = nil
---@type string
Control.anchorH = nil

Control._anchorW = "left"
Control._anchorH = "up"

Control._repositionQueued = false
Control._resizeQueued = false

Control.visibilityChangedSignal = Control:newSignal("visibility_changed")
Control.focusChangedSignal = Control:newSignal("focus_changed")
Control.sortHintSignal = Control:newSignal("sort_hint")

--- Create a property with name 'name' that updates '_name' and calls function 'set' if the value of '_name' has changed
---@param name string
---@param set function
local function definePropertySet(name, set)
    local privName = "_" .. name
    Control:defineProperty(name,
    function (o)
        return o[privName]
    end,
    function (o, value)
        local prev = o[privName]
        local dif = prev ~= value
        if dif then
            o[privName] = value
            set(o, value, prev)
        end
    end
)
end


---@param self Control
---@param x number
---@param y number
local function setGXY(self, x, y)
    if not self.parent then
        error("Unable to update position control with no parent! __name: " .. self.__name, 4)
    end

    local changed = self._gx ~= x or self._gy ~= y
    if not changed then
        return
    end

    self._gx = x
    self._gy = y
    self._x = self._gx - self.parent._gx
    self._y = self._gy - self.parent._gy

    for _, c in ipairs(self.children) do
        setGXY(c, self.gx + c.x, self.gy + c.y)
    end

    self:transformChanged()
    self:queueDraw()
end

local function setXY(self, x, y)
    setGXY(self, self.parent.gx + x, self.parent.gy + y)
end

Control:defineProperty('gx',
    function (o)
        return o._gx
    end,
    function(o, value)
        local new, old = value, o._gx
        setGXY(o, new, o._gy)
        local delta = new - old
        o._ox = o._ox + delta
    end
)

Control:defineProperty('gy',
    function (o)
        return o._gy
    end,
    function(o, value)
        local new, old = value, o._gy
        setGXY(o, o._gx, new)
        local delta = new - old
        o._oy = o._oy + delta
    end
)

definePropertySet('x', function(o, new, old)
    setXY(o, o._x, o._y)
    local delta = new - old
    o._ox = o._ox + delta
end)

definePropertySet('y', function(o, new, old)
    setXY(o, o._x, o._y)
    local delta = new - old
    o._oy = o._oy + delta
end)

definePropertySet('w', function(o)
    o._w = math.max(o._w, o._minW)
    o:queueDraw()
    o:transformChanged()
    o:sizeChanged()
    o:queueReposition()
    o:emitSignal(o.sortHintSignal)
    for _, c in ipairs(o.children) do
        c:queueRetransform()
    end
end)

definePropertySet('h', function(o)
    o._h = math.max(o._h, o._minH)
    o:queueDraw()
    o:transformChanged()
    o:sizeChanged()
    o:queueReposition()
    o:emitSignal(o.sortHintSignal)
    for _, c in ipairs(o.children) do
        c:queueRetransform()
    end
end)

definePropertySet('minW', function(o)
    o.w = math.max(o.w, o._minW)
    o:queueRetransform()
end)

definePropertySet('minH', function(o)
    o.h = math.max(o.h, o._minH)
    o:queueRetransform()
end)

definePropertySet('fillW', function(o)
    o:queueRetransform()
end)

definePropertySet('fillH', function(o)
    o:queueRetransform()
end)

definePropertySet('marginL', function(o)
    o:queueRetransform()
end)

definePropertySet('marginR', function(o)
    o:queueRetransform()
end)

definePropertySet('marginU', function(o)
    o:queueRetransform()
end)

definePropertySet('marginD', function(o)
    o:queueRetransform()
end)

definePropertySet('paddingL', function(o)
    o:queueRetransform()
end)

definePropertySet('paddingR', function(o)
    o:queueRetransform()
end)

definePropertySet('paddingU', function(o)
    o:queueRetransform()
end)

definePropertySet('paddingD', function(o)
    o:queueRetransform()
end)

definePropertySet('anchorW', function(o)
    o:queueRetransform()
end)

definePropertySet('anchorH', function(o)
    o:queueRetransform()
end)

definePropertySet('text', function(o, new, old)
    o:queueRetransform()
    o:queueDraw()
    o:textChanged()
    if #new ~= #old then
        o:emitSignal(o.sortHintSignal)
    end
end)

definePropertySet('fitToText', function(o)
    o:queueResize()
end)

definePropertySet('textAlignW', function(o)
    o:queueDraw()
end)

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

definePropertySet('visible', function(o)
    o:visibilityChanged()
    o:emitSignal(o.visibilityChangedSignal)
    o:emitSignal(o.sortHintSignal)
    propogateVisiblity(o)
    o:queueDraw()
end)

---@param text string?
function Control:init(text)
    object.init(self, text)
    self.children = {}
    if text then
        self._text = text
    end
end

function Control:reposition()
    local c = self
    local p = c.parent
    if not p then
        return
    end

    local x = p.paddingL + c.marginL + c._ox
    local y = p.paddingU + c.marginU + c._oy

    local pw, ph = 0, 0
    if c.anchorW ~= "left" or c.anchorH ~= "up" then
        pw, ph = p:getFillSize()
    end

    if c.anchorW == "right" then
        x = x + pw - c:getPaddedW() - self.marginR
    elseif c.anchorW == "center" then
        x = x + math.floor(pw / 2 + 0.5) - math.floor(c:getPaddedW() / 2 + 0.5)
    end

    if c.anchorH == "down" then
        y = y + ph - c:getPaddedH() - self.marginU
    elseif c.anchorH == "center" then
        y = y + math.floor(ph / 2 + 0.5) - math.floor(c:getPaddedH() / 2 + 0.5)
    end

    setXY(self, x, y)
end

function Control:getDesiredSize()
    local c = self
    local p = c.parent
    if not p then
        return 0, 0
    end

    local w, h = self.w, self.h

    local fillW, fillH = 0, 0
    if c.fillW or c.fillH then
        fillW, fillH = p:getFillSize()
    end

    local minW, minH = self:getMinSize()
    local _maxW, _maxH = self:getMaxSize()
    if _maxW > -1 then
        w = math.min(w, _maxW)
    end

    if _maxH > -1 then
        h = math.min(h, _maxH)
    end

    if c.fillW then
        w = fillW - c.paddingL - c.paddingR - c.marginL - c.marginR
        w = math.min(w, fillW)
    end

    if c.fillH then
        h = fillH - c.paddingU - c.paddingD - c.marginU - c.marginD
        h = math.min(h, fillH)
    end

    w = math.max(minW, w)
    h = math.max(minH, h)
    return w, h
end

function Control:resize()
    self.w, self.h = self:getDesiredSize()
end

---@param w number
function Control:toPaddedW(w)
    return w + self.paddingL + self.paddingR
end

---@param h number
function Control:toPaddedH(h)
    return h + self.paddingU + self.paddingD
end

function Control:getPaddedW()
    return self:toPaddedW(self.w)
end

function Control:getPaddedH()
    return self:toPaddedH(self.h)
end

function Control:getMinSize()
    if not self.visible then
        return 0, 0
    end

    local minW = self.minW
    local minH = self.minH
    if self.fitToText and self.text ~= "" then
        minW = math.max(#self.text, minW)
        minH = math.max(1, minH)
    end

    return minW, minH
end

function Control:getMaxSize()
    return -1, -1
end

-- Determines the max amount of space a child node should occupy when the child has fillW or fillH = true
function Control:getFillSize()
    return self.w, self.h
end

Control.shadow = false -- Change this to style

--- WARNING: Use queueFree instead if you simply want to remove the control.
--- Removes control's variables and signals and makes the object throw an error on setting and getting variables
function Control:free()
    object.free(self)
end

function Control:queueFree()
    -- TODO add check
    engine.queueFree(self)
    if self:inFocus() then
        self:releaseFocus()
    end
end

function Control:queueDraw()
    engine.queueDraw()
end

function Control:queueReposition()
    self._repositionQueued = true
end

function Control:queueResize()
    self._resizeQueued = true
end

function Control:queueRetransform()
    self:queueReposition()
    self:queueResize()
end

---Calls the function at the end of the render cycle
---Note: the calling control will be the first argument, if that is not desired use engine.callDeferred instead
---@param fn function
---@param ... any
function Control:callDeferred(fn, ...)
    engine.callDeferred(fn, {self, ...})
end

function Control:getBorders()
    local w, h = self:getPaddedW(), self:getPaddedH()
    local left = self._gx + 1
    local up = self._gy + 1
    local right = self._gx + w
    local down = self._gy + h
    return left, up, right, down
end

---Creates and assigns a new style object for the control
function Control:newStyle()
    self.style = engine.style:inherit()
    return self.style
end

---@return Style
function Control:getStyle()
    if self.inheritStyle then
        return self.parent:getStyle()
    else
        return self.style
    end
end

function Control:getText()
    return self.text
end

function Control:updateTree()
    self:update()
    for _, c in ipairs(self.children) do
        c:updateTree()
    end
end

function Control:update()
    if self._resizeQueued then
        self._resizeQueued = false
        self:resize()
    end
    if self._repositionQueued then
        self._repositionQueued = false
        self:reposition()
    end
end

-- Determines how the control object is drawn
function Control:render()
    --SHADOW
    self:drawShadow()
    --PANEL
    self:drawPanel()
    --TEXT
    self:drawText()
end

-- Draws the control object if it is valid, NOTE this should not be used to redraw object, use 'queueDraw' instead
function Control:draw()
    if self.visible == false or self.rendering == false or self.parent == nil then
        return
    end

    self:render()
end

function Control:drawShadow()
    if self.shadow then
        engine.drawShadow(self.gx, self.gy, self:getPaddedW(), self:getPaddedH(), self:getStyle())
    end
end

function Control:drawPanel()
    local l, u, r, d = self:getBorders()
    engine.drawPanel(l, u, r, d, self:getStyle())
end

---@param text string
function Control:formatText(text)
    expect(1, text, "string")
    -- x, y
    local x = self.gx + self.paddingL + 1
    local y = self.gy  + self.paddingU + 1

    if text == "" then
        return text, x, y
    end

    if self.textAlignW == "center" then
        x = x + math.ceil((self.w - #text) / 2)
        y = y + math.floor((self.h) / 2)
    end

    -- clip text
    local p = self:toPaddedW(0)
    local l = #text - p
    if self.clipText == true then
        l = math.min(#text, self:getPaddedW() - p - 1)
    end
    local s = self.offsetTextX + 1
    local t = text:sub(s, s + l)
    return t, x, y
end

function Control:drawText()
    local text, x, y = self:formatText(self:getText())
    engine.drawText(text, x, y, self:getStyle())
end

local function addChild(self, c)
    c.parent = self
    --setGXY(c, self.gx + c.x, self.gy + c.y) -- THINK
    --updateChildGlobalPosition(self, c)
    self:childAdded(c)
    c:queueRetransform()
    c:treeEntered()
end

---Add the Control object 'o' as a child
---@param o Control
function Control:add(o)
    if o.parent then
        error("Attempt to add a child that already has a parent! __name: " .. o.__name, 2)
    end

    table.insert(self.children, o)
    addChild(self, o)
    self:childrenChanged()
    self:queueDraw()
    return o
end

---@return Control
---@param i integer
function Control:getChild(i)
    return self.children[i]
end

---Removes the Control object 'o' from the parent, NOTE if you want to delete the object use queueFree instead
---@param o Control
function Control:remove(o)
    local idx = 0
    for i = 1, #self.children do
        if self.children[i] == o then
            table.remove(self.children, i)
            idx = i
            break
        end
    end

    if idx == 0 then
        return
    end

    o.parent = nil
    self:childrenChanged()
    self:queueDraw()
    self:childRemoved(o)
end

function Control:freeChildren()
    for i, b in ipairs(self.children) do
        b:queueFree()
    end
    self.children = {}
end

---Frees and replaces the control's children, this is recommended to be used instead of Control.add when adding a large number of children
---@param children Control[]
function Control:replaceChildren(children)
    self:freeChildren()
    self.children = children
    for i = 1, #self.children do
        local c = self:getChild(i)
        addChild(self, c)
    end
    self:childrenChanged()
    self:queueDraw()
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
    engine.input.setFocusControl(engine.input.getFocusOwner(self))
end

function Control:releaseFocus()
    if engine.input.getFocusControl() == engine.input.getFocusOwner(self) then
        engine.input.setFocusControl(nil)
    end
end

function Control:grabCursor()
    engine.input.setCursorControl(self)
end

function Control:releaseCursor()
    if engine.input.getCursorControl() == self then
        engine.input.setCursorControl(nil)
    end
end

function Control:grabInput()
    engine.input.setInputControl(self)
end

function Control:releaseInput()
    if engine.input.getInputControl() == self then
        engine.input.setInputControl(nil)
    end
end

function Control:grabDown()
    engine.input.setDownControl(self)
end

function Control:releaseDown()
    if engine.input.getDownControl() == self then
        engine.input.setDownControl(nil)
    end
end

--Event Functions that can be overwritten
function Control:treeEntered() end
function Control:childrenChanged() end
function Control:down() end
function Control:up() end
function Control:pressed() end
---@param button integer
---@param x number
---@param y number
function Control:click(button, x, y) end
---@param button integer
---@param x number
---@param y number
function Control:doubleClick(button, x, y) end
---@param button integer
---@param x number
---@param y number
---@param dx number
---@param dy number
function Control:drag(button, x, y, dx, dy) end
---@param dir integer
---@param x number
---@param y number
function Control:scroll(dir, x, y) end

function Control:focusChanged() end
-- If the control has cursor control, see control:grabCursor(), this function will be responsible for drawing the cursor 
function Control:updateCursor() end
function Control:input(data) end

function Control:textChanged() end
function Control:sizeChanged() end
function Control:transformChanged() end
function Control:visibilityChanged() end
-- Function will be called before a container sorts this control
function Control:containerPreSort() end

---@param c Control
function Control:childAdded(c) end
---@param c Control
function Control:childRemoved(c) end

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
---@param checked boolean?
---@return Checkbox
function Control:addCheckbox(text, checked)
    return addControl(self, engine.Checkbox, text, checked)
end

---@param text string
---@param color number
---@return ColorPicker
function Control:addColorPicker(text, color)
    return addControl(self, engine.ColorPicker, text, color)
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

---@return ArrayContainer
function Control:addHContainer()
    return addControl(self, engine.ArrayContainer, "horizontal")
    --return addControl(self, engine.HContainer)
end

---@return Icon
function Control:addIcon()
    return addControl(self, engine.Icon)
end

---@return LineEdit
function Control:addLineEdit()
    return addControl(self, engine.LineEdit)
end

---@param alignmentMode string?
---@return ScrollContainer
function Control:addScrollContainer(alignmentMode)
    return addControl(self, engine.ScrollContainer, alignmentMode)
end

---@param alignmentMode string
---@return ArrayContainer
function Control:addArrayContainer(alignmentMode)
    return addControl(self, engine.ArrayContainer, alignmentMode)
end

---@return ArrayContainer
function Control:addVContainer()
    --return addControl(self, engine.VContainer)
    return addControl(self, engine.ArrayContainer, "vertical")
end

---@param text string?
---@return WindowControl
function Control:addWindowControl(text)
    return addControl(self, engine.WindowControl, text)
end

return Control
end
