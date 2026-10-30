if mos == nil then
    printError("Error must be opened with MOS!")
    return
end

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")
local args = {...}

mos.log("MOS Error Popup: ", textutils.serialize(args))

---@type Engine
mos.applyTheme(engine)
local main = engine.root:addVContainer()

for _, err in ipairs(args) do
    local c = main:addControl()
    c.text = tostring(err):match"^%s*(.-)%s*$"
    c.marginL = 1
    c.marginR = 1
end


mosWindow.minW = main.w
mosWindow.minH = main.h + 1
mosWindow.w = mosWindow.minW
mosWindow.h = mosWindow.minH
mosWindow.oldW = mosWindow.w
mosWindow.oldH = mosWindow.h

mosWindow:resize()

engine.start()
