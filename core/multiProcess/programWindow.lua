-- Extends windowControl, attaches a programViewport to a window.
---@return ProgramWindow
---@param windowControl WindowControl
---@param input Input
return function(windowControl, input)
---@class ProgramWindow : WindowControl
local ProgramWindow = windowControl:newClass()
ProgramWindow.__type = "ProgramWindow"

---@type ProgramViewport
ProgramWindow.programViewport = nil

function ProgramWindow:render()
    local style = self:getStyle()
    --SHADOW
    self:drawShadow(style)
    --PANEL
    local l = self._gx + 1
    local u = self._gy + 1
    local r = self._gx + self._w
    local d = self._gy + 1 --draw only the top of the window, the rest is hidden by the program viewport
    self:drawPanel(l, u, r, d, style)
    --TEXT
    self:write(self.text, style)
end

function ProgramWindow:addViewport(pv)
    self.programViewport = pv
    self:add(pv)
    pv.y = 1
    pv.h = pv.h - 1
    pv.propogateFocusUp = true
end

function ProgramWindow:close()
    self.programViewport:endProcess()
    windowControl.close(self)
end

function ProgramWindow:down()
    windowControl.down(self)
    self:toFront()
end

function ProgramWindow:sizeChanged()
    windowControl.sizeChanged(self)
    if self.programViewport then
        self.programViewport.w = self.w
        self.programViewport.h = self.h - 1
    end
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

function ProgramWindow:closed() end

return ProgramWindow
end
