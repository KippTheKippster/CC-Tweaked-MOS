---@type MOS
local mos = __mos
---@type ProgramWindow
local mosWindow = __mosWindow
if mos == nil then
    printError("File Explorer must be opened with MOS!")
    return
end

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")

local args = { ... }

local fe = {}
fe.currentPath = ""
fe.startFile = ""

fe.selection = {}
---@enum PasteMode
fe.PasteMode = {
    COPY = 1,
    CUT = 2,
}

---@type PasteMode
fe.pasteMode = fe.PasteMode.COPY
fe.clipboard = {}

fe.mountedDisks = {}
fe.diskTools = {}
fe.toolsBound = false

---comment
---@param path string
---@param modifier FileOpenModifier
fe.openFileCallback = function(path, modifier, ...)
    if mos then
        if modifier == mos.FileOpenModifier.EDIT then
            mos.editProgram(path)
        elseif modifier == mos.FileOpenModifier.ARGS then
            mos.openProgramWithArgs(path)
        else
            mos.openProgram(path, ...)
        end
    end
end

if type(args[1]) == "function" then
    fe.openFileCallback = args[1]
end

local settings = args[2] or {}
local dirColor = colors.blue

if mos then
    mos.applyTheme(engine)
    dirColor = mos.profile.dirColor or mos.theme.fileColors.dirText
end

local fileStyle = engine.style:unique()
local fileSelectStyle = engine.style:unique()
fileSelectStyle.backgroundColor = colors.lightGray
local dirStyle = engine.style:unique()
dirStyle.textColor = dirColor
local dirSelectStyle = fileSelectStyle:unique()
dirSelectStyle.textColor = dirColor

engine.background = false

local main = engine.root:addVContainer()
main.expandW = true
main.expandH = true
main.rendering = true

local top = main:addHContainer()
top.expandW = true
top.h = 1
top.topLevel = true

local backButton = top:addButton()
backButton.text = "<"
backButton.h = 1
backButton.dragSelectable = true

local topSpacer = top:addControl()
topSpacer.text = ""

local pathContainer = top:addHContainer()
pathContainer.expandW = true
pathContainer.h = 1
pathContainer.rendering = true

local searchbar = main:addLineEdit()
searchbar.topLevel = true
searchbar.expandW = true
searchbar.visible = false

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

if settings.saveMode then
    saveContainer = SaveContainer:new()
    saveContainer.expandW = true

    saveContainer.saveEdit = saveContainer:addLineEdit()
    saveContainer.saveEdit.expandW = true
    saveContainer.saveEdit.text = args[3]

    saveContainer.saveButton = saveContainer:addButton()
    saveContainer.saveButton.text = "Save"
    saveContainer.saveButton.pressed = function()
        fe.openFile(fe.nameToPath(saveContainer.saveEdit.text), mos.getFileOpenModifierInput())
    end

    main:add(saveContainer)
end


---@return boolean, string
function fe.pPopupError(f, ...)
    local ok, err = pcall(f, ...)
    if ok == false then
        for i = 1, 3 do
            local idx = err:find(":")
            if idx ~= nil then
                err = err:sub(idx + 1)
            end
        end
        err = err:sub(2)
        mos.popupError(err)
    end
    return ok, err
end

---@class FileButton : Button
local FileButton = engine.Button:newClass()
FileButton.selected = false
FileButton.selectStyle = fileSelectStyle
FileButton.path = ""
FileButton._marginL = 1
FileButton._marginR = 1

function FileButton:render()
    --PANEL
    local st = self:getStyle()
    if st ~= self.normalStyle then -- Skip drawing background when it is the same as the program background
        self:drawPanel(self:getBorders())
    end

    --INFO TEXT
    local selfText = self.text
    local text = ""

    if fs.isDir(self.path) then              -- This can all be moved to init
        selfText = ">" .. selfText
        text = tostring(#fs.list(self.path)) -- This could be slow
    else
        local size = fs.getSize(self.path)
        if size < 100 then
            text = math.ceil(fs.getSize(self.path)) .. "  B"
        else
            text = math.ceil(fs.getSize(self.path) / 100) / 10 .. " kB"
        end
    end

    if mos.isFileFavorite(self.path) then
        if mos.profile.dirLeftHeart then
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
    if self.selected then
        if not engine.input.isKey(keys.leftCtrl) then
            fe.unselectFileButton(self, true)
        end
    else
        fe.selectFileButton(self, not engine.input.isKey(keys.leftCtrl))
    end
end

function FileButton:getStyle()
    if self.isClicked then
        return self.styleDown
    elseif self.selected then
        return self.selectStyle
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
        fileButton.selectStyle = dirSelectStyle
        fileButton.doublePressed = function(o)
            fe.openDir(path)
        end
    else
        fileButton.style = fileStyle
        fileButton.doublePressed = function(o)
            fe.openFile(path, mos.getFileOpenModifierInput())
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

---Combines the current path and the filename
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
    if mos.profile.dirShowDot and mos.profile.dirShowMos and mos.profile.dirShowRom then
        return files
    end

    local valid = function(file)
        if not mos.profile.dirShowDot and file:sub(1, 1) == "." then
            return false
        end

        local path = fs.combine(dir, file)
        if not mos.profile.dirShowMos and path == mos.toMosPath("") or path == ".mosdata" then
            return false
        end

        if not mos.profile.dirShowRom and path == "rom" then
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
    if not fs.exists(path) then
        error("Attemting to open non existent dir '" .. path .. "'")
    end

    fe.currentPath = path
    fe.clearSelection()

    fileContainer:freeChildren()
    pathContainer:freeChildren()
    scrollContainer:setScroll(0)

    searchbar.text = ""

    local bRoot = pathContainer:addButton()
    bRoot.text = "/"
    bRoot.dragSelectable = true
    bRoot.pressed = function()
        fe.openDir("")
    end

    local split = engine.utils.split(path, "/")
    local bPath = ""
    for i, v in ipairs(split) do
        bPath = fs.combine(bPath, v)

        local b = pathContainer:addButton()
        b.dragSelectable = true
        b.text = v .. "/"
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

    for _, dirName in ipairs(dirNames) do
        local b = fe.addFileButton(dirName)
        if b.path == fe.startFile then
            fe.selectFileButton(b, true)
        end
    end

    for _, fileName in ipairs(fileNames) do
        local b = fe.addFileButton(fileName)
        if b.path == fe.startFile then
            fe.selectFileButton(b, true)
        end
    end

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
---@param openModifier FileOpenModifier
function fe.openFile(path, openModifier, ...)
    fe.openFileCallback(path, openModifier, ...)
end

function fe.refresh()
    fe.openDir(fe.currentPath)
end

---comment
---@param name string
function fe.makeFile(name)
    if name == nil or name == "" then return end
    name = fe.formatName(name)
    local path = fe.nameToPath(name)
    if fe.pPopupError(fs.open, path, "w") then
        fe.addFileButton(name)
        os.queueEvent("mos_file_new", path)
    end
end

---comment
---@param name string
function fe.makeDir(name)
    if name == nil or name == "" then return end
    name = fe.formatName(name)
    local path = fe.nameToPath(name)
    if fe.pPopupError(fs.makeDir, path) then
        fe.addFileButton(name)
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
        fe.delete(v)
    end

    fe.clearSelection()
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
---@param pasteMode PasteMode
function fe.pasteClipboard(pasteMode)
    local fn = fs.copy
    if pasteMode == fe.PasteMode.CUT then
        fn = fs.move
    end

    for i, v in ipairs(fe.clipboard) do
        local to = fe.nameToPath(fs.getName(v))
        if fe.pPopupError(fn, v, to) then
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

---comment
---@return FileButton?
function fe.getFocusFileButton()
    if #fe.selection == 0 then
        return nil
    else
        return fe.selection[#fe.selection]
    end
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
            mos.openProgram(mos.toOsPath("/programs/diskInfo.lua"), path).text = "Disk Info '" .. title .. "'"
        elseif text == "Eject" then
            disk.eject(path)
        end
    end

    return dropdown
end

function fe.newDriveDropdown(path)
    ---@type Dropdown
    local dropdown = mos.engine.Dropdown:new()
    local title = disk.getMountPath(path)
    dropdown.text = title
    dropdown.text = "[" .. dropdown.text .. "]"
    dropdown.w = #dropdown.text
    dropdown:addToList("Install Folder")
    dropdown:addToList("Install Here")
    dropdown:addToList("--------------", false)
    dropdown:addToList("Set Label")
    dropdown:addToList("Info")
    dropdown:addToList("--------------", false)
    dropdown:addToList("Eject")

    dropdown.optionPressed = function(o, idx)
        local text = o:getOptionText(idx)
        if text == "Install Folder" then
            local edit = fe.newFileEdit("", function (o)
                fe.pPopupError(fs.copy, disk.getMountPath(path), fe.nameToPath(o.text))
                fe.addFileButton(o.text)
                o:queueFree()
            end)
            fileContainer:add(edit)
        elseif text == "Install Here" then
            local mountPath = disk.getMountPath(path)
            local files = fs.list(mountPath, "r")
            for i = 1, #files do
                local from = fs.combine(mountPath, files[i])
                local to = fe.nameToPath(files[i])
                local ok = true
                if fs.exists(to) then
                    ok = fe.pPopupError(fs.delete, to)
                end
                if ok then
                    ok = fe.pPopupError(fs.copy, from, to)
                    --if ok then
                    --    fe.addFileButton(files[i])
                    --end
                end
            end
            fe.refresh()
        elseif text == "Set Label" then
            mos.openArgs(function (data)
                disk.setLabel(path, data[1]) -- TODO Combine data to one string
            end, disk.getLabel(path)).text = "Set Label"
            return
        elseif text == "Info" then
            mos.openProgram(mos.toOsPath("/programs/diskInfo.lua"), path).text = "Disk Info '" .. title .. "'"
            return
        elseif text == "Eject" then
            fe.eject(path)
        end

        mosWindow:grabFocus()
    end

    return dropdown
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
    mos.log("mount ", path)
    fe.mountedDisks[path] = true
    assert(fe.diskTools[path] == nil, "Trying to add a disk tool that already exists!")
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
    mos.log("unmount ", path)
    fe.mountedDisks[path] = false
    assert(fe.diskTools[path] ~= nil, "Trying to remove a non-existent disk tool!")
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
    local mountPaths = {
        "top",
        "bottom",
        "front",
        "back",
        "right",
        "left"
    }

    for i, name in ipairs(mountPaths) do
        if disk.isPresent(name) then
            fe.mountDisk(name)
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
                fe.openFile(focusPath, mos.FileOpenModifier.NONE)
            end
        end
    elseif text == "Open w/ args" then
        if focusPath and fs.isDir(focusPath) == false then
            fe.openFile(focusPath, mos.FileOpenModifier.ARGS)
        end
    elseif text == "Edit" then
        if focusPath then
            if fs.isDir(focusPath) == false then
                fe.openFile(focusPath, mos.FileOpenModifier.EDIT)
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
    local focusPath = focusFileButton.path
    local text = editDropdown:getOptionText(i)
    if text == "Cut" then
        fe.pasteMode = fe.PasteMode.CUT
        fe.copySelectionToClipboard()
    elseif text == "Copy" then
        fe.pasteMode = fe.PasteMode.COPY
        fe.copySelectionToClipboard()
    elseif text == "Paste" then
        fe.pasteClipboard(fe.pasteMode)
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

mos.bindTool(mosWindow, function(focus)
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
        end
    end

    if engine.input.isInputGrabbed() then
        return
    end

    if event == "paste" then
        fe.pasteClipboard(fe.pasteMode)
    elseif event == "char" then
        local focus = engine.input.getFocus() -- This should be replaced with inputConsumed
        if focus == nil or focus.__type ~= "LineEdit" then
            searchbar:grabFocus()
        end
    elseif event == "key" then
        if engine.input.isKey(keys.leftCtrl) then
            local k = data[2]
            if k == keys.x then
                fe.pasteMode = fe.PasteMode.CUT
                fe.copySelectionToClipboard()
            elseif k == keys.c then
                fe.pasteMode = fe.PasteMode.COPY
                fe.copySelectionToClipboard()
            elseif k == keys.r then
                local b = fe.getFocusFileButton()
                if b then
                    fe.addRenameFileEdit(b)
                end
            elseif k == keys.f then
                fe.favoriteSelection()
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
                fe.clearSelection()
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
                fe.clearSelection()
            end
        elseif data[2] == keys.enter then
            local focus = fe.getFocusFileButton()
            if focus then
                if fs.isDir(focus.path) then
                    fe.openDir(focus.path)
                else
                    fe.openFile(focus.path, mos.getFileOpenModifierInput())
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
    elseif event == "disk_eject" then
        fe.unmountDisk(data[2])
    elseif event == "mos_favorite_add" then
        main:queueDraw()
    elseif event == "mos_favorite_remove" then
        main:queueDraw()
    elseif event == "mos_refresh_files" then
        fe.refresh()
    end
end

engine.input.addRawEventListener(rawEvent)

if settings.dir then
    fe.currentPath = settings.dir
end

fe.openDir(fe.currentPath)
fe.scanDisks()

engine.start()

-- Ideas
-- When opening a folder just add more files to the container instead of replacing them
