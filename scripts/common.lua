local Common = {}
local MathUtils = require("utility.math-utils")
local Logging = require("utility.logging")
local Constants = require("constants")

--- Caps the Delay seconds setting in ticks and if it was too great shows warning error.
---@param tickCount uint
---@param rawDelaySeconds number
---@param commandName string
---@param settingName string
---@return uint cappedTickCount
Common.CapComamndsDelaySetting = function(tickCount, rawDelaySeconds, commandName, settingName)
    if tickCount > MathUtils.UintMax then
        tickCount = MathUtils.UintMax
        Logging.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " had " .. settingName .. " capped at max ticks, as excessively large number of delay seconds provided: " .. tostring(rawDelaySeconds))
    end

    return tickCount
end

return Common
