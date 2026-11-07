-- Extends windowControl, attaches a programViewport to a window.
---@return ProgramWindow
---@param windowControl WindowControl
---@param engine Engine
return function(windowControl, engine)
---@class ProgramWindow : WindowControl
local ProgramWindow = windowControl:newClass()
ProgramWindow.__type = "ProgramWindow"
ProgramWindow._borderDrag = ""
---@type ProgramViewport
ProgramWindow.programViewport = nil

ProgramWindow._pauseBorders = true

---@param self ProgramWindow
local function reposition(self) error"what" end

---@type boolean
ProgramWindow.borders = nil
ProgramWindow._borders = true
ProgramWindow:defineProperty("borders",
    function (o)
        return o._borders
    end,
    function (o, value)
        local changed = value ~= o._borders
        o._borders = value
        if changed and o.parent and not o.fullscreen then
            if value then
                o.x = o.x - 1
            else
                o.x = o.x + 1
            end
            for _, c in ipairs(o.children) do
                c:queueRetransform() -- HACK should be done automatically
            end

            reposition(o)
        end
    end
)

local function round(x)
    return math.floor(x + 0.5)
end

---@param c table
---@param x integer
---@param y integer
local function writeAt(c, x, y)
    if not c then
        return
    end

    term.setCursorPos(x, y)
    term.setTextColor(c.textColor)
    term.setBackgroundColor(c.backgroundColor)
    term.write(c.text)
end

---@param self ProgramWindow
---@param side string
local function getBorderStyle(self, side)
    if self._borderDrag == side then
        return self.styleDown
    else
        return self:getStyle()
    end
end

---@param self ProgramWindow
---@param x integer
---@param y integer
---@param flip boolean
---@param side string
local function charAt(self, text, x, y, flip, side)
    local bg = getBorderStyle(self, side).backgroundColor--self:getStyle().backgroundColor
    x, y = x - self.gx, y - self.gy
    local char = engine.utils.getWindowChar(self.programViewport.program.window, x, y)
    if char then
        char.text = text
        char.textColor = bg
        if flip then
            char.textColor = char.backgroundColor
            char.backgroundColor = bg
        end
    else
        --char = {text = "invalid", textColor = colors.red, backgroundColor = colors.black}
    end

    return char
end

---@param self ProgramWindow
function reposition(self)
    if self.borders and not self.fullscreen then
        self.paddingL = 1
        self.paddingR = 1
        self.paddingD = 1
    else
        self.paddingL = 0
        self.paddingR = 0
        self.paddingD = 0
    end

    self.scaleButton.visible = not self.borders

    if self.programViewport then
        self.programViewport.w = self.w
        self.programViewport.h = self.h - 1
    end
end

---@param self ProgramWindow
local function drawBorder(self)
    if not self.borders or self.fullscreen or not self:isVisible() or self._pauseBorders then
        return
    end

    local cursorX, cursorY = term.getCursorPos()
    local cursorTc, cursorBc = term.getTextColor(), term.getBackgroundColor()
    local cursorBlink = term.getCursorBlink()

    local current = term.current()
    term.redirect(engine.screenBuffer)
    term.setCursorBlink(false)

    local bg = self:getStyle().backgroundColor
    local x, y = 0, 0
    local w, h = self:getPaddedW(), self:getPaddedH()
    --- Note that the far left is gx = 0 for a control and x = 1 for term
    for i=2, h - 1 do
        --- left
        x, y = self.gx + 1, self.gy + i
        writeAt(charAt(self, string.char(149), x, y - 1, false, "left"), x, y)

        --- right
        x, y = self.gx + w, self.gy + i
        writeAt(charAt(self, string.char(149), x-2, y - 1, true, "right"), x, y)
    end

    for i=2, w-1 do
        --- down
        x, y = self.gx + i, self.gy + h
        --writeAt(charAt(self, string.char(143), x, y - 2, true), x, y)
        writeAt(charAt(self, string.char(131), x - 1, y - 2, true, "down"), x, y)
    end

    -- up left
    x, y = self.gx + 1, self.gy + 1
    writeAt({text = " ", backgroundColor = getBorderStyle(self, "up_left").backgroundColor, textColor = 1}, x, y)

    -- up right
    x, y = self.gx + w, self.gy + 1
    writeAt({text = " ", backgroundColor = getBorderStyle(self, "up_right").backgroundColor, textColor = 1}, x, y)

    -- down left
    x, y = self.gx + 1, self.gy + h
    writeAt(charAt(self, string.char(130), x, y - 2, true, "down_left"), x, y)
    --writeAt(charAt(self, string.char(138), x + 1, y - 2, true), x, y)

    -- down right
    x, y = self.gx + w, self.gy + h
    writeAt(charAt(self, string.char(129), x - 2, y - 2, true, "down_right"), x, y)
    --writeAt(charAt(self, string.char(133), x - 1, y - 2, true), x, y)

    term.redirect(current)
    term.setCursorPos(cursorX, cursorY)
    term.setTextColor(cursorTc)
    term.setBackgroundColor(cursorBc)
    term.setCursorBlink(cursorBlink)
end

function ProgramWindow:treeEntered()
    reposition(self)
end

function ProgramWindow:click(b, x, y)
    windowControl.click(self, b, x, y)
    if not self.borders then
        return
    end

    local w, h = self:getPaddedW(), self:getPaddedH()

    local d = ""
    if y > 1 and y < h then
        if x == 1 then
            d = "left"
        elseif x == w then
            d = "right"
        end
    elseif y == h then
        if x == 1 then
            d = "down_left"
        elseif x == w then
            d = "down_right"
        else
            d = "down"
        end
    elseif y == 1 then
        if x == 1 then
            d = "up_left"
        elseif x == w then
            d = "up_right"
        end
    end

    if d ~= "" then
        self:queueDraw()
    end

    self._borderDrag = d
end

function ProgramWindow:doubleClick(b, x, y)
    if not self.borders then
        return
    end

    local d = self._borderDrag
    local w, h = engine.screenBuffer.getSize()
    if d == "" then
        self.fullscreen = self.fullscreen ~= true
        return
    end

    self.oldW = self.w
    self.oldH = self.h

    self.x = -1
    self.y = 0
    self.w = w + 2
    self.h = h + 1

    if d == "left" or d == "down_left" or d == "up_left" then
        self.w = round(w / 2)
    end

    if d == "right" or d == "down_right" or d == "up_right" then
        self.x = round(w / 2)
        self.w = self.x - self:toPaddedW(0)
    end

    if d == "down" or d == "down_left" or d == "down_right" then
        self.y = round(h / 2)
        self.h = h - self.y - self:toPaddedH(0) + 1
    end

    if d == "up_left" or d == "up_right" then
        self.h = round(h / 2)
    end
end

function ProgramWindow:drag(b, x, y, dx, dy)
    local d = self._borderDrag
    if d == "" then
        windowControl.drag(self, b, x, y, dx, dy)
        return
    end

    if not self.borders then
        return
    end

    if d == "left" or d == "down_left" or d == "up_left" then
        local w = self.w
        self.w = self.w - x + 1
        self.w = math.max(self.minW, self.w)
        local delta = w - self.w
        self.x = self.x + delta
    end

    if d == "right" or d == "down_right" or d == "up_right"  then
        self.w = x - self:toPaddedW(0)
    end

    if d == "down" or d == "down_left" or d == "down_right" then
        self.h = y - self:toPaddedH(0)
    end

    if d == "up_left" or d == "up_right" then
        local h = self.h
        self.h = self.h - y + 1
        self.h = math.max(self.minH, self.h)
        local delta = h - self.h
        self.y = self.y + delta
    end

    self.w = math.max(self.minW, self.w)
    self.h = math.max(self.minH, self.h)
    self.oldW = self.w
    self.oldH = self.h
end

function ProgramWindow:pressed()
    self._borderDrag = ""
end

function ProgramWindow:getText()
    if self.borders then
        return self.text
    else
        return "  " .. self.text
    end
end

function ProgramWindow:render()
    --SHADOW
    self:drawShadow()
    --PANEL
    local l = self._gx + 1
    local u = self._gy + 1
    local r = self._gx + self._w - 1
    local d = self._gy + 1 --draw only the top of the window, the rest is hidden by the program viewport
    engine.drawPanel(l, u, r, d, self:getStyle())
    --TEXT
    self:drawText()

    self._pauseBorders = false
    drawBorder(self)
end

---@param pv ProgramViewport
function ProgramWindow:addViewport(pv)
    self.programViewport = pv
    self:add(pv)
    pv.x = 0
    pv.y = 1
    pv.h = pv.h - 2
    pv.w = pv.w - 5
    pv.propagateFocusUp = true
end

function ProgramWindow:close()
    if not self.programViewport.program.dead then
        self.programViewport:endProcess()
    end
    windowControl.close(self)
end

function ProgramWindow:sizeChanged()
    reposition(self)
end

function ProgramWindow:transformChanged()
    self._pauseBorders = true
end

function ProgramWindow:fullscreenChanged()
    reposition(self)
end

function ProgramWindow:focusChanged()
    windowControl.focusChanged(self)
    self._pauseBorders = true
end

function ProgramWindow:updateCursor()
    local window = self.programViewport.program.window
    local parentTerm = term.current()
    term.redirect(window)
    term.setCursorPos(window.getCursorPos())
    term.setCursorBlink(window.getCursorBlink())
    term.setTextColor(window.getTextColor())
    term.redirect(parentTerm)
end

function ProgramWindow:_onViewportEvent()
    if self.focus then
        drawBorder(self)
    end
end

function ProgramWindow:closed() end

return ProgramWindow
end
