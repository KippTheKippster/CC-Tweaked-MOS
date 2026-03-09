---@type MOS
local mos = __mos
if mos == nil then
    printError("Settings must be opened with MOS!")
    return
end

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")


mos.applyTheme(engine)

local seperatorStyle = engine.style:inherit()
seperatorStyle.textColor = colors.gray

local scrollContainer = engine.root:addScrollContainer()
scrollContainer.expandW = true
scrollContainer.expandH = true

local main = scrollContainer:addVContainer()
main.expandW = true
main.expandH = true
main.marginL = 1
main.marginR = 1

local settingsButton = engine.Button:newClass()
settingsButton._h = 1

local function addSeperator(text)
    local seperator = main:addControl()
    seperator.h = 2
    seperator.expandW = true
    seperator.centerText = true
    seperator.style = seperatorStyle
    seperator.text = text
    return seperator
end


---@param text string
local function addLabel(text)
    ---@type Control
    local label = main:addControl()
    label.text = text
    label.expandW = true
    label.h = 1
    return label
end

---@param o Control
local function addReset(o)
    local reset = engine.Button:new()
    reset.inheritStyle = false
    reset.text = "x"
    reset.w = 1
    o:add(reset)
    reset.x = -1
    return reset
end

local function addSettingsInfo(text, infoText)
    local label = addLabel(text)
    ---@type Button
    local info = engine.Control:new()
    label:add(info)
    info.text = infoText
    info.h = 1
    info.anchorW = info.Anchor.RIGHT
    return info
end


local function addSettingsButton(text, buttonText)
    local label = addLabel(text)

    ---@type Button
    local button = settingsButton:new()
    label:add(button)
    button.text = buttonText
    button.dragSelectable = true
    button.anchorW = button.Anchor.RIGHT
    return button
end

local function addSettingsColor(text, defaultColor)
    local label = addLabel(text)

    local picker = label:addColorPicker()

    picker.text = "[      ]"
    picker.anchorW = picker.Anchor.RIGHT
    picker.dragSelectable = true
    if defaultColor then
        picker.style.backgroundColor = defaultColor
    end

    return picker
end


local function addSettingsLineEdit(text, editText)
    local label = addLabel(text)

    local edit = label:addLineEdit()
    edit.w = 16
    edit.text = editText
    edit.dragSelectable = true
    edit.anchorW = edit.Anchor.RIGHT
    return edit
end

local fileExplorer = nil

addSeperator("-MOS-")
addSettingsInfo("Version", tostring(mos.getVersion()))
local installerText = "[Install]"
if fs.exists("/mosInstaller.lua") then
    installerText = "[Run]"
end
local versionButton = addSettingsButton("Installer", installerText)
function versionButton:pressed()
    if fs.exists("/mosInstaller.lua") then
        mos.openFile("mosInstaller.lua").text = "MOS Installer"
    else
        mos.openFile("/rom/programs/http/pastebin.lua", "get", "Wa0niW8x", "mosInstaller.lua").text = "Downloading MOS Installer"
        versionButton.text = "[Run]"
        versionButton.parent:expandChildren()
    end
end

addSeperator("-Computer-")
local freeSpace = math.floor(fs.getFreeSpace("") * 1e-4) / 100
local capacity = math.floor(fs.getCapacity("") * 1e-4) / 100
addSettingsInfo("ID", "#" .. tostring(os.getComputerID()))
addSettingsInfo("Free Space", freeSpace .. "/" .. capacity  .. " MB")
local labelEdit = addSettingsLineEdit("Label", os.getComputerLabel())
function labelEdit:textSubmitted()
    os.setComputerLabel(labelEdit.text)
end


addSeperator("-Appearance-")

local changeTheme = addSettingsButton("Theme", "[Browse]")

function changeTheme:pressed()
    fileExplorer = mos.openFileDialogue("Choose .thm", {
        callback = function (path)
            local suffix = ".thm"
            if path:sub(-#suffix) == suffix then
                mos.loadTheme(path)
                mos.engine.root:queueDraw()
                engine.root:queueDraw()
                fileExplorer:close()
            end
        end,
        start = mos.toOsPath("/themes/")
    })
end

local changeBackground = addSettingsButton("Background Image", "[Browse]")

local imageReset = addReset(changeBackground)
imageReset.visible = mos.profile.backgroundIcon ~= nil and mos.profile.backgroundIcon ~= ""

function changeBackground:pressed()
    fileExplorer = mos.openFileDialogue("Choose .nfp", {
        callback = function (path)
            mos.backgroundIcon.texture = paintutils.loadImage(path)
            mos.profile.backgroundIcon = path
            imageReset.visible = true
            fileExplorer:close()
        end,
        start = mos.toOsPath("/textures/backgrounds/")
    })
end

function imageReset:pressed()
    mos.profile.backgroundIcon = nil
    mos.backgroundIcon.texture = nil
    mos.profile.backgroundIcon = ""
    imageReset.visible = false
end

local picker = addSettingsColor("Background Color", mos.profile.backgroundColor or mos.theme.backgroundColor)

local colorReset = addReset(picker)

colorReset.visible = mos.profile.backgroundColor ~= nil
if mos.profile.backgroundColor ~= nil then
    picker.style.backgroundColor = mos.profile.backgroundColor
end

colorReset.pressed = function (o)
    ---@type Profile
    mos.profile.backgroundColor = nil
    mos.engine.backgroundColor = mos.theme.backgroundColor
    mos.refreshTheme()
    o.visible = false
    picker.style.backgroundColor = mos.theme.backgroundColor
end


function picker:colorClicked(color)
    mos.profile.backgroundColor = color
    mos.engine.backgroundColor = color
    mos.engine.root:queueDraw()
    colorReset.visible = true
end

addSeperator("-File Explorer-")

local dirColorPicker = addSettingsColor("Dir Color", mos.theme.fileColors.dirText)
local dirColorReset = addReset(dirColorPicker)
dirColorReset.visible = mos.profile.dirColor ~= nil
if mos.profile.dirColor ~= nil then
    dirColorPicker.style.backgroundColor = mos.profile.dirColor
end

dirColorReset.pressed = function (o)
    ---@type Profile
    mos.profile.dirColor = nil
    --mos.engine.backgroundColor = mos.theme.backgroundColor
    mos.refreshTheme()
    o.visible = false
    dirColorPicker.style.backgroundColor = mos.theme.fileColors.dirText
end

function dirColorPicker:colorClicked(color)
    mos.profile.dirColor = color
    mos.engine.root:queueDraw()
    dirColorReset.visible = true
end

local dotFiles = addSettingsButton("Show dot Files", "[ ]")
if mos.profile.dirShowDot then
    dotFiles.text = "[x]"
end

dotFiles.pressed = function (o)
    mos.profile.dirShowDot = mos.profile.dirShowDot == false
    os.queueEvent("mos_refresh_files")
    if mos.profile.dirShowDot then
        o.text = "[x]"
    else
        o.text = "[ ]"
    end
end


local mosFiles = addSettingsButton("Show mos Files", "[ ]")
if mos.profile.dirShowMos then
    mosFiles.text = "[x]"
end

mosFiles.pressed = function (o)
    mos.profile.dirShowMos = mos.profile.dirShowMos == false
    os.queueEvent("mos_refresh_files")
    if mos.profile.dirShowMos then
        o.text = "[x]"
    else
        o.text = "[ ]"
    end
end


local romFiles = addSettingsButton("Show rom Files", "[ ]")
if mos.profile.dirShowRom then
    romFiles.text = "[x]"
end

romFiles.pressed = function (o)
    mos.profile.dirShowRom = mos.profile.dirShowRom == false
    os.queueEvent("mos_refresh_files")
    if mos.profile.dirShowRom then
        o.text = "[x]"
    else
        o.text = "[ ]"
    end
end

local leftHeart = addSettingsButton("Heart on Left Side", "[ ]")
if mos.profile.dirLeftHeart then
    leftHeart.text = "[x]"
end

leftHeart.pressed = function (o)
    mos.profile.dirLeftHeart = mos.profile.dirLeftHeart == false
    --os.queueEvent("mos_refresh_files")
    if mos.profile.dirLeftHeart then
        o.text = "[x]"
    else
        o.text = "[ ]"
    end
end


engine.start()