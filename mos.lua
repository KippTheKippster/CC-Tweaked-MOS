local src = debug.getinfo(1, "S").source:sub(2)
if not src:find("/") then src = shell.getRunningProgram() end
shell.run(fs.combine(fs.getDir(src), "os/os.lua"))