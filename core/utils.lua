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

local function saveTable(file, tbl, compact, allowRepetitions)
    if type(file) == "table" then
        error("WHAT",2)
    end
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

---comment
---@param w table
---@return table?
local function getWindowChar(w, x, y)
    local _, h = w.getSize()
    if y <= 0 or y > h then
        return nil
    end

    local text, textColor, backgroundColor = w.getLine(y)
    local textChar = text:sub(x, x)
    if textChar ~= "" then
        local textColorChar = textColor:sub(x,x)
        local backgroundColorChar = backgroundColor:sub(x,x)

        local char = { text = textChar, textColor = colors.black, backgroundColor = colors.fromBlit(backgroundColorChar) }
        if textChar ~= " " then
            char.textColor = colors.fromBlit(textColorChar)
        end

        return char
    end

    return nil
end

local function inArea(x, y, x1, y1, w, h)
    if (
        x <= x1 + w and
        x >= x1 and
        y <= y1 + h and
        y >= y1
    ) then
        return true
    else
        return false
    end
end

local function overlappingArea(x, y, w, h, x1, y1, w1, h1)
    if (
        x <= x1 + w1 and
        x + w >= x1 and
        y <= y1 + h1 and
        y + h >= y1
    ) then
        return true
    else
        return false
    end
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
    getWindowChar = getWindowChar,
    inArea = inArea,
    overlappingArea = overlappingArea
}

---@type Utils
return Utils