---@param control Control
---@param style Style
---@return WindowControl
return function(control, style, styleFocus, styleDown)
---@class WindowControl : Control
local WindowControl = control:newClass()
WindowControl.__type = "WindowControl"

WindowControl.draggable = true
WindowControl.exitButton = nil
WindowControl.scaleButton = nil
WindowControl.minimizeButton = nil
WindowControl._minW = 10
WindowControl._minH = 4
WindowControl.oldW = 10
WindowControl.oldH = 4
WindowControl._fullscreen = false

---@type boolean
WindowControl.fullscreen = nil

WindowControl:defineProperty('fullscreen',
    function(o) return o._fullscreen end,
    function(o, value)
        ---@type WindowControl
        local wi = o
        if wi._fullscreen == value then
            return
        end

        wi._fullscreen = value
        if value then
            wi.x = 0
            wi.y = 0
            wi.oldW = wi.w
            wi.oldH = wi.h
            wi.fillW = true
            wi.fillH = true
            wi:toFront()
            wi:grabFocus()
            wi:emitSignal(wi.fullscreenChangedSignal)
        else
            wi.fillW = false
            wi.fillH = false
            wi.w = wi.oldW
            wi.h = wi.oldH
            wi:emitSignal(wi.fullscreenChangedSignal)
        end
    end
)

WindowControl.closedSignal = WindowControl:newSignal()
WindowControl.fullscreenChangedSignal = WindowControl:newSignal()
WindowControl.shadow = false
WindowControl._fitToText = false

WindowControl.style = style
WindowControl.styleFocus = styleFocus
WindowControl.styleDown = styleDown

---comment
---@param w WindowControl
---@param ... any
local function addButton(w, ...)
    local b = w:addButton(...)
    b.inheritStyle = true
    b.styleDown = w.styleDown
    return b
end

function WindowControl:init(text)
    control.init(self, text)

    local exit = addButton(self, "x")
    self.exitButton = exit
    exit.inheritStyle = true
    exit.x = self.w - 1
    exit.w = 1
    exit.h = 1
    exit.dragSelectable = true
    exit.propogateFocusUp = true
    exit.pressed = function(o)
        self:close()
    end

    local scale = self:addControl("%")
    self.scaleButton = scale
    scale.inheritStyle = true
    scale.w = 1
    scale.h = 1
    scale.propogateFocusUp = true

    scale.drag = function(o, b, x, y, dx, dy)
        local w = self.w
        self.w = self.w - x + 1
        self.w = math.max(self.minW, self.w)
        local dw = w - self.w
        self.x = self.x + dw

        local h = self.h
        self.h = self.h - y + 1
        self.h = math.max(self.minH, self.h)
        local dh = h - self.h
        self.y = self.y + dh

        self.oldW = self.w
        self.oldH = self.h
    end

    scale.doublePressed = function(o)
        o.parent.fullscreen = true
    end

    local min = addButton(self, "-")
    self.minimizeButton = min
    min.inheritStyle = true
    min.w = 1
    min.h = 1
    min.propogateFocusUp = true
    min.dragSelectable = true
    min.pressed = function(o)
        self.visible = false
    end
end

function WindowControl:getText()
    return "  " .. self.text
end

function WindowControl:close()
    self:closed()
    self:emitSignal(self.closedSignal)
    self:queueFree()
end

function WindowControl:drag(b, x, y, rx, ry)
    control.drag(self, b, x, y, rx, ry)
    self.w = self.oldW
    self.h = self.oldH
    self.oldW = self.w
    self.oldH = self.h
    if self.fullscreen then
        local tw = self.w
        self.fullscreen = false
        local gx = x + self.gx - 1
        local ox = gx - self.parent.gx
        -- TODO THINK FIXME
        self.x = math.floor(ox - self.w * (x / tw) + 0.5)
    end
end

function WindowControl:sizeChanged()
    self.exitButton.x = self.w - 1
    self.minimizeButton.x = self.w - 2
end

function WindowControl:refreshMinSize()
    self.minW, self.minH = math.min(self.minW, self.w), math.min(self.minH, self.h)
    self.oldW, self.oldH = self.w, self.h
end

function WindowControl:focusChanged()
    self:updateFocus()
end

function WindowControl:updateFocus()
    if self:inFocus() then
        self:toFront()
        self:grabCursor()
    else
        self:releaseCursor()
    end
end

function WindowControl:getStyle()
    if self:inFocus() then
        return self.styleFocus
    else
        return self.style
    end
end

function WindowControl:closed() end

return WindowControl
end
