local function contains(t, v)
    for _, x in ipairs(t) do
        if v == x then
            return true
        end
    end
    return false
end

---Returns index of value in table or nil
---@param t table
---@param v any
---@return integer?
local function find(t, v)
    for i, o in ipairs(t) do
		if o == v then
			return i
		end
	end
    return nil
end

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function push(table, object, dir)
	for i = 1, #table do
		if table[i] == object then
			if i + dir < 1 or i + dir > #table then return i end
			local o1 = table[i + dir]
			table[i] = o1
			table[i + dir] = object
			return i + dir
		end
	end

	return nil
end

local function pushUp(table, object)
	return push(table, object, -1)
end

local function pushDown(table, object)
	return push(table, object, 1)
end

local function pushTop(table, object)
	repeat until pushUp(table, object) == 1
end

local function pushBottom(table, object)
	repeat until pushDown(table, object) == #table
end

local function saveTable(tbl, file, compact, allowRepetitions)
    compact = compact or false
    allowRepetitions = allowRepetitions or true
    local f = fs.open(file, "w")
    if f == nil then return false end
    local data = textutils.serialize(tbl, {compact = compact, allow_repetitions  = allowRepetitions })
    f.write(data)
    f.close()
    return true
end

local function loadTable(file)
    local f = fs.open(file, "r")
    if f == nil then return nil end
    local data = f.readAll()
    f.close()
    return textutils.unserialize(data)
end



---@class Utils
local Utils = {
	contains = contains,
    find = find,
	split = split,
	pushUp = pushUp,
	pushDown = pushDown,
	pushTop = pushTop,
	pushBottom = pushBottom,
	saveTable = saveTable,
	loadTable = loadTable,
}

---@type Utils
return Utils