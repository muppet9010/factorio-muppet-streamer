local Common = {}
local MathUtils = require("utility.math-utils")
local Logging = require("utility.logging")
local Constants = require("constants")

--- Caps the Delay seconds setting in ticks and if it was too great shows warning error.
---@param tickCount Tick
---@param delaySeconds Second
---@param commandName string
---@param settingName string
---@return Tick cappedTickCount
Common.CapComamndsDelaySetting = function(tickCount, delaySeconds, commandName, settingName)
    if tickCount > MathUtils.UintMax then
        tickCount = MathUtils.UintMax
        Logging.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " had " .. settingName .. " capped at max ticks, as excessively large number of delay seconds provided: " .. tostring(delaySeconds))
    end

    return tickCount
end

return Common
