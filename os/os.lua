print("MOS is Starting...")

---@class MOS
local mos = {}
function mos.getVersion()
    return "1.0.0"
end

mos.latestMosOption = ""

local runningProgram = shell.getRunningProgram()
local mosPath = "/" .. fs.getDir(fs.getDir(runningProgram))
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

local dest = "/.mosdata/logs/"
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

---@type Engine
local engine = require(coreDotPath .. ".engine")

---@type MultiProgram
local mp = engine.newMultiProgram()

local windows = {}
local customTools = {}
local currentWindow = nil

--MOS
--User
---@class Theme
local defaultTheme = {
    backgroundColor = colors.red,
    shadow = true,
    shadowTextColor = colors.black,
    shadowBackgroundColor = colors.gray,
    toolbarColors = nil,
    mainColors = {
        text = colors.black,
        background = colors.white,
        downText = colors.black,
        downBackground = colors.lightBlue,
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
        map[v] = value
    end
end

local fileAssociation = {}
appendToMap(fileAssociation, {".txt", ".md", ".log", ".usr", ".json", ".settings"}, {program="/rom/programs/edit.lua"})
fileAssociation[".nfp"] = {program="os/programs/paint.lua"}

---@class User
local defaultUser = {
    backgroundColor = nil,
    backgroundIcon = toOsPath("/textures/backgrounds/melvin.nfp"),
    fileExceptions = {},
    theme = "",
    favorites = {

    },
    dirShowDot = true,
    dirShowRom = true,
    dirShowMos = true,
    dirColor = nil,
    dirLeftHeart = true,
}

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

---comment
---@param file string?
---@return User, boolean
function mos.loadUser(file)
    file = file or "/.mosdata/users/user.usr"
    local user = engine.utils.loadTable(file)
    local loaded = user ~= nil
    user = user or {}
    validateTable(user, defaultUser)
    return user, loaded
end

---comment
---@param file string?
---@param user User?
function mos.saveUser(file, user)
    file = file or "/.mosdata/users/user.usr"
    user = user or mos.user
    engine.utils.saveTable(user, file)
end

---comment
---@param file string
---@param user User?
---@return boolean
function mos.isFileFavorite(file, user)
    user = user or mos.user
    return user.favorites[file] ~= nil
end

---comment
---@param file string
---@param settings table?
---@param user User?
function mos.addFileFavorite(file, settings, user)
    user = user or mos.user
    if user.favorites[file] ~= nil then return end
    settings = settings or { name = fs.getName(file) }
    user.favorites[file] = settings
    if user == mos.user then
        os.queueEvent("mos_favorite_add", file)
    end
end

---comment
---@param file string
---@param user User?
function mos.removeFileFavorite(file, user)
    user = user or mos.user
    user.favorites[file] = nil
    if user == mos.user then
        os.queueEvent("mos_favorite_remove", file)
    end
end

---comment
---@param file string
function mos.loadTheme(file)
    local theme = engine.utils.loadTable(file)
    if theme == nil then
        mos.theme = defaultTheme
    else
        mos.theme = theme
        mos.user.theme = file
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
    engine.backgroundColor = mos.user.backgroundColor or mos.theme.backgroundColor
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

    e. style = styleToolbar
    e.Dropdown.styleDown = styleToolbarDown

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
---@type User
mos.user = nil

local userLoaded
mos.user, userLoaded = mos.loadUser()
mos.loadTheme(mos.user.theme)
engine.utils.saveTable(defaultTheme, toOsPath("/themes/default.thm"))

--Objects
--Background
local backgroundIcon = engine.root:addIcon()
backgroundIcon.text = ""
if mos.user.backgroundIcon ~= "" and fs.exists(mos.user.backgroundIcon or "") then
    backgroundIcon.texture = paintutils.loadImage(mos.user.backgroundIcon)
end
backgroundIcon.anchorW = backgroundIcon.Anchor.CENTER
backgroundIcon.anchorH = backgroundIcon.Anchor.CENTER
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
function topBar:getStyle()
    if mos.fullscreenWindow then
       return mos.style.toolbarFullscreen
    else
       return mos.style.toolbar
    end
end

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
    for k, v in pairs(mos.user.favorites) do
        l = #k
    end
    if l > -1 then
        mosDropdown:addToList("-------------", false)
        for k, v in pairs(mos.user.favorites) do
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
        topBar.style = mos.style.toolbarFullscreen
        engine.Dropdown.style = mos.style.toolbarFullscreen
        engine.Dropdown.styleDown = mos.style.toolbarFullscreenDown
    else
        windowContainer:toFront()
        topBar.style = mos.style.toolbar
        engine.Dropdown.style = mos.style.toolbar
        engine.Dropdown.styleDown = mos.style.toolbarDown
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
        local v = mos.user.fileExceptions[file] or mos.user.fileExceptions[suffix] or fileAssociation[suffix]
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
---}
---@param title string
---@param options table
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
if not userLoaded then
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
