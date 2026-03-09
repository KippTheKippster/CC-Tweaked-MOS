-- Extends control, draws the inbuilt cc-tweaked window object on to a control object.
---@param control Control
---@param mp MultiProgram
---@param input Input
---@return ProgramViewport
return function(control, mp, input)
---@class ProgramViewport : Control
local ProgramViewport = control:newClass()
ProgramViewport.__type = "ProgramViewport"

ProgramViewport.rendering = false
ProgramViewport.mouseIgnore = false
ProgramViewport.program = nil
ProgramViewport.parentTerm = nil
ProgramViewport.terminated = false
ProgramViewport.skipEvent = false
ProgramViewport.oldW = 0
ProgramViewport.oldH = 0
ProgramViewport.resizeQueued = false
---@type table
ProgramViewport.focusKeys = nil
ProgramViewport.queuedEvents = nil

function ProgramViewport:init()
    control.init(self)

    self.oldW = self.w
    self.oldH = self.h
    self.focusKeys = {}
    self.queuedEvents = {}
end

function ProgramViewport:draw()
    if self.program == nil then return end
    self:updateWindow()
end

function ProgramViewport:visibilityChanged()
    if self:isVisible() == false then
        self:updateWindow()
    end
end

function ProgramViewport:transformChanged()
    if self.oldH ~= self.h or self.oldW ~= self.w then
        self.resizeQueued = true
    end
    self.oldW, self.oldH = self.w, self.h
end

function ProgramViewport:launchProgram(parentTerm, programPath, extraEnv, ...)
    self.parentTerm = parentTerm
    self.program = mp.launchProgram(parentTerm, programPath, extraEnv, function(data)
        if self:isValid() then
            for i, v in ipairs(self.queuedEvents) do
                self:unhandledEvent(v)
            end
            self.queuedEvents = {}

            return self:unhandledEvent(data)
        end
        return {true}
    end, self.gx + 1, self.gy + 1, self.w, self.h, ...)
end

function ProgramViewport:endProcess()
    self.terminated = true
    mp.endProcess(self.program)
end

function ProgramViewport:queueEvent(data)
    if coroutine.status(self.program.co) == "suspended" then
        self:unhandledEvent(data)
    else
        table.insert(self.queuedEvents, data)
    end
end

local function drawChildren(viewport)
    for i = 1, #viewport.children do
        viewport.children[i]:draw()
    end
end

local function resumeProcess(viewport, data)
    local status = coroutine.status(viewport.program.co)
    if status == "dead" then
        return { true }
    end
    local result = mp.resumeProcess(viewport.program, data)
    --drawChildren(viewport)
    return result
end

---comment
---@param data table
function ProgramViewport:unhandledEvent(data)
    if self.program == nil then return { true } end
    local event = data[1]

    if self.skipEvent == true and event ~= "timer" then -- TODO add a more robust way of skipping input
        self.skipEvent = false
        return { true }
    end

    local args = data
    if event == "mouse_click" or event == "mouse_drag" or event == "mouse_up" then
        if self.parent:inFocus() == false then return { true } end
        if input.getCurrentControl() ~= self then return { true } end
        local button, x, y = data[2], data[3], data[4]
        local offsetX, offsetY = self.program.window.getPosition()

        args = table.pack(event, button, x - offsetX + 1, y - offsetY + 1)
    elseif event == "mouse_scroll" then
        if self.parent:inFocus() == false then return { true } end
        local button, x, y = data[2], data[3], data[4]
        local offsetX, offsetY = self.program.window.getPosition()

        args = table.pack(event, button, x - offsetX + 1, y - offsetY + 1)
    elseif event == 'char' then
        if self.parent:inFocus() == false then return { true } end

        args = data
    elseif event == 'key' then
        if self.parent:inFocus() == false then return { true } end

        local key = data[2]
        local held = data[3]

        if self.focusKeys[key] == nil and held == false then
            self.focusKeys[key] = true
        end

        if (held and self.focusKeys[key]) or not held then
            args = data
        end
    elseif event == "key_up" then
        if self.parent:inFocus() == false then return { true } end


        if self.terminated == true then
            if self.focusKeys[data[2]] == true and self.parent:inFocus() then
                self.parent:close()
            end
        end

        self.focusKeys[data[2]] = nil
        args = data
    end

    if self.terminated == true then
        return { true }
    end

    local result = resumeProcess(self, args)

    if coroutine.status(self.program.co) == "dead" and self.terminated == false then
        self.terminated = true
        term.redirect(self.program.window)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        print("Press any key to close window.")

        term.redirect(self.parentTerm)
        return { true }
    end

    if result then
        local ok, err = result[1], result[2]
        if ok == false then
            term.redirect(self.program.window)
            term.setCursorPos(1, 1)
            term.setTextColor(colors.red)
            term.setBackgroundColor(colors.black)
            print("Viewport Result: ", err)
            if __mos then
                __mos.log("Viewport Error: ", err)
            end
            term.redirect(self.parentTerm)
            return result
        end

        self:queueDraw()

        return result
    end

    return result
end

function ProgramViewport:updateWindow()
    if self.program == nil then return end
    if self:isVisible() == false then
        self.program.window.setVisible(false)
        return
    end

    term.redirect(self.program.window)

    self.program.window.reposition(self.gx + 1, self.gy + 1, self.w, self.h) --, self.program.window)
    if self.resizeQueued == true then
        resumeProcess(self, { "term_resize" })
        self.resizeQueued = false
    end

    self.program.window.setVisible(true)
    drawChildren(self)

    if self.parent:inFocus() == false then -- This makes it so that only the focused viewport is constantly drawn (unfocused windows have to wait for next redraw)
        self.program.window.setVisible(false)
    end

    term.redirect(self.parentTerm)
end

return ProgramViewport
end
