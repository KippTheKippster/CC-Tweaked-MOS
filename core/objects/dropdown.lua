---@return Dropdown
return function(button, input, utils)
---@class Dropdown : Button
local Dropdown = button:newClass()
Dropdown.__type = "Dropdown"

Dropdown._h = 1
Dropdown.list = nil
Dropdown.open = false
Dropdown.dragSelectable = true
Dropdown.shortcutSelection = nil
Dropdown.optionShadow = true

function Dropdown:init(text)
    button.init(self, text)
    self.list = self:addVContainer()
    self.list.minW = 0
    self.list.minH = 0
    self.list.fitToChildrenW = true
    self.list.fitToChildrenH = true
    self.list.render = function (o)
        o:drawShadow()
    end
    self.list.rendering = true
    self.list.topLevel = true
    self.list.y = self.h
    self.list.visible = false
    self.list.propogateFocusUp = true
    self.list.dragSelectable = true
    self.list.shadow = self.optionShadow
    self.list.mouseIgnore = true

    self.list.rendering = true

    input.addRawEventListener(self)
end

function Dropdown:queueFree()
    input.removeRawEventListener(self)
    button.queueFree(self)
end

function Dropdown:isOpened()
   return self.list.visible == true
end

function Dropdown:close()
    self.list.visible = false
    self.shortcutSelection = nil
end

function Dropdown:rawEvent(data)
    local event = data[1]
    if event == "mouse_up" then
        self:close()
    end
end

function Dropdown:focusChanged()
    if self.focus == false then
        self:up()
        if self.shortcutSelection ~= nil then
            self.shortcutSelection:up()
        end

        self:close()
    end
end

---@return Control
function Dropdown:addToList(text, clickable)
    if clickable == nil then
        clickable = true
    end

    local b = nil
    if clickable == true then
        b = self.list:addButton()
        b.optionSelectable = true
    else
        b = self.list:addControl()
        b.optionSelectable = false
    end
    b.shadow = false
    b.text = text
    b.h = 1
    b.dragSelectable = true
    b.propogateFocusUp = true
    b.marginL = 1
    b.marginR = 1
    b.expandW = true
    local down = b.down
    b.down = function(o)
        if self.shortcutSelection then
            self.shortcutSelection:up()
        end
        down(o)
        self.shortcutSelection = o
    end
    b.pressed = function(o)
        for i = 1, #o.parent.children do
            if o.parent.children[i] == o then
                self:optionPressed(i)
                break
            end
        end
    end

    b.getStyle = function (o)
        if not o.optionSelectable then
            return self.styleDisabled
        elseif o.isClicked then
            return self.styleDown
        else
            return self.style
        end
    end

    self.list:queueSort()

    return b
end

function Dropdown:removeFromList(o)
    if type(o) == "string" then
        for i = 1, #self.list.children do
            if self.list.children[i].text == o then
                self.list.children[i]:queueFree()
                break
            end
        end
    else
        self.list:remove(o)
    end
end

function Dropdown:clearList()
    if self.list == nil then return end
    for i = 1, #self.list.children do
        self.list:remove(self.list.children[1])
    end
    self.shortcutSelection = nil
end

function Dropdown:down()
    if self.disabled then
        return
    end

    button.down(self)
    self.list.visible = true
    if self.shortcutSelection and self.shortcutSelection ~= self then
        self.shortcutSelection:up()
    end

    self.shortcutSelection = self
end

function Dropdown:getOptionText(i)
    return self.list.children[i].text
end

function Dropdown:getOption(i)
    return self.list.children[i]
end

function Dropdown:getOptionsTextList()
    local textList = {}
    for i = 1, #self.list.children do
        table.insert(textList, self.list.children[i].text)
    end
    return textList
end

function Dropdown:next()
    if self.disabled then
        self.list.visible = false
        return
    end

    self.list.visible = true
    if self:isOpened() == false then
        if self.shortcutSelection ~= nil then
            self.shortcutSelection:releaseFocus()
        end
        self.shortcutSelection = nil
    end

    if self.shortcutSelection ~= nil then
        self.shortcutSelection:up()
        local idx = utils.find(self.list.children, self.shortcutSelection)

        if idx == nil then
            self.shortcutSelection = self.list.children[1]
        else
            self.shortcutSelection = nil
            for i = 1, #self.list.children - idx do
                local next = self.list.children[idx + i]
                if next ~= nil and next.optionSelectable == true then
                    self.shortcutSelection = next
                    break
                end
            end
        end
    end

    if self.shortcutSelection == nil then
        self.shortcutSelection = self
    end

    self.shortcutSelection:down()
    self.shortcutSelection:grabFocus()
end

function Dropdown:previous()
    self.list.visible = true
    if self:isOpened() == false then
        if self.shortcutSelection ~= nil then
            self.shortcutSelection:releaseFocus()
        end
        self.shortcutSelection = nil
    end

    if self.shortcutSelection ~= nil then
        self.shortcutSelection:up()
        local idx = utils.find(self.list.children, self.shortcutSelection)

        if idx == nil then
            self.shortcutSelection = self.list.children[#self.list.children]
        else
            self.shortcutSelection = nil
            for i = 1, #self.list.children do
                local next = self.list.children[idx - i]
                if next ~= nil and next.optionSelectable == true then
                    self.shortcutSelection = next
                    break
                end
            end
        end
    end

    if self.shortcutSelection == nil then
        self.shortcutSelection = self
    end

    self.shortcutSelection:down()
    self.shortcutSelection:grabFocus()
end

function Dropdown:release()
    if self:isOpened() == true then
        if self.shortcutSelection ~= nil then
            self.shortcutSelection:up()
            self.shortcutSelection:pressed()
        end

        self:close()
    end
    self.shortcutSelection = nil
end

function Dropdown:optionPressed(i) end

return Dropdown
end