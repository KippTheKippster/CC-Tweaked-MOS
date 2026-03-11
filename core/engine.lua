local src = debug.getinfo(1, "S").source:sub(2)
local corePath = fs.getDir(src)
local coreDotPath = "." .. corePath:gsub("/", ".")

---@class Engine
local engine = {}
---@type MultiProgram?
engine.mp = nil
---@type Process?
engine.p = nil

local parentTerm = term.current()
local initialW, initialH = parentTerm.getSize()
local screenBuffer = window.create(parentTerm, 1, 1, initialW, initialH)

engine.parentTerm = parentTerm
engine.screenBuffer = screenBuffer

---Returns { text, textColor, backgroundColor } drawn at position x, y or nil 
---@param x number
---@param y number
---@return table?
function engine.getChar(x, y)
    local _, h = engine.screenBuffer.getSize()
    if y <= 0 or y > h then
        return nil
    end

    local text, textColor, backgroundColor = screenBuffer.getLine(y)
    local textChar = text:sub(x, x)
    if textChar ~= "" then
        local textColorChar = textColor:sub(x,x)
        local backgroundColorChar = backgroundColor:sub(x,x)

        local char = { text = textChar, textColor = colors.black, backgroundColor = colors.fromBlit(backgroundColorChar) }
        if textChar ~= " " then
            char.textColor = colors.fromBlit(textColorChar)
        end

        return char
    end

    return nil
end

---@type Object
local object = require(coreDotPath .. ".object")
local collision = require(coreDotPath .. ".collision")
---@type Input
local input = require(coreDotPath .. ".input")(engine, collision)
---@type Utils
local utils = require(coreDotPath .. ".utils")

---@type Input
engine.input = input
---@type Utils
engine.utils = utils
engine.freeQueue = {}

---@type Style
local style = require(coreDotPath .. ".style")
engine.style = style

local styleDown = style:inherit()
styleDown.backgroundColor = colors.white
styleDown.textColor = colors.orange
engine.styleDown = styleDown

local styleDisabled = style:inherit()
styleDisabled.textColor = colors.gray
engine.styleDisabled = styleDisabled

local styleEdit = style:inherit()
styleEdit.backgroundColor = colors.gray
engine.styleEdit = styleEdit
local styleEditFocus = style:inherit()
styleEditFocus.backgroundColor = colors.lightGray
engine.styleEditFocus = styleEditFocus

local styleScroll = style:inherit()
styleScroll.textColor = colors.lightGray
styleScroll.backgroundColor = colors.gray
engine.styleScroll = styleScroll
local styleScrollDown = styleScroll:inherit()
styleScrollDown.textColor = colors.orange
engine.styleScrollDown = styleScrollDown

--Objects
local function requireObject(name, ...)
    local o = require(coreDotPath .. ".objects." .. name)(...)
    o.name = name:gsub("^%l", string.upper)
    return o
end

---@type Control
engine.Control = requireObject("control", object, engine, style)
---@type Button
engine.Button = requireObject("button", engine.Control, styleDown, styleDisabled)
---@type Dropdown
engine.Dropdown = requireObject("dropdown", engine.Button, input, utils)
---@type ColorPicker
engine.ColorPicker = requireObject("colorPicker", engine.Control, input, style)
---@type Container
engine.Container = requireObject("container", engine.Control)
---@type VContainer
engine.VContainer = requireObject("vContainer", engine.Container)
---@type HContainer
engine.HContainer = requireObject("hContainer", engine.Container)
---@type FlowContainer
engine.FlowContainer = requireObject("flowContainer", engine.Container)
---@type ScrollContainer
engine.ScrollContainer = requireObject("scrollContainer", engine.Container, collision, input, styleScroll, styleScrollDown)
---@type WindowControl
engine.WindowControl = requireObject("windowControl", engine.Control, engine.Button, style, style)
---@type LineEdit
engine.LineEdit = requireObject("lineEdit", engine.Control, engine.input, styleEdit, styleEditFocus)
---@type Icon
engine.Icon = requireObject("icon", engine.Control)

---@type Control
local root = engine.Control:new()
root.rendering = false
root.__name = "root"
root.w = initialW
root.h = initialH
root.mouseIgnore = true

engine.running = false
engine.queueRedraw = false
engine.background = true
engine.backgroundColor = colors.black
engine.root = root

local function resizeBuffer(w, h)
    screenBuffer.reposition(1, 1, w, h)
    engine.root.w, engine.root.h = w, h
end

---@param o Control
---@param topLevelList table?
local function drawTree(o, topLevelList)
    if o.visible == false then return end
    if o.topLevel and topLevelList then
        table.insert(topLevelList, o) -- TODO make list persistent
    else
        o:draw()
        local c = o.children
        for i = 1, #c do
            drawTree(c[i], topLevelList)
        end
    end
end

local function redrawScreen()
    term.redirect(screenBuffer)
    screenBuffer.setVisible(false)

    if engine.background == true then
        term.setBackgroundColor(engine.backgroundColor)
        term.clear()
    end

    local topLevelList = {}
    drawTree(engine.root, topLevelList)
    for i, control in ipairs(topLevelList) do
        drawTree(control, nil)
    end

    if input.getCursorControl() == nil then
        term.setCursorBlink(false)
    else
        input.getCursorControl():updateCursor()
    end

    screenBuffer.setVisible(true)
    term.redirect(parentTerm)
end

local function pRedrawScreen()
    local ok, err = pcall(redrawScreen)
    if not ok then
        term.redirect(parentTerm)
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        error(err, 0)
    end
end

local drawTimerID = 0
local function fnDraw()
    while engine.running do
        if engine.queueRedraw == true then
            engine.drawCount = engine.drawCount + 1
            pRedrawScreen()
            engine.queueRedraw = false
        end

        if engine.mp then
            drawTimerID = engine.mp.startTimer(engine.p, 0.05)
        else
            drawTimerID = os.startTimer(0.05)
        end
        coroutine.yield()
    end
end

local fnInput = function()
    while engine.running do
        term.redirect(parentTerm)
        local event = input.processInput()
        if event == "term_resize" then
            resizeBuffer(parentTerm.getSize())
        elseif event == "terminate" then
            engine.stop()
        end
    end
end

engine.drawCount = 0
function engine.start()
    if engine.running then return end
    if __mp and __p then
        engine.mp = __mp
        engine.p = __p
    end

    engine.running = true
    resizeBuffer(screenBuffer.getSize())
    pRedrawScreen()

    local function freeTree(c)
        for _, child in ipairs(c.children) do
            freeTree(child)
        end
        c:free()
    end

    local function freeQueue()
        for _, c in ipairs(engine.freeQueue) do
            if c ~= nil and c:isValid() then
                if c.parent then
                    c.parent:remove(c)
                end
                freeTree(c)
            end
        end

        engine.freeQueue = {}
    end

    local coDraw = coroutine.create(fnDraw)
    local coInput = coroutine.create(fnInput)

    coroutine.resume(coDraw)
    while engine.running do
        freeQueue()
        local data = table.pack(os.pullEventRaw())
        local ok, err = false, nil
        if data[1] == "timer" and data[2] == drawTimerID then
            ok, err = coroutine.resume(coDraw, table.unpack(data))
        else
            ok, err = coroutine.resume(coInput, table.unpack(data))
        end

        if ok == false then
            error("Engine: " .. tostring(err), 0)
            engine.stop()
            local current = term.current()
            term.redirect(engine.screenBuffer)
            term.setCursorPos(1, 1)
            term.redirect(current)
        end
    end

    engine.stop()
end

function engine.stop()
    engine.running = false
end

---@param mp MultiProgram
---@return string?
function engine.startMultiProgram(mp)
    engine.mp = mp
    engine.p = mp.launchProcess(engine.screenBuffer, engine.start, nil, 1, 1, screenBuffer.getSize())

    local err = mp.start()
    return err
end

---@return Engine
return engine
