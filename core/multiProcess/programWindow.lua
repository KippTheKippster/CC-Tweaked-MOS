-- Extends windowControl, attaches a programViewport to a window.
---@return ProgramWindow
---@param windowControl WindowControl
---@param engine Engine
return function(windowControl, engine)
---@class ProgramWindow : WindowControl
local ProgramWindow = windowControl:newClass()
ProgramWindow.__type = "ProgramWindow"

---@type ProgramViewport
ProgramWindow.programViewport = nil

function ProgramWindow:render()
    --SHADOW
    self:drawShadow()
    --PANEL
    local l = self._gx + 1
    local u = self._gy + 1
    local r = self._gx + self._w
    local d = self._gy + 1 --draw only the top of the window, the rest is hidden by the program viewport
    engine.drawPanel(l, u, r, d, self:getStyle())
    --TEXT
    self:drawText()
end

function ProgramWindow:addViewport(pv)
    self.programViewport = pv
    self:add(pv)
    pv.y = 1
    pv.h = pv.h - 1
    pv.propogateFocusUp = true
end

function ProgramWindow:close()
    windowControl.close(self)
    if not self.programViewport.program.dead then
        self.programViewport:endProcess()
    end
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
