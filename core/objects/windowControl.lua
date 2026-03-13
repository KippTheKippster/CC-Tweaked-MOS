---@param control Control
---@param button Button
---@param style Style
---@return WindowControl
return function(control, button, style, styleFocus)
---@class WindowControl : Control
local WindowControl = control:newClass()
WindowControl.__type = "WindowControl"

WindowControl.draggable = true
WindowControl.clipText = true
WindowControl.exitButton = nil
WindowControl.scaleButton = nil
WindowControl.minimizeButton = nil
WindowControl._minW = 10
WindowControl._minH = 4
WindowControl.oldW = 10
WindowControl.oldH = 4
WindowControl.fullscreen = false
WindowControl.closedSignal = WindowControl:createSignal()
WindowControl.fullscreenChangedSignal = WindowControl:createSignal()
WindowControl.shadow = true
WindowControl._marginL = 2
WindowControl._fitToText = false

WindowControl.style = style
WindowControl.styleFocus = styleFocus

function WindowControl:init(text)
    control.init(self, text)

    local exit = self:addButton("x")
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

    scale.drag = function(o, b, x, y, rx, ry)
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

    scale.doublePressed = function(o)
        o.parent:setFullscreen(true)
    end

    local min = self:addButton("-")
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

function WindowControl:close()
    self:closed()
    self:emitSignal(self.closedSignal)
    self:queueFree()
end

function WindowControl:setFullscreen(fullscreen)
    local wi = self
    if wi.fullscreen == fullscreen then
        return
    end

    wi.fullscreen = fullscreen
    if fullscreen == true then
        local w, h = term.getSize()
        wi.gx = 0
        wi.gy = 0
        wi.oldW = wi.w
        wi.oldH = wi.h
        wi.w = w
        wi.h = h
        wi:toFront()
        wi:grabFocus()
        self:emitSignal(self.fullscreenChangedSignal)
    else
        wi.w = self.oldW
        wi.h = self.oldH
        wi:emitSignal(wi.fullscreenChangedSignal)
    end
end

function WindowControl:drag(b, x, y, rx, ry)
    control.drag(self, b, x, y, rx, ry)
    if self.fullscreen == true then
        local tw = self.w
        self:setFullscreen(false)
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