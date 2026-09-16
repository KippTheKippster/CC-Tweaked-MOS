if mos == nil then
    printError("File Explorer must be opened with MOS")
    return
end

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")

local args = { ... }

local fe = {}
fe.currentPath = ""
fe.startFile = ""
--- Stores file buttons
--- key:  path,
--- value: button
---@type table<string, FileButton>
fe.fileButtons = {}

---@type FileButton[]
fe.selection = {}

fe.pasteMode = "copy"
---@type string[]
fe.clipboard = {}
--- Stores disks that have been mounted
--- key:  disk name,
--- value: mount path
---@type table<string, string>
fe.mountedDisks = {}
---@type table<string, Control>
fe.diskTools = {}
fe.toolsBound = false

local options = args[1] or {closeOnOpen = false}
local function getDirColor()
    return settings.get("mos.files.dir_color") or mos.theme.fileColors.dirText
end

fe.openFileCallback = mos.openWithModifier
if type(options.callback) == "function" then
    fe.openFileCallback = options.callback
end


if mos then
    mos.applyTheme(engine)
end

local fileStyle = engine.style:inherit()
local fileSelectStyle = engine.styleEditFocus:inherit() -- TODO UNIQUE SHOULD WORK HERE
local fileCutStyle = engine.styleDisabled:inherit()
local dirStyle = engine.style:unique()
dirStyle.textColor = getDirColor()
local dirSelectStyle = fileSelectStyle:inherit()
dirSelectStyle.textColor = getDirColor()
local dirCutStyle = engine.styleDisabled:inherit()

engine.background = false

local main = engine.root:addVContainer()
main.expandW = true
main.expandH = true
main.rendering = true

local top = main:addHContainer()
top.expandW = true
top.h = 1
top.topLevel = true
top.style = engine.styleEditFocus:inherit()

local backButton = top:addButton()
backButton.text = "<"
backButton.h = 1
backButton.dragSelectable = true
backButton.inheritStyle = true

local topSpacer = top:addControl()
topSpacer.text = ""
topSpacer.inheritStyle = true

local pathContainer = top:addHContainer()
pathContainer.expandW = true
pathContainer.h = 1
pathContainer.rendering = true
pathContainer.inheritStyle = true

local searchbar = main:addLineEdit()
searchbar.topLevel = true
searchbar.expandW = true
searchbar.visible = false

local warning = main:addControl("")
do
    warning.expandW = true
    local s = warning.style:inherit()
    s.backgroundColor = colors.yellow
    warning.style = s
end
warning.visible = false

searchbar.textChanged = function(self)
    engine.LineEdit.textChanged(self)
    if self.text == "" then
        self.visible = false
        self:releaseFocus()
    else
        self.visible = true
    end
    main:queueSort()
    fe.filter(self.text)
end

local scrollContainer = main:addScrollContainer()
scrollContainer.expandW = true
scrollContainer.expandH = true

local fileContainer = scrollContainer:addVContainer()
fileContainer.expandW = true
fileContainer.fitToChildrenH = true

---@class SaveContainer : HContainer
local SaveContainer = engine.HContainer:newClass()
SaveContainer._expandW = true
---@type LineEdit
SaveContainer.saveEdit = nil
---@type Button
SaveContainer.saveButton = nil

---@type SaveContainer
local saveContainer = nil

if options.mode == "save" then
    saveContainer = SaveContainer:new()
    saveContainer.expandW = true

    saveContainer.saveEdit = saveContainer:addLineEdit()
    saveContainer.saveEdit.expandW = true
    --saveContainer.saveEdit.text = args[3]
    saveContainer.saveEdit:grabFocus()

    saveContainer.saveButton = saveContainer:addButton()
    saveContainer.saveButton.text = "Save"
    saveContainer.saveButton.pressed = function()
        fe.openFile(fe.nameToPath(saveContainer.saveEdit.text), mos.getInputFileOpenModifier())
    end

    main:add(saveContainer)
end

---@param err string
function fe.popupError(err)
    mos.popupError(fs.getName(err))
end

---@param warn string
function fe.setWarning(warn)
    if warn == "" then
        warning.visible = false
        warning:queueDraw()
        main:queueSort()
    else
        warning.text = "Warning: " .. warn
        warning.visible = true
        warning:queueDraw()
        main:queueSort()
    end
end

---@param f function
---@param ... any
---@return boolean, string
function fe.pPopupError(f, ...)
    local ok, err = pcall(f, ...)
    err = tostring(err)
    if not ok then
        fe.popupError(err)
    end
    return ok, err
end

---@type string[]
local errors = {}

function fe.popupErrorMulti()
    if #errors > 0 then
        mos.popupError(table.unpack(errors))
        errors = {}
    end
end

---comment
---@param f function
---@param ... any
---@return boolean, string
function fe.pPopupErrorMulti(f, ...)
    local ok, err = pcall(f, ...)
    err = fs.getName(tostring(err))
    if not ok then
        table.insert(errors, err)
    end
    return ok, err
end

---@class FileButton : Button
local FileButton = engine.Button:newClass()
FileButton.selected = false
FileButton.styleSelect = fileSelectStyle
FileButton.styleCut = fileCutStyle
FileButton.path = ""
FileButton.fileInfo = {
    type = "file",
    size = 0
}
FileButton._marginL = 1
FileButton._marginR = 1

function FileButton:render()
    --PANEL
    local st = self:getStyle()
    if st ~= self.style then -- Skip drawing background when it is the same as the program background
        self:drawPanel(self:getBorders())
    end

    --INFO TEXT
    local selfText = self.text
    local text = ""

    if self.fileInfo.type == "dir" then
        selfText = ">" .. selfText
        text = tostring(self.fileInfo.size)
    else
        local size = self.fileInfo.size--fs.getSize(self.path)
        if size < 100 then
            text = math.ceil(size) .. "  B"
        else
            text = math.ceil(size / 100) / 10 .. " kB"
        end
    end

    if mos.isFileFavorite(self.path) then
        if settings.get("mos.files.left_heart") then
            selfText = string.char(3) .. " " .. selfText
        else
            text = text .. " " .. string.char(3)
        end
    end

    if #text < self.w - #selfText - 2 then
        term.setBackgroundColor(st.backgroundColor)
        term.setTextColor(st.textColor)
        local x = self.w - #text
        term.setCursorPos(self.gx + x, self.gy + 1)
        term.write(text)
    end

    --TEXT
    self:write(selfText)
end

function FileButton:down()
    engine.Button.down(self)
    if self.selected and not engine.input.isKey(keys.leftShift) then
        if not engine.input.isKey(keys.leftCtrl) then
            fe.unselectFileButton(self, true)
        end
    else
        local focus = fe.selection[1]
        if focus and engine.input.isKey(keys.leftShift) then
            fe.clearSelection()
            local from = engine.utils.find(fileContainer.children, focus)
            local to   = engine.utils.find(fileContainer.children, self)
            local delta = to - from
            local sign = math.abs(delta) / delta
            for i = 1, math.abs(delta)+1 do
                local b = fe.getFileButton(from + (i-1)*sign)
                if b then
                    fe.selectFileButton(b, false)
                end
            end
        else
            fe.selectFileButton(self, not engine.input.isKey(keys.leftCtrl))
        end
    end
end

function FileButton:getStyle()
    if self.isClicked then
        return self.styleDown
    elseif self.selected then
        return self.styleSelect
    elseif engine.utils.contains(fe.clipboard, self.path) then
        return self.styleCut
    else
        return self.style
    end
end

---comment
---@param b FileButton
---@param clearSelection boolean
function fe.selectFileButton(b, clearSelection)
    if clearSelection then
        fe.clearSelection()
    end

    if saveContainer and saveContainer.saveEdit then
        saveContainer.saveEdit.text = b.text
    end

    scrollContainer:scrollToView(b.gy)

    fe.addToSelection(b)
    b:queueDraw()
end

---@param b FileButton
---@param clearSelection boolean
function fe.unselectFileButton(b, clearSelection)
    if clearSelection then
        fe.clearSelection()
    end

    fe.removeFromSelection(b)
end

---comment
---@param b FileButton
function fe.addToSelection(b)
    b.selected = true
    table.insert(fe.selection, b)
end

---comment
---@param b FileButton
function fe.removeFromSelection(b)
    b.selected = false
    table.remove(fe.selection, engine.utils.find(fe.selection, b))
end

function fe.clearSelection()
    for i, b in ipairs(fe.selection) do
        if b:isValid() == true then
            b.selected = false
            b:queueDraw()
        end
    end

    fe.selection = {}
end

---comment
---@param name string
---@return FileButton
function fe.newFileButton(name)
    ---@type FileButton
    local fileButton = FileButton:new()
    fileButton.__name = name
    local path = fe.nameToPath(name)
    if fs.isDir(path) then
        fileButton.style = dirStyle
        fileButton.styleSelect = dirSelectStyle
        fileButton.styleCut = dirCutStyle
        fileButton.fileInfo = {
            type = "dir",
            size = #fs.list(path)
        }
        fileButton.doublePressed = function(o)
            if engine.input.isKey(keys.leftShift) then
                mos.openDir(o.path)
            else
                fe.openDir(o.path)
            end
        end
    else
        fileButton.style = fileStyle
        fileButton.fileInfo = {
            type = "file",
            size = fs.getSize(path)
        }
        fileButton.doublePressed = function(o)
            fe.openFile(o.path, mos.getInputFileOpenModifier())
        end
    end
    fileButton.h = 1
    fileButton.expandW = true
    fileButton.dragSelectable = true
    fileButton.text = name
    fileButton.path = path
    return fileButton
end

---comment
---@param name string
---@return FileButton
function fe.addFileButton(name)
    local fileButton = fe.newFileButton(name)
    fileContainer:add(fileButton)
    return fileButton
end

---comment
---@param text string
---@param callback function
---@return LineEdit
function fe.newFileEdit(text, callback)
    local edit = engine.LineEdit:new()
    edit.text = text
    edit.expandW = true
    edit:grabFocus()
    edit.textSubmitted = function()
        callback(edit)
    end
    return edit
end

---comment
---@param callback function
---@return LineEdit
function fe.addFileEdit(callback)
    local edit = fe.newFileEdit("", callback)
    fileContainer:add(edit)
    fe.clearSelection()
    scrollContainer:scrollToView(fileContainer.gy + fileContainer.h + 1)
    mosWindow:grabFocus()
    return edit
end

---Combines the current path and 'name' to a full path
---@param name string
---@return string
function fe.nameToPath(name)
    return fs.combine(fe.currentPath, name)
end

function fe.formatName(name)
    local path = fe.nameToPath(name)
    return fs.getName(path)
end

function fe.list(dir)
    local files = fs.list(dir)
    local sDot, sMos, sRom = settings.get("mos.files.show_dot"), settings.get("mos.files.show_mos"), settings.get("mos.files.show_rom")
    if sDot and sMos and sRom then
        return files
    end

    local valid = function(file)
        if not sDot and file:sub(1, 1) == "." then
            return false
        end

        local path = fs.combine(dir, file)
        if not sMos and path == mos.toMosPath("") or path == ".mosdata" then
            return false
        end

        if not sRom and path == "rom" then
            return false
        end

        return true
    end

    local list = {}
    for _, v in ipairs(files) do
        if valid(v) then
            table.insert(list, v)
        end
    end

    return list
end

---comment
---@param path string
function fe.openDir(path)
    term.setBackgroundColor(colors.black)
    if not fs.exists(path) then
        mos.popupError("Attemting to open non existent dir '" .. path .. "'")
        return
    end

    if not fs.isDir(path) then
        mos.popupError("Not a directory '" .. path .. "'")
        return
    end

    fe.currentPath = path
    fe.clearSelection()
    fe.fileButtons = {}
    fe.setWarning("")

    fileContainer:freeChildren()
    pathContainer:freeChildren()
    scrollContainer:setScroll(0)

    searchbar.text = ""

    local bRoot = pathContainer:addButton()
    bRoot.text = "/"
    bRoot.dragSelectable = true
    bRoot.inheritStyle = true
    bRoot.pressed = function()
        fe.openDir("")
    end

    local split = engine.utils.split(path, "/")
    local bPath = ""
    for i, v in ipairs(split) do
        bPath = fs.combine(bPath, v)

        local b = pathContainer:addButton()
        b.text = v .. "/"
        b.dragSelectable = true
        b.inheritStyle = true
        local ok = bPath
        b.pressed = function()
            fe.openDir(ok)
        end
    end

    local dirNames = {}
    local fileNames = {}
    for _, file in ipairs(fe.list(path)) do
        local filePath = fe.nameToPath(file)
        if fs.isDir(filePath) then
            table.insert(dirNames, file)
        else
            table.insert(fileNames, file)
        end
    end

    local fileButtons = {}

    for _, dirName in ipairs(dirNames) do
        local b = fe.newFileButton(dirName)
        if fe.mountedDisks[b.path] then
            b.text = "["..b.text.."]"
        end
        fe.fileButtons[dirName] = b
        table.insert(fileButtons, b)
        if b.path == fe.startFile then
            fe.selectFileButton(b, true)
        end
    end

    for _, fileName in ipairs(fileNames) do
        local b = fe.newFileButton(fileName)
        fe.fileButtons[fileName] = b
        table.insert(fileButtons, b)
        if b.path == fe.startFile then
            fe.selectFileButton(b, true)
        end
    end

    fileContainer:replaceChildren(fileButtons)

    fe.startFile = ""
end

---comment
---@param filter string
function fe.filter(filter)
    if filter == "" then
        for _, v in ipairs(fileContainer.children) do
            v.visible = true
        end
    else
        for _, v in ipairs(fileContainer.children) do
            if filter == "" or v.path:find(filter, 1, true) ~= nil then
                v.visible = true
            else
                v.visible = false
            end
        end
    end
    fileContainer:queueSort()
end

---comment
---@param path string
---@param openModifier string
function fe.openFile(path, openModifier, ...)
    fe.openFileCallback(path, openModifier, ...)
    if options.closeOnOpen ~= false then
        mosWindow:close()
    end
end

function fe.refresh()
    fe.openDir(fe.currentPath)
end

---comment
---@param path string
function fe.refreshFile(path)
    if fs.getDir(path) == fe.currentPath then
        if fe.fileButtons[path] then
            if not fs.exists(path) then
                fe.fileButtons[path]:queueFree()
                fe.fileButtons[path] = nil
            end
        else
            if fs.exists(path) then
                local b = fe.addFileButton(fs.getName(path))
                fe.fileButtons[path] = b
            end
        end
    end

    if path == fe.currentPath then
        if fs.exists(path) then
            fe.openDir(path)
        else
            fe.setWarning("current dir does not exist")
        end
    end
end

---comment
---@param name string
function fe.makeFile(name)
    -- Note: unlike fs.makeDir, fs.open does not throw errors when it fails to create a file, so checks are required
    if name == nil or name == "" then return end
    if not fs.exists(fe.currentPath) then return end
    name = fe.formatName(name)
    local path = fe.nameToPath(name)
    if fs.exists(path) then
        fe.popupError(path .. ": File exists")
        return
    end

    if fs.isReadOnly(fe.currentPath) then
        fe.popupError(path .. ": Access denied")
        return
    end

    if fe.pPopupError(fs.open, path, "w") then
        local b = fe.addFileButton(name)
        fe.addToSelection(b)
        os.queueEvent("mos_file_new", path)
    end
end

---comment
---@param name string
function fe.makeDir(name)
    if name == nil or name == "" then return end
    if not fs.exists(fe.currentPath) then return end
    name = fe.formatName(name)
    local path = fe.nameToPath(name)
    if fe.pPopupError(fs.makeDir, path) then
        local b = fe.addFileButton(name)
        fe.addToSelection(b)
        os.queueEvent("mos_file_new", path)
    end
end

function fe.favoriteSelection()
    if #fe.selection == 0 then
        return
    end

    local fn = mos.addFileFavorite
    if mos.isFileFavorite(fe.getFocusFileButton().path) then
        fn = mos.removeFileFavorite
    end

    for i, v in ipairs(fe.selection) do
        fn(v.path)
    end
    mos.refreshMosDropdown()
end

---comment
---@param b FileButton
function fe.delete(b)
    if fe.pPopupError(fs.delete, b.path) then
        -- TODO Remove from selection
        b:queueFree()
        os.queueEvent("mos_file_delete", b.path)
    end
end

function fe.deleteSelection()
    for i, v in ipairs(fe.selection) do
        if fe.pPopupErrorMulti(fs.delete, v.path) then
            v:queueFree()
            os.queueEvent("mos_file_delete", v.path)
        end
    end

    fe.popupErrorMulti()
    fe.clearSelection()
end

function fe.copy()
    fe.pasteMode = "copy"
    fe.copySelectionToClipboard()
end

function fe.cut()
    fe.pasteMode = "cut"
    fe.copySelectionToClipboard()
    fe.clearSelection()
end

function fe.paste()
    fe.pasteClipboard(fe.pasteMode)
end

function fe.clearClipboard()
    fe.clipboard = {}
end

function fe.copySelectionToClipboard()
    fe.clearClipboard()
    for i, v in ipairs(fe.selection) do
        table.insert(fe.clipboard, v.path)
    end
end

---comment
---@param pasteMode string
function fe.pasteClipboard(pasteMode)
    local fn = fs.copy
    if pasteMode == "cut" then
        fn = fs.move
    end
    for i, v in ipairs(fe.clipboard) do
        local to = fe.nameToPath(fs.getName(v))

        if pasteMode == "copy" then
            while fs.exists(to) do
                to = to .. " copy"
            end
        end

        if pasteMode == "cut" and ("/" .. fs.getDir(v) == fe.currentPath or fs.getDir(v) == fe.currentPath) then
            
        elseif fe.pPopupErrorMulti(fn, v, to) then
            if fn == fs.copy then
                os.queueEvent("mos_file_copy", v, to)
                os.queueEvent("mos_file_new", to)
            elseif fn == fs.move then
                os.queueEvent("mos_file_move", v, to)
                os.queueEvent("mos_file_delete", v)
                os.queueEvent("mos_file_new", to)
            end
        end

    end

    fe.popupErrorMulti()    
    fe.clearClipboard()
    fe.refresh()
end

---comment
---@param b FileButton
---@param name string
function fe.rename(b, name)
    name = fe.formatName(name)
    if b.text == name then
        return
    end

    local path = fe.nameToPath(name)
    if fe.pPopupError(fs.move, b.path, path) then
        b.text = name
        b.path = path
    end
    --fe.refresh()
end

---comment
---@param b FileButton
function fe.addRenameFileEdit(b)
    fe.selectFileButton(b, true)
    local edit = fe.newFileEdit(b.text, function(o)
        fe.rename(b, o.text)
        o:queueFree()
    end)
    edit.inheritStyle = false
    b:add(edit)
end

---@return FileButton?
function fe.getFocusFileButton()
    return fe.selection[#fe.selection]
end

---@param i integer
---@return FileButton
function fe.getFileButton(i)
    return fileContainer:getChild(i)
end

function fe.newAudioDropdown(path)
    ---@type Dropdown
    local dropdown = mos.engine.Dropdown:new()
    local title = disk.getAudioTitle(path) or disk.getpath(path)
    dropdown.text = title
    dropdown.text = "[" .. dropdown.text .. "]"
    dropdown.w = #dropdown.text
    dropdown:addToList("Play Audio")
    dropdown:addToList("Stop Audio")
    dropdown:addToList("----------", false)
    dropdown:addToList("Info")
    dropdown:addToList("----------", false)
    dropdown:addToList("Eject")

    dropdown.optionPressed = function(o, i)
        local text = o:getOptionText(i)
        if text == "Play Audio" then
            disk.playAudio(path)
        elseif text == "Stop Audio" then
            disk.stopAudio(path)
        elseif text == "Info" then
            mos.openFile(mos.toOsPath("/programs/diskInfo.lua"), path).text = "Disk Info '" .. title .. "'"
        elseif text == "Eject" then
            disk.eject(path)
        end
    end

    return dropdown
end

function fe.newDriveDropdown(path)
    ---@type Dropdown
    local dropdown = mos.engine.Dropdown:new()
    local mount = disk.getMountPath(path)
    dropdown.text = mount
    dropdown.text = "[" .. dropdown.text .. "]"
    dropdown.w = #dropdown.text
    dropdown:addToList("Open")
    dropdown:addToList("Open Window")
    dropdown:addToList("--------------", false)
    dropdown:addToList("Set Label")
    dropdown:addToList("Info")
    dropdown:addToList("--------------", false)
    dropdown:addToList("Eject")

    dropdown.optionPressed = function(o, idx)
        local text = o:getOptionText(idx)
        if text == "Open" then
            fe.openDir(mount)
        elseif text == "Open Window" then
            mos.openDir(mount)
            return
        elseif text == "Set Label" then
            mos.openArgs(function (data)
                disk.setLabel(path, data[1]) -- TODO Combine data to one string
            end, disk.getLabel(path)).text = "Set Label"
            return
        elseif text == "Info" then
            mos.openFile(mos.toOsPath("/programs/diskInfo.lua"), path).text = "Disk Info '" .. mount .. "'"
            return
        elseif text == "Eject" then
            disk.eject(path)
        end

        mosWindow:grabFocus()
    end

    return dropdown
end

local function isDiskSupported(path)
    return disk.hasData(path) or disk.hasAudio(path)
end

function fe.newDiskDropdown(path)
    if disk.hasData(path) then
        return fe.newDriveDropdown(path)
    elseif disk.hasAudio(path) then
        return fe.newAudioDropdown(path)
    else
        error("Unsupported Disk")
    end
end

---comment
---@param path string
function fe.mountDisk(path)
    if not isDiskSupported(path) then
        return
    end

    local mount = disk.getMountPath(path) or disk.getAudioTitle(path) or "UNKOWN"
    fe.mountedDisks[path] = mount
    assert(fe.diskTools[path] == nil, "Trying to add a disk tool that already exists")
    local bound = fe.toolsBound
    if bound then
        fe.clearTools()
    end
    fe.diskTools[path] = fe.newDiskDropdown(path)
    if bound then
        fe.addTools()
    end
end

---comment
---@param path string
function fe.unmountDisk(path)
    if not fe.mountedDisks[path] then
        return
    end

    fe.mountedDisks[path] = nil
    assert(fe.diskTools[path] ~= nil, "Trying to remove a non-existent disk tool")
    local bound = fe.toolsBound
    if bound then
        fe.clearTools()
    end
    fe.diskTools[path]:queueFree()
    fe.diskTools[path] = nil
    if bound then
        fe.addTools()
    end
end

function fe.scanDisks()
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "drive") then
            local drive = peripheral.wrap(name)
            if drive.isDiskPresent() then
                fe.mountDisk(name)
            end
        end
    end
end

function fe.backDir()
    if fe.currentPath == "" then
        fe.openDir("")
    else
        fe.openDir(fs.getDir(fe.currentPath))
    end
end

function backButton:pressed()
    fe.backDir()
end

-- MOS
local fileDropdown = mos.engine.Dropdown:new()
fileDropdown.text = "File"
fileDropdown:addToList("New File")
fileDropdown:addToList("New Dir")
fileDropdown:addToList("------------", false)
fileDropdown:addToList("Open")
fileDropdown:addToList("Open w/ args")
fileDropdown:addToList("------------", false)
fileDropdown:addToList("Edit")
fileDropdown:addToList("------------", false)
fileDropdown:addToList("Close")

function fileDropdown:optionPressed(i)
    local focusFileButton = fe.getFocusFileButton()
    local focusPath = nil
    if focusFileButton then
        focusPath = focusFileButton.path
    end

    local text = fileDropdown:getOptionText(i)
    if text == "New File" then
        fe.addFileEdit(function(edit)
            edit:queueFree()
            fe.makeFile(edit.text)
        end)
    elseif text == "New Dir" then
        fe.addFileEdit(function(edit)
            edit:queueFree()
            fe.makeDir(edit.text)
        end)
    elseif text == "Open" then
        if focusPath then
            if fs.isDir(focusPath) then
                fe.openDir(focusPath)
            else
                fe.openFile(focusPath, "none")
            end
        end
    elseif text == "Open w/ args" then
        if focusPath and fs.isDir(focusPath) == false then
            fe.openFile(focusPath, "args")
        end
    elseif text == "Edit" then
        if focusPath then
            if fs.isDir(focusPath) == false then
                fe.openFile(focusPath, "edit")
            end
        end
    elseif text == "Close" then
        if mosWindow then
            mosWindow:close()
        end
    end
end

local editDropdown = mos.engine.Dropdown:new()
editDropdown.text = "Edit"
editDropdown:addToList("Cut")
editDropdown:addToList("Copy")
editDropdown:addToList("Paste")
editDropdown:addToList("--------", false)
editDropdown:addToList("Rename")
editDropdown:addToList("Favorite")
editDropdown:addToList("--------", false)
editDropdown:addToList("Delete")

function editDropdown:optionPressed(i)
    local focusFileButton = fe.getFocusFileButton()
    if not focusFileButton then
        return
    end
    local text = editDropdown:getOptionText(i)
    if text == "Cut" then
        fe.cut()
    elseif text == "Copy" then
        fe.copy()
    elseif text == "Paste" then
        fe.paste()
    elseif text == "Rename" then
        fe.addRenameFileEdit(focusFileButton)
        mosWindow:grabFocus()
    elseif text == "Favorite" then
        fe.favoriteSelection()
    elseif text == "Delete" then
        fe.deleteSelection()
    end
end

function fe.addTools()
    mos.addToToolbar(fileDropdown)
    mos.addToToolbar(editDropdown)
    --- TODO Prioritize where disk.hasData() == true
    for _, v in pairs(fe.diskTools) do
        mos.addToToolbar(v)
    end
end

function fe.clearTools()
    mos.removeFromToolbar(fileDropdown)
    mos.removeFromToolbar(editDropdown)
    for _, v in pairs(fe.diskTools) do
        mos.removeFromToolbar(v)
    end
end

mos.bindWindowTool(mosWindow, function(focus)
    fe.toolsBound = focus
    if focus then
        fe.addTools()
    else
        fe.clearTools()
    end
end)

local function input(data)
    local event = data[1]

    if event == "key" then
        local k = data[2]
        if k == keys.down or k == keys.up then
            if searchbar.focus then
                searchbar:releaseFocus()
            end
        elseif k == keys.enter and options.mode == "save" and saveContainer and saveContainer.saveEdit and saveContainer.saveEdit:inFocus() then -- Long long man
            fe.openFileCallback(fe.nameToPath(saveContainer.saveEdit.text), 0)
            return
        end
    end

    if engine.input.isInputGrabbed() then
        return
    end

    if event == "paste" then
        fe.paste()
    elseif event == "char" then
        searchbar:grabFocus()
    elseif event == "key" then
        local k = data[2]
        if k == keys.backspace then
            if searchbar.visible then
                searchbar:grabFocus()
                return
            end
        end

        if engine.input.isKey(keys.leftCtrl) then
            if k == keys.x then
                fe.cut()
            elseif k == keys.c then
                fe.copy()
            elseif k == keys.r then
                local b = fe.getFocusFileButton()
                if b then
                    fe.addRenameFileEdit(b)
                end
            elseif k == keys.f then
                fe.favoriteSelection()
            elseif k == keys.a then
                for _, v in ipairs(fileContainer.children) do
                    fe.addToSelection(v)
                end
                main:queueDraw()
            end
        elseif data[2] == keys.delete then
            fe.deleteSelection()
        end

        if data[2] == keys.down then
            if #fileContainer.children == 0 then
                return
            end

            local focus = fe.getFocusFileButton()
            if focus == nil then
                fe.selectFileButton(fileContainer:getChild(1), true)
            else
                local start = engine.utils.find(fileContainer.children, focus) + 1
                for i = start, #fileContainer.children do
                    local c = fileContainer:getChild(i)
                    if c.visible then
                        fe.selectFileButton(c, true)
                        return
                    end
                end
                --fe.clearSelection()
                fe.selectFileButton(fileContainer:getChild(1), true)
            end
        elseif data[2] == keys.up then
            if #fileContainer.children == 0 then
                return
            end

            local focus = fe.getFocusFileButton()
            if focus == nil then
                fe.selectFileButton(fileContainer:getChild(#fileContainer.children), true)
            else
                local start = engine.utils.find(fileContainer.children, focus)
                for i = 1, start - 1 do
                    local index = start - i
                    local c = fileContainer:getChild(index)
                    if c.visible then
                        fe.selectFileButton(c, true)
                        return
                    end
                end
                fe.selectFileButton(fileContainer:getChild(#fileContainer.children), true)
            end
        elseif data[2] == keys.enter then
            local focus = fe.getFocusFileButton()
            if focus then
                if fs.isDir(focus.path) then
                    fe.openDir(focus.path)
                else
                    fe.openFile(focus.path, mos.getInputFileOpenModifier())
                end
            end
        elseif data[2] == keys.right then
            local focus = fe.getFocusFileButton()
            if focus then
                if fs.isDir(focus.path) then
                    fe.openDir(focus.path)
                    if #fileContainer.children > 0 then
                        fe.selectFileButton(fileContainer:getChild(1), true)
                    end
                end
            end
        elseif data[2] == keys.left then
            fe.startFile = fe.currentPath
            fe.backDir()
        end
    end
end

local function rawEvent(data)
    input(data)

    local event = data[1]
    if event == "disk" then
        fe.mountDisk(data[2])
        if fe.mountedDisks[data[2]] then
            fe.refreshFile(fe.mountedDisks[data[2]])
        end
    elseif event == "disk_eject" then
        if fe.mountedDisks[data[2]] then
            fe.refreshFile(fe.mountedDisks[data[2]])
        end
        fe.unmountDisk(data[2])
    elseif event == "mos_favorite" then
        main:queueDraw()
    elseif event == "mos_favorite_remove" then
        main:queueDraw()
    elseif event == "mos_refresh_files" then
        fe.refresh()
    end
end

engine.input.addRawEventListener(rawEvent)

if options.start then
    fe.currentPath = options.start
end

fe.scanDisks()
fe.openDir(fe.currentPath)

engine.start()
