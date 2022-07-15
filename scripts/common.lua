local Common = {}
local MathUtils = require("utility.helper-utils.math-utils")
local LoggingUtils = require("utility.helper-utils.logging-utils")
local Constants = require("constants")
local CommandsUtils = require("utility.helper-utils.commands-utils")

--- Takes a delay value in seconds and returns the Scheduled Event tick value.
---@param delaySeconds double|nil
---@param currentTick uint
---@param commandName string
---@param settingName string
---@return UtilityScheduledEvent_UintNegative1
Common.DelaySecondsSettingToScheduledEventTickValue = function(delaySeconds, currentTick, commandName, settingName)
    local scheduleTick  ---@type UtilityScheduledEvent_UintNegative1
    if (delaySeconds ~= nil and delaySeconds > 0) then
        scheduleTick = currentTick + math.floor(delaySeconds * 60) --[[@as uint]]
        local valueWasOutsideRange  ---@type boolean
        scheduleTick, valueWasOutsideRange = MathUtils.ClampToUInt(scheduleTick)
        if valueWasOutsideRange then
            LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " - " .. settingName .. " capped at max ticks, as excessively large number of delay seconds provided: " .. tostring(delaySeconds))
        end
    else
        scheduleTick = -1 ---@type UtilityScheduledEvent_UintNegative1
    end
    return scheduleTick
end

--- A bespoke check for a player's name setting. Includes the setting as mandatory and that there's a player with this name.
---@param playerName string
---@param commandName string
---@param settingName string
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
---@return boolean isValid
Common.CheckPlayerNameSettingValue = function(playerName, commandName, settingName, commandString)
    -- Check its a valid populated string first, then that it's a player's name.
    if not CommandsUtils.ParseStringArgument(playerName, true, commandName, settingName, nil, commandString) then
        return false
    elseif game.get_player(playerName) == nil then
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " - " .. settingName .. " is invalid player name")
        if commandString ~= nil then
            LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
        end
        return false
    end
    return true
end

return Common
