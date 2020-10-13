local AggressiveTrainDriver = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")

AggressiveTrainDriver.CreateGlobals = function()
    global.aggressiveTrainDriver = global.spawnAroundPlayer or {}
    global.aggressiveTrainDriver.nextId = global.spawnAroundPlayer.nextId or 0
end

AggressiveTrainDriver.OnLoad = function()
    Commands.Register("muppet_streamer_aggressive_train_driver", {"api-description.muppet_streamer_aggressive_train_driver"}, AggressiveTrainDriver.AggressiveTrainDriverCommand, true)
    EventScheduler.RegisterScheduledEventType("SpawnAroundPlayer.AggressiveTrainDriverScheduled", AggressiveTrainDriver.AggressiveTrainDriverScheduled)
end

AggressiveTrainDriver.AggressiveTrainDriverCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_aggressive_train_driver command "
    local commandData
    if command.parameter ~= nil then
        commandData = game.json_to_table(command.parameter)
    end
    if commandData == nil or type(commandData) ~= "table" then
        Logging.LogPrint(errorMessageStart .. "requires details in JSON format.")
        return
    end

    local delay = 0
    if commandData.delay ~= nil then
        delay = tonumber(commandData.delay)
        if delay == nil then
            Logging.LogPrint(errorMessageStart .. "delay is Optional, but must be a non-negative number if supplied")
            return
        end
        delay = math.max(delay * 60, 0)
    end

    local target = commandData.target
    if target == nil then
        Logging.LogPrint(errorMessageStart .. "target is mandatory")
        return
    elseif game.get_player(target) == nil then
        Logging.LogPrint(errorMessageStart .. "target is invalid player name")
        return
    end

    local forceString = commandData.force
    if forceString ~= nil then
        if game.forces[forceString] == nil then
            Logging.LogPrint(errorMessageStart .. "optional force provided, but isn't a valid force name")
            return
        end
    end

    local entityName = commandData.entityName
    if entityName == nil or SpawnAroundPlayer.EntityTypeDetails[entityName] == nil then
        Logging.LogPrint(errorMessageStart .. "entityName is mandatory and must be a supported type")
        return
    end

    local radiusMax = tonumber(commandData.radiusMax)
    if radiusMax == nil or radiusMax <= 0 then
        Logging.LogPrint(errorMessageStart .. "radiusMax is mandatory and must be a number greater than 0")
        return
    end

    local radiusMin = tonumber(commandData.radiusMin)
    if radiusMin == nil or radiusMin < 0 then
        radiusMin = 0
    end

    local existingEntities = commandData.existingEntities
    if existingEntities == nil or (existingEntities ~= "overlap" and existingEntities ~= "avoid") then
        Logging.LogPrint(errorMessageStart .. "existingEntities is mandatory and must be a supported setting type")
        return
    end

    local quantity = tonumber(commandData.quantity)
    local density = tonumber(commandData.density)
    local ammoCount = tonumber(commandData.ammoCount)

    local followPlayer = commandData.followPlayer
    if followPlayer ~= nil then
        if type(followPlayer) ~= "boolean" then
            Logging.LogPrint(errorMessageStart .. "optional followPlayer provided, but isn't a boolean true/false")
            return
        end
    end

    global.AggressiveTrainDriver.nextId = global.AggressiveTrainDriver.nextId + 1
    EventScheduler.ScheduleEvent(
        command.tick + delay,
        "SpawnAroundPlayer.AggressiveTrainDriverScheduled",
        global.AggressiveTrainDriver.nextId,
        {target = target, entityName = entityName, radiusMax = radiusMax, radiusMin = radiusMin, existingEntities = existingEntities, quantity = quantity, density = density, ammoCount = ammoCount, followPlayer = followPlayer, forceString = forceString}
    )
end

AggressiveTrainDriver.AggressiveTrainDriverScheduled = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_aggressive_train_driver command "
    local data = eventData.data

    TODO
end

return AggressiveTrainDriver
