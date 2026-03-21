---@param container Container
---@param collision Collision
---@param input Input
---@return ScrollContainer
return function(container, collision, input, style, styleDown)
    ---@class ScrollContainer : Container
    local ScrollContainer = container:newClass()
    ScrollContainer.__type = "ScrollContainer"

    ScrollContainer.ScrollMode = { VERTICAL = 0, HORIZONTAL = 1 }
    ScrollContainer.scrollMode = ScrollContainer.ScrollMode.VERTICAL
    ScrollContainer.rendering = true
    ScrollContainer.barStartX = 0
    ScrollContainer.barStartY = 0
    ScrollContainer.barEndX = 0
    ScrollContainer.barEndY = 0
    ScrollContainer.barDown = false
    ScrollContainer.dynamicBar = true
    ScrollContainer._mOffset = 0
    ScrollContainer.style = style
    ScrollContainer.styleDown = styleDown

    function ScrollContainer:init(...)
        container.init(self)
        input.addRawEventListener(self)
        container.init(self, ...)
    end

    function ScrollContainer:queueFree()
        input.removeRawEventListener(self)
        container.queueFree(self)
    end

    local function limitScroll(self, y)
        local child = self:getChild(1)
        if not child then
            return y
        end

        if y >= 0 then
            y = 0
        elseif y < self.h - child.h then
            y = self.h - child.h
        end
        
        return y
    end

    local function limitChildY(self)
        local child = self:getChild(1)
        if not child then
            return
        end

        child.y = limitScroll(self, child.y)
    end

    function ScrollContainer:render()
        local c = self:getChild(1)
        local offset = 0
        if (self.h) / (c.h - self.h) > 1 then
            local steps = math.max(0, c.h - self.h)
            local stepAmount = math.min(1.0, ((self.h - 1) / steps))
            offset = -c.y * stepAmount
        else
            local o = 1
            if c.y == 0 then
                o = 0
            end
            offset = (-c.y * (self.h - 2)) / (c.h - self.h) + o
        end

        local stepCount = math.max(0, c.h - (self.h - 1))
        local size = math.max(0, self.h - stepCount)
        if self.dynamicBar then
            if size >= self.h - 1 then -- No scroll
                self.marginR = 0
                limitChildY(self)
                return
            else
                if self.marginR == 0 then
                    self.marginR = 1
                    limitChildY(self)
                end
            end
        end

        local st = self:getStyle()

        local startX = self.gx + self.w
        local endX = startX
        local startY = self.gy + 1
        local endY = startY + self.h - 1
        paintutils.drawLine(startX, startY, endX, endY, st.backgroundColor)

        startY = math.floor(self.gy + offset + 1)
        endY = startY + math.ceil(size)

        paintutils.drawLine(startX, startY, endX, endY, st.textColor)

        self.barStartX = startX
        self.barStartY = startY
        self.barEndX = endX
        self.barEndY = endY
    end

    function ScrollContainer:getStyle()
        if self.barDown then
            return self.styleDown
        else
            return self.style
        end
    end

    function ScrollContainer:sort()
        local child = self:getChild(1)
        if child == nil then
            return
        end

        child:resize()
        limitChildY(self)
    end

    function ScrollContainer:setScroll(position)
        local child = self:getChild(1)
        child.y = limitScroll(self, -position)
    end

    function ScrollContainer:scroll(dir, _, _)
        local child = self:getChild(1)
        self:setScroll(-child.y + dir)
    end

    ---comment
    ---@param gy number
    function ScrollContainer:scrollToView(gy)
        local c = self:getChild(1)
        local y = gy - self.gy
        if y < 0 then
           self:setScroll(gy - c.gy)
        elseif y >= self.h then
            self:setScroll(gy - c.gy - self.h + 1) -- is this right?
        end
    end

    function ScrollContainer:transformChanged()
        limitChildY(self)
    end

    function ScrollContainer:resize()
        container.resize(self)
        self:sort()
    end

    function ScrollContainer:rawEvent(data)
        local event = data[1]
        if event == "mouse_click" then
            local x = data[3]
            local y = data[4]
            if collision.inArea(x, y, self.barStartX, self.barStartY, self.barEndX - self.barStartX, self.barEndY - self.barStartY) then
                self.barDown = true
                self:queueDraw()
                self._mOffset = self.barStartY - y - 1
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
                self:setScroll(o)
            end
        end
    end

    return ScrollContainer
end
