---@type MOS
local mos = __mos
---@type ProgramWindow
local mosWindow = __mosWindow
if mos == nil then
    printError("DiskInfo must be opened with MOS!")
    return
end

---@type Engine
local engine = require(mos.mosDotPath .. ".core.engine")
mos.applyTheme(engine)

local args = {...}
local diskName = args[1] or ""

if not disk.isPresent(diskName) then
    error("Disk '" .. diskName .. "' is not present", 0)
end

local main = engine.root:addVContainer()
main.rendering = true
main.fitToChildrenW = true
main.fitToChildrenH = true
main.anchorW = main.Anchor.CENTER
main.anchorH = main.Anchor.CENTER

local Line = engine.Control:newClass()
Line._h = 1

local w = 0
local h = 1

local function newLine(text)
    local l = Line:new()
    l.text = text
    main:add(l)
    w = math.max(w, #text)
    h = h + 1
    return l
end

if disk.hasAudio(diskName) then
    newLine(" Title - " .. disk.getAudioTitle(diskName))
    newLine("  Type - Audio")
    newLine("  Port - " .. diskName)
else
    newLine(" Label - " .. disk.getLabel(diskName) .. "\n")
    newLine("  Type - Data")
    local path = disk.getMountPath(diskName)
    newLine("  Free - " .. math.ceil(fs.getFreeSpace(path) / 1000) .. "/" .. math.ceil(fs.getCapacity(path) / 1000) .. "kB")
    newLine(" Mount - " .. disk.getMountPath(diskName))
    newLine("  Port - " .. diskName)
    newLine("    ID - " .. disk.getID(diskName))
end

mosWindow.minW = w - 1
mosWindow.minH = h
mosWindow.w = w + 1
mosWindow.h = h + 2

engine.start()
