--[[
    All maths related utils functions.
]]
--

local MathUtils = {}
local math_min, math_max, math_floor, math_random, math_exp = math.min, math.max, math.floor, math.random, math.exp

MathUtils.LogisticEquation = function(index, height, steepness)
    return height / (1 + math_exp(steepness * (index - 0)))
end

MathUtils.ExponentialDecayEquation = function(index, multiplier, scale)
    return multiplier * math_exp(-index * scale)
end

MathUtils.RoundNumberToDecimalPlaces = function(num, numDecimalPlaces)
    local result
    if numDecimalPlaces ~= nil and numDecimalPlaces > 0 then
        local mult = 10 ^ numDecimalPlaces
        result = math_floor(num * mult + 0.5) / mult
    else
        result = math_floor(num + 0.5)
    end
    if result ~= result then
        -- Result is NaN so set it to 0.
        result = 0
    end
    return result
end

--- Checks if the provided number is a NaN value.
---
--- Should be done locally if called frequently.
---@param value number
---@return boolean valueIsANan
MathUtils.IsNumberNan = function(value)
    if value ~= value then
        return true
    else
        return false
    end
end

--- This steps through the ints with min and max being seperatee steps.
---@param value int
---@param min int
---@param max int
---@return int
MathUtils.LoopIntValueWithinRange = function(value, min, max)
    if value > max then
        return min - (max - value) - 1
    elseif value < min then
        return max + (value - min) + 1
    else
        return value
    end
end

--- This treats the min and max values as equal when looping: max - 0.1, max/min, min + 0.1. Depending on starting input value you get either the min or max value at the border.
---@param value number
---@param min number
---@param max number
---@return number
MathUtils.LoopFloatValueWithinRange = function(value, min, max)
    if value > max then
        return min + (value - max)
    elseif value < min then
        return max - (value - min)
    else
        return value
    end
end

--- This treats the min and max values as equal when looping: max - 0.1, max/min, min + 0.1. But maxExclusive will give the minInclusive value. So maxExclsuive can never be returned.
---
--- Should be done locally if called frequently.
---@param value number
---@param minInclusive number
---@param maxExclusive number
---@return number
MathUtils.LoopFloatValueWithinRangeMaxExclusive = function(value, minInclusive, maxExclusive)
    if value >= maxExclusive then
        return minInclusive + (value - maxExclusive)
    elseif value < minInclusive then
        return maxExclusive - (value - minInclusive)
    else
        return value
    end
end

--- Return the passed in number clamped to within the max and min limits inclusively.
---@param value number
---@param min number
---@param max number
---@return number
MathUtils.ClampNumber = function(value, min, max)
    return math_min(math_max(value, min), max)
end

-- This doesn't guarentee correct on some of the edge cases, but is as close as possible assuming that 1/256 is the variance for the same number (Bilka, Dev on Discord)
MathUtils.FuzzyCompareDoubles = function(num1, logic, num2)
    local numDif = num1 - num2
    local variance = 1 / 256
    if logic == "=" then
        if numDif < variance and numDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "!=" then
        if numDif < variance and numDif > -variance then
            return false
        else
            return true
        end
    elseif logic == ">" then
        if numDif > variance then
            return true
        else
            return false
        end
    elseif logic == ">=" then
        if numDif > -variance then
            return true
        else
            return false
        end
    elseif logic == "<" then
        if numDif < -variance then
            return true
        else
            return false
        end
    elseif logic == "<=" then
        if numDif < variance then
            return true
        else
            return false
        end
    end
end

MathUtils.GetRandomFloatInRange = function(lower, upper)
    return lower + math_random() * (upper - lower)
end

return MathUtils
