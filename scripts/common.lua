local Common = {}
local MathUtils = require("utility.helperUtils.math-utils")
local LoggingUtils = require("utility.helperUtils.logging-utils")
local Constants = require("constants")

--- Takes a parsed delay setting value in seconds and returns the Scheduled Event tick value.
---@param delaySecondsRaw uint
---@param currentTick uint
---@param commandName string
---@param settingName string
---@return UtilityScheduledEvent_UintNegative1
Common.DelaySecondsSettingToScheduledEventTickValue = function(delaySecondsRaw, currentTick, commandName, settingName)
    local scheduleTick  ---@type UtilityScheduledEvent_UintNegative1
    if (delaySecondsRaw ~= nil and delaySecondsRaw > 0) then
        scheduleTick = currentTick + math.floor(delaySecondsRaw * 60) --[[@as uint]]
        local valueWasOutsideRange  ---@type boolean
        scheduleTick, valueWasOutsideRange = MathUtils.ClampToUInt(scheduleTick)
        if valueWasOutsideRange then
            LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " had " .. settingName .. " capped at max ticks, as excessively large number of delay seconds provided: " .. tostring(delaySecondsRaw))
        end
    else
        scheduleTick = -1 ---@type UtilityScheduledEvent_UintNegative1
    end
    return scheduleTick
end

return Common
