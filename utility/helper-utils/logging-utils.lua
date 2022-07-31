--- Logging functions.
--- Requires the utility "constants" file to be populated within the root of the mod.

local LoggingUtils = {} ---@class Utility_LoggingUtils
local Constants = require("constants")
local StringUtils = require("utility.helper-utils.string-utils")
local TableUtils = require("utility.helper-utils.table-utils")
local Colors = require("utility.lists.colors")

----------------------------------------------------------------------------------
--                          PUBLIC FUNCTIONS
----------------------------------------------------------------------------------

---@param position MapPosition
---@return string
LoggingUtils.PositionToString = function(position)
    if position == nil then
        return "nil position"
    end
    return "(" .. position.x .. ", " .. position.y .. ")"
end

---@param boundingBox BoundingBox
---@return string
LoggingUtils.BoundingBoxToString = function(boundingBox)
    if boundingBox == nil then
        return "nil boundingBox"
    end
    return "((" .. boundingBox.left_top.x .. ", " .. boundingBox.left_top.y .. "), (" .. boundingBox.right_bottom.x .. ", " .. boundingBox.right_bottom.y .. "))"
end

--- Write an error colored text string to the screen (if possible), plus the Factorio log file. Not the mod's bespoke log file.
--- For use in direct error handling.
--- If in data stage can't print to screen. Also when in game during tick 0 can't print to screen. Either use the EventScheduler.GamePrint to do this or handle it another way at usage time.
---@param text string
---@param recordToModLog? boolean|nil # Defaults to false. Normally only used to avoid duplicating function calling of LoggingUtils.ModLog().
LoggingUtils.LogPrintError = function(text, recordToModLog)
    if game ~= nil then
        game.print(tostring(text), Colors.errorMessage)
    end
    log(tostring(text))
    if recordToModLog then
        LoggingUtils._RecordToModsLog(text)
    end
end

--- Write a warning colored text string to the screen (if possible), plus the Factorio log file. Not the mod's bespoke log file.
--- For use in direct error handling.
--- If in data stage can't print to screen. Also when in game during tick 0 can't print to screen. Either use the EventScheduler.GamePrint to do this or handle it another way at usage time.
---@param text string
---@param recordToModLog? boolean|nil # Defaults to false. Normally only used to avoid duplicating function calling of LoggingUtils.ModLog().
LoggingUtils.LogPrintWarning = function(text, recordToModLog)
    if game ~= nil then
        game.print(tostring(text), Colors.warningMessage)
    end
    log(tostring(text))
    if recordToModLog then
        LoggingUtils._RecordToModsLog(text)
    end
end

--- Write a text string to the screen (if possible), plus the Factorio log file. Not the mod's bespoke log file.
--- For use in bespoke situations (and pre LogPrintError).
--- If in data stage can't print to screen. Also when in game during tick 0 can't print to screen. Either use the EventScheduler.GamePrint to do this or handle it another way at usage time.
---@param text string
---@param enabled? boolean|nil # Defaults to True. Allows code to not require lots of `if` in calling functions.
---@param textColor? Color|nil # Defaults to Factorio white.
---@param recordToModLog? boolean|nil # Defaults to false. Normally only used to avoid duplicating function calling of LoggingUtils.ModLog().
LoggingUtils.LogPrint = function(text, enabled, textColor, recordToModLog)
    if enabled ~= nil and not enabled then
        return
    end
    if game ~= nil then
        game.print(tostring(text), textColor)
    end
    log(tostring(text))
    if recordToModLog then
        LoggingUtils._RecordToModsLog(text)
    end
end

--- Write a text string to the mod's log file (if possible) and the Factorio log file. Optionally to the screen as well.
--- For use in logging action sequences, rather than direct error handling.
--- If in data stage can't write to mod's custom log file.
---@param text string
---@param writeToScreen boolean
---@param enabled? boolean|nil # Defaults to True.
LoggingUtils.ModLog = function(text, writeToScreen, enabled)
    if enabled ~= nil and not enabled then
        return
    end
    if game ~= nil then
        LoggingUtils._RecordToModsLog(text)
        log(tostring(text))
        if writeToScreen then
            game.print(tostring(text))
        end
    else
        log(tostring(text))
    end
end

--- Just records some text to the Mod's log file (if possible) in the bespoke data folder. Logs if this isn't possible.
--- Does nothing if can't write to files at present (no game object yet).
---@param text string
LoggingUtils._RecordToModsLog = function(text)
    if game == nil then
        return
    end
    if Constants.LogFileName == nil or Constants.LogFileName == "" then
        game.print("ERROR - No Constants.LogFileName set", Colors.errorMessage)
        log("ERROR - No Constants.LogFileName set")
    end
    game.write_file(Constants.LogFileName, tostring(text) .. "\r\n", true)
end

-- Runs the function in a wrapper that will log detailed information should an error occur. Is used to provide a debug release of a mod with enhanced error logging. Will slow down real world usage and so shouldn't be used for general releases.
-- CODE NOTE: JustARandomGeek doesn't believe that the ".instrument" check is needed for the control hook and the presence of the __DebugAdapter variable is enough. Check if this function is used ever again.
---@param functionRef function,
---@param ... any
LoggingUtils.RunFunctionAndCatchErrors = function(functionRef, ...)
    -- Doesn't support returning values to caller as can't do this for unknown argument count.
    -- Uses a random number in file name to try and avoid overlapping errors in real game. If save is reloaded and nothing different done by player will be the same result however.

    -- If the debug adapter with instrument mode (control hook) is active just run the function and end as no need to log to file anything. As the logging write out is slow in debugger. Just runs the function normally and return any results.
    if __DebugAdapter ~= nil and __DebugAdapter.instrument then
        functionRef(...)
        return
    end

    local args = { ... } ---@type any[]

    -- Is in debug mode so catch any errors and log state data.
    -- Only produces correct stack traces in regular Factorio, not in debugger as this adds extra lines to the stacktrace.
    ---@type boolean, UtilityLogging_RunFunctionAndCatchErrors_ErrorObject
    local success, errorObject = xpcall(functionRef, LoggingUtils._RunFunctionAndCatchErrors_ErrorHandlerFunction, ...)
    if success then
        return
    else
        local logFileName = Constants.ModName .. " - error details - " .. tostring(math.random() .. ".log")
        local contents = ""
        local AddLineToContents = function(text)
            contents = contents .. text .. "\r\n"
        end
        AddLineToContents("Error: " .. errorObject.message)

        -- Tidy the stacktrace up by removing the indented (\9) lines that relate to this xpcall function. Makes the stack trace read more naturally ignoring this function.
        local newStackTrace, lineCount = "stacktrace:\n", 1
        local rawxpcallLine
        for line in string.gmatch(errorObject.stacktrace, "(\9[^\n]+)\n") do
            local skipLine = false
            if lineCount == 1 then
                skipLine = true
            elseif string.find(line, "(...tail calls...)") then
                skipLine = true
            elseif string.find(line, "rawxpcall") or string.find(line, "xpcall") then
                skipLine = true
                rawxpcallLine = lineCount + 1
            elseif lineCount == rawxpcallLine then
                skipLine = true
            end
            if not skipLine then
                newStackTrace = newStackTrace .. line .. "\n"
            end
            lineCount = lineCount + 1
        end
        AddLineToContents(newStackTrace)

        AddLineToContents("")
        AddLineToContents("Function call arguments:")
        for index, arg in pairs(args) do
            AddLineToContents(TableUtils.TableContentsToJSON(LoggingUtils.PrintThingsDetails(arg), "argument number: " .. tostring(index)))
        end

        game.write_file(logFileName, contents, false) -- Wipe file if it exists from before.
        error('Debug release: see log file in Factorio Data\'s "script-output" folder.\n' .. errorObject.message .. "\n" .. newStackTrace, 0)
    end
end

-- Used to make a text object of something's attributes that can be stringified. Supports LuaObjects with handling for specific ones.
---@param thing any # can be a simple data type, table, or LuaObject.
---@param _tablesLogged? table<any, string>|nil # don't pass in, only used internally when self referencing the function for looping.
---@return table
LoggingUtils.PrintThingsDetails = function(thing, _tablesLogged)
    _tablesLogged = _tablesLogged or {} -- Internal variable passed when self referencing to avoid loops.

    -- Simple values just get returned.
    if type(thing) ~= "table" then
        return { LITERAL_VALUE = thing }
    end ---@cast thing table

    -- Handle specific Factorio Lua objects
    local thing_objectName = thing.object_name --[[@as string|nil]]
    if thing_objectName ~= nil then
        ---@cast thing LuaObject
        -- Invalid things are returned in safe way.
        if not thing.valid then
            return {
                object_name = thing_objectName,
                valid = thing.valid
            }
        end

        if thing_objectName == "LuaEntity" then
            ---@cast thing LuaEntity
            local thing_type = thing.type
            local entityDetails = {
                object_name = thing_objectName,
                valid = thing.valid,
                type = thing_type,
                name = thing.name,
                unit_number = thing.unit_number,
                position = thing.position,
                direction = thing.direction,
                orientation = thing.orientation,
                health = thing.health,
                color = thing.color,
                speed = thing.speed,
                backer_name = thing.backer_name
            }
            if thing_type == "locomotive" or thing_type == "cargo-wagon" or thing_type == "fluid-wagon" or thing_type == "artillery-wagon" then
                entityDetails.trainId = thing.train.id
            end

            return entityDetails
        elseif thing_objectName == "LuaTrain" then
            ---@cast thing LuaTrain
            local carriages = {} ---@type table<uint, table>
            for i, carriage in pairs(thing.carriages) do
                ---@cast i uint
                carriages[i] = LoggingUtils.PrintThingsDetails(carriage, _tablesLogged)
            end
            return {
                object_name = thing_objectName,
                valid = thing.valid,
                id = thing.id,
                state = thing.state,
                schedule = thing.schedule,
                manual_mode = thing.manual_mode,
                has_path = thing.has_path,
                speed = thing.speed,
                signal = LoggingUtils.PrintThingsDetails(thing.signal, _tablesLogged),
                station = LoggingUtils.PrintThingsDetails(thing.station, _tablesLogged),
                carriages = carriages
            }
        else
            -- Other Lua object.
            return {
                object_name = thing_objectName,
                valid = thing.valid
            }
        end
    end

    -- Is just a general table so return all its keys.
    local returnedSafeTable = {} ---@type table<any, any>
    _tablesLogged[thing] = "logged"
    ---@cast thing table<any, any>
    for key, value in pairs(thing) do
        if _tablesLogged[key] ~= nil or _tablesLogged[value] ~= nil then
            local valueIdText
            if value.id ~= nil then
                valueIdText = "ID: " .. value.id
            else
                valueIdText = "no ID"
            end
            returnedSafeTable[key] = "circular table reference - " .. valueIdText
        else
            returnedSafeTable[key] = LoggingUtils.PrintThingsDetails(value, _tablesLogged)
        end
    end
    return returnedSafeTable
end

--- Writes out sequential numbers at the set position. Used as a visual debugging tool.
---@param targetSurfaceIdentification SurfaceIdentification
---@param targetPosition LuaEntity|MapPosition
LoggingUtils.WriteOutNumberedMarker = function(targetSurfaceIdentification, targetPosition)
    global.UtilityLogging_NumberedCount = global.UtilityLogging_NumberedCount or 1 ---@type uint
    rendering.draw_text {
        text = global.UtilityLogging_NumberedCount,
        surface = targetSurfaceIdentification,
        target = targetPosition,
        color = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },
        scale_with_zoom = true,
        alignment = "center",
        vertical_alignment = "bottom"
    }
    global.UtilityLogging_NumberedCount = global.UtilityLogging_NumberedCount + 1
end

--- Writes out sequential numbers at the SurfacePositionString. Used as a visual debugging tool.
---@param targetSurfacePositionString SurfacePositionString
LoggingUtils.WriteOutNumberedMarkerForSurfacePositionString = function(targetSurfacePositionString)
    local tempSurfaceId, tempPos = StringUtils.SurfacePositionStringToSurfaceAndPosition(targetSurfacePositionString)
    LoggingUtils.WriteOutNumberedMarker(tempSurfaceId, tempPos)
end

----------------------------------------------------------------------------------
--                          PRIVATE FUNCTIONS
----------------------------------------------------------------------------------

---@class UtilityLogging_RunFunctionAndCatchErrors_ErrorObject
---@field message string
---@field stacktrace string

---@param errorMessage string
LoggingUtils._RunFunctionAndCatchErrors_ErrorHandlerFunction = function(errorMessage)
    local errorObject = { message = errorMessage, stacktrace = debug.traceback() }
    return errorObject
end

return LoggingUtils
