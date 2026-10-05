---@param engine Engine
---@param control Control
---@param button Button
---@param style Style
---@return WindowControl
return function(engine, control, button, style, styleFocus, styleDown)
---@class WindowControl : Control
local WindowControl = control:newClass()
WindowControl.__type = "WindowControl"

WindowControl.clipText = true
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

WindowControl:defineProperty('fullscreen', {
    get = function(o) return o._fullscreen end,
    set = function(o, value)
        ---@type WindowControl
        local wi = o
        if wi._fullscreen == value then
            return
        end

        wi._fullscreen = value
        if value then
            wi.gx = 0
            wi.gy = 0
            wi.oldW = wi.w
            wi.oldH = wi.h
            wi.expandW = true
            wi.expandH = true
            wi:toFront()
            wi:grabFocus()
            wi:emitSignal(wi.fullscreenChangedSignal)
        else
            wi.expandW = false
            wi.expandH = false
            wi.w = wi.oldW
            wi.h = wi.oldH
            wi:emitSignal(wi.fullscreenChangedSignal)
        end
    end
})

WindowControl.closedSignal = WindowControl:createSignal()
WindowControl.fullscreenChangedSignal = WindowControl:createSignal()
WindowControl.shadow = false
WindowControl._marginL = 2
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
    exit.propagateFocusUp = true
    exit.pressed = function(o)
        self:close()
    end

    local scale = self:addControl("%")
    self.scaleButton = scale
    scale.inheritStyle = true
    scale.w = 1
    scale.h = 1
    scale.propagateFocusUp = true

    scale.drag = function(o, b, x, y, dx, dy)
        local gx = x + self.gx - 1
        local gy = y + self.gy - 1

        local dx = self.gx - gx
        local dy = self.gy - gy

        local w = self.w + dx
        local h = self.h + dy

        if w >= self.minW then
            self.gx = gx
            self.w = self.w + dx
            self.oldW = self.w
        end

        if h >= self.minH then
            self.gy = gy
            self.h = self.h + dy
            self.oldH = self.h
        end
    end

    scale.doubleClick = function(o)
        o.parent.fullscreen = true
    end

    local min = addButton(self, "-")
    self.minimizeButton = min
    min.inheritStyle = true
    min.w = 1
    min.h = 1
    min.propagateFocusUp = true
    min.dragSelectable = true
    min.pressed = function(o)
        self.visible = false
    end

end

function WindowControl:close()
    self:closed()
    self:emitSignal(self.closedSignal)
    self:queueFree()
end

function WindowControl:drag(b, x, y, dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy
    self.w = self.oldW
    self.h = self.oldH
    self.oldW = self.w
    self.oldH = self.h
    if self.fullscreen == true then
        local tw = self.w
        self.fullscreen = false
        local gx = x + self.gx - 1
        self.gx = math.floor(gx - self.w * (x / tw) + 0.5)
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