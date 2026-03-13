print("MOS is Starting...")

---@class MOS
local mos = {}
function mos.getVersion()
    return "1.0.0"
end

local dest = "/.mosdata/.logs/"
if fs.exists(dest) then
    local logs = fs.list(dest)
    for i = 1, #logs - 4 do
        fs.delete(fs.combine(dest, logs[i]))
    end
end

local logFile = fs.open(fs.combine(dest, tostring(os.epoch("utc")) .. ".log"), "w")
function mos.log(...)
    local line = ""
    local data = table.pack(...)
    for _, v in ipairs(data) do
        line = line .. tostring(v) .. " "
    end
    line = line .. '\n'

    logFile.write(line)
    logFile.flush()
end

mos.latestMosOption = ""

--local runningProgram = shell.getRunningProgram()
local mosPath = "/" .. fs.getDir(fs.getDir(debug.getinfo(1, "S").source:sub(2)))
local mosDotPath = mosPath:gsub("/", ".")
local corePath = mosPath .. "/core"
local coreDotPath = mosDotPath .. ".core"
local osPath = mosPath .. "/os"
local osDotPath = mosDotPath .. ".os"

mos.mosPath = mosPath
mos.mosDotPath = mosPath

---comment
---@param name string
---@return string
local function toMosPath(name)
    return fs.combine(mosPath, name)
end

---@param name string
---@return string
local function toOsPath(name)
    return fs.combine(osPath, name)
end

---@param name string
---@return string
local function toCorePath(name)
    return fs.combine(corePath, name)
end

mos.toMosPath = toMosPath
mos.toOsPath = toOsPath
mos.toCorePath = toCorePath

---@type MultiProgram
local mp = require(coreDotPath .. ".multiProcess.multiProgram")

---@type Engine
local engine = require(coreDotPath .. ".engine") --mp.loadProgram(engineEnv, toCorePath("/engine.lua"))()--
local windows = {}
local customTools = {}
local currentWindow = nil

--MOS
---@class Theme
local defaultTheme = {
    backgroundColor = colors.red,
    shadow = true,
    shadowTextColor = colors.black,
    shadowBackgroundColor = colors.white,
    toolbarColors = nil,
    mainColors = {
        text = colors.black,
        background = colors.white,
        downText = colors.black,
        downBackground = colors.lightBlue,
        disabledText = colors.gray,
        focusText = colors.black,
        focusBackground = colors.lightGray,
    },
    windowColors = {
        text = colors.gray,
        background = colors.white,
        focusText = colors.white,
        focusBackground = colors.blue,
        downBackground = colors.white,
        downText = colors.black,
        exitText = colors.black,
        exitBackground = colors.red,
    },
    fileColors = {
        dirText = colors.blue
    },
    palette = {},
}

local function appendToMap(map, list, value)
    for i, v in ipairs(list) do
        if type(value) == "table" then
            local copy = {} -- Entries need to be unique
            for k, tv in pairs(value) do
                copy[k] = tv
            end
            value = copy
        end
        map[v] = value
    end
end

local function validateTable(tbl, default)
    if default == nil then
        error("Got nil default", 2)
    end

    for k, v in pairs(default) do
        if tbl[k] == nil then
            tbl[k] = v
        end
    end
end

function mos.saveSettings()
    settings.save("/.mosdata/users/" .. mos.user .. "/.settings")
end

---comment
---@param file string
---@return boolean
function mos.isFileFavorite(file)
    return mos.favorites[file] ~= nil
end

---comment
---@param file string
---@param settings table?
function mos.addFileFavorite(file, settings)
    if mos.favorites[file] ~= nil then return end
    settings = settings or { name = fs.getName(file) }
    mos.favorites[file] = settings
    os.queueEvent("mos_favorite", file)
    engine.utils.saveTable(".mosdata/users/" .. mos.user .. "/.favorites" , mos.favorites)
end

---comment
---@param file string
function mos.removeFileFavorite(file)
    mos.favorites[file] = nil
    os.queueEvent("mos_favorite_remove", file)
    engine.utils.saveTable(".mosdata/users/" .. mos.user .. "/.favorites" , mos.favorites)
end

---comment
---@param file string
function mos.loadTheme(file)
    local theme = engine.utils.loadTable(file)
    mos.log("'" .. file .. "'", theme)
    if theme == nil then
        mos.theme = defaultTheme
        mos.log("heck")
    else
        mos.theme = theme
        validateTable(theme, defaultTheme)
    end

    mos.refreshTheme()
end

local dropdown = engine.Dropdown
local programViewport = require(coreDotPath .. ".multiProcess.programViewport")(engine.Control, mp, engine.input)
local programWindow = require(coreDotPath .. ".multiProcess.programWindow")(engine.WindowControl, engine.input)

function mos.refreshTheme()
    local palette = mos.theme.palette
    local redirects = { engine.screenBuffer }
    for _, window in ipairs(windows) do
        table.insert(redirects, window.programViewport.program.window)
    end

    for _, redirect in ipairs(redirects) do
        redirect.setVisible(false)
        for i = 0, 15 do
            local color = 2 ^ i
            if palette[color] ~= nil then
                redirect.setPaletteColor(color, palette[color])
            else
                redirect.setPaletteColor(color, term.nativePaletteColor(color))
            end
        end
    end

    mos.style = mos.applyTheme(engine)
    engine.backgroundColor = settings.get("mos.background_color") or mos.theme.backgroundColor
    engine.root:queueDraw()
    os.queueEvent("mos_refresh_theme")
end

---comment
---@param targetEngine Engine
---@param theme Theme?
function mos.applyTheme(targetEngine, theme)
    assert(targetEngine ~= nil)
    local e = targetEngine
    --Styles
    theme = theme or mos.theme
    --Background
    e.backgroundColor = theme.mainColors.background
    theme.shadowTextColor = theme.shadowTextColor or colors.black
    theme.shadowBackgroundColor = theme.shadowBackgroundColor or colors.black

    --Toolbar
    local mainColors = theme.mainColors

    local style = e.style
    local styleDown = e.styleDown
    local styleDisabled = e.styleDisabled

    local styleWindow = e.style:inherit()
    local styleWindowFocus = styleWindow:inherit()

    local styleToolbar = style:inherit()
    local styleToolbarDown = styleDown:inherit()
    local styleToolbarFullscreen = styleWindowFocus:inherit()
    local styleToolbarFullscreenDown = styleDown:inherit()
    if theme.toolbarColors then
        styleToolbar.textColor = theme.toolbarColors.text
        styleToolbar.backgroundColor = theme.toolbarColors.background

        styleToolbarDown.textColor = theme.toolbarColors.downText
        styleToolbarDown.backgroundColor = theme.toolbarColors.downBackground

        styleToolbarFullscreen.textColor = theme.toolbarColors.fullscreenText
        styleToolbarFullscreen.backgroundColor = theme.toolbarColors.fullscreenBackground

        styleToolbarFullscreenDown.textColor = theme.toolbarColors.fullscreenDownText
        styleToolbarFullscreenDown.backgroundColor = theme.toolbarColors.fullscreenDownBackground
    end

    e.style = styleToolbar
    e.Dropdown.styleDown = styleToolbarDown
    --e.Dropdown.styleDisabled = styleToolbarDisabled

    e.WindowControl.style = styleWindow
    e.WindowControl.styleFocus = styleWindowFocus

    style.textColor = mainColors.text
    style.backgroundColor = mainColors.background
    style.shadowTextColor = theme.shadowTextColor
    style.shadowBackgroundColor = theme.shadowBackgroundColor
    style.shadowOffsetU = 0

    styleDown.textColor = mainColors.downText
    styleDown.backgroundColor = mainColors.downBackground

    dropdown.optionShadow = theme.shadow

    --Window
    local windowColors = theme.windowColors

    programWindow.shadow = theme.shadow
    styleWindow.shadowTextColor = theme.shadowColor
    styleWindow.shadowOffsetU = -1
    styleWindow.backgroundColor = windowColors.background
    styleWindow.textColor = windowColors.text

    styleWindowFocus.backgroundColor = windowColors.focusBackground
    styleWindowFocus.textColor = windowColors.focusText

    local styles = {
        main = style,
        mainDown = styleDown,
        mainDisabled = styleDisabled,
        window = styleWindow,
        windowFocus = styleWindowFocus,
        toolbar = styleToolbar,
        toolbarDown = styleToolbarDown,
        toolbarFullscreen = styleToolbarFullscreen,
        toolbarFullscreenDown = styleToolbarFullscreenDown,
    }

    return styles
end

mos.theme = defaultTheme

do
    local function def (name, default, description, _type)
        settings.define("mos." .. name, {description = description, default = default, type = _type or type(default) })
    end

    def("theme", toOsPath("/themes/default.thm"))
    def("background_image", nil, nil, "string")
    def("background_color", nil, nil, "number")
    def("files.show_dot", true)
    def("files.show_mos", true)
    def("files.show_rom", true)
    def("files.dir_color", nil, nil, "number")
    def("files.left_heart", true)

    local fa = {}
    appendToMap(fa, { ".txt", ".md", ".log", ".usr", ".json", ".settings", ".favorites", ".cfg" }, { program="/rom/programs/edit.lua" })
    fa[".nfp"] = { program = toOsPath("/programs/paint.lua") }
    def("file_association", fa)
end

mos.user = "user"
do
    local userPath = ".mosdata/users/" .. mos.user
    if not fs.exists(userPath) then
        fs.makeDir(userPath)
    end

    local settingsPath = userPath .. "/.settings"
    if not fs.exists(settingsPath) then
        settings.set("mos.background_image", toOsPath("/textures/backgrounds/melvin.nfp"))
        settings.save(settingsPath)
    end

    local favoritesPath = userPath .. "/.favorites"
    if not fs.exists(favoritesPath) then
        local f = fs.open(favoritesPath, "w")
        f.write("{}")
        f.close()
    end

    settings.load(settingsPath)
    mos.favorites = engine.utils.loadTable(favoritesPath)
end


mos.loadTheme(settings.get"mos.theme")
engine.utils.saveTable(toOsPath("/themes/default.thm"), defaultTheme)

--Objects
--Background
local backgroundIcon = engine.root:addIcon()
backgroundIcon.text = ""
do
    local path = settings.get("mos.background_image")
    if path and path ~= "" and fs.exists(path) then
        backgroundIcon.texture = paintutils.loadImage(path)
    end
end
backgroundIcon.centered = true
mos.backgroundIcon = backgroundIcon


local focusContainer = engine.root:addControl()
focusContainer.expandW = true
focusContainer.mouseIgnore = true
focusContainer.rendering = false

local windowContainer = focusContainer:addControl()
windowContainer.mouseIgnore = true
windowContainer.rendering = false

--Top Bar
local topBar = focusContainer:addControl("")
topBar.rendering = true
topBar.mouseIgnore = true
topBar.expandW = true
--[[
function topBar:getStyle()
    if mos.fullscreenWindow then
       return mos.style.toolbarFullscreen
    else
       return mos.style.toolbar
    end
end
]]--

--Tool Bar
local toolBar = topBar:addHContainer()
toolBar.expandW = true
toolBar.h = 1
toolBar.separation = 1
toolBar.mouseIgnore = true
toolBar.inheritStyle = true

local function toolbarChildFocusChanged(c)
    if c.focus == true then
        topBar:toFront()
    end
end

function mos.addToToolbar(control)
    control:connectSignal(control.focusChangedSignal, toolbarChildFocusChanged, control)
    toolBar:add(control)
    control.inheritStyle = true
end

function mos.removeFromToolbar(control)
    toolBar:remove(control)
end

---@type Dropdown
local windowDropdown = dropdown:new()
windowDropdown.disabled = true
mos.addToToolbar(windowDropdown)
windowDropdown.text = "="

---@type Dropdown
local mosDropdown = dropdown:new()
mos.addToToolbar(mosDropdown)
mosDropdown.text = "MOS"

function mos.refreshMosDropdown()
    mosDropdown:clearList()
    mosDropdown:addToList("File Explorer")
    mosDropdown:addToList("Settings")
    mosDropdown:addToList("Shell")

    local l = -1
    for k, v in pairs(mos.favorites) do
        l = #k
    end
    if l > -1 then
        mosDropdown:addToList("-------------", false)
        for k, v in pairs(mos.favorites) do
            local option = mosDropdown:addToList(v.name .. " ")
            option.pressed = function(o)
                mos.openWithModifier(k, mos.getInputFileOpenModifier())
            end
            local x = option:addButton()
            x.text = string.char(3)
            x.inheritStyle = true
            x.w = #x.text
            x.h = 1
            x.anchorW = x.Anchor.RIGHT
            x.dragSelectable = true
            x.propogateFocusUp = true
            x.pressed = function()
                mos.removeFileFavorite(k)
                mos.refreshMosDropdown()
            end
        end
        mosDropdown:addToList("-------------", false)
    end

    --mosDropdown:addToList("Reboot")
    mosDropdown:addToList("Exit")
end

mos.refreshMosDropdown()

local clock = topBar:addControl()
clock.h = 1
clock.anchorW = clock.Anchor.RIGHT
clock.inheritStyle = true

local function isFullscreen()
    return mos.fullscreenWindow ~= nil
end

local function setFullscreenMode(fullscreen)
    backgroundIcon.visible = fullscreen == false
    if fullscreen == true then
        topBar:toFront()
    else
        windowContainer:toFront()
    end
end


---comment
---@param w ProgramWindow
local function windowFullscreenChanged(w)
    if w.fullscreen == false then
        if w == mos.fullscreenWindow then
            mos.fullscreenWindow = nil
        end
    else
        mos.fullscreenWindow = w
    end

    setFullscreenMode(isFullscreen())
end

---comment
---@param w WindowControl
---@param b Button
local function windowClosed(w, b)
    w.fullscreen = false
    windowFullscreenChanged(w) -- This is a bit of a hack, but it doesn't seem like the fullscreen signal is called right after?
    if isFullscreen() == false then
        setFullscreenMode(false)
    end
    windowDropdown:removeFromList(b)
    if customTools[w] ~= nil then
        customTools[w](false)
    end

    table.remove(windows, engine.utils.find(windows, w))

    w.visible = false
    for i = 0, #windowContainer.children - 1 do
        local nextW = windowContainer.children[#windowContainer.children - i]
        if nextW.visible == true then
            nextW.programViewport.skipEvent = true
            nextW:grabFocus()
            break
        end
    end

    windowDropdown.disabled = #windows == 0
end

local function windowVisibilityChanged(w)
    if currentWindow == w then
        if customTools[w] ~= nil then
            customTools[w](w.visible)
        end
    end
end

---comment
---@param window ProgramWindow
local function windowFocusChanged(window)
    --window.programViewport:queueEvent({ "mos_window_focus", window.focus })
    window.programViewport:queueEvent({ "mos_window_focus", window.focus })
    if window.focus == false then
        return
    end


    if currentWindow ~= window then
        if customTools[currentWindow] ~= nil then
            customTools[currentWindow](false)
        end
        if customTools[window] ~= nil then
            customTools[window](true)
        end
    end

    currentWindow = window
    if not isFullscreen() then
        windowContainer:toFront()
    end
    window:queueDraw()
end

function mos.addWindow(w)
    local count = 1
    local text = w.text
    for k, v in ipairs(windows) do
        if v.text == w.text then
            count = count + 1
            w.text = text .. "(" .. count .. ")"
        end
    end
    w.text = w.text .. " "
    local b = windowDropdown:addToList(w.text)
    b.window = w
    local x = b:addButton()
    x.text = "x"
    x.inheritStyle = true
    x.w = #x.text
    x.h = 1
    x.anchorW = x.Anchor.RIGHT
    x.dragSelectable = true
    x.propogateFocusUp = true
    x.pressed = function()
        w:close()
    end

    table.insert(windows, w)

    w:connectSignal(w.closedSignal, windowClosed, w, b)
    w:connectSignal(w.fullscreenChangedSignal, windowFullscreenChanged, w)
    w:connectSignal(w.visibilityChangedSignal, windowVisibilityChanged, w)
    w:connectSignal(w.focusChangedSignal, windowFocusChanged, w)
    w:grabFocus()

    w:queueDraw()

    windowDropdown.disabled = false
end

---Creates a new window running the program of path, unless you want more control window use 'openFile' instead
---@param name string
---@param path string
---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@param ... any
---@return ProgramWindow
function mos.launchProgram(name, path, x, y, w, h, ...)
    local window = programWindow:new()
    windowContainer:add(window)

    ---@type ProgramViewport
    local viewport = programViewport:new()
    window:addViewport(viewport)

    window.x = x
    window.y = y
    window.w = w
    window.h = h
    window:refreshMinSize()

    window.oldW = w --Fixes bug so that the window doesn't resize to default size
    window.oldH = h
    window.text = name

    local extraEnv = {}

    extraEnv.__mos = mos
    extraEnv.__mosWindow = window
    extraEnv.term = engineTerm
    extraEnv.window = engineWindow
    extraEnv.paintutils = enginePaintutils

    viewport:launchProgram(engine.screenBuffer, path, extraEnv, ...)
    --viewport:unhandledEvent({}) -- Forces program to start

    mos.addWindow(window)

    window:draw()

    return window
end

mos.windowStartX = 1
mos.windowStartY = 2

local function nextWindowTransform()
    local screenW, screenH = mos.root.w, mos.root.h
    local x, y, w, h = mos.windowStartX, mos.windowStartY, math.floor(screenW * 0.66), math.floor(screenH * 0.75)
    mos.windowStartX = mos.windowStartX + 1
    mos.windowStartY = mos.windowStartY + 1
    if x + w > screenW - 2 then
        mos.windowStartX = 1
    end

    if y + h > screenH - 2 then
        mos.windowStartY = 2
    end
    return x, y, w, h
end

---@enum FileOpenModifier
mos.FileOpenModifier = {
    NONE = 0,
    EDIT = 1,
    ARGS = 2
}

---comment
---@return FileOpenModifier
function mos.getInputFileOpenModifier()
    if engine.input.isKey(keys.leftCtrl) then
        return mos.FileOpenModifier.EDIT
    elseif engine.input.isKey(keys.leftShift) then
        return mos.FileOpenModifier.ARGS
    else
        return mos.FileOpenModifier.NONE
    end
end


---comment
---@param path string
---@param modifier FileOpenModifier
---@param ... any
function mos.openWithModifier(path, modifier, ...)
    if fs.isDir(path) then
        mos.openDir(path)
    elseif modifier == mos.FileOpenModifier.EDIT then
        mos.editFile(path)
    elseif modifier == mos.FileOpenModifier.ARGS then
        mos.openFileWithArgs(path)
    else
        mos.openFile(path, ...)
    end
end

---Opens a new window running the program expected for the file type (i.e. paint for nfp files, for lua files it will run as expected)
---@param path string
---@param ... any
---@return ProgramWindow
function mos.openFile(path, ...)
    local x, y, w, h = nextWindowTransform()
    local file = fs.getName(path)
    local i = file:reverse():find(".", 1, true)
    if i then
        local suffix = file:sub(#file + 1 - i)
        local fa = settings.get("mos.file_association") or {}
        local v = fa[file] or fa[suffix]
        --mos.log(suffix, textutils.serialise(fileAssociation), v)
        if v then
            local program = path
            if v.program then
                if v.program:sub(1, 1) == "/" then
                    program = v.program
                else
                    program = toMosPath(v.program)
                end
            end
    
            if v.fullscreen then
                x, y = 0, 0
                w, h = engine.root.w, engine.root.h
            end
    
            local wi = mos.launchProgram(file, program, x, y, w, h, path, ...)
            if v.fullscreen then
                wi:setFullscreen(true)
            end
            return wi
        end
    end

    return mos.launchProgram(file, path, x, y, w, h, ...)
end

---@param path string
---@return ProgramWindow
function mos.editFile(path)
    local x, y, w, h = nextWindowTransform()
    return mos.launchProgram("Edit '" .. fs.getName(path) .. "'", "/rom/programs/edit.lua", x, y, w, h, path)
end

---@param callback function
---@param startText string?
---@param workingFile string?
---@return ProgramWindow
function mos.openArgs(callback, startText, workingFile)
    return mos.launchProgram("Args", toOsPath("programs/writeArgs.lua"), 3, 3, 24, 2, callback, startText or "", workingFile or "")
end

---comment
---@param path string
---@param startText string?
---@return ProgramWindow
function mos.openFileWithArgs(path, startText)
    local args =  mos.openArgs(
        function(data)
            mos.openFile(path, table.unpack(data))
        end, startText, path)
    args.text = "Args '" .. fs.getName(path) .. "'"
    return args
end

---@param path string
---@return ProgramWindow
function mos.openDir(path)
    local w = mos.openFile(toOsPath("/programs/files.lua"), {start = path})
    w.text = "File Explorer"
    return w
end

---comment
---options = {
--- callback: function? (function that will be called when file is selected, will open file if callback is null)
--- start: string? (start directory)
--- saveMode: boolean?
--- closeOnOpen: boolean?
---}
---@param title string
---@param options table?
---@return ProgramWindow
function mos.openFileDialogue(title, options)
    local w = mos.openFile(toOsPath("/programs/files.lua"), options)
    w.text = title
    return w
end

---comment
---@param title string
---@param text string
---@param x number?
---@param y number?
---@param w number?
---@param h number?
---@param parent Control?
---@return WindowControl?
function mos.createPopup(title, text, x, y, w, h, parent)
    parent = parent or engine.root

    local popup = parent:addWindowControl()
    popup.text = title

    x = x or 16
    y = y or 7
    w = w or 20
    h = h or 2

    popup.x, popup.y, popup.w, popup.h = x, y, w, h
    popup:refreshMinSize()

    local label = popup:addControl()
    label.expandW = true
    label.y = 1
    label.h = 1
    label.text = text
    label.clipText = true
    return popup
end

---comment
---@return ProgramWindow
function mos.popupError(...)
    local err = mos.openFile(mos.toOsPath("/programs/error.lua"), ...)
    err.programViewport.program.window.setVisible(false)
    err.text = "Error"
    return err
end

function mosDropdown:optionPressed(i)
    local text = mosDropdown:getOptionText(i)
    mos.latestMosOption = text
    if text == "Shell" then
        mos.openFile("/rom/programs/advanced/multishell.lua").text = "Shell"
    elseif text == "Exit" then
        mp.exit()
    elseif text == "Reboot" then
        mp.exit()
        shell.run(osPath .. "/os.lua")
    elseif text == "File Explorer" then
        mos.openDir("")
    elseif text == "Settings" then
        mos.openFile(toOsPath("/programs/settings.lua")).text = "Settings"
    end
end

function windowDropdown:optionPressed(i)
    local option = windowDropdown:getOption(i)
    for _, window in ipairs(windows) do
        if window == option.window then
            window.visible = true
            window:grabFocus()
            window:toFront()
        end
    end
end

function mos.bindTool(window, callbackFunction)
    customTools[window] = callbackFunction
end

local clock_timer_id
local root = engine.root

engine.input.addRawEventListener(root)

function clock:update()
    self.text = textutils.formatTime(os.time('local'), true)
    clock_timer_id = mp.startTimer(engine.p, 1.0)
end

function root:rawEvent(data)
    local event = data[1]
    if event == "timer" and data[2] == clock_timer_id then
        clock:update()
    end

    if event == "key" then
        if data[2] == keys.w then
            if engine.input.isKey(keys.leftCtrl) then
                if engine.utils.contains(windows, engine.input.getFocus()) then
                    engine.input.getFocus():close()
                end
            end
        elseif data[2] == keys.f4 then
            if currentWindow ~= nil then
                currentWindow:setFullscreen(currentWindow.fullscreen == false)
            end
        elseif data[2] == keys.s then
            if engine.input.isKey(keys.leftAlt) then
                if mos.quickSearch:isOpen() then
                    mos.quickSearch:close()
                else
                    mos.quickSearch:open()
                end
            end
            --mos.quickSearch:next()
        elseif data[2] == keys.enter then
            mos.quickSearch:select()
        elseif data[2] == keys.up then
            mos.quickSearch:previous()
        elseif data[2] == keys.down then
            mos.quickSearch:next()
        elseif engine.input.isKey(keys.leftAlt) then
            for i = 1, #toolBar.children do
                if data[2] == keys.one + (i - 1) then
                    if toolBar.children[i].next then
                        toolBar.children[i]:next()
                    end
                end
            end
        end
    elseif event == "key_up" then
        if data[2] == keys.leftAlt then
            for i = 1, #toolBar.children do
                if toolBar.children[i] and toolBar.children[i].release then
                    toolBar.children[i]:release()
                end
            end
        end
    end
end

clock:update()

mos.engine = engine
mos.root = engine.root
---@type ProgramWindow?
mos.fullscreenWindow = nil
mos.quickSearch = require(osDotPath .. ".programs.quickSearch")(mos)
engine.root:add(mos.quickSearch)
mos.quickSearch.y = 1

mos.log("Launching MOS")
if userLoaded == false then
    mos.popupError("Failed to load user!", "Using default.")
end

local err = engine.startMultiProgram(mp)
mos.log("MOS Terminated")

if err == nil or err == "Terminated" then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.setCursorPos(1, 1)
    term.setCursorBlink(true)
    term.clear()
    print("MOS Terminated...")
else
    mos.log("MOS Error: ", err)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    --term.setCursorPos(1, 1)
    term.setCursorBlink(true)
    --term.clear()
    print("Something Went Wrong :(")
    print(err)
end

engine.stop()

if mos.latestMosOption == "Reboot" then
    shell.run(mosPath .. "/mos.lua")
end
