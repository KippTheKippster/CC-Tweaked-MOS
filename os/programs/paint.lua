---@type MOS
local mos = __mos
local mosWindow = __mosWindow
if mos == nil then
    printError("Paint must be opened with MOS!")
    return
end

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")

local args = { ... }

---@type Control
local background = nil
---@type Control
local sprite = nil
---@type Control
local selectionBox = nil
---@type table
local coords = nil

--#region Paint
local paint = {}
paint.canvas = nil
paint.selectionCanvas = nil
paint.copyCanvas = nil
paint.saveFile = ""
paint.colorL = colors.white
paint.colorR = colors.black
paint.edited = false
paint.tool = "pen"

local colourLookup = {}
for n = 1, 16 do
    colourLookup[string.byte("0123456789abcdef", n, n)] = 2 ^ (n - 1)
end

paint.charToColor = function(char)
    return colourLookup[char]
end

paint.colorToChar = function(color)
    if type(color) == "number" then
        local value = math.floor(math.log(color) / math.log(2)) + 1
        if value >= 1 and value <= 16 then
            return string.sub("0123456789abcdef", value, value)
        end
    end
    return " "
end

paint.createCanvas = function(w, h)
    local canvas = {}
    for i = 1, h do
        canvas[i] = {}
        for j = 1, w do
            canvas[i][j] = -1
        end
    end

    return canvas
end

paint.fillCanvas = function(canvas, color)
    for i = 1, #canvas do
        for j = 1, #canvas[i] do
            canvas[i][j] = color
        end
    end
end

paint.clearCanvas = function(canvas)
    paint.fillCanvas(canvas, -1)
end

paint.clearCanvasArea = function(canvas, x, y, w, h)
    local _w, _h = paint.getCanvasSize(canvas)
    if x + w > _w then
        w = w - (x + w - _w)
    end

    if y + h > _h then
        h = h - (y + h - _h)
    end

    local offsetX = 0
    local offsetY = 0

    if x < 0 then
        offsetX = -x
        w = w + x
    end

    if y < 0 then
        offsetY = -y
        h = h + y
    end

    for i = 1, h do
        for j = 1, w do
            canvas[i + y + offsetY][j + x + offsetX] = -1
        end
    end
end

paint.createCanvasCopy = function(canvas)
    local copy = {}
    local w, h = paint.getCanvasSize(canvas)
    for i = 1, h do
        copy[i] = {}
        for j = 1, w do
            copy[i][j] = canvas[i][j]
        end
    end

    return copy
end

paint.createCanvasAreaCopy = function(canvas, x, y, w, h)
    local copy = {}
    for i = 1, h do
        copy[i] = {}
        for j = 1, w do
            copy[i][j] = canvas[i + y][j + x]
        end
    end

    return copy
end

paint.pasteCanvasArea = function(from, to, x, y)
    local fromW, fromH = paint.getCanvasSize(from)
    local toW, toH = paint.getCanvasSize(to)
    local w, h = fromW, fromH
    if x + fromW > toW then
        w = w - (x + fromW - toW)
    end

    if y + fromH > toH then
        h = h - (y + fromH - toH)
    end

    local offsetX = 0
    local offsetY = 0

    if x < 0 then
        offsetX = -x
        w = w + x
    end

    if y < 0 then
        offsetY = -y
        h = h + y
    end

    for i = 1, h do
        for j = 1, w do
            local color = from[i + offsetY][j + offsetX]
            if color > -1 then
                to[i + y + offsetY][j + x + offsetX] = from[i + offsetY][j + offsetX]
            end
        end
    end
end

paint.resizeCanvas = function(canvas, x, y, w, h)
    local _w, _h = paint.getCanvasSize(canvas)

    -- Trim
    if h < _h then
        for i = h, _h - 1 do
            table.remove(canvas, #canvas)
        end
    end

    if y > 1 then
        for i = 1, y - 1 do
            table.remove(canvas, 1)
        end
    end

    _w, _h = paint.getCanvasSize(canvas)
    if w < _w then
        for i = 1, _h do
            for j = w, _w - 1 do
                table.remove(canvas[i], #canvas[i])
            end
        end
    end

    if x > 1 then
        for i = 1, _h do
            for j = 1, x - 1 do
                table.remove(canvas[i], 1)
            end
        end
    end

    -- Expand
    _w, _h = paint.getCanvasSize(canvas)

    -- TODO Add expand left and up

    if h - y + 1 > _h then
        for i = _h + 1, h - y + 1 do
            local line = {}
            for j = 1, _w do
                line[j] = -1
            end
            table.insert(canvas, #canvas + 1, line)
        end
    end

    _w, _h = paint.getCanvasSize(canvas)
    if w - x + 1 > _w then
        for i = 1, _h do
            for j = _w + 1, w - x + 1 do
                canvas[i][j] = -1
            end
        end
    end
end

paint.trimCanvas = function(canvas)
    local w, h = paint.getCanvasSize(canvas)
    local l, r, u, d = w, 1, -1, -1
    local uLocked = true
    local dLocked = true
    for i = 1, h do
        local count = 0
        for j = 1, w do
            if canvas[i][j] > -1 then
                l = math.min(l, j)
                r = math.max(r, j)
                count = count + 1
            end
        end
        if count == 0 then
            uLocked = false
            if dLocked == false and d == -1 then
                d = i - 1
            end
        else
            dLocked = false
            if uLocked == false and u == -1 then
                u = i
            end
        end
    end

    if d == -1 then -- TODO Fix check
        d = w
    end

    if u == -1 then
        u = 1
    end


    paint.resizeCanvas(canvas, l, u, r, d)
end

paint.getCanvasSize = function(canvas)
    if #canvas == 0 then
        return 0, 0
    end

    return #canvas[1], #canvas
end

paint.squareCanvas = function(canvas)
    local w, h = 0, #canvas
    for i = 1, h do
        w = math.max(w, #canvas[i])
    end

    for i = 1, h do
        for j = 1, w do
            canvas[i][j] = canvas[i][j] or -1
        end
    end
end


paint.saveCanvas = function(canvas, file)
    local f, err = fs.open(file, "w")
    if not f then
        return false, err
    end

    canvas = canvas or paint.canvas

    local w, h = paint.getCanvasSize(canvas)
    for i = 1, h do
        local line = ""
        for j = 1, w do
            line = line .. paint.colorToChar(canvas[i][j])
        end
        f.writeLine(line)
    end

    f.close()
    return true
end

paint.canvasContainsPoint = function(canvas, x, y)
    local w, h = paint.getCanvasSize(canvas)
    return x > 0 and y > 0 and x < w + 1 and y < h + 1
end

paint.getCanvasPixel = function(canvas, x, y)
    return canvas[y][x]
end

paint.setCanvasPixel = function(canvas, x, y, color)
    canvas[y][x] = color
end

paint.fitSprite = function()
    sprite.w, sprite.h = paint.getCanvasSize(paint.canvas)
end

paint.centerSprite = function()
    local w, h = engine.root.w, engine.root.h
    sprite.x, sprite.y = math.floor((w - sprite.w) / 2.0), math.floor((h - sprite.h) / 2.0)
end

paint.newImage = function(w, h)
    paint.saveFile = ""
    paint.canvas = paint.createCanvas(w, h)
    paint.fitSprite()
    paint.centerSprite()
    sprite:queueDraw()
end

paint.openImage = function(file)
    paint.saveFile = file
    paint.canvas = paintutils.loadImage(file) -- FIXME if image isn't stored as a square it will result in canvas not being a square
    paint.squareCanvas(paint.canvas)
    paint.fitSprite()
    paint.centerSprite()
    sprite:queueDraw()
    mosWindow.text = "Paint " .. fs.getName(file)
end

paint.saveImage = function(file)
    paint.saveFile = file
    paint.saveCanvas(paint.canvas, file)
    mosWindow.text = "Paint " .. fs.getName(file)
end

paint.setEdited = function(edited)
    edited = edited or true
    if paint.edited == false and edited then
        paint.edited = true
        mosWindow.text = mosWindow.text .. "*"
        mosWindow:queueDraw()
    end

    if paint.edited == true and edited == false then
        paint.edited = false
        mosWindow.text = mosWindow.text:sub(1, #mosWindow.text - 1)
        mosWindow:queueDraw()
    end
end
--#endregion

--#region Ui
local ui = {}
ui.fileExplorer = nil

ui.new = function()
    paint.newImage(16, 10)
    mosWindow:grabFocus()
end

ui.open = function()
    ui.fileExplorer = mos.openFileDialogue("Open File", function(path)
        paint.openImage(path)
        ui.fileExplorer:close()
        mosWindow:grabFocus()
        paint.setEdited(false)
    end)
end

ui.save = function()
    if paint.saveFile == "" then
        ui.saveAs()
    else
        paint.saveImage(paint.saveFile)
        paint.setEdited(false)
        mosWindow:grabFocus()
    end
end

ui.saveAs = function()
    ui.fileExplorer = mos.openFileDialogue("Save File", function(path)
        local suffix = ".nfp"
        if path:sub(- #suffix) ~= suffix then
            path = path .. suffix
        end
        paint.saveImage(path)
        ui.fileExplorer:close()
        mosWindow:grabFocus()
        paint.setEdited(false)
    end, true, paint.saveFile)
end

background = engine.root:addControl()
background.expandW = true
background.expandH = true
background.rendering = false

sprite = background:addControl()

selectionBox = sprite:addControl()
selectionBox.text = ""
selectionBox.w = 0
selectionBox.h = 0
selectionBox.visible = false
selectionBox.mouseIgnore = true
selectionBox.dragging = false
selectionBox.style = selectionBox.style:unique()
selectionBox.style.border = true
selectionBox.style.background = false
selectionBox.style.borderColor = colors.white

function background:down()
    if selectionBox.visible and paint.selectionCanvas then
        selectionBox.visible = false
        paint.pasteCanvasArea(paint.selectionCanvas, paint.canvas, selectionBox.x, selectionBox.y)
        paint.selectionCanvas = nil
    end
end

engine.input.addRawEventListener(sprite)

function sprite:rawEvent(data)
    local event = data[1]
    if event == "term_resize" then
        paint.centerSprite()
    elseif event == "key" then
        local key = data[2]
        if engine.input.isKey(keys.leftCtrl) then
            if key == keys.s then
                if engine.input.isKey(keys.leftShift) then
                    ui.saveAs()
                else
                    ui.save()
                end
            elseif key == keys.o then
                ui.open()
            elseif key == keys.c then
                if paint.tool == "selection" and paint.selectionCanvas then
                    paint.copyCanvas = paint.createCanvasCopy(paint.selectionCanvas)
                end
            end
        else
            if key == keys.d or key == keys.right then
                self.x = self.x - 1
            elseif key == keys.a or key == keys.left then
                self.x = self.x + 1
            elseif key == keys.w or key == keys.up then
                self.y = self.y + 1
            elseif key == keys.s or key == keys.down then
                self.y = self.y - 1
            end

            if key == keys.f then
                paint.centerSprite()
            elseif key == keys.delete then
                if paint.selectionCanvas then
                    paint.clearCanvas(paint.selectionCanvas)
                    selectionBox:queueDraw()
                end
            end
        end
    elseif event == "paste" then
        if paint.copyCanvas == nil then
            return
        end

        if paint.selectionCanvas then
            paint.pasteCanvasArea(paint.selectionCanvas, paint.canvas, selectionBox.x, selectionBox.y)
        end

        local w, h = paint.getCanvasSize(paint.copyCanvas)
        selectionBox.x = 0
        selectionBox.y = 0
        selectionBox.w = w
        selectionBox.h = h
        selectionBox.visible = true
        selectionBox.mouseIgnore = false

        paint.selectionCanvas = paint.copyCanvas
    end
end

function sprite:transformChanged()
    coords.text = sprite.x .. " " .. sprite.y
end

local function fillArea(char, x, y, w, h)
    for i = 1, h do
        for j = 1, w do
            term.setCursorPos(x + j, y + i)
            term.write(char)
        end
    end
end

function sprite:render()
    if paint.canvas ~= nil then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        local w, h = term.getSize()
        fillArea(string.char(146), 0, 0, w, h)

        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
        w, h = paint.getCanvasSize(paint.canvas)
        fillArea(string.char(127), self.x, self.y, w, h)

        paintutils.drawImage(paint.canvas, self.x + 1, self.y + 1)
    end
end

function sprite:setPixel(b, x, y)
    paint.setEdited()

    local color = paint.colorR
    if b == 1 then
        color = paint.colorL
    end

    paint.setCanvasPixel(paint.canvas, x, y, color)
    if color == -1 then
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
        term.setCursorPos(x + self.gx, y + self.gy)
        term.write(string.char(127))
    else
        paintutils.drawPixel(x + self.gx, y + self.gy, color)
    end
end

function sprite:down(b, x, y)
    if paint.tool == "pen" then
        sprite:setPixel(b, x, y)
    elseif paint.tool == "selection" then
        if paint.selectionCanvas then
            paint.pasteCanvasArea(paint.selectionCanvas, paint.canvas, selectionBox.x, selectionBox.y)
        end

        paint.selectionCanvas = nil
        selectionBox.x = x - 1
        selectionBox.y = y - 1
        selectionBox.w = 1
        selectionBox.h = 1
        selectionBox.mouseIgnore = true
        selectionBox.visible = true
    elseif paint.tool == "bucket" then
        local dirs = {
            { x = 1,  y = 0 },
            { x = 0,  y = 1 },
            { x = -1, y = 0 },
            { x = 0,  y = -1 }
        }

        local function fill(canvas, colorFrom, colorTo, queue)
            local point = queue[#queue]
            table.remove(queue, #queue)
            paint.setCanvasPixel(paint.canvas, point.x, point.y, colorTo)
            for _, dir in pairs(dirs) do
                local next = { x = point.x + dir.x, y = point.y + dir.y }
                if paint.canvasContainsPoint(canvas, next.x, next.y) and paint.getCanvasPixel(canvas, next.x, next.y) == colorFrom then
                    table.insert(queue, next)
                end
            end

            if #queue > 0 then
                fill(canvas, colorFrom, colorTo, queue)
            end
        end

        local fillColor = paint.colorR
        if b == 1 then
            fillColor = paint.colorL
        end
        local queue = { { x = x, y = y } }
        local color = paint.getCanvasPixel(paint.canvas, x, y)
        if color ~= fillColor then
            pcall(fill, paint.canvas, color, fillColor, queue)
            self:queueDraw()
        end
    end
end

function sprite:drag(b, x, y, rx, ry)
    if x < 1 or y < 1 or x > self.w or y > self.h then return end
    if paint.tool == "pen" then
        sprite:setPixel(b, x, y)
    elseif paint.tool == "selection" then
        selectionBox.w = x - selectionBox.x
        selectionBox.h = y - selectionBox.y
    end
end

function sprite:up()
    if paint.tool == "selection" then
        if selectionBox.w == 1 and selectionBox.h == 1 then
            selectionBox.visible = false
        else
            selectionBox.mouseIgnore = false
            if selectionBox.w < 1 then -- Ensure that size isn't negative
                local x = selectionBox.x
                local w = selectionBox.w
                selectionBox.x = x + w - 1
                selectionBox.w = w * -1 + 2
            end
            if selectionBox.h < 1 then
                local y = selectionBox.y
                local h = selectionBox.h
                selectionBox.y = y + h - 1
                selectionBox.h = h * -1 + 2
            end

            paint.selectionCanvas = paint.createCanvasAreaCopy(paint.canvas, selectionBox.x, selectionBox.y,
                selectionBox.w, selectionBox.h)
            paint.clearCanvasArea(paint.canvas, selectionBox.x, selectionBox.y, selectionBox.w, selectionBox.h)
        end
    end
end

function selectionBox:drag(b, x, y, rx, ry)
    self.x = self.x + rx
    self.y = self.y + ry
end

function selectionBox:render()
    if paint.selectionCanvas ~= nil then
        paintutils.drawImage(paint.selectionCanvas, self.gx + 1, self.gy + 1)
    end

    engine.Control.render(self)
end

local toolbar = engine.root:addVContainer()
toolbar.w = 1

local toolIcon = engine.Control:newClass()
toolIcon._fitToText = false
toolIcon._w = 1
toolIcon._h = 1
toolIcon._text = "Tool"
toolIcon.dragSelectable = true
toolIcon.tool = "Pen"

local toolNormalStyle = engine.style:unique()
toolNormalStyle.backgroundColor = colors.lightGray
toolNormalStyle.textColor = colors.black

local toolSelectStyle = engine.style:unique()
toolSelectStyle.backgroundColor = colors.white
toolSelectStyle.textColor = colors.black

local currentToolIcon = nil

local function setCurrentToolIcon(c)
    if currentToolIcon then
        currentToolIcon.style = toolNormalStyle
    end

    currentToolIcon = c
    currentToolIcon.style = toolSelectStyle
    paint.tool = currentToolIcon.tool
end

function toolIcon:down()
    setCurrentToolIcon(self)
    self.w = #self.text
end

function toolIcon:up()
    self.w = 1
end

local penTool = toolIcon:new()
toolbar:add(penTool)
penTool.text = string.char(14) .. " Pen"
penTool.tool = "pen"

local selectTool = toolIcon:new()
toolbar:add(selectTool)
selectTool.text = string.char(35) .. " Selection Box"
selectTool.tool = "selection"

local bucketTool = toolIcon:new()
toolbar:add(bucketTool)
bucketTool.text = string.char(219) .. " Bucket"
bucketTool.tool = "bucket"

setCurrentToolIcon(penTool)

local palette = engine.root:addControl()
palette.rendering = false

palette.w = 2
palette.anchorW = palette.Anchor.RIGHT
palette.expandH = true

local colorL = palette:addControl()
local colorR = palette:addControl()
colorL.text = ""
colorR.text = ""
colorL.y = 17
colorR.y = 17
colorL.x = 0
colorR.x = 1
colorL.w = 1
colorR.w = 1
colorL.h = 1
colorR.h = 1
colorL.style = colorL.style:unique()
colorR.style = colorR.style:unique()
colorL.style.backgroundColor = paint.colorL
colorR.style.backgroundColor = paint.colorR

for i = 0, 16 do
    ---@class PaletteColor : Control
    local c = palette:addControl()
    c.minW = 2
    c.h = 1
    c.y = i
    c.text = ""
    c.dragSelectable = true
    c.style = c.style:unique()
    if i == 16 then
        c.style.backgroundColor = colors.gray
        c.style.textColor = colors.lightGray
        c.text = string.char(127) .. string.char(127)
        c.colorIndex = -1
    else
        c.style.backgroundColor = 2 ^ i
        c.colorIndex = c.style.backgroundColor
    end
    c.down = function(_, b)
        if b == 1 then
            paint.colorL = c.colorIndex
            colorL.style = c.style
        else
            paint.colorR = c.colorIndex
            colorR.style = c.style
        end
        c:queueDraw()
    end
end

local coordsStyle = engine.style:unique()
coordsStyle.textColor = colors.white
coordsStyle.backgroundColor = colors.black

coords = engine.root:addControl()
coords.anchorH = coords.Anchor.DOWN
coords.h = 1
coords.style = coordsStyle

local windowStyle = engine.style:unique()
windowStyle.backgroundColor = colors.white

local editStyle = engine.style:unique()
editStyle.backgroundColor = colors.gray
editStyle.textColor = colors.white

local editFocusStyle = editStyle:inherit()
editFocusStyle.backgroundColor = colors.black

local function createEditField(fieldName, text, parent)
    text = text or ""

    local h = engine.HContainer:new()
    h.h = 1
    h.expandW = true
    local label = h:addControl()
    label.text = fieldName
    label.h = 1

    local edit = h:addLineEdit()
    edit.inheritStyle = false
    edit.h = 1
    edit.expandW = true
    edit.text = text
    edit.normalStyle = editStyle
    edit.focusStyle = editFocusStyle
    edit.style = editStyle

    parent:add(h)

    return edit
end

---comment
---@return WindowControl
local function createDialogue()
    local wi = engine.root:addWindowControl()
    wi.style = windowStyle
    wi.x = 1
    wi.y = 1
    return wi
end

local function createResizeDialogue(fn)
    local _w, _h = paint.getCanvasSize(paint.canvas)

    ---@class resizeDialogue : WindowControl
    local wi = createDialogue()
    wi.text = "Resize"
    wi.vContainer = wi:addVContainer()
    wi.vContainer.expandW = true
    wi.vContainer.expandH = true
    wi.vContainer.y = 1
    wi.wEdit = createEditField("W: ", tostring(_w), wi.vContainer)
    wi.hEdit = createEditField("H: ", tostring(_h), wi.vContainer)
    wi.ok = wi:addButton()
    wi.ok.text = "Ok"
    wi.ok.h = 1
    wi.ok.expandW = true
    wi.ok.centerText = true
    wi.ok.anchorH = wi.Anchor.DOWN
    wi.ok.pressed = function()
        local w = tonumber(wi.wEdit.text) or _w
        local h = tonumber(wi.hEdit.text) or _h
        fn(w, h)
        wi:queueFree()
        --wi.wEdit:queueFree()
    end
    wi:expandChildren()

    wi.wEdit:grabFocus()
end

--#endregion

--#region MOS
if mos then
    local fileDropdown = mos.engine.Dropdown:new()
    fileDropdown.text = "File"
    fileDropdown:addToList("New  Image")
    fileDropdown:addToList("Open Image")
    fileDropdown:addToList("----------", false)
    fileDropdown:addToList("Save")
    fileDropdown:addToList("Save As...")
    fileDropdown:addToList("----------", false)
    fileDropdown:addToList("Close")

    function fileDropdown:optionPressed(i)
        local text = fileDropdown:getOptionText(i)
        if text == "New  Image" then
            ui.new()
        elseif text == "Open Image" then
            ui.open()
        elseif text == "Save" then
            ui.save()
        elseif text == "Save As..." then
            ui.saveAs()
        elseif text == "Close" then
            mosWindow:close()
        end
    end

    local imageDropdown = mos.engine.Dropdown:new()
    imageDropdown.text = "Image"
    imageDropdown:addToList("Resize")
    imageDropdown:addToList("Trim")
    imageDropdown:addToList("------", false)
    imageDropdown:addToList("Fill")
    imageDropdown:addToList("Clear")

    function imageDropdown:optionPressed(i)
        local text = imageDropdown:getOptionText(i)
        if text == "Resize" then
            createResizeDialogue(function(w, h)
                paint.resizeCanvas(paint.canvas, 1, 1, w, h)
                paint.fitSprite()
                paint.centerSprite()
                paint.setEdited()
            end)
        elseif text == "Trim" then
            paint.trimCanvas(paint.canvas)
            paint.fitSprite()
            sprite:queueDraw()
            paint.setEdited()
        elseif text == "Fill" then
            paint.fillCanvas(paint.canvas, paint.colorL)
            sprite:queueDraw()
            paint.setEdited()
        elseif text == "Clear" then
            paint.clearCanvas(paint.canvas)
            sprite:queueDraw()
            paint.setEdited()
        end

        mosWindow:grabFocus()
    end

    mos.bindTool(mosWindow, function(focus)
        if focus then
            mos.addToToolbar(fileDropdown)
            mos.addToToolbar(imageDropdown)
        else
            mos.removeFromToolbar(fileDropdown)
            mos.removeFromToolbar(imageDropdown)
        end
    end)
end
--#endregion

local startFile = args[1]
if startFile ~= nil and type(startFile) == "string" then
    paint.openImage(startFile)
end

if paint.canvas == nil then
    paint.newImage(16, 10)
end

engine.start()
