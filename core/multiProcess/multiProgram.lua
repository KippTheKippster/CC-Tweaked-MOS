local corePath = fs.getDir(fs.getDir(debug.getinfo(1, "S").source:sub(2)))

-- Handles coroutines of multiple programs
---@class MultiProgram
local mp = {}
local tProcesses = {}
local endQueue = {}
local sleepQueue = {}

---comment
---@param p Process
---@param data table
---@return table
function mp.resumeProcess(p, data)
    term.redirect(p.window)
    local status = table.pack(coroutine.resume(p.co, table.unpack(data)))
    term.redirect(p.parentTerm)
    return status
end

---comment
---@param parentTerm table
---@param process function
---@param resume function?
---@param x number
---@param y number
---@param w number
---@param h number
---@param ... ...
---@return Process
function mp.launchProcess(parentTerm, process, resume, x, y, w, h, ...)
    local current = term.current()
    ---@class Process
    local p = {}
    local args = table.pack(...)
    ---@type table
    p.window = window.create(parentTerm, x, y, w, h, false)
    p.parentTerm = parentTerm
    p.co = coroutine.create(function()
        term.redirect(p.window)
        process(p, table.unpack(args))
        term.redirect(parentTerm)
    end)
    p.resume = resume or function(data)
        return mp.resumeProcess(p, data)
    end
    p.dead = false
    table.insert(tProcesses, p)
    term.redirect(current)
    return p
end

---comment
---@param env table
---@param programPath string
---@return function?, string?
function mp.loadProgram(env, programPath)
    setmetatable(env, { __index = _G })

    if settings.get("bios.strict_globals", false) then
        -- load will attempt to set _ENV on this environment, which
        -- throws an error with this protection enabled. Thus we set it here first.
        env._ENV = env
        getmetatable(env).__newindex = function(_, name)
            error("Attempt to create global " .. tostring(name), 2)
        end
    end

    return loadfile(programPath, nil, env)
end


---comment
---@param extraEnv table?
---@return table
function mp.createEnv(extraEnv)
    local env = { shell = shell, multishell = multishell, __mp = mp }
    env.require, env.package = dofile("/rom/modules/main/cc/require.lua").make(env, "")

    extraEnv = extraEnv or {}
    for k, v in pairs(extraEnv) do
        env[k] = v
    end

    return env
end


local function runMultishellWrapper(p, env, ...)
    local args = table.pack(...)
    _G.__wrapper = {
        env = env,
        args = args,
        mp = mp,
        p = p,
        _G = _G
    }

    local fn = mp.loadProgram(env, "/rom/programs/advanced/multishell.lua")
    if fn then
        local ok, err = fn()
        if ok == false then
            error(err)
        end
    end
end

---comment
---@param parentTerm table
---@param programPath string
---@param extraEnv table
---@param resume function
---@param x number
---@param y number
---@param w number
---@param h number
---@param ... any
---@return Process
function mp.launchProgram(parentTerm, programPath, extraEnv, resume, x, y, w, h, ...)
    local env = mp.createEnv(extraEnv)
    local p = mp.launchProcess(parentTerm, function(p, ...)
        runMultishellWrapper(p, env, programPath, ...) -- TODO Read and fix error messages
        os.run(env, programPath, ...)
        mp.runProgram(env, programPath, ...)
  
        --[[
        local fn, err = mp.loadProgram(env, programPath)
        if fn == nil then
            error(err)
        end
        local ok, err = fn(...)
        if ok == false then
            error(err)
        end
        ]]--
    end, resume, x, y, w, h, ...)

    coroutine.resume(p.co, "start")
    coroutine.resume(p.co, "paste", corePath .. "/multiProcess/multishellWrapper.lua")
    coroutine.resume(p.co, "key", keys.enter)

    return p
end


---comment
---@param p Process
---@param err string
function mp.forceError(p, err)
    local c = term.current()
    term.redirect(p.window)
    debug.sethook(p.co, function() error(err) end, "l")
    mp.resumeProcess(p, { "force_error" })
    term.redirect(c)
end

---comment
---@param p Process
---@param data table
function mp.queueExclusiveEvent(p, data)

end

---Starts a timer that will only be sent to the p Process paramater, returns timer id
---@param p Process
---@param time number
---@return integer
function mp.startTimer(p, time)
    local id = os.startTimer(time)
    sleepQueue[id] = p
    return id
end

---comment
---@param p Process
function mp.endProcess(p)
    p.dead = true
    table.insert(endQueue, p)
end

local running = true
function mp.exit()
    running = false
end

---comment
---@return table
local function process()
    local data = table.pack(os.pullEventRaw())
    if data[1] == "timer" then
        ---@type Process
        local p = sleepQueue[data[2]]
        if p then
            return p.resume(data)
        end
    end

    local n = #tProcesses
    for i = 1, n do
        ---@type Process
        local p = tProcesses[i]
        if p.dead == false then
            local status = p.resume(data)
            if status[1] == false then
                return status
            end
        end
    end

    return { true }
end

local function find(t, v)
    for i, o in ipairs(t) do
		if o == v then
			return i
		end
	end
    return nil
end

---comment
---@return string?
function mp.start()
    term.clear()
    running = true
    local parentTerm = term.current()
    while running and #tProcesses > 0 do
        local ok, err, errP = table.unpack(process())
        if ok == false then
            return err
        end

        for _, p in ipairs(endQueue) do
            local i = find(tProcesses, p)
            if i == nil then
                error("Trying to remove non existent process!", 2)
            end
            p.window.setVisible(false)
            debug.sethook(p.co, function() error("killed") end, "l")
            table.remove(tProcesses, i)
        end

        endQueue = {}
    end
    return nil
end

return mp
