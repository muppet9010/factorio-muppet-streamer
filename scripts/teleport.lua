local Teleport = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Events = require("utility/events")

local DestinationTypeSelection = {random = "random", biterNest = "biterNest", biterGroup = "biterGroup", spawn = "spawn", position = "position"}

Teleport.CreateGlobals = function()
    global.teleport = global.teleport or {}
    global.teleport.nextId = global.teleport.nextId or 0
    global.teleport.pathingRequests = global.teleport.pathingRequests or {}
end

Teleport.OnLoad = function()
    Commands.Register("muppet_streamer_teleport", {"api-description.muppet_streamer_teleport"}, Teleport.TeleportCommand, true)
    EventScheduler.RegisterScheduledEventType("Teleport.PlanTeleportTarget", Teleport.PlanTeleportTarget)
    Events.RegisterHandlerEvent(defines.events.on_script_path_request_finished, "teleport.OnScriptPathRequestFinished", Teleport.OnScriptPathRequestFinished)
end

Teleport.OnStartup = function()
end

Teleport.TeleportCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_teleport command "
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

    local destinationTypeRaw = commandData.destinationType
    local destinationType, destinationTargetPosition = DestinationTypeSelection[destinationTypeRaw], nil
    if destinationType == nil then
        destinationTargetPosition = Utils.TableToProperPosition(destinationTypeRaw)
        if destinationTargetPosition == nil then
            Logging.LogPrint(errorMessageStart .. "destinationType is Mandatory and must be a valid type or a table for position")
            return
        else
            destinationType = DestinationTypeSelection.position
        end
    end

    local minDistanceRaw, minDistance = commandData.minDistance, 0
    if minDistanceRaw ~= nil then
        minDistance = tonumber(minDistanceRaw)
        if minDistance == nil then
            Logging.LogPrint(errorMessageStart .. "minDistance is Optional, but if supplied must be 0 or greater")
            return
        end
    end

    local maxDistance = tonumber(commandData.maxDistance)
    if destinationType == DestinationTypeSelection.position or destinationType == DestinationTypeSelection.spawn then
        maxDistance = 0
    elseif maxDistance == nil then
        Logging.LogPrint(errorMessageStart .. "maxDistance is Mandatory, must be 0 or greater")
        return
    end

    local reachableOnlyRaw, reachableOnly = commandData.reachableOnly, true
    if reachableOnlyRaw ~= nil then
        reachableOnly = Utils.ToBoolean(reachableOnlyRaw)
        if reachableOnly == nil then
            Logging.LogPrint(errorMessageStart .. "reachableOnly is Optional, but if provided must be a boolean")
            return
        end
    end

    global.teleport.nextId = global.teleport.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "Teleport.PlanTeleportTarget", global.teleport.nextId, {teleportId = global.teleport.nextId, target = target, minDistance = minDistance, maxDistance = maxDistance, destinationType = destinationType, destinationTargetPosition = destinationTargetPosition, reachableOnly = reachableOnly, targetAttempt = 0})
end

Teleport.PlanTeleportTarget = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_teleport command "
    local data = eventData.data

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character then
        game.print({"message.muppet_streamer_teleport_not_character_controller", data.target})
        return
    end

    data.targetAttempt = data.targetAttempt + 1

    if data.destinationType == DestinationTypeSelection.spawn then
        data.destinationTargetPosition = targetPlayer.force.get_spawn_position(targetPlayer.surface)
    elseif data.destinationType == DestinationTypeSelection.position then
        data.destinationTargetPosition = data.destinationTargetPosition
    elseif data.destinationType == DestinationTypeSelection.random then
        --TODO
    elseif data.destinationType == DestinationTypeSelection.biterNest then
        --TODO
    elseif data.destinationType == DestinationTypeSelection.biterGroup then
    --TODO
    end

    data.targetPlayer = targetPlayer
    Teleport.PlanTeleportLocation(data)
end

Teleport.IsTeleportableVehicle = function(vehicle)
    return vehicle ~= nil and vehicle.valid and (vehicle.name == "car" or vehicle.name == "tank" or vehicle.name == "spider-vehicle")
end

Teleport.PlanTeleportLocation = function(data)
    local targetPlayer = data.targetPlayer
    local targetPlayerEntity
    if Teleport.IsTeleportableVehicle(targetPlayer.vehicle) then
        targetPlayerEntity = targetPlayer.vehicle
    else
        targetPlayerEntity = targetPlayer.character
    end

    local arrivalPos, arrivalRadius = nil, 10
    for _ = 1, 10 do
        local randomPos = Utils.RandomLocationInRadius(data.destinationTargetPosition, arrivalRadius, 1)
        randomPos = Utils.RoundPosition(randomPos, 0) -- Make it tile border aligned as most likely place to get valid placements from when in a base. We search in whole tile increments from this tile border.
        arrivalPos = targetPlayer.surface.find_non_colliding_position(targetPlayerEntity.name, randomPos, 10, 1, false)
        if arrivalPos ~= nil then
            break
        end
    end
    if arrivalPos == nil then
        game.print({"message.muppet_streamer_call_for_help_no_teleport_location_found", targetPlayer.name, targetPlayer.name})
        return
    end
    data.thisAttemptPosition = arrivalPos

    if data.reachableOnly then
        local pathRequestId =
            targetPlayer.surface.request_path {
            bounding_box = targetPlayerEntity.prototype.collision_box, -- Work around for: https://forums.factorio.com/viewtopic.php?f=182&t=90146
            collision_mask = targetPlayerEntity.prototype.collision_mask,
            start = arrivalPos,
            goal = targetPlayer.position,
            force = targetPlayer.force,
            radius = 1,
            can_open_gates = true,
            entity_to_ignore = targetPlayerEntity,
            pathfind_flags = {allow_paths_through_own_entities = true, cache = false}
        }
        global.teleport.pathingRequests[pathRequestId] = data
    else
        Teleport.Teleport(data)
    end
end

Teleport.OnScriptPathRequestFinished = function(event)
    local data = global.teleport.pathingRequests[event.id]
    if data == nil then
        -- Not our path request
        return
    end

    global.teleport.pathingRequests[event.id] = nil
    local player = data.player
    if event.path == nil then
        -- Path request failed
        data.attempt = data.attempt + 1
        if data.attempt > 5 then
            game.print({"message.muppet_streamer_teleport_no_teleport_location_found", player.name})
        else
            Teleport.PlanTeleportTarget({data = data})
        end
    else
        Teleport.Teleport(data)
    end
end

Teleport.Teleport = function(data)
    local targetPlayer = data.targetPlayer
    if Teleport.IsTeleportableVehicle(targetPlayer.vehicle) then
        targetPlayer.vehicle.teleport(data.thisAttemptPosition)
    else
        targetPlayer.teleport(data.thisAttemptPosition)
    end
end

return Teleport
