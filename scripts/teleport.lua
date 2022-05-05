local Teleport = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Events = require("utility/events")

---@class Teleport_DestinationTypeSelection
local DestinationTypeSelection = {random = "random", biterNest = "biterNest", enemyUnit = "enemyUnit", spawn = "spawn", position = "position"}

---@class DestinationTypeSelectionDescription
local DestinationTypeSelectionDescription = {random = "Random Location", biterNest = "Nearest Biter Nest", enemyUnit = "Enemy Unit", spawn = "spawn", position = "Set Position"}

local MaxTargetAttempts = 5
local MaxRandomPositionsAroundTarget = 10
local MaxDistancePositionAroundTarget = 10

---@class Teleport_CommandDetails @ The details for a specific teleport event in an an RCON command.
---@field delay uint
---@field target string @ Target player's name.
---@field arrivalRadius double
---@field minDistance double
---@field maxDistance double
---@field destinationType Teleport_DestinationTypeSelection
---@field destinationTargetPosition MapPosition|null
---@field reachableOnly boolean
---@field backupTeleportSettings Teleport_CommandDetails|null
---@field destinationTypeDescription DestinationTypeSelectionDescription

---@class Teleport_TeleportDetails @ The data on a teleport action being undertaken. This includes the attributes from the first Teleport_CommandDetails within it directly.
---@field teleportId uint
---@field target string
---@field arrivalRadius double
---@field minDistance double
---@field maxDistance double
---@field destinationType Teleport_DestinationTypeSelection
---@field destinationTargetPosition MapPosition|null
---@field reachableOnly boolean
---@field targetAttempt uint
---@field failedTargetPositions MapPosition[]
---@field backupTeleportSettings Teleport_CommandDetails|null
---@field destinationTypeDescription DestinationTypeSelectionDescription
---@field thisAttemptPosition MapPosition|null @ The map position of the current teleport attempt.
---@field spawnerDistances

Teleport.CreateGlobals = function()
    global.teleport = global.teleport or {}
    global.teleport.nextId = global.teleport.nextId or 0 ---@type uint
    global.teleport.pathingRequests = global.teleport.pathingRequests or {} ---@type table<Id, Teleport_TeleportDetails> @ The path request Id to its teleport details for whne the path request completes.
    global.teleport.surfaceBiterNests = global.teleport.surfaceBiterNests or Teleport.FindExistingSpawnersOnAllSurfaces() ---@type table<Id, table<UnitNumber, LuaEntity>> @ A table of surface index numbers to a table of spawner's by thier unit number.
end

Teleport.OnLoad = function()
    Commands.Register("muppet_streamer_teleport", {"api-description.muppet_streamer_teleport"}, Teleport.TeleportCommand, true)
    EventScheduler.RegisterScheduledEventType("Teleport.PlanTeleportTarget", Teleport.PlanTeleportTarget)
    Events.RegisterHandlerEvent(defines.events.on_script_path_request_finished, "Teleport.OnScriptPathRequestFinished", Teleport.OnScriptPathRequestFinished)
    Events.RegisterHandlerEvent(defines.events.on_biter_base_built, "Teleport.OnBiterBaseBuilt", Teleport.OnBiterBaseBuilt)
    Events.RegisterHandlerEvent(defines.events.script_raised_built, "Teleport.ScriptRaisedBuilt", Teleport.ScriptRaisedBuilt, "Type-UnitSpawner", {{filter = "type", type = "unit-spawner"}})
    Events.RegisterHandlerEvent(defines.events.on_chunk_generated, "Teleport.OnChunkGenerated", Teleport.OnChunkGenerated)
    Events.RegisterHandlerEvent(defines.events.on_entity_died, "Teleport.OnEntityDied", Teleport.OnEntityDied, "Type-UnitSpawner", {{filter = "type", type = "unit-spawner"}})
    Events.RegisterHandlerEvent(defines.events.script_raised_destroy, "Teleport.ScriptRaisedDestroy", Teleport.ScriptRaisedDestroy, "Type-UnitSpawner", {{filter = "type", type = "unit-spawner"}})
end

--- Triggered when the RCON command is run.
---@param command CustomCommandData
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

    local commandValues = Teleport.GetCommandData(commandData, errorMessageStart, 0)
    if commandValues == nil then
        return
    end

    Teleport.ScheduleTeleportCommand(commandValues)
end

--- Validates the data from an RCON commands's arguments in to a table of details.
---@param commandData table @ Table of arguments passed in to the RCON command.
---@param errorMessageStart string
---@param depth uint @ Used when looping recursively in to backup settings. Populate as 0 for the initial calling of the function in the raw RCON command handler.
---@return Teleport_CommandDetails commandDetails
Teleport.GetCommandData = function(commandData, errorMessageStart, depth)
    local depthErrorMessage = ""
    if depth > 0 then
        depthErrorMessage = "at depth " .. depth .. " - "
    end

    local delay = 0
    if commandData.delay ~= nil then
        delay = tonumber(commandData.delay)
        if delay == nil then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "delay is Optional, but must be a non-negative number if supplied")
            return
        end
        delay = math.max(delay * 60, 0)
    end

    local target = commandData.target
    if target == nil then
        Logging.LogPrint(errorMessageStart .. "target is mandatory")
        return
    elseif game.get_player(target) == nil then
        Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "target is invalid player name")
        return
    end

    local destinationTypeRaw = commandData.destinationType
    local destinationType, destinationTargetPosition = DestinationTypeSelection[destinationTypeRaw], nil
    if destinationType == nil then
        destinationTargetPosition = Utils.TableToProperPosition(destinationTypeRaw)
        if destinationTargetPosition == nil then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "destinationType is Mandatory and must be a valid type or a table for position")
            return
        else
            destinationType = DestinationTypeSelection.position
        end
    end

    local destinationTypeDescription = DestinationTypeSelectionDescription[destinationType]

    local arrivalRadiusRaw, arrivalRadius = commandData.arrivalRadius, 0
    if arrivalRadiusRaw ~= nil then
        arrivalRadius = tonumber(arrivalRadiusRaw)
        if arrivalRadius == nil or arrivalRadius < 0 then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "arrivalRadius is Optional, but if supplied must be 0 or greater")
            return
        end
    end

    local minDistanceRaw, minDistance = commandData.minDistance, 0
    if minDistanceRaw ~= nil then
        minDistance = tonumber(minDistanceRaw)
        if minDistance == nil or minDistance < 0 then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "minDistance is Optional, but if supplied must be 0 or greater")
            return
        end
    end

    local maxDistance = tonumber(commandData.maxDistance)
    if destinationType == DestinationTypeSelection.position or destinationType == DestinationTypeSelection.spawn then
        maxDistance = 0
    elseif maxDistance == nil or maxDistance < 0 then
        Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "maxDistance is Mandatory, must be 0 or greater")
        return
    end

    local reachableOnly = false
    if commandData.reachableOnly ~= nil then
        reachableOnly = Utils.ToBoolean(commandData.reachableOnly)
        if reachableOnly == nil then
            Logging.LogPrint(errorMessageStart .. "reachableOnly is Optional, but if provided must be a boolean")
            return
        elseif reachableOnly == true and not (destinationType == DestinationTypeSelection.biterNest or destinationType == DestinationTypeSelection.random) then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "reachableOnly is enabled set for unsupported destinationType")
            return
        end
    end

    local backupTeleportSettingsRaw, backupTeleportSettings = commandData.backupTeleportSettings, nil
    if backupTeleportSettingsRaw ~= nil and type(backupTeleportSettingsRaw) == "table" then
        backupTeleportSettings = Teleport.GetCommandData(backupTeleportSettingsRaw, errorMessageStart, depth + 1)
    end

    return {delay = delay, target = target, arrivalRadius = arrivalRadius, minDistance = minDistance, maxDistance = maxDistance, destinationType = destinationType, destinationTargetPosition = destinationTargetPosition, reachableOnly = reachableOnly, backupTeleportSettings = backupTeleportSettings, destinationTypeDescription = destinationTypeDescription}
end

--- Schedule a commands details to occur after the set delay.
---@param commandValues Teleport_CommandDetails
Teleport.ScheduleTeleportCommand = function(commandValues)
    global.teleport.nextId = global.teleport.nextId + 1
    EventScheduler.ScheduleEvent(
        game.tick + commandValues.delay,
        "Teleport.PlanTeleportTarget",
        global.teleport.nextId,
        {
            teleportId = global.teleport.nextId,
            target = commandValues.target,
            arrivalRadius = commandValues.arrivalRadius,
            minDistance = commandValues.minDistance,
            maxDistance = commandValues.maxDistance,
            destinationType = commandValues.destinationType,
            destinationTargetPosition = commandValues.destinationTargetPosition,
            reachableOnly = commandValues.reachableOnly,
            targetAttempt = 0,
            failedTargetPositions = {},
            backupTeleportSettings = commandValues.backupTeleportSettings,
            destinationTypeDescription = commandValues.destinationTypeDescription,
            thisAttemptPosition = nil,
            spawnerDistances = {}
        }
    )
end

--- When the actual teleport action needs to be planned and done (post scheduled delay).
---@param eventData any
Teleport.PlanTeleportTarget = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_teleport command "
    local data = eventData.data ---@type Teleport_TeleportDetails

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
        data.destinationTargetPosition = Utils.RandomLocationInRadius(targetPlayer.position, data.maxDistance, data.minDistance)
    elseif data.destinationType == DestinationTypeSelection.biterNest then
        -- TODO: use spawner force from cache. Cache other re-used data to reduce API calls.
        if data.targetAttempt > 1 then
            table.insert(data.failedTargetPositions, data.destinationTargetPosition)
        else
            for unitNumber, spawner in pairs(global.teleport.surfaceBiterNests[targetPlayer.surface.index]) do
                if not spawner.valid then
                    global.teleport.surfaceBiterNests[targetPlayer.surface.index][unitNumber] = nil
                elseif (not targetPlayer.force.get_cease_fire(spawner.force)) and (not targetPlayer.force.get_friend(spawner.force)) then
                    -- Not a friend or cease fire force, so enemy.
                    -- potential spawner isn't too close to a bad location already tried.
                    local spawnerDistance = Utils.GetDistance(targetPlayer.position, spawner.position)
                    if spawnerDistance <= data.maxDistance and spawnerDistance >= data.minDistance then
                        table.insert(data.spawnerDistances, {distance = spawnerDistance, spawner = spawner})
                    end
                end
            end
        end
        for index, spawnerDetails in pairs(data.spawnerDistances) do
            for _, badSpawnerPosition in pairs(data.failedTargetPositions) do
                if Utils.GetDistance(badSpawnerPosition, spawnerDetails.spawner.position) < 30 then
                    -- Target spawner is too close to a bad previous target attempt.
                    data.spawnerDistances[index] = nil
                    break
                end
            end
        end
        if #data.spawnerDistances == 0 then
            game.print({"message.muppet_streamer_teleport_no_biter_nest_found", targetPlayer.name})
            Teleport.DoBackupTeleport(data)
            return
        end
        if data.targetAttempt == 1 then
            table.sort(
                data.spawnerDistances,
                function(a, b)
                    return a.distance < b.distance
                end
            )
        end
        data.destinationTargetPosition = Utils.GetFirstTableValue(data.spawnerDistances).spawner.position
    elseif data.destinationType == DestinationTypeSelection.enemyUnit then
        data.destinationTargetPosition = targetPlayer.surface.find_nearest_enemy {position = targetPlayer.position, max_distance = data.maxDistance, force = targetPlayer.force}
        if data.destinationTargetPosition == nil then
            game.print({"message.muppet_streamer_teleport_no_enemy_unit_found", targetPlayer.name})
            Teleport.DoBackupTeleport(data)
            return
        end
    end

    data.targetPlayer = targetPlayer
    Teleport.PlanTeleportLocation(data)
end

--- Confirms if the vehicle is teleportable (non train).
---@param vehicle LuaEntity
---@return boolean isVehicleTeleportable
Teleport.IsTeleportableVehicle = function(vehicle)
    --TODO: check for internal function caching opportunities.
    return vehicle ~= nil and vehicle.valid and (vehicle.name == "car" or vehicle.name == "tank" or vehicle.name == "spider-vehicle")
end

--- Find a position near the target for the player to go and start a pathing request if enabled.
---@param data Teleport_TeleportDetails
Teleport.PlanTeleportLocation = function(data)
    local targetPlayer = data.targetPlayer
    local targetPlayerPathingEntity, targetPlayerPlacementEntity = targetPlayer.character, targetPlayer.character
    if Teleport.IsTeleportableVehicle(targetPlayer.vehicle) then
        targetPlayerPlacementEntity = targetPlayer.vehicle
    end

    local arrivalPos
    for _ = 1, MaxRandomPositionsAroundTarget do
        local randomPos = Utils.RandomLocationInRadius(data.destinationTargetPosition, data.arrivalRadius, 1)
        randomPos = Utils.RoundPosition(randomPos, 0) -- Make it tile border aligned as most likely place to get valid placements from when in a base. We search in whole tile increments from this tile border.
        arrivalPos = targetPlayer.surface.find_non_colliding_position(targetPlayerPlacementEntity.name, randomPos, MaxDistancePositionAroundTarget, 1, false)
        if arrivalPos ~= nil then
            break
        end
    end
    if arrivalPos == nil then
        if data.targetAttempt > MaxTargetAttempts then
            game.print({"message.muppet_streamer_teleport_no_teleport_location_found", targetPlayer.name})
            Teleport.DoBackupTeleport(data)
            return
        else
            Teleport.PlanTeleportTarget({data = data})
            return
        end
    end
    data.thisAttemptPosition = arrivalPos

    if data.reachableOnly then
        local pathRequestId =
            targetPlayer.surface.request_path {
            bounding_box = targetPlayerPathingEntity.prototype.collision_box, -- Work around for (unknown what the non-workaround code logic would be): https://forums.factorio.com/viewtopic.php?f=182&t=90146
            collision_mask = targetPlayerPathingEntity.prototype.collision_mask,
            start = arrivalPos,
            goal = targetPlayer.position,
            force = targetPlayer.force,
            radius = 1,
            can_open_gates = true,
            entity_to_ignore = targetPlayerPlacementEntity,
            pathfind_flags = {allow_paths_through_own_entities = true, cache = false}
        }
        global.teleport.pathingRequests[pathRequestId] = data
    else
        Teleport.Teleport(data)
    end
end

---@param event on_script_path_request_finished
Teleport.OnScriptPathRequestFinished = function(event)
    local data = global.teleport.pathingRequests[event.id]
    if data == nil then
        -- Not our path request
        return
    end

    global.teleport.pathingRequests[event.id] = nil
    local targetPlayer = data.targetPlayer
    if event.path == nil then
        -- Path request failed
        if data.targetAttempt > MaxTargetAttempts then
            game.print({"message.muppet_streamer_teleport_no_teleport_location_found", targetPlayer.name})
            Teleport.DoBackupTeleport(data)
        else
            Teleport.PlanTeleportTarget({data = data})
        end
    else
        Teleport.Teleport(data)
    end
end

--- Do the actual teleport of the target to the valid location.
---@param data Teleport_TeleportDetails
Teleport.Teleport = function(data)
    local targetPlayer = data.targetPlayer
    local teleportResult, wasDriving, wasPassengerIn
    if Teleport.IsTeleportableVehicle(targetPlayer.vehicle) then
        teleportResult = targetPlayer.vehicle.teleport(data.thisAttemptPosition)
    else
        if targetPlayer.vehicle ~= nil and targetPlayer.vehicle.valid then
            -- Player is in a non suitable vehicle, so get them out of it before teleporting.
            if targetPlayer.vehicle.get_driver() then
                wasDriving = targetPlayer.vehicle
            elseif targetPlayer.vehicle.get_passenger() then
                wasPassengerIn = targetPlayer.vehicle
            end
            targetPlayer.driving = false
        end
        teleportResult = targetPlayer.teleport(data.thisAttemptPosition)
    end
    if not teleportResult then
        if wasDriving then
            wasDriving.set_driver(targetPlayer)
        elseif wasPassengerIn then
            wasPassengerIn.set_passenger(targetPlayer)
        end
        game.print("Muppet Streamer Error - teleport failed")
        Teleport.DoBackupTeleport(data)
    end
end

--- Called when a higher priority teleport has failed. If theres a backup teleprot action that will be tried next.
---@param data Teleport_TeleportDetails
Teleport.DoBackupTeleport = function(data)
    if data.backupTeleportSettings ~= nil then
        game.print({"message.muppet_streamer_teleport_doing_backup", data.backupTeleportSettings.destinationTypeDescription, data.backupTeleportSettings.target})
        Teleport.ScheduleTeleportCommand(data.backupTeleportSettings)
    end
end

---@param event on_biter_base_built
Teleport.OnBiterBaseBuilt = function(event)
    local entity = event.entity
    if not entity.valid or entity.type ~= "unit-spawner" then
        return
    end
    Teleport.SpawnerCreated(entity)
end

---@param event script_raised_built
Teleport.ScriptRaisedBuilt = function(event)
    local entity = event.entity
    if not entity.valid or entity.type ~= "unit-spawner" then
        return
    end
    Teleport.SpawnerCreated(entity)
end

---@param event on_chunk_generated
Teleport.OnChunkGenerated = function(event)
    local area, surface = event.area, event.surface
    local spawners = surface.find_entities_filtered {area = area, type = "unit-spawner"}
    for _, spawner in pairs(spawners) do
        Teleport.SpawnerCreated(spawner)
    end
end

---@param event on_entity_died
Teleport.OnEntityDied = function(event)
    local entity = event.entity
    if not entity.valid or entity.type ~= "unit-spawner" then
        return
    end
    Teleport.SpawnerRemoved(entity)
end

---@param event script_raised_destroy
Teleport.ScriptRaisedDestroy = function(event)
    local entity = event.entity
    if not entity.valid or entity.type ~= "unit-spawner" then
        return
    end
    Teleport.SpawnerRemoved(entity)
end

--- Called when a spawner has been created and we need to add it to our records.
---@param spawner LuaEntity
Teleport.SpawnerCreated = function(spawner)
    -- Create the surface table if it doesn't exist. Happens when the surface is created adhock during play.
    local spawner_surface_index = spawner.surface.index
    local thisSurfaceBiterNests = global.teleport.surfaceBiterNests[spawner_surface_index]
    if thisSurfaceBiterNests == nil then
        global.teleport.surfaceBiterNests[spawner_surface_index] = {}
        thisSurfaceBiterNests = global.teleport.surfaceBiterNests[spawner_surface_index]
    end
    -- Record the spawner.
    thisSurfaceBiterNests[spawner.unit_number] = spawner
end

--- Called when a spawner has been removed from the map and we need to remove it from our records.
---@param spawner LuaEntity
Teleport.SpawnerRemoved = function(spawner)
    local thisSurfaceBiterNests = global.teleport.surfaceBiterNests[spawner.surface.index]
    if thisSurfaceBiterNests == nil then
        -- No records for this surface so nothing to remove. Shouldn't be possible to reach, but is safer.
        return
    end
    thisSurfaceBiterNests[spawner.unit_number] = nil
end

--- Find all existing spawners on all surfaces and record them. For use at mods initial load to handle being added to a map mid game.
---@return table<Id, table<UnitNumber, LuaEntity>> surfaceBiterNests
Teleport.FindExistingSpawnersOnAllSurfaces = function()
    local surfaceNests = {} ---@type table<Id, table<UnitNumber, LuaEntity>>
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        surfaceNests[surface_index] = surfaceNests[surface_index] or {}
        local spawners = surface.find_entities_filtered {type = "unit-spawner"}
        for _, spawner in pairs(spawners) do
            surfaceNests[surface_index][spawner.unit_number] = spawner
        end
    end
    return surfaceNests
end

return Teleport
