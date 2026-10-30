---@param container Container
---@param engine Engine
---@return ScrollContainer
return function(container, engine, style, styleDown)
    ---@class ScrollContainer : Container
    local ScrollContainer = container:newClass()
    ScrollContainer.__type = "ScrollContainer"

    --- "vertical" or "horizontal"
    ScrollContainer.alignmentMode = "vertical"
    ScrollContainer.rendering = true
    ScrollContainer._barStartX = 0
    ScrollContainer._barStartY = 0
    ScrollContainer._barEndX = 0
    ScrollContainer._barEndY = 0
    ScrollContainer._barVisible = false
    ScrollContainer.barDown = false
    ScrollContainer.dynamicBar = true
    ScrollContainer._mOffset = 0
    ScrollContainer.styleScroll = style
    ScrollContainer.styleScrollDown = styleDown
    ScrollContainer._scrollValue = 0
    ---@type integer
    ScrollContainer.scrollValue = nil

    local function errorMode(mode)
        local level = 1
        if type(mode) == "string" then
            error("Invalid alignmentMode " .. mode, level)
        else
            error("Invalid alignmentMode not string!", level)
        end
    end

    ---@param o Control
    ---@param mode string
    ---@return integer
    local function offset(o, mode)
        if mode == "vertical" then
            return o.y
        elseif mode == "horizontal" then
            return o.x
        end
        errorMode(mode)
    end

    ---@param o Control
    ---@param value integer
    ---@param mode string
    local function setOffset(o, value, mode)
        if mode == "vertical" then
            o.y = value
        elseif mode == "horizontal" then
            o.x = value
        else
            errorMode(mode)
        end
        o:reposition()
    end

    ---@param o Control
    ---@param mode string
    ---@return integer
    local function gOffset(o, mode)
        if mode == "vertical" then
            return o.gy
        elseif mode == "horizontal" then
            return o.gx
        end
        errorMode(mode)
    end

    ---@param o Control
    ---@param mode string
    ---@return integer
    local function length(o, mode)
        if mode == "vertical" then
            return o:toPaddedH(o.h)
        elseif mode == "horizontal" then
            return o:toPaddedW(o.w)
        end
        errorMode(mode)
    end

    local function limitScroll(self, o)
        local child = self:getChild(1)
        if not child then
            return o
        end

        local dif =  length(self, self.alignmentMode) - length(child, self.alignmentMode)
        if o >= 0 then
            o = 0
        elseif o < dif then
            o = dif
        end

        return o
    end


    ScrollContainer:defineProperty("scrollValue",
        function (self)
            return self._scrollValue
        end,
        function (self, value)
            self._scrollValue = value
            local child = self:getChild(1)
            setOffset(child, limitScroll(self, -value), self.alignmentMode)
        end
    )

    ---@param alignmentMode string?
    function ScrollContainer:init(alignmentMode)
        engine.input.addRawEventListener(self)
        if type(alignmentMode) == "string" then
            self.alignmentMode = alignmentMode
        end

        container.init(self)
    end

    function ScrollContainer:queueFree()
        engine.input.removeRawEventListener(self)
        container.queueFree(self)
    end

    local function limitChildOffset(self, mode)
        local child = self:getChild(1)
        if not child then
            return
        end

        setOffset(child, limitScroll(self, offset(child, mode)), mode)
    end

    local function isBarVisible(self)
        local c = self:getChild(1)
        if self.dynamicBar then
            local _, _minH = c:getMinSize()
            return c:toPaddedH(_minH) > self.h
        else
            return self._barVisible
        end
    end

    -- FIXME should not render every frame
    function ScrollContainer:render()
        container.render(self)

        if self.alignmentMode ~= "vertical" then
            return
        end

        local c = self:getChild(1)
        local ch = c:toPaddedH(c.h)
        local offset = 0
        if (self.h) / (ch - self.h) > 1 then
            local steps = math.max(0, ch - self.h)
            local stepAmount = math.min(1.0, ((self.h - 1) / steps))
            offset = -c.y * stepAmount
        else
            local o = 1
            if c.y == 0 then
                o = 0
            end
            offset = (-c.y * (self.h - 2)) / (ch - self.h) + o
        end

        --self.marginR = 1

        local stepCount = math.max(0, ch - (self.h - 1))
        local size = math.max(0, self.h - stepCount)
        if self.dynamicBar then
            if isBarVisible(self) then
                self._barVisible = true
                if c.paddingR == 0 then
                    --c.marginR = 1
                    --c.x = -1
                    --self.marginR = -1
                    limitChildOffset(self, self.alignmentMode)
                end
            else
                self._barVisible = false
                limitChildOffset(self, self.alignmentMode)
                return
            end
            if size >= self.h - 1 then -- No scroll
                --c.paddingR = 0
            else
            end
        end

        local st = self.styleScroll
        if self.barDown then
            st = self.styleScrollDown
        end

        local startX = self.gx + self.w-- + 1
        local endX = startX
        local startY = self.gy + 1
        local endY = startY + self.h - 1
        paintutils.drawLine(startX, startY, endX, endY, st.backgroundColor)

        startY = math.floor(self.gy + offset + 1)
        endY = startY + math.ceil(size)

        paintutils.drawLine(startX, startY, endX, endY, st.textColor)

        self._barStartX = startX
        self._barStartY = startY
        self._barEndX = endX
        self._barEndY = endY
    end

    function ScrollContainer:sort()
        local child = self:getChild(1)
        if child == nil then
            return
        end

        --child:update()
        child:containerPreSort()

        local _, minH = child:getMinSize()
        if self.dynamicBar then
            child.h = minH
        end

        child:resize()
        child:reposition()
        limitChildOffset(self, self.alignmentMode)
    end

    function ScrollContainer:scroll(dir, _, _)
        local child = self:getChild(1)
        self.scrollValue = -offset(child, self.alignmentMode) + dir
    end

    ---comment
    ---@param go number
    function ScrollContainer:scrollToView(go)
        local c = self:getChild(1)
        local o = go - gOffset(self, self.alignmentMode)
        if o < 0 then
            self.scrollValue = go - gOffset(c, self.alignmentMode)
        elseif o >= length(self, self.alignmentMode) then
            self.scrollValue = go - gOffset(c, self.alignmentMode) - length(self, self.alignmentMode) + 1
        end
    end

    function ScrollContainer:transformChanged()
        limitChildOffset(self, self.alignmentMode)
    end

    function ScrollContainer:getFillSize()
        if isBarVisible(self) then
            return self.w - 1, self.h
        else
            return self.w, self.h
        end
    end

    function ScrollContainer:rawEvent(data)
        local event = data[1]
        if event == "mouse_click" then
            local x = data[3]
            local y = data[4]
            if engine.collision.inArea(x, y, self._barStartX, self._barStartY, self._barEndX - self._barStartX, self._barEndY - self._barStartY) then
                self.barDown = true
                self:queueDraw()
                self._mOffset = self._barStartY - y - 1
            end
        elseif event == "mouse_up" then
            self.barDown = false
            self:queueDraw()
        elseif event == "mouse_drag" then
            if self.barDown then
                local x = data[3]
                local y = data[4]
                local c = self:getChild(1)
                local m = y - self.gy + self._mOffset
                local s = math.max(1, (c.h - self.h) / (self.h-1))
                local o = m * s
                self.scrollValue = o
            end
        end
    end

    return ScrollContainer
end
