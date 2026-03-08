---@class Object
local Object = {}
Object.__name = "object"
Object.__type = "Object"
setmetatable(Object, { connections = {}, properties = {}, class = true })


--Get key from object
local function object__index(o, key)
    local mt = getmetatable(o)
    local properties = rawget(mt, "properties")
    local property = properties[key]
    if property then
        if property.get == nil then
            error("Attempting to read property with missing get function: " .. key .. " " .. tostring(o))
        end

        if rawget(mt, "class") == true then
            error("Attempting to get property value of class", 2)
        end

        return property.get(o)
    end

    if rawget(o, key) ~= nil then
        return rawget(o, key)
    end

    while mt ~= nil do
        local raw = rawget(mt, "__base")[key]
        if raw ~= nil then
            return raw
        end
        mt = getmetatable(mt)
    end

    return nil
end

--Set key from object
local function object__newindex(o, key, value)
    local mt = getmetatable(o)
    local properties = rawget(mt, "properties")
    local property = properties[key]
    if property then
        if property.set == nil then
            error(
            "Attempting to assign read-only property: " ..
            key .. " " .. tostring(o) .. " with value " .. tostring(value) .. ".", 2)
        end
        if rawget(mt, "class") == true then
            error("Attempting to set property value of class", 2)
        end

        property.set(o, value)
        return
    end

    rawset(o, key, value)
end

local function properties__index(o, key)
    local mt = getmetatable(o)
    local base = rawget(mt, "__base")
    return base[key]
end

local function properties__newindex(o, key, value)
    rawset(o, key, value)
end

local function free__index(o, key)
    if key == "isValid" then
        return function()
            return false
        end
    elseif key == "__type" then
        return rawget(o, "__type")
    elseif key == "__name" then
        return rawget(o, "__name")
    end

    error("\nAttempting to access value from the previously freed object: " .. tostring(o), 2)
end

local function free__newindex(o, key, value)
    error("Attempting to assign value to the previously freed object: " .. tostring(o), 2)
end

local function new(base)
    local o = {}
    local mt = {
        __base = base,
        __index = object__index,
        __newindex = object__newindex,
    }

    setmetatable(o, mt)
    return o, mt
end

--Creates a new object, copying properties and signals to the new object
---@return table
function Object:new(...)
    local sMt = getmetatable(self)
    if not sMt.class then
        error("Attempting to instance a non class object!", 2)
    end

    local o, mt = new(self)
    local properties = {}
    local pMt = {
        __base = getmetatable(self).properties,
        __index = properties__index,
        __newindex = properties__newindex,
    }

    setmetatable(properties, pMt)
    mt.properties = properties
    mt.connections = {}

    o:init(...)
    return o
end

function Object:newClass()
    local sMt = getmetatable(self) 
    if not sMt.class then
        error("Attempting to create class from instance!", 1)
    end

    local o, mt = new(self)
    local properties = {}
    for k, v in pairs(sMt.properties) do
        properties[k] = v
    end
    --rawset(o, "properties", properties)
    mt.properties = properties
    mt.class = true
    return o
end

function Object:init(...) end

function Object:isValid()
    return true
end

function Object:free()
    local mt = getmetatable(self)
    for k, v in pairs(mt.connections) do
        self:disconnectSignal(k, v.method)
    end

    local __type = self.__type
    local __name = self.__name
    for k in pairs(self) do
        self[k] = nil
    end
    self.__type = __type
    self.__name = __name

    local fMt = {
        __index = free__index,
        __newindex = free__newindex
    }

    setmetatable(self, fMt)
end

---Defines a new get set property
---@param key string
---@param methods table
---@param redefine boolean?
function Object:defineProperty(key, methods, redefine)
    if key == nil then
        error("Attemting to define property with key nil " .. tostring(self), 2)
    end

    local mt = getmetatable(self)
    local properties = rawget(mt, "properties")
    if properties[key] and redefine ~= true then
        error(
        "Attempting to define an already defined property: " ..
        key .. " " .. tostring(self) .. " . " .. tostring(redefine), 2)
    end


    properties[key] = methods
end

---@return Signal
function Object:createSignal()
    ---@class Signal
    local signal = {}
    return signal
end

---@param signal Signal
---@param method function
---@param ... any
function Object:connectSignal(signal, method, ...)
    local mt = getmetatable(self)
    if mt.connections[signal] == nil then
        mt.connections[signal] = {}
    end
    local connection = {
        method = method,
        binds = table.pack(...)
    }
    table.insert(mt.connections[signal], connection)
end

---@param signal Signal
---@param method function
function Object:disconnectSignal(signal, method)
    local mt = getmetatable(self)
    local connections = mt.connections[signal]
    if mt.connections[signal] == nil then
        return
    end

    for i = 1, #connections do
        local connection = connections[i]
        if connection.method == method then
            mt.connections[signal][i] = nil
            return
        end
    end
end

---@param signal Signal
---@param ... any
function Object:emitSignal(signal, ...)
    local mt = getmetatable(self)
    local connections = mt.connections[signal]
    if connections ~= nil then
        for i = 1, #connections do
            local connection = connections[i]
            local args = {}
            for j = 1, #connection.binds do
                table.insert(args, connection.binds[j])
            end
            local a = table.pack(...)
            for j = 1, #a do
                table.insert(args, a[j])
            end
            connections[i].method(table.unpack(args))
        end
    end
end

---@return Object
return Object
