---@return Style
---@class Style
local Style = {}
---@return Style
function Style:inherit()
    local style = {}
    local mt = {
        base = self,
        __index = function (o, key)
            local mt = getmetatable(o)
            return mt.base[key]
        end,
        __newindex = rawset
    }
    setmetatable(style, mt)
    return style
end

---@return Style
function Style:unique()
    local style = {}
    local base = self
    while base ~= nil do
        for k, v in pairs(base) do
            style[k] = v
        end
        local mt = getmetatable(base)
        if mt then
            base = mt.base
        else
            return style
        end
    end

    return style
end

Style.backgroundColor = colors.lightGray
Style.borderColor = colors.gray
Style.textColor = colors.black
Style.background = true
Style.border = false
Style.shadowTextColor = colors.black
Style.shadowBackgroundColor = colors.gray
Style.shadowOffsetL = 0
Style.shadowOffsetR = 0
Style.shadowOffsetU = 0
Style.shadowOffsetD = 0

return Style