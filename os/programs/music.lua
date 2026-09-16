---@type MOS
local mos = mos
---@type ProgramWindow
local mosWindow = mosWindow
if mos == nil then
    error("File Explorer must be opened with MOS", 0)
end

local dfpwm = require("cc.audio.dfpwm")
local chunkSize = 512

local mc = {}
mc.file = arg[1] or ""
mc.playing = mc.file ~= ""
mc.bufferCount = 0

local ui = {}

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")
mos.applyTheme(engine)

local main = engine.root:addVContainer()
main.expandW = true
main.expandH = true

---@param path string
function mc.loadFile(path)
    local f, err = fs.open(path, "r")
    if not f then
        error(err)
    end
    mc.file = path
    mc.reader = f
    mc.decoder = dfpwm.make_decoder()
    mc.bufferCount = 0

    ui.updatePlayText()
end

function mc.seekForward()
end

local controls = main:addHContainer()
controls.expandW = true
controls:addControl()

local resetButton = controls:addButton(string.char(171))
resetButton.pressed = function ()
    mc.loadFile(mc.file)
end

local playButton = controls:addButton()
playButton.expandW = true
local spacer = controls:addControl()
--spacer.expandW = true
local time = controls:addControl("")
function ui.updatePlayText()
    if not mc.audioValid() then
        playButton.text = ""
    elseif mc.playing then
        playButton.text = " Pause "
    else
        playButton.text = " Resume "
    end

    local s = math.floor(mc.bufferCount * 0.085333333333)
    local m = math.floor(s / 60)
    time.text = ("%d:%02d "):format(m , s%60)

    local a = string.char(14)
    local b = string.char(15)

    if s % 2 == 0 then
        a = string.char(15)
        b = string.char(14)
    end

    if mc.audioValid() then
        mosWindow.text = ("%s Playing %s %s"):format(a, fs.getName(mc.file), b)
    end
end

function mc.audioValid()
    return mc.reader
end

function mc.start()
    if not mc.audioValid() then
        ui.updatePlayText()
        return
    end

    mc.playing = true
    ui.updatePlayText()
end

function mc.stop()
    mc.playing = false
    ui.updatePlayText()
end

function mc.toggle()
    if mc.playing then
        mc.stop()
    else
        mc.start()
    end
end

playButton.pressed = function ()
    mc.toggle()
end

ui.updatePlayText()

local playlistTitle = main:addControl("Playlist")
playlistTitle.centerText = true
playlistTitle.style = engine.styleDisabled
playlistTitle.expandW = true
local playlistScroll = main:addScrollContainer()
playlistScroll.expandW = true
playlistScroll.expandH = true
playlistScroll.style = playlistScroll.style:inherit()
playlistScroll.rendering = true
local playlist = playlistScroll:addVContainer()
playlist.expandW = true
playlist.fitToChildrenH = true

mos.bindWindowAudio(mosWindow, function ()
    if not mc.playing then
        return
    end

    local chunk = mc.reader.read(chunkSize)
    if chunk == nil then
        mc.stop()
        return
    end

    local buffer = mc.decoder(chunk)
    mos.addSamples(buffer, buffer)
    --addSamples(buffer, buffer)

    mc.bufferCount = mc.bufferCount + 1
    ui.updatePlayText()
end)

local fileDropdown = mos.engine.Dropdown:new("File")
fileDropdown:addToList("Open")

function fileDropdown:optionPressed(i)
    local text = fileDropdown:getOptionText(i)
    if text == "Open" then
        mos.openFileDialogue("Open .dfpwm file", {
            callback = function (path)
                mc.loadFile(path)
            end
        })
    end
end

mos.bindWindowTool(mosWindow, function(focus)
    if focus then
        mos.addToToolbar(fileDropdown)
    else
        mos.removeFromToolbar(fileDropdown)
    end
end)

do
    local dir = ""--fs.getDir(mc.file) or ""
    local files = fs.list(dir)
    local count = 1
    for _, file in ipairs(files) do
        if string.sub(file, -string.len(".dfpwm")) == ".dfpwm" then
            local path = fs.combine(dir, file)
            local c = playlist:addButton(("%d. %s"):format(count, file))
            c.expandW = true
            c.marginL = 1
            c.marginR = 1
            c.style = engine.style:inherit()
            c.pressed = function ()
                mc.loadFile(path)
                mc.start()
            end
            count = count + 1
        end
    end
end

mosWindow.text = "Music Player"
if mc.file ~= "" then
    mc.loadFile(mc.file)
end

engine.start()