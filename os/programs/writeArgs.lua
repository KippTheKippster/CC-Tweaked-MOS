local completion = require("cc.completion")
local args = {...}
local callbackFunction = args[1]
local startText = args[2]
local file = args[3]

local fnComplete = nil
local fileInfo = shell.getCompletionInfo()[file]
if fileInfo then
    fnComplete = fileInfo.fnComplete
end

local function tokenise(...)
    local sLine = table.concat({ ... }, " ")
    local tWords = {}
    local bQuoted = false
    for match in string.gmatch(sLine .. "\"", "(.-)\"") do
        if bQuoted then
            table.insert(tWords, match)
        else
            for m in string.gmatch(match, "[^ \t]+") do
                table.insert(tWords, m)
            end
        end
        bQuoted = not bQuoted
    end
    return tWords
end

local input = read(nil, nil, function (text)
    if fnComplete then
        local sLine =  file .. " " .. text
        local tWords = tokenise(sLine)
        local nIndex = #tWords
        if string.sub(sLine, #sLine, #sLine) == " " then
            nIndex = nIndex + 1
        end
        if nIndex > 1 then
            local sPath = file
            local sPart = tWords[nIndex] or ""
            local tPreviousParts = tWords
            tPreviousParts[nIndex] = nil
            --local cArgs = completeProgramArgument(fnComplete, sPath , nIndex - 1, sPart, tPreviousParts)
            local cArgs = fnComplete(shell, nIndex - 1, sPart, tPreviousParts)
            if cArgs == nil then
                return nil
            else
                return completion.choice("", cArgs)
            end
        end
        return nil
    else
        return nil
    end
end, startText)

if callbackFunction then
    callbackFunction(tokenise(input))
end

if mosWindow then
    mosWindow:close()
end