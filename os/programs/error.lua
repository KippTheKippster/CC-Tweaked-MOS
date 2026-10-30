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
main.paddingL = 1
main.paddingR = 1

for _, err in ipairs(args) do
    local c = main:addControl()
    c.text = tostring(err):match"^%s*(.-)%s*$"
end

main:updateTree()

mosWindow.minW = main:getPaddedW()
mosWindow.minH = main:getPaddedH()
mosWindow.w = mosWindow.minW
mosWindow.h = mosWindow.minH
mosWindow.oldW = mosWindow.w
mosWindow.oldH = mosWindow.h

mosWindow:resize()

engine.start()
