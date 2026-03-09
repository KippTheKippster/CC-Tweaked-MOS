---@param mos MOS
return function (mos)
local engine = mos.engine

---@class QuickSearch : LineEdit
local qs = engine.LineEdit:new()
qs.h = 1
qs.expandW = true
qs.visible = false
qs.styleFocus = mos.style.toolbar
qs.marginL = 2
qs._skip = true
function qs:init()
    engine.LineEdit.init(self)
    qs.x = 2
end

function qs:treeEntered()
    self:resize()
end

qs.programs = {}

table.insert(qs.programs, { name = "File Explorer", path = "/mos/os/programs/files.lua" })
table.insert(qs.programs, { name = "Shell", path = "/rom/programs/advanced/multishell.lua" })
table.insert(qs.programs, { name = "Settings", path = "/mos/os/programs/settings.lua" })
table.insert(qs.programs, { name = "Paint", path = "/mos/os/programs/paint.lua" })
table.insert(qs.programs, { name = "Lua", path = "/rom/programs/lua.lua" })
table.insert(qs.programs, { name = "Time", path = "/rom/programs/time.lua" })

local dirs = { "" }
local index = 1
while index <= #dirs do
    local dir = dirs[index]
    local files = fs.list(dirs[index])
    for i, file in ipairs(files) do
        if fs.isDir(file) then
            local path = fs.combine(dir, file)
            if not disk.isPresent(path) then       
                if file ~= "rom" and file ~= "mos" and file ~= ".logs" and file ~= ".mosdata" then
                    table.insert(dirs, path)
                end
            end
        else
            table.insert(qs.programs, { name = file, path = fs.combine(dir, file) })
        end
    end

    index = index + 1
end


function qs:textChanged()
    engine.LineEdit.textChanged(self)
    qs:refreshList()
end

function qs:input(data)
    if data[1] == "char" then
        if self._skip == false then
            engine.LineEdit.input(self, data)
        end
        self._skip = false
    else
        engine.LineEdit.input(self, data)
    end
end


function qs:open()
    self._skip = true
    self.cursorX = 0
    self.text = ""
    self:grabFocus()
    self:refreshList()
    self.list.shortcutSelection = self.list.children[1]
    self.list:next()
end

function qs:close()
    self:grabFocus()
    self:releaseFocus()
    self.visible = false
    self.list:clearList()
end


function qs:next()
    if self:isOpen() then
        self.list:next()
    end
end

function qs:previous()
    if self:isOpen() then
        self.list:previous()
    end
end

function qs:select()
    if self.list.shortcutSelection then
        self.list.shortcutSelection:pressed()
    end
end

function qs:isOpen()
    return self.visible
end

function qs:focusChanged()
    engine.LineEdit.focusChanged(self)
    self.visible = self:inFocus()
end

local list = qs:addDropdown()
list.propogateFocusUp = true
list.rendering = false
list.mouseIgnore = true
qs.list = list

local icon = qs:addControl()
icon.propogateFocusUp = true
icon.text = string.char(187)
icon.fitToText = false
icon.w = 2
icon.h = 1
icon.inheritStyle = true

function qs:refreshList ()
    local pathSelection = ""
    if list.shortcutSelection then
        pathSelection = list.shortcutSelection.text
    end

    local count = 0
    list:clearList()
    for i, program in ipairs(qs.programs) do
        if count >= 10 then
            break
        end

        local continue = true
        if mos.user.dirShowDot == false and program.name:sub(0, 1) == "." then
            continue = false
        end

        if program.name:lower():find(qs.text:lower()) == nil then --and fs.isDir(files[i]) == false then
            continue = false
        end

        if continue then
            local option = list:addToList(program.name)--shortcuts[i]:sub(1, #shortcuts[i] - 4))
            option.pressed = function (o)
                self:close()
                mos.openWithModifier(program.path, mos.getInputFileOpenModifier())
            end

            if option.text == pathSelection then
                list.shortcutSelection = option
                option:down()
            end

            count = count + 1
        end
    end

    if list.shortcutSelection == nil then
        list.shortcutSelection = list
        list:next()
    end
end

return qs
end
