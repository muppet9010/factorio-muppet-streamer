local DelayedLua = {} ---@class DelayedLua
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local LoggingUtils = require("utility.helper-utils.logging-utils")
local Constants = require("constants")
local MathUtils = require("utility.helper-utils.math-utils")

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

--- Called to add a delayed Lua event.
---@param delay number
---@param functionString string
---@param functionData table|nil
---@return uint|nil scheduleId
DelayedLua.AddDelayedLua_Remote = function(delay, functionString, functionData)
    local messagePrefix = Constants.ModFriendlyName .. " - add_delayed_lua - "
    local errorMessagePrefix = messagePrefix .. "Error: "
    local currentTick = game.tick

    -- Check the delay provided.
    if delay == nil then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`delay` argument must be provided.")
        return nil
    elseif type(delay) ~= "number" then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`delay` argument must be a Lua number type, provided: " .. type(delay))
        return nil
    end
    delay = math.floor(delay)
    if delay < 0 then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`delay` argument must be 0 or greater, provided: " .. tostring(delay))
        return nil
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

    -- Check the function string provided.
    if functionString == nil then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument must be provided.")
        return nil
    elseif type(functionString) ~= "string" then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument must be a Lua string type, provided: " .. type(functionString))
        return nil
    end

    -- Make sure the text string provided is suitable for running.
    local delayedFunction = DelayedLua.GetFunctionFromFunctionStringSafely(functionString, errorMessagePrefix)
    if delayedFunction == nil then return nil end

    -- Check the data if provided.
    if functionData ~= nil then
        if type(functionData) ~= "table" then
            LoggingUtils.LogPrintError(errorMessagePrefix .. "`data` argument must be a Lua table type when populated, provided: " .. type(functionData))
            return nil
        end
    end

    global.delayedLua.nextId = global.delayedLua.nextId + 1
    ---@type DelayedLua_ScheduledEvent
    local scheduledEvent = { id = global.delayedLua.nextId, functionString = functionString, functionData = functionData }
    if scheduleTick ~= -1 then
        EventScheduler.ScheduleEventOnce(scheduleTick, "DelayedLua.ActionDelayedLua", global.delayedLua.nextId, scheduledEvent)
    else
        ---@type UtilityScheduledEvent_CallbackObject
        local eventData = { tick = currentTick, name = "DelayedLua.ActionDelayedLua", instanceId = global.delayedLua.nextId, data = scheduledEvent }
        DelayedLua.ActionDelayedLua(eventData)
    end

    return global.delayedLua.nextId
end

--- Gets a Lua function from the functionString argument in a safe manner, handling any errors in the process.
---@param functionString string
---@param errorMessagePrefix string
---@return function|nil functionForDelayedExecution
DelayedLua.GetFunctionFromFunctionStringSafely = function(functionString, errorMessagePrefix)
    -- Make sure the provided string isn't bytecode.
    if string.find(functionString, "^\27LuaR\0\1\4\8\4\8\0\25") ~= nil then
        -- Has a Lua header, so is bytecode.
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument must be the code of a Lua function in string form, provided was bytecode from `string.dump()`.")
        return nil
    end

    -- Make sure the provided string is for a function and not just a random Lua code snippet. They both look the same after going through `load`.
    if string.find(functionString, "^%s*function%(") == nil then
        -- Is a non function, so just a bit of Lua code
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument must be the code of a Lua function in string form. This wasn't in the form `function() game.print(\"blah\") end`")
        return nil
    end

    -- Make sure the text string provided is actually a function and not something else.
    local funcContainer, funcStringLoadError = load("return " .. functionString)
    if funcStringLoadError ~= nil or funcContainer == nil then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`functionString` argument errored when converting to Lua code with error: " .. (funcStringLoadError or "[BLANK ERROR MESSAGE]"))
        return nil
    end

    -- Have to get the real inner function from the container object that load makes.
    local delayedFunction = funcContainer() --[[@as function]]
    return delayedFunction
end

--- Called when a scheduled delayed lua event occurs.
---@param event UtilityScheduledEvent_CallbackObject
DelayedLua.ActionDelayedLua = function(event)
    local scheduledEvent = event.data ---@type DelayedLua_ScheduledEvent
    local messagePrefix = Constants.ModFriendlyName .. " - Delayed Lua runtime code - "
    local errorMessagePrefix = messagePrefix .. "Error: "

    -- Make the LuaFunction and run it.
    local delayedFunction = DelayedLua.GetFunctionFromFunctionStringSafely(scheduledEvent.functionString, errorMessagePrefix)
    if delayedFunction == nil then return end
    local errorMessage, fullErrorDetails = LoggingUtils.RunFunctionAndCatchErrors(delayedFunction, scheduledEvent.functionData)

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

--- Called to remove a scheduled Lua event. Reports if the removal was successful.
---@param scheduleId uint
---@return boolean removedSuccessfully
DelayedLua.RemoveDelayedLua_Remote = function(scheduleId)
    local messagePrefix = Constants.ModFriendlyName .. " - remove_delayed_lua - "
    local errorMessagePrefix = messagePrefix .. "Error: "

    -- Check the scheduleId provided is valid.
    if not DelayedLua.CheckScheduledId(scheduleId, errorMessagePrefix) then
        return false
    end

    -- Remove the scheduled Id's event.
    if EventScheduler.IsEventScheduledOnce("DelayedLua.ActionDelayedLua", scheduleId) then
        EventScheduler.RemoveScheduledOnceEvents("DelayedLua.ActionDelayedLua", scheduleId)
        return true
    else
        return false
    end
end

--- Gets the data for a scheduled delayed Lua instance.
---@param scheduleId uint
---@return table|nil data
DelayedLua.GetDelayedLuaData_Remote = function(scheduleId)
    local messagePrefix = Constants.ModFriendlyName .. " - get_delayed_lua_data - "
    local errorMessagePrefix, warningMessagePrefix = messagePrefix .. "Error: ", messagePrefix .. "Warning: "

    -- Check the scheduleId provided.
    if not DelayedLua.CheckScheduledId(scheduleId, errorMessagePrefix) then
        return nil
    end

    -- Get the data for the scheduled Id from it's event.
    local scheduledLuaEvents = EventScheduler.GetScheduledOnceEvents("DelayedLua.ActionDelayedLua", scheduleId)
    if scheduledLuaEvents == nil then
        LoggingUtils.LogPrintWarning(warningMessagePrefix .. "no delayed lua with schedule Id: " .. tostring(scheduleId))
        return nil
    elseif #scheduledLuaEvents ~= 1 then
        LoggingUtils.LogPrintWarning(errorMessagePrefix .. "more than 1 delayed lua with schedule Id - report to mod author as error: " .. tostring(scheduleId))
        return nil
    end
    local scheduledLuaEvent = scheduledLuaEvents[1] -- Only ever 1 result for an Id.
    local delayedLua = scheduledLuaEvent.eventData ---@type DelayedLua_ScheduledEvent
    return delayedLua.functionData
end

--- Sets the data for a scheduled delayed Lua instance. Reports if the update was successful.
---@param scheduleId uint
---@param functionData table|nil
---@return boolean updatedSuccessfully
DelayedLua.SetDelayedLuaData_Remote = function(scheduleId, functionData)
    local messagePrefix = Constants.ModFriendlyName .. " - set_delayed_lua_data - "
    local errorMessagePrefix = messagePrefix .. "Error: "

    -- Check the scheduleId provided.
    if not DelayedLua.CheckScheduledId(scheduleId, errorMessagePrefix) then
        return false
    end

    -- Check the data provided.
    if functionData ~= nil then
        if type(functionData) ~= "table" then
            LoggingUtils.LogPrintError(errorMessagePrefix .. "`data` argument must be a Lua table type when populated, provided: " .. type(functionData))
            return false
        end
    end

    -- Set the data for the scheduled Id in it's event.
    local scheduledLuaEvents = EventScheduler.GetScheduledOnceEvents("DelayedLua.ActionDelayedLua", scheduleId)
    if scheduledLuaEvents == nil then
        return false
    elseif #scheduledLuaEvents ~= 1 then
        LoggingUtils.LogPrintWarning(errorMessagePrefix .. "more than 1 delayed lua with schedule Id - report to mod author as error: " .. tostring(scheduleId))
        return false
    end
    local scheduledLuaEvent = scheduledLuaEvents[1] -- Only ever 1 result for an Id.
    local delayedLua = scheduledLuaEvent.eventData ---@type DelayedLua_ScheduledEvent
    delayedLua.functionData = functionData
    return true
end

--- Check the Schedule Id is a generally suitable parameter value.
---@param scheduleId uint
---@param errorMessagePrefix string
---@return boolean valid
DelayedLua.CheckScheduledId = function(scheduleId, errorMessagePrefix)
    if scheduleId == nil then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`scheduleId` argument must be provided.")
        return false
    elseif type(scheduleId) ~= "number" then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`scheduleId` argument must be a Lua number type, provided: " .. type(scheduleId))
        return false
    elseif scheduleId ~= math.floor(scheduleId) then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`scheduleId` argument must be an integer number, provided: " .. tostring(scheduleId))
        return false
    elseif scheduleId < 0 then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`scheduleId` argument must be 0 or greater, provided: " .. tostring(scheduleId))
        return false
    elseif scheduleId > global.delayedLua.nextId then
        LoggingUtils.LogPrintError(errorMessagePrefix .. "`scheduleId` argument must not be greater than the max scheduled Lua code Id, provided: " .. tostring(scheduleId))
        return false
    end

    return true
end

return DelayedLua
