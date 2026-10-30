---@param engine Engine
---@param collision Collision
return function(engine, collision)
local targetTerm = term.current()
local mouse = {}
---@type Control?
mouse.current = nil
---@type Control?
mouse.clickControl = nil
---@type Control?
mouse.cursorControl = nil
---@type Control?
mouse.inputControl = nil
mouse.clickTime = os.clock()
mouse.doublePressed = false
mouse.dragX = 0
mouse.dragY = 0

local propogateCancel = false

local function isValid(o)
    if o == nil then
        return false
    elseif type(o) == "function" then
        return true
    elseif o.isValid == nil or o:isValid() == true then
        return true
    else
        return false
    end
end

---comment
---@param c Control
---@param x number
---@param y number
---@return boolean
local function isControlInPoint(c, x, y)
    return collision.inArea(
        x, y, math.floor(c.gx) + 1, math.floor(c.gy) + 1, math.floor(c:getPaddedW()) - 1, math.floor(c:getPaddedH()) - 1
    )
end

local function getBranchInPoint(root, x, y)
    if root.visible == false then
        return nil
    end

    for i = 1, #root.children do
        local child = root:getChild(#root.children - i + 1)
        local branchInPoint = getBranchInPoint(child, x, y)
        if branchInPoint then
            return branchInPoint
        end
    end

    if isControlInPoint(root, x, y) and root.mouseIgnore == false then
        return root
    end

    return nil
end

---Returns a list with all the root top level controls
---@param root Control
---@param list table
---@return table
local function getTopLevelControls(root, list)
    for i = 1, #root.children do
        local child = root:getChild(#root.children - i + 1)
        if child.topLevel and child:isVisible() then
            table.insert(list, child)
        else
            getTopLevelControls(child, list)
        end
    end

    return list
end

---Returns the deepest control in branch that overlaps point (x, y)
---@param x number
---@param y number
---@return Control?
function mouse.getControlInPoint(x, y)
    local topControls = getTopLevelControls(engine.root, {})
    for _, control in ipairs(topControls) do
        local branch = getBranchInPoint(control, x, y)
        if branch then
            return branch
        end
    end

    return getBranchInPoint(engine.root, x, y)
end

---Returns the focus owner of control c
---@param c Control
---@return Control?
function mouse.getFocusOwner(c)
    if c == nil then
        return nil
    elseif c:isValid() == false then
        return nil
    elseif c.propogateFocusUp == false then
        return c
    else
        return mouse.getFocusOwner(c.parent)
    end
end

function mouse.changeFocus(o)
    local owner = mouse.getFocusOwner(o)
    local currentOwner = mouse.getFocusOwner(mouse.current)

    if owner == currentOwner then
        mouse.current = o
        return
    end

    if currentOwner ~= nil then
        currentOwner.focus = false
    end

    if owner ~= nil then
        owner.focus = true
    end

    if currentOwner ~= nil then
        currentOwner:focusChanged()
        currentOwner:emitSignal(currentOwner.focusChangedSignal)
    end

    if owner ~= nil then
        owner:focusChanged()
        owner:emitSignal(owner.focusChangedSignal)
    end

    mouse.current = o
end

function mouse.inTerm(x, y)
    local w, h = targetTerm.getSize()
    return collision.inArea(x, y, 1, 1, w, h)
end

function mouse.click(button, x, y)
    mouse.dragX = x
    mouse.dragY = y
    local c = mouse.getControlInPoint(x, y)
    mouse.clickControl = c
    if mouse.current ~= c then -- If user clicks on a new control (or nothing)
        mouse.clickTime = os.clock()
        mouse.changeFocus(c)
        if c then
            c:down(button, x - c.gx, y - c.gy)
        end
    elseif c then -- If user clicks on the same control
        c:down(button, x - c.gx, y - c.gy)
        local time = os.clock()
        local delta = time - mouse.clickTime
        mouse.clickTime = time
        if delta < 0.33 then
            c:doublePressed(button, x - c.gx, y - c.gy)
        end
    end
end

local function grabControlFocus(c)
    mouse.changeFocus(c)
end

local function releaseControlFocus(c)
    mouse.changeFocus(nil)
end

local function setCursorControl(c)
    mouse.cursorControl = c
end

local function getCursorControl()
    if isValid(mouse.cursorControl) then
        return mouse.cursorControl
    else
        return nil
    end
end

---comment
---@param c Control?
local function setInputControl(c)
    mouse.inputControl = c
end

---@return Control?
local function getInputControl()
    if isValid(mouse.inputControl) then
        return mouse.inputControl
    else
        return nil
    end
end

---@boolean
local function isInputGrabbed()
    return getInputControl() ~= nil
end

function mouse.up(button, x, y)
    mouse.clickControl = nil
    if isValid(mouse.current) == false then return end
    local c = mouse.current
    mouse.current:up(button, x - c.gx, y - c.gy)
    mouse.current:pressed(button, x - c.gx, y - c.gy)
end

function mouse.drag(button, x, y)
    if isValid(mouse.current) == false then return end
    local relativeX = x - mouse.dragX
    local relativeY = y - mouse.dragY
    local c = mouse.getControlInPoint(x, y)
    if c ~= nil and c ~= mouse.current and c.dragSelectable == true and mouse.current.dragSelectable == true then
        mouse.current:up(button, x, y)
        mouse.changeFocus(c)
        c:down(button, x - c.gx, y - c.gy)
    end
    mouse.dragX = x
    mouse.dragY = y
    mouse.current:drag(button, x - mouse.current.gx, y - mouse.current.gy, relativeX, relativeY)
end

function mouse.scroll(dir, x, y)
    local function scrollControl(c)
        if isControlInPoint(c, x, y) == true then
            c:scroll(dir, x, y)
        end

        for i = 1, #c.children do
            scrollControl(c.children[i])
        end
    end

    scrollControl(engine.root)
end

local function getFocus()
    return mouse.getFocusOwner(mouse.current)
end

local function getCurrentControl()
    return mouse.current
end

local keys = {}

local function isKey(key)
    return keys[key] == true
end

local function key(k)
    keys[k] = true
end

local function keyUp(k)
    keys[k] = false
end


local function mouseClick(button, x, y)
    if mouse.inTerm(x, y) == false then return end
    mouse.click(button, x, y)
end

local function mouseScroll(dir, x, y) -- NOTE: This is bad, TODO remake how objects recieve input
    if mouse.inTerm(x, y) == false then return end
    mouse.scroll(dir, x, y)
end

local function mouseUp(button, x, y)
    if mouse.inTerm(x, y) == false then return end
    mouse.up(button, x, y)
end

local function mouseDrag(button, x, y)
    if mouse.inTerm(x, y) == false then
        if mouse.current then
            mouse.current:up(button, x, y)
        end
    else
        mouse.drag(button, x, y)
    end
end

local rawEventListeners = {}
local function addRawEventListener(o)
    table.insert(rawEventListeners, o)
end

local function removeRawEventListener(o)
    table.remove(rawEventListeners, engine.utils.find(rawEventListeners, o))
end

local function stopRawEventPropopgation()
    propogateCancel = true
end

local function rawEvent(data)
    propogateCancel = false
    for _, listener in ipairs(rawEventListeners) do
        if propogateCancel == false and isValid(listener) then
            if type(listener) == "table" then
                listener:rawEvent(data)
            elseif type(listener) == "function" then
                listener(data)
            end
        end
    end
end

---comment
---@return string?
local function processInput()
    local data = table.pack(os.pullEventRaw())
    local event = data[1]

    if isValid(mouse.current) == false then
        mouse.current = nil
    end

    if isValid(mouse.cursorControl) == false then
        mouse.cursorControl = nil
    end

    if event == 'key' then
        key(data[2])
    elseif event == 'key_up' then
        keyUp(data[2])
    elseif event == 'mouse_click' then
        mouseClick(
            data[2],
            data[3],
            data[4]
        )
    elseif event == 'mouse_up' then
        mouseUp(
            data[2],
            data[3],
            data[4]
        )
    elseif event == "mouse_drag" then
        mouseDrag(
            data[2],
            data[3],
            data[4]
        )
    elseif event == "mouse_scroll" then
        mouseScroll(
            data[2],
            data[3],
            data[4]
        )
    elseif event == "mos_window_focus" then
        if mouse.clickControl then -- Is this used?
            mouse.clickControl:up(0, 0, 0)
            mouse.clickControl = nil
        end
    end

    
    rawEvent(data)
    
    if isValid(mouse.inputControl) then
        mouse.inputControl:input(data) -- TODO Have a pre and post input for inputControl
    end

    return event
end

local function setTargetTerm(t)
    targetTerm = t
end

---@class Input
local Input = {
    isControlInPoint = isControlInPoint,
    getBranchInPoint = mouse.getControlInPoint,
    isKey = isKey,
    processInput = processInput,
    addRawEventListener = addRawEventListener,
    removeRawEventListener = removeRawEventListener,
    grabControlFocus = grabControlFocus,
    releaseControlFocus = releaseControlFocus,
    getFocus = getFocus,
    getCurrentControl = getCurrentControl,
    setCursorControl = setCursorControl,
    getCursorControl = getCursorControl,
    setInputControl = setInputControl,
    getInputControl = getInputControl,
    isInputGrabbed = isInputGrabbed,
    setTargetTerm = setTargetTerm,
    stopRawEventPropopgation = stopRawEventPropopgation
}

return Input
end
