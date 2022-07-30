--[[
    Handles selecting a random item from a list of imperfect selection chances.
]]
--

local RandomChance = {} ---@class Utility_RandomChance
local math_floor, math_random = math.floor, math.random

--- Takes a number and returns an int of the value with any partial int value being converted to a chance of +1 included in the returned result.
---
--- i.e. 5.3 as input will return 5 30% of the time and 6 the other 70% of the time.
---@param value double
---@return int
RandomChance.HandleFloatNumberAsChancedValue = function(value)
    local intValue = math_floor(value)
    local partialValue = value - intValue
    local chancedValue = intValue
    if partialValue ~= 0 then
        local rand = math_random()
        if rand >= partialValue then
            chancedValue = chancedValue + 1
        end
    end
    return chancedValue
end

--- Updates the 'chancePropertyName' named attribute of each entry in the referenced `dataSet` table to be proportional of a combined dataSet value of 1.
---
--- The dataset is a table of entries. Each entry has various keys that are used in the calling scope and ignored by this function. It also has a key of the name passed in as the chancePropertyName parameter that defines the chance of this result.
---@param dataSet table[] # The dataSet to be reviewed and updated.
---@param chancePropertyName string # The attribute name that has the chance value per dataSet entry.
---@param skipFillingEmptyChance? boolean # Defaults to FALSE. If TRUE then total chance below 1 will not be scaled up, so that nil results can be had in random selection.
---@return table[] # Same object passed in by reference as dataSet, so technically no return is needed, legacy.
RandomChance.NormaliseChanceList = function(dataSet, chancePropertyName, skipFillingEmptyChance)
    local totalChance = 0
    for _, v in pairs(dataSet) do
        totalChance = totalChance + v[chancePropertyName]
    end
    local multiplier = 1
    if not skipFillingEmptyChance or (skipFillingEmptyChance and totalChance > 1) then
        multiplier = 1 / totalChance
    end
    for _, v in pairs(dataSet) do
        ---@cast v table<string, number> # This isn't strictly true, but must be for the chancePropertyName field.
        v[chancePropertyName] = v[chancePropertyName] * multiplier
    end
    return dataSet
end

--- Looks over a table of chanced events and selects one randomly based on a named chance key's value. Requires the table to be normalised to a total chance of no greater than 1. A total of less than 1 chance can result in no event being selected.
---@param dataSet table[]
---@param chancePropertyName string
---@return any|nil
RandomChance.GetRandomEntryFromNormalisedDataSet = function(dataSet, chancePropertyName)
    local random = math_random()
    local chanceRangeLow = 0
    local chanceRangeHigh
    for _, v in pairs(dataSet) do
        chanceRangeHigh = chanceRangeLow + v[chancePropertyName]
        if random >= chanceRangeLow and random <= chanceRangeHigh then
            return v
        end
        chanceRangeLow = chanceRangeHigh
    end
    return nil
end

return RandomChance
