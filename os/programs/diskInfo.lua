if mos == nil then
    error("DiskInfo must be opened with MOS", 0)
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
main.expandW = true
main.expandH = true
main.anchorW = "center"

local w = 0
local h = 1

local function newLine(text)
    local l = main:addControl(text)
    w = math.max(w, #text)
    h = h + 1
    l:resize()
end

if disk.hasAudio(diskName) then
    newLine(" Title - " .. disk.getAudioTitle(diskName))
    newLine("  Type - Audio")
    newLine("  Port - " .. diskName)
else
    newLine(" Label - " .. (disk.getLabel(diskName) or "") .. "\n")
    newLine("  Type - Data")
    local path = disk.getMountPath(diskName)
    newLine("  Free - " .. math.ceil(fs.getFreeSpace(path) / 1000) .. "/" .. math.ceil(fs.getCapacity(path) / 1000) .. "kB")
    newLine(" Mount - " .. disk.getMountPath(diskName))
    newLine("  Port - " .. diskName)
    newLine("    ID - " .. disk.getID(diskName))
end

main:queueSort()
main:queueDraw()

mosWindow.w = w + 1
mosWindow.h = h
mosWindow.oldW = mosWindow.w
mosWindow.oldH = mosWindow.h

engine.start()
