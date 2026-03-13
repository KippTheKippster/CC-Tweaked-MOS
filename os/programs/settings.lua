---@type MOS
local mos = __mos
if mos == nil then
    printError("Settings must be opened with MOS!")
    return
end

local se = {}

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")
mos.applyTheme(engine)

local main = engine.root:addVContainer()
main.expandW = true
main.expandH = true

local scroll = main:addScrollContainer()
scroll.expandW = true
scroll.expandH = true

local list = scroll:addVContainer()
list.expandW = true
list.expandH = true
list.marginL = 1
list.marginR = 1

local bottom = main:addHContainer()
bottom.expandW = true

local bottomSpacer = bottom:addControl()
bottomSpacer.expandW = true

local saveButton = bottom:addButton("\16Save")
saveButton.disabled = true
function saveButton:pressed()
    saveButton.disabled = true
    mos.saveSettings()
end

local function addSeperator(label)
    local seperator = list:addControl(label)
    seperator.expandW = true
    seperator.centerText = true
    seperator.style = engine.Button.styleDisabled
    return seperator
end

local function addLine(label, control)
    local line = list:addControl(label)
    line.expandW = true
    line:add(control)
    control.w = #control.text
    control.anchorW = control.Anchor.RIGHT
end

---comment
---@param name string
---@param label string
---@param control Control
---@param addRevert boolean?
local function addSetting(name, label, control, addRevert)
    ---@class Setting : Control
    local setting = list:addControl(label)
    setting.expandW = true
    ---@type Button?
    setting.revertButton = nil
    setting:add(control)
    setting.set = function (value)
        if value then
            settings.set(name, value)
        else
            settings.unset(name)
        end
        setting:checkRevert()
        se.settingChanged(name, value)
    end
    setting.get = function (value)
        return settings.get(name)
    end

    function setting:checkRevert()
        if addRevert == false then
            return
        end

        local details = settings.getDetails(name)
        if not details.value or details.value == details.default then
            if self.revertButton then
                self.revertButton:queueFree()
                self.revertButton = nil
            end
        else
            if not self.revertButton then
                local x = control:addButton("x")
                x.x = -1
                self.revertButton = x
                x.pressed = function ()
                    setting.set(details.default)
                    self:checkRevert()
                end
            end
        end
    end

    control.w = #control.text
    control.anchorW = control.Anchor.RIGHT
    if addRevert ~= false then
        setting:checkRevert()
    end
    return setting
end

addSeperator("-MOS-")

addLine("Version", engine.Control:new(mos.getVersion()))
local bInstall = engine.Button:new"[Install]"
if fs.exists("/mosInstaller.lua") then
    bInstall.text = "[Run]"
end
bInstall.pressed = function ()
    if fs.exists("/mosInstaller.lua") then
        mos.openFile("mosInstaller.lua").text = "MOS Installer"
    else
        mos.openFile("/rom/programs/http/pastebin.lua", "get", "Wa0niW8x", "mosInstaller.lua").text = "Downloading MOS Installer"
        bInstall.text = "[Run]"
    end
end
addLine("Installer", bInstall)

addSeperator("-Computer-")

do
    local freeSpace = math.floor(fs.getFreeSpace("") * 1e-4) / 100
    local capacity = math.floor(fs.getCapacity("") * 1e-4) / 100
    addLine("ID", engine.Control:new("#" .. tostring(os.getComputerID())))
    addLine("Free Space", engine.Control:new(freeSpace .. "/" .. capacity  .. " MB"))
end

do
    local labelEdit = engine.LineEdit:new()--addSettingsLineEdit("Label", os.getComputerLabel())
    function labelEdit:textSubmitted()
        os.setComputerLabel(labelEdit.text)
    end

    addLine("Label", labelEdit)
    labelEdit.w = 16
    labelEdit:resize()
end

addSeperator("-Appearance-")

local bTheme = engine.Button:new("[Browse]")
local sTheme = addSetting("mos.theme", "Theme", bTheme)
bTheme.pressed = function ()
    mos.openFileDialogue("Choose .thm", {
        callback = sTheme.set,
        start = mos.toOsPath("/themes"),
        closeOnOpen = true
    })
end

local bBackgroundIcon = engine.Button:new("[Browse]")
local sBackgroundIcon = addSetting("mos.background_image", "Background Image", bBackgroundIcon)
bBackgroundIcon.pressed = function ()
    mos.openFileDialogue("Choose .nfp", {
        callback = sBackgroundIcon.set,
        start = mos.toOsPath("/textures/backgrounds"),
        closeOnOpen = true
    })
end

---@type ColorPicker
local bBackgroundColor = engine.ColorPicker:new("[      ]", settings.get("mos.background_color") or mos.theme.backgroundColor)
local sBackgroundColor = addSetting("mos.background_color", "Background Color", bBackgroundColor)
bBackgroundColor.colorPressed = function (_, color)
    sBackgroundColor.set(color)
end

addSeperator("-File Explorer-")

local bDirColor = engine.ColorPicker:new("[      ]", settings.get("mos.files.dir_color") or mos.theme.fileColors.dirText)
local sDirColor = addSetting("mos.files.dir_color", "Dir Color", bDirColor)
bDirColor.colorPressed = function (_, color)
    sDirColor.set(color)
end

local bDot = engine.Checkbox:new("   ", settings.get("mos.files.show_dot"))
local sDot = addSetting("mos.files.show_dot", "Show dot Files", bDot, false)
bDot.pressed = function (self)
    engine.Checkbox.pressed(self)
    sDot.set(settings.get("mos.files.show_dot") == false)
end

local bMos = engine.Checkbox:new("   ", settings.get("mos.files.show_mos"))
local sMos = addSetting("mos.files.show_mos", "Show mos Files", bMos, false)
bMos.pressed = function (self)
    engine.Checkbox.pressed(self)
    sMos.set(settings.get("mos.files.show_mos") == false)
end

local bRom = engine.Checkbox:new("   ", settings.get("mos.files.show_rom"))
local sRom = addSetting("mos.files.show_rom", "Show rom Files", bRom, false)
bRom.pressed = function (self)
    engine.Checkbox.pressed(self)
    sRom.set(settings.get("mos.files.show_rom") == false)
end

local bHeart = engine.Checkbox:new("   ", settings.get("mos.files.left_heart"))
local sHeart = addSetting("mos.files.left_heart", "Heart on Left Side", bHeart, false)
bHeart.pressed = function (self)
    engine.Checkbox.pressed(self)
    sHeart.set(settings.get("mos.files.left_heart") == false)
end

---comment
---@param name string
function se.settingChanged(name, value)
    saveButton.disabled = false

    local details = settings.getDetails(name)
    if name == "mos.theme" then
        mos.loadTheme(value)
        bBackgroundColor.color = settings.get("mos.background_color") or mos.theme.backgroundColor
        bDirColor.color = settings.get("mos.files.dir_color") or mos.theme.fileColors.dirText
    elseif name == "mos.background_image" then
        if value then
            mos.backgroundIcon.texture = paintutils.loadImage(value)
        else
            mos.backgroundIcon.texture = nil
        end
    elseif name == "mos.background_color" then
        local c = value or mos.theme.backgroundColor
        mos.engine.backgroundColor = c
        bBackgroundColor.color = c
    elseif name == "mos.files.dir_color" then
        bDirColor.color = value or mos.theme.fileColors.dirText
    end
end


engine.start()