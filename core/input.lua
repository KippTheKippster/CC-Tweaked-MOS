local expect = require "cc.expect"
local field = expect.field
expect = expect.expect

---@param engine Engine
---@param utils Utils
return function(engine, utils)
    ---@class Input
    local input = {}

    ---@type table<integer, boolean>
    local heldKeys = {}
    ---@type table<integer, boolean>
    local heldMouseButtons = {}

    local mouseX, mouseY = 0, 0
    local mouseClickTime = 0.0

    ---@type (function|table)[]
    local rawEventListeners = {}
    local propagateCancel = false

    local
    ---@type Control?
    focusControl,  -- Control that has focus
    ---@type Control?
    cursorControl, -- Control that controls blinking cursor (control:updateCursor() is called)
    ---@type Control?
    inputControl,  -- Control that receives event input (control:input() is called)
    ---@type Control?
    downControl,   -- Control that is being held down
    ---@type Control?
    clickControl   -- Control that was last clicked

    local function inTerm(x, y)
        expect(1, x, "number")
        expect(2, y, "number")
        local w, h = term.getSize()
        return utils.inArea(x, y, 1, 1, w, h)
    end

    ---@param c Control?
    ---@return boolean
    local function isControlValid(c)
        if type(c) ~= "table" then
            return false
        elseif c.isValid ~= nil and c:isValid() then
            return true
        else
            return false
        end
    end

    ---@param c Control?
    ---@return Control?
    local function toValidControl(c)
        if isControlValid(c) then
            return c
        else
            return nil
        end
    end

    local function expectControl(index, c, allowNil)
        local err = true
        local valid = toValidControl(c)
        if c == nil then
            err = allowNil ~= true
        elseif valid then
            err = false
        end

        if err then
            error(("bad argument #%d (Control expected, got %s)"):format(index, type(c)), 3)
        end
    end

    ---@param c Control
    ---@param x number
    ---@param y number
    local function toLocal(c, x, y)
        expectControl(1, c)
        return x - c.gx, y - c.gy
    end

    ---@param c Control?
    ---@param fn function
    local function recursiveControlMethodUp(c, fn)
        if not c then
            return
        end

        local ok = fn(c)
        if ok then
            recursiveControlMethodUp(c.parent, fn)
        end
    end

    ---@param key number
    function input.isKeyHeld(key)
        return heldKeys[key] ~= nil
    end

    ---@param button number
    function input.isMouseButtonHeld(button)
        return heldMouseButtons[button] ~= nil
    end

    function input.cancelEventPropagation()
        propagateCancel = true
    end

    ---@param listener function|table
    function input.addRawEventListener(listener)
        expect(1, listener, "function", "table")
        table.insert(rawEventListeners, listener)
    end

    ---@param listener function|table
    function input.removeRawEventListener(listener)
        expect(1, listener, "function", "table")
        table.remove(rawEventListeners, engine.utils.find(rawEventListeners, listener))
    end

    local function isControlOnPoint(c, x, y)
        return utils.inArea(
            x, y, math.floor(c.gx) + 1, math.floor(c.gy) + 1, math.floor(c.w) - 1, math.floor(c.h) - 1
        )
    end

    local function getBranchFromPoint(root, x, y)
        if root.visible == false then
            return nil
        end

        for i = 1, #root.children do
            local child = root:getChild(#root.children - i + 1)
            local branchInPoint = getBranchFromPoint(child, x, y)
            if branchInPoint then
                return branchInPoint
            end
        end

        if isControlOnPoint(root, x, y) and root.mouseFilter ~= "ignore" then
            return root
        end

        return nil
    end

    ---@param x number
    ---@param y number
    ---@return Control?
    function input.getControlFromPoint(x, y)
        -- Top level
        for _, c in ipairs(engine.getTopLevelControls()) do
            local branch = getBranchFromPoint(c, x, y)
            if isControlValid(branch) then
                return branch
            end
        end

        return getBranchFromPoint(engine.root, x, y)
    end

    ---Returns the focus owner of control c
    ---@param c Control|nil
    ---@return Control|nil
    function input.getFocusOwner(c)
        if not c or not isControlValid(c) then
            return nil
        elseif not c.propagateFocusUp then
            return c
        else
            return input.getFocusOwner(c.parent)
        end
    end

    --#region Control

    ---@param c Control|nil
    function input.setFocusControl(c)
        expectControl(1, c, true)

        if c == focusControl then
            return
        end

        local o = focusControl
        focusControl = c

        if o and isControlValid(o) then
            o.focus = false
            o:focusChanged()
            o:emitSignal(o.focusChangedSignal)
        end

        if c and isControlValid(c) then
            c.focus = true
            c:focusChanged()
            c:emitSignal(c.focusChangedSignal)
        end
    end

    ---@return Control|nil
    function input.getFocusControl()
        return toValidControl(focusControl)
    end

    ---@param c Control|nil
    function input.setCursorControl(c)
        expectControl(1, c, true)
        cursorControl = c
    end

    ---@return Control|nil
    function input.getCursorControl()
        return toValidControl(cursorControl)
    end

    ---@param c Control|nil
    function input.setInputControl(c)
        expectControl(1, c, true)
        inputControl = c
    end

    ---@return Control|nil
    function input.getInputControl()
        return toValidControl(inputControl)
    end

    function input.setDownControl(c)
        expectControl(1, c, true)

        if c == downControl then
            return
        end

        if downControl and isControlValid(downControl) then
            downControl:up()
        end

        downControl = c
        if c then
            c:down()
        end
    end

    function input.getDownControl()
        return toValidControl(downControl)
    end

    --#endregion

    --#region Event Handling

    local function eventKey(key)
        heldKeys[key] = true
    end

    local function eventKeyUp(key)
        heldKeys[key] = nil
    end

    local function eventMouseClick(b, x, y)
        heldMouseButtons[b] = true

        mouseX, mouseY = x, y
        local clickTime = os.clock()
        local deltaTime = clickTime - mouseClickTime
        mouseClickTime = clickTime

        if not inTerm(x, y) then
            return
        end

        local c = input.getControlFromPoint(x, y)
        local o = clickControl
        clickControl = c

        input.setFocusControl(input.getFocusOwner(c))
        input.setDownControl(c)
        if c and isControlValid(c) then
            recursiveControlMethodUp(c, function (p)
                p:click(b, toLocal(p, x, y))
                return p.mouseFilter == "pass"
            end)
        end

        if c and isControlValid(c) and c == o then
            if deltaTime < 0.33 then
                recursiveControlMethodUp(c, function (p)
                    p:doubleClick(b, toLocal(p, x, y))
                    return p.mouseFilter == "pass"
                end)
                mouseClickTime = 0
            end
        end
    end

    local function eventMouseUp(b, x, y)
        heldMouseButtons[b] = nil

        mouseX, mouseY = x, y
        if not inTerm(x, y) then
            return
        end

        if downControl and isControlValid(downControl) then
            downControl:pressed()
        end

        input.setDownControl(nil)
    end

    local function eventMouseDrag(b, x, y)
        local dx, dy = x - mouseX, y - mouseY
        mouseX, mouseY = x, y
        if not inTerm(x, y) then
            input.setDownControl(nil)
            return
        end

        local validClickControl = toValidControl(clickControl)

        if clickControl and isControlValid(clickControl) then
            recursiveControlMethodUp(clickControl, function (p)
                local lx, ly = toLocal(p, x, y)
                p:drag(b, lx, ly, dx, dy)
                return p.mouseFilter == "pass"
            end)
        end

        local c = input.getControlFromPoint(x, y)
        local validC = toValidControl(c)
        if not validC then
            input.setDownControl(nil)
        elseif validC ~= clickControl and not validC.dragSelectable then
            input.setDownControl(nil)
        end

        if validC and validClickControl then
            if (validC.dragSelectable and validClickControl.dragSelectable) or validC == validClickControl then
                input.setDownControl(c)
                input.setFocusControl(input.getFocusOwner(c))
            end
        end
    end

    local function eventMouseScroll(dir, x, y)
        if not inTerm(x, y) then
            return
        end

        local function scrollControl(c)
            if isControlOnPoint(c, x, y) then
                c:scroll(dir, toLocal(c, x, y))
            end

            for i = 1, #c.children do
                scrollControl(c.children[i])
            end
        end

        scrollControl(engine.root)
    end

    local function eventAny(data)
        for _, listener in ipairs(rawEventListeners) do
            if propagateCancel == false then
                if type(listener) == "table" then
                    listener:rawEvent(data)
                elseif type(listener) == "function" then
                    listener(data)
                end
            end
        end
    end

    --#endregion

    ---@return table
    function input.pullEvent()
        propagateCancel = false

        local data = table.pack(os.pullEventRaw())
        local event = data[1]

        if event == "key" then
            eventKey(data[2])
        elseif event == "key_up" then
            eventKeyUp(data[2])
        elseif event == "mouse_click" then
            eventMouseClick(data[2], data[3], data[4])
        elseif event == "mouse_up" then
            eventMouseUp(data[2], data[3], data[4])
        elseif event == "mouse_drag" then
            eventMouseDrag(data[2], data[3], data[4])
        elseif event == "mouse_scroll" then
            eventMouseScroll(data[2], data[3], data[4])
        elseif event == "mos_window_focus" then
            if data[2] == false then
                input.setDownControl(nil)
                input.setFocusControl(nil)
            end
        end

        eventAny(data)

        if inputControl and isControlValid(inputControl) then
            inputControl:input(data)
        end

        return data
    end

    return input
end
