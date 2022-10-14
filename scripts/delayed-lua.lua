local DelayedLua = {} ---@class DelayedLua
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local LoggingUtils = require("utility.helper-utils.logging-utils")
local Constants = require("constants")
local MathUtils = require("utility.helper-utils.math-utils")

--[[
/sc
local testFunction = function(data) game.print(game.tick .. " - " .. data.name) end
local data = {name = "me"}
remote.call("muppet_streamer", "add_delayed_lua", 60, string.dump(testFunction), data)
]]

---@class DelayedLua_ScheduledEvent
---@field id uint
---@field functionString string
---@field functionData table|nil

DelayedLua.CreateGlobals = function()
    global.delayedLua = global.delayedLua or {} ---@class DelayedLua_Global
    global.delayedLua.nextId = global.delayedLua.nextId or 0 ---@type uint
end

DelayedLua.OnLoad = function()
    EventScheduler.RegisterScheduledEventType("DelayedLua.ActionDelayedLua", DelayedLua.ActionDelayedLua)
end

--- Called to add a delayed lua event.
---@param delay number
---@param functionString string
---@param functionData table|nil
DelayedLua.AddDelayedLua_Remote = function(delay, functionString, functionData)
    local messagePrefix = Constants.ModFriendlyName .. " - add_delayed_lua - "
    local errorMessagePrefix = messagePrefix .. "Error: "
    local currentTick = game.tick

    -- Check the delay provided.
    if delay == nil then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`delay` argument must be provided.")
        return
    elseif type(delay) ~= "number" then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`delay` argument must be a Lua number type, provided: " .. type(delay))
        return
    end
    delay = math.floor(delay)
    if delay < 0 then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`delay` argument must be 0 or greater, provided: " .. tostring(delay))
        return
    end ---@cast delay uint
    local scheduleTick ---@type UtilityScheduledEvent_UintNegative1
    if delay > 0 then
        local valueWasOutsideRange ---@type boolean
        scheduleTick, valueWasOutsideRange = MathUtils.ClampToUInt(currentTick + delay)
        if valueWasOutsideRange then
            LoggingUtils.LogPrintWarning(errorMessagePrefix .. "`delay` argument capped at max ticks, as excessively large number of delay seconds provided: " .. tostring(delay))
        end
        if scheduleTick == currentTick then
            scheduleTick = -1 ---@type UtilityScheduledEvent_UintNegative1
        end
    else
        scheduleTick = -1 ---@type UtilityScheduledEvent_UintNegative1
    end

    -- Check the function provided.
    if functionString == nil then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument must be provided.")
        return
    elseif type(functionString) ~= "string" then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument must be a Lua string type, provided: " .. type(functionString))
        return
    end
    -- Make sure the text string provided is actually a function and not something else.
    local func = load(functionString)
    if type(func) ~= "function" then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument must be a string dumped from a Lua function type, provided was a string dump of type: " .. type(func))
        return
    end

    -- Check the data if provided.
    if functionData ~= nil then
        if type(functionData) ~= "table" then
            LoggingUtils.LogPrintError(errorMessagePrefix .. "`data` argument must be a Lua table type when populated, provided: " .. type(functionData))
            return
        end
    end

    global.delayedLua.nextId = global.delayedLua.nextId + 1
    ---@type DelayedLua_ScheduledEvent
    local scheduledEvent = { id = global.delayedLua.nextId, functionString = functionString, functionData = functionData }
    EventScheduler.ScheduleEventOnce(scheduleTick, "DelayedLua.ActionDelayedLua", global.delayedLua.nextId, scheduledEvent)
end

--- Called when a scheduled delayed lua event occurs.
---@param event UtilityScheduledEvent_CallbackObject
DelayedLua.ActionDelayedLua = function(event)
    local scheduledEvent = event.data ---@type DelayedLua_ScheduledEvent
    local messagePrefix = Constants.ModFriendlyName .. " - Delayed Lua runtime code - "
    local errorMessagePrefix = messagePrefix .. "Error: "

    -- Make the LuaFunction and run it.
    local func = load(scheduledEvent.functionString) --[[@as function]]
    local errorMessage, fullErrorDetails = LoggingUtils.RunFunctionAndCatchErrors(func, scheduledEvent.functionData)

    -- Handle if the code errored.
    if errorMessage then
        -- Add our delayed function code
        fullErrorDetails = fullErrorDetails .. "\r\n\r\n" .. "Delayed Lua Code - raw LuaFunction as a string:" .. "\r\n" .. scheduledEvent.functionString

        local logFileName = Constants.ModName .. " - Delayed Lua runtime code error details - " .. tostring(event.instanceId .. ".log")
        game.write_file(logFileName, fullErrorDetails, false) -- Write file overwriting any same named file.

        LoggingUtils.LogPrintError(errorMessagePrefix .. "delayed lua code execution errored:     " .. tostring(errorMessage))
        LoggingUtils.LogPrintError(errorMessagePrefix .. "see log file in Factorio's `script-output` folder for full details:    " .. logFileName)

        return
    end
end



return DelayedLua
