--[[
    All position concept related utils functions, including bounding boxes.
]]
--

local StringUtils = {}
local math_floor = math.floor
local string_match, string_find, string_sub, string_len, string_gsub = string.match, string.find, string.sub, string.len, string.gsub

--- Trims leading and trailing spaces off a text string.
---
--- trim6 from http://lua-users.org/wiki/StringTrim
---@param text string
---@return string trimmedString
StringUtils.StringTrim = function(text)
    return string_match(text, "^()%s*$") and "" or string_match(text, "^%s*(.*%S)")
end

--- Split a string on the specified characters in to a list of strings. The splitting characters aren't included in the output. The results are trimmed of blank spaces.
---@param text string
---@param splitCharacters string
---@return string[]
StringUtils.SplitStringOnCharactersToList = function(text, splitCharacters)
    local list = {} ---@type string[]
    local results = text:gmatch("[^" .. splitCharacters .. "]*")
    for phrase in results do
        -- Trim spaces from the phrase text. Code from StringUtils.StringTrim()
        phrase = string_match(phrase, "^()%s*$") and "" or string_match(phrase, "^%s*(.*%S)")

        if phrase ~= nil and phrase ~= "" then
            table.insert(list, phrase)
        end
    end
    return list
end

--- Split a string on the specified characters to a dictionary of the strings. The splitting characters aren't included in the output. The results are trimmed of blank spaces.
---@param text string
---@param splitCharacters string
---@return table<string, true>
StringUtils.SplitStringOnCharactersToDictionary = function(text, splitCharacters)
    local list = {} ---@type table<string, true>
    local results = text:gmatch("[^" .. splitCharacters .. "]*")
    for phrase in results do
        -- Trim spaces from the phrase text. Code from StringUtils.StringTrim()
        phrase = string_match(phrase, "^()%s*$") and "" or string_match(phrase, "^%s*(.*%S)")

        if phrase ~= nil and phrase ~= "" then
            list[phrase] = true
        end
    end
    return list
end

--- Makes a string of a position.
---@param position MapPosition
---@return string
StringUtils.FormatPositionToString = function(position)
    return position.x .. "," .. position.y
end

---@class SurfacePositionString : string @ A surface and position as a string: "surfaceId_x,y"

--- Makes a string of the surface Id and position to allow easy table lookup.
---@param surfaceId uint
---@param positionTable MapPosition
---@return SurfacePositionString
StringUtils.FormatSurfacePositionToString = function(surfaceId, positionTable)
    return surfaceId .. "_" .. positionTable.x .. "," .. positionTable.y --[[@as SurfacePositionString]]
end

--- Backwards converts a SurfacePositionString to usable data. This is ineffecient and should only be used for debugging.
---@param surfacePositionString SurfacePositionString
---@return uint surfaceIndex
---@return MapPosition position
StringUtils.SurfacePositionStringToSurfaceAndPosition = function(surfacePositionString)
    local underscoreIndex = string_find(surfacePositionString, "_")
    local surfaceId = tonumber(string_sub(surfacePositionString, 1, underscoreIndex - 1)) --[[@as uint]] -- It went in from a uint, so must come out as one.
    local commaIndex = string_find(surfacePositionString, ",")
    local positionX = tonumber(string_sub(surfacePositionString, underscoreIndex + 1, commaIndex - 1))
    local positionY = tonumber(string_sub(surfacePositionString, commaIndex + 1, string_len(surfacePositionString)))
    return surfaceId, {x = positionX, y = positionY}
end

--- Pad a number with leading 0's up to the required length and return as a string.
---@param number double
---@param requiredLength uint
---@return string paddedNumber
StringUtils.PadNumberToMinimumDigits = function(number, requiredLength)
    local numberString = tostring(number)
    local shortBy = requiredLength - string_len(numberString)
    for i = 1, shortBy do
        numberString = "0" .. numberString
    end
    return numberString
end

--- Adds commas to a number and returns it as a string.
---@param number double
---@return string
StringUtils.DisplayNumberPretty = function(number)
    if number == nil then
        return ""
    end
    local formatted = tostring(number)
    local k
    while true do
        formatted, k = string_gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
        if (k == 0) then
            break
        end
    end
    return formatted
end

--- Display time in a string broken down to hour, minute and second. With the range of time units configurable.
---@param inputTicks int
---@param displayLargestTimeUnit 'auto'|'hour'|'minute'|'second'
---@param displaySmallestTimeUnit 'auto'|'hour'|'minute'|'second'
StringUtils.DisplayTimeOfTicks = function(inputTicks, displayLargestTimeUnit, displaySmallestTimeUnit)
    if inputTicks == nil then
        return ""
    end
    local negativeSign = ""
    if inputTicks < 0 then
        negativeSign = "-"
        inputTicks = -inputTicks
    end
    local hours = math_floor(inputTicks / 216000)
    local displayHours = StringUtils.PadNumberToMinimumDigits(hours, 2)
    inputTicks = inputTicks - (hours * 216000)
    local minutes = math_floor(inputTicks / 3600)
    local displayMinutes = StringUtils.PadNumberToMinimumDigits(minutes, 2)
    inputTicks = inputTicks - (minutes * 3600)
    local seconds = math_floor(inputTicks / 60)
    local displaySeconds = StringUtils.PadNumberToMinimumDigits(seconds, 2)

    if displayLargestTimeUnit == "auto" then
        if hours > 0 then
            displayLargestTimeUnit = "hour"
        elseif minutes > 0 then
            displayLargestTimeUnit = "minute"
        else
            displayLargestTimeUnit = "second"
        end
    end
    if not (displayLargestTimeUnit == "hour" or displayLargestTimeUnit == "minute" or displayLargestTimeUnit == "second") then
        error("unrecognised displayLargestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end
    if displaySmallestTimeUnit == nil or displaySmallestTimeUnit == "" or displaySmallestTimeUnit == "auto" then
        displaySmallestTimeUnit = "second"
    end
    if not (displaySmallestTimeUnit == "hour" or displaySmallestTimeUnit == "minute" or displaySmallestTimeUnit == "second") then
        error("unrecognised displaySmallestTimeUnit argument in Utils.MakeLocalisedStringDisplayOfTime")
    end

    local timeUnitIndex = {second = 1, minute = 2, hour = 3}
    local displayLargestTimeUnitIndex = timeUnitIndex[displayLargestTimeUnit]
    local displaySmallestTimeUnitIndex = timeUnitIndex[displaySmallestTimeUnit]
    local timeUnitRange = displayLargestTimeUnitIndex - displaySmallestTimeUnitIndex

    if timeUnitRange == 2 then
        return (negativeSign .. displayHours .. ":" .. displayMinutes .. ":" .. displaySeconds)
    elseif timeUnitRange == 1 then
        if displayLargestTimeUnit == "hour" then
            return (negativeSign .. displayHours .. ":" .. displayMinutes)
        else
            return (negativeSign .. displayMinutes .. ":" .. displaySeconds)
        end
    elseif timeUnitRange == 0 then
        if displayLargestTimeUnit == "hour" then
            return (negativeSign .. displayHours)
        elseif displayLargestTimeUnit == "minute" then
            return (negativeSign .. displayMinutes)
        else
            return (negativeSign .. displaySeconds)
        end
    else
        error("time unit range is negative in Utils.MakeLocalisedStringDisplayOfTime")
    end
end

--- Seperates out the number and unit from when they combined in a single string, i.e. 5Kwh
---@param text string
---@return double number
---@return string unit
StringUtils.GetValueAndUnitFromString = function(text)
    return string_match(text, "%d+%.?%d*"), string_match(text, "%a+")
end

return StringUtils
