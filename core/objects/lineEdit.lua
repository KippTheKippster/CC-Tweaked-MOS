---@param control Control
---@param input Input
---@param style Style
---@return LineEdit
return function(control, input, style, styleFocus)
---@class LineEdit : Control
local LineEdit = control:newClass()
LineEdit.__type = "LineEdit"

LineEdit.style = style
LineEdit.styleFocus = styleFocus

LineEdit._h = 1
LineEdit._w = 12
LineEdit._minH = 1
LineEdit._text = ""
LineEdit._cursorX = 0
---@type integer
LineEdit.cursorX = nil
LineEdit.clipText = true
LineEdit.lineScroll = 0
LineEdit._fitToText = false

LineEdit:defineProperty("cursorX", {
    get = function (o)
        return o._cursorX
    end,
    set = function (o, x)
        x = math.max(x, 0)
        x = math.min(x, #o.text)
        o._cursorX = x
        o:queueDraw()
    end
})

function LineEdit:render()
    local w = self.w - 1 - (self.marginL + self.marginR)
    if self.cursorX - self.offsetTextX > w then
        self.offsetTextX = self.cursorX - (w)
    end
    if self.cursorX - self.offsetTextX < 0 then
        self.offsetTextX = self.offsetTextX + (self.cursorX - self.offsetTextX)
    end

    self.offsetTextX = math.min(self.offsetTextX, math.max(0, #self.text - w))

    control.render(self)
end

function LineEdit:updateCursor()
    local s = self:getStyle()
    --term.setCursorPos(self.gx + #self.text + self.cursorOffset + self.marginL + 1, self.gy + 1)
    term.setCursorPos(self.cursorX - self.offsetTextX + self.marginL + self.gx + 1, self.gy + 1)
    term.setTextColor(s.textColor)
    term.setBackgroundColor(s.backgroundColor)
    term.setCursorBlink(true)
end

function LineEdit:addText(text, x)
    self.text = (
        self.text:sub(0, x) ..
        text ..
        self.text:sub(x + 1)
    )
end

function LineEdit:removeText(from, to)
    if to == 0 then
        return
    end

    self.text = (
        self.text:sub(0, from) ..
        self.text:sub(to)
    )
end

local function findPrevWord(str, x)
    local inSpace = true
    local i = x
    while i > 0 do
        if string.byte(str, i, i) == 32 then
            if inSpace == false then
                return i
            end
        else
            inSpace = false
        end
        i = i - 1
    end

    return i
end

local function findNextWord(str, x)
    local inSpace = true
    local i = x
    while i <= #str do
        i = i + 1
        if string.byte(str, i, i) == 32 then
            if inSpace == false then
                return i - 1
            end
        else
            inSpace = false
        end
    end

    return i - 1
end

function LineEdit:input(data)
    local event = data[1]
    if event == "char" then
        self:addText(data[2], self.cursorX)
        self.cursorX = self.cursorX + #data[2]
    elseif event == "key" then
        local k = data[2]
        local ctrl = input.isKey(keys.leftCtrl)
        if k == keys.backspace then
            if ctrl then
                local i = findPrevWord(self.text, self.cursorX)
                self:removeText(i, self.cursorX + 1)
                self.cursorX = i
            else
                self:removeText(self.cursorX - 1, self.cursorX + 1)
                self.cursorX = self.cursorX - 1
            end
        elseif k == keys.left then
            if ctrl then
                self.cursorX = findPrevWord(self.text, self.cursorX)
            else
                self.cursorX = self.cursorX - 1
            end
        elseif k == keys.right then
            if ctrl then
                self.cursorX = findNextWord(self.text, self.cursorX)
            else
                self.cursorX = self.cursorX + 1
            end
        elseif k == keys.enter then
            self:releaseFocus()
        end
    end
end

function LineEdit:down(b, x, y)
    self.cursorX = x - 1 + self.offsetTextX
end

function LineEdit:focusChanged()
    if self.focus then
        self.cursorX = #self.text
        self:grabCursor()
        self:grabInput()
    else
        self:textSubmitted()
        term.setCursorBlink(false)
        self:releaseCursor()
        self:releaseInput()
    end
    self:queueDraw()
end

function LineEdit:getStyle()
    if self:inFocus() then
       return self.styleFocus
    else
        return self.style
    end
end


function LineEdit:textSubmitted() end

return LineEdit
end