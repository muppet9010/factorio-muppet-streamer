--- Logging functions.
--- Requires the utility "constants" file to be populated within the root of the mod.

local Logging = {}
local Constants = require("constants")
local StringUtils = require("utility.string-utils")
local TableUtils = require("utility.table-utils")

---@param position MapPosition
---@return string
Logging.PositionToString = function(position)
    if position == nil then
        return "nil position"
    end
    return "(" .. position.x .. ", " .. position.y .. ")"
end

---@param boundingBox BoundingBox
---@return string
Logging.BoundingBoxToString = function(boundingBox)
    if boundingBox == nil then
        return "nil boundingBox"
    end
    return "((" .. boundingBox.left_top.x .. ", " .. boundingBox.left_top.y .. "), (" .. boundingBox.right_bottom.x .. ", " .. boundingBox.right_bottom.y .. "))"
end

---@param text string
---@param enabled? boolean @ Defaults to True.
Logging.Log = function(text, enabled)
    if enabled ~= nil and not enabled then
        return
    end
    if game ~= nil then
        if Constants.LogFileName == nil or Constants.LogFileName == "" then
            game.print("ERROR - No Constants.LogFileName set")
            log("ERROR - No Constants.LogFileName set")
        end
        game.write_file(Constants.LogFileName, tostring(text) .. "\r\n", true)
        log(tostring(text))
    else
        log(tostring(text))
    end
end

---@param text string
---@param enabled? boolean @ Defaults to True.
Logging.LogPrint = function(text, enabled)
    if enabled ~= nil and not enabled then
        return
    end
    if game ~= nil then
        -- Won't print on 0 tick (startup) due to core game limitation. Either use the EventScheduler.GamePrint to do this or handle it another way at usage time.
        game.print(tostring(text))
    end
    Logging.Log(text)
end

-- Runs the function in a wrapper that will log detailed infromation should an error occur. Is used to provide a debug release of a mod with enhanced error logging. Will slow down real world usage and so shouldn't be used for general releases.
---@param functionRef function
Logging.RunFunctionAndCatchErrors = function(functionRef, ...)
    -- Doesn't support returning values to caller as can't do this for unknown argument count.
    -- Uses a random number in file name to try and avoid overlapping errors in real game. If save is reloaded and nothing different done by player will be the same result however.

    -- If the debug adapter with instrument mode (control hook) is active just run the fucntion and end as no need to log to file anything. As the logging write out is slow in debugger. Just runs the function normally and return any results.
    if __DebugAdapter ~= nil and __DebugAdapter.instrument then
        functionRef(...)
        return
    end

    local errorHandlerFunc = function(errorMessage)
        local errorObject = {message = errorMessage, stacktrace = debug.traceback()}
        return errorObject
    end

    local args = {...}

    -- Is in debug mode so catch any errors and log state data.
    -- Only produces correct stack traces in regular Factorio, not in debugger as this adds extra lines to the stacktrace.
    local success, errorObject = xpcall(functionRef, errorHandlerFunc, ...)
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
        local newStackTrace, lineCount, rawxpcallLine = "stacktrace:\n", 1, nil
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
            AddLineToContents(TableUtils.TableContentsToJSON(Logging.PrintThingsDetails(arg), index))
        end

        game.write_file(logFileName, contents, false) -- Wipe file if it exists from before.
        error('Debug release: see log file in Factorio Data\'s "script-output" folder.\n' .. errorObject.message .. "\n" .. newStackTrace, 0)
    end
end

-- Used to make a text object of something's attributes that can be stringified. Supports LuaObjects with handling for specific ones.
---@param thing any @ can be a simple data type, table, or LuaObject.
---@param _tablesLogged? table @ don't pass in, only used internally when self referencing the function for looping.
---@return table
Logging.PrintThingsDetails = function(thing, _tablesLogged)
    _tablesLogged = _tablesLogged or {} -- Internal variable passed when self referencing to avoid loops.

    -- Simple values just get returned.
    if type(thing) ~= "table" then
        return tostring(thing)
    end

    -- Handle specific Factorio Lua objects
    local thing_objectName = thing.object_name
    if thing_objectName ~= nil then
        -- Invalid things are returned in safe way.
        if not thing.valid then
            return {
                object_name = thing_objectName,
                valid = thing.valid
            }
        end

        if thing_objectName == "LuaEntity" then
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
            local carriages = {}
            for i, carriage in pairs(thing.carriages) do
                carriages[i] = Logging.PrintThingsDetails(carriage, _tablesLogged)
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
                signal = Logging.PrintThingsDetails(thing.signal, _tablesLogged),
                station = Logging.PrintThingsDetails(thing.station, _tablesLogged),
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
    local returnedSafeTable = {}
    _tablesLogged[thing] = "logged"
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
            returnedSafeTable[key] = Logging.PrintThingsDetails(value, _tablesLogged)
        end
    end
    return returnedSafeTable
end

--- Writes out sequential numbers at the set position. Used as a visial debugging tool.
---@param targetSurface LuaSurface
---@param targetPosition LuaEntity|MapPosition
Logging.WriteOutNumberedMarker = function(targetSurface, targetPosition)
    global.numberedCount = global.numberedCount or 1
    rendering.draw_text {
        text = global.numberedCount,
        surface = targetSurface,
        target = targetPosition,
        color = {r = 1, g = 0, b = 0, a = 1},
        scale_with_zoom = true,
        alignment = "center",
        vertical_alignment = "bottom"
    }
    global.numberedCount = global.numberedCount + 1
end

--- Writes out sequential numbers at the SurfacePositionString. Used as a visial debugging tool.
---@param targetSurfacePositionString SurfacePositionString
Logging.WriteOutNumberedMarkerForSurfacePositionString = function(targetSurfacePositionString)
    local tempSurfaceId, tempPos = StringUtils.SurfacePositionStringToSurfaceAndPosition(targetSurfacePositionString)
    Logging.WriteOutNumberedMarker(tempSurfaceId, tempPos)
end

return Logging
