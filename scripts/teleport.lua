local Teleport = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Events = require("utility/events")

---@class Teleport_DestinationTypeSelection
local DestinationTypeSelection = {random = "random", biterNest = "biterNest", enemyUnit = "enemyUnit", spawn = "spawn", position = "position"}

---@class Teleport_DestinationTypeSelectionDescription
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
---@field destinationTypeDescription Teleport_DestinationTypeSelectionDescription

---@class Teleport_TeleportDetails @ The data on a teleport action being undertaken. This includes the attributes from the first Teleport_CommandDetails within it directly.
---@field teleportId uint
---@field target string
---@field targetPlayer LuaPlayer
---@field arrivalRadius double
---@field minDistance double
---@field maxDistance double
---@field destinationType Teleport_DestinationTypeSelection
---@field destinationTargetPosition MapPosition|null
---@field reachableOnly boolean
---@field targetAttempt uint
---@field backupTeleportSettings Teleport_CommandDetails|null
---@field destinationTypeDescription Teleport_DestinationTypeSelectionDescription
---@field thisAttemptPosition MapPosition|null @ The map position of the current teleport attempt.
---@field spawnerDistances table<uint, Teleport_TargetPlayerSpawnerDistanceDetails> @ If destinationType is biterNest then populated when looking for a spawner to target, otherwise empty. Key'd as a gappy numerial order. The enemy spawners found on this surface from our spawner list and the distance they are from the player's current position.

---@class Teleport_TargetPlayerSpawnerDistanceDetails
---@field distance double
---@field spawnerDetails Teleport_SpawnerDetails

---@class Teleport_SpawnerDetails
---@field unitNumber UnitNumber
---@field entity LuaEntity
---@field position MapPosition
---@field forceName string

---@alias surfaceForceBiterNests table<Id, table<string, table<UnitNumber, Teleport_SpawnerDetails>>> @ A table of surface index numbers, to tables of force names, to spawner's details key'd by their unit number. Allows easy filtering to current surface and then bacth ignoring of non-enemy spawners.

Teleport.CreateGlobals = function()
    global.teleport = global.teleport or {}
    global.teleport.nextId = global.teleport.nextId or 0 ---@type uint
    global.teleport.pathingRequests = global.teleport.pathingRequests or {} ---@type table<Id, Teleport_TeleportDetails> @ The path request Id to its teleport details for whne the path request completes.
    global.teleport.surfaceBiterNests = global.teleport.surfaceBiterNests or Teleport.FindExistingSpawnersOnAllSurfaces() ---@type surfaceForceBiterNests
    global.teleport.chunkGeneratedId = global.teleport.chunkGeneratedId or 0 ---@type uint
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
    EventScheduler.RegisterScheduledEventType("Teleport.OnChunkGenerated_Scheduled", Teleport.OnChunkGenerated_Scheduled)
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
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local commandValues = Teleport.GetCommandData(commandData, errorMessageStart, 0, command.parameter)
    if commandValues == nil then
        return
    end

    Teleport.ScheduleTeleportCommand(commandValues)
end

--- Validates the data from an RCON commands's arguments in to a table of details.
---@param commandData table @ Table of arguments passed in to the RCON command.
---@param errorMessageStart string
---@param depth uint @ Used when looping recursively in to backup settings. Populate as 0 for the initial calling of the function in the raw RCON command handler.
---@param commandStringText string @ The raw command text sent via RCON.
---@return Teleport_CommandDetails commandDetails
Teleport.GetCommandData = function(commandData, errorMessageStart, depth, commandStringText)
    local depthErrorMessage = ""
    if depth > 0 then
        depthErrorMessage = "at depth " .. depth .. " - "
    end

    local delay = 0
    if commandData.delay ~= nil then
        delay = tonumber(commandData.delay)
        if delay == nil then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "delay is Optional, but must be a non-negative number if supplied")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
            return
        end
        delay = math.max(delay * 60, 0)
    end

    local target = commandData.target
    if target == nil then
        Logging.LogPrint(errorMessageStart .. "target is mandatory")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
        return
    elseif game.get_player(target) == nil then
        Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "target is invalid player name")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
        return
    end

    local destinationTypeRaw = commandData.destinationType
    local destinationType, destinationTargetPosition = DestinationTypeSelection[destinationTypeRaw], nil
    if destinationType == nil then
        destinationTargetPosition = Utils.TableToProperPosition(destinationTypeRaw)
        if destinationTargetPosition == nil then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "destinationType is Mandatory and must be a valid type or a table for position")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
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
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
            return
        end
    end

    local minDistanceRaw, minDistance = commandData.minDistance, 0
    if minDistanceRaw ~= nil then
        minDistance = tonumber(minDistanceRaw)
        if minDistance == nil or minDistance < 0 then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "minDistance is Optional, but if supplied must be 0 or greater")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
            return
        end
    end

    local maxDistance = tonumber(commandData.maxDistance)
    if destinationType == DestinationTypeSelection.position or destinationType == DestinationTypeSelection.spawn then
        maxDistance = 0
    elseif maxDistance == nil or maxDistance < 0 then
        Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "maxDistance is Mandatory, must be 0 or greater")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
        return
    end

    local reachableOnly = false
    if commandData.reachableOnly ~= nil then
        reachableOnly = Utils.ToBoolean(commandData.reachableOnly)
        if reachableOnly == nil then
            Logging.LogPrint(errorMessageStart .. "reachableOnly is Optional, but if provided must be a boolean")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
            return
        elseif reachableOnly == true and not (destinationType == DestinationTypeSelection.biterNest or destinationType == DestinationTypeSelection.random) then
            Logging.LogPrint(errorMessageStart .. depthErrorMessage .. "reachableOnly is enabled set for unsupported destinationType")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. commandStringText)
            return
        end
    end

    local backupTeleportSettingsRaw, backupTeleportSettings = commandData.backupTeleportSettings, nil
    if backupTeleportSettingsRaw ~= nil and type(backupTeleportSettingsRaw) == "table" then
        backupTeleportSettings = Teleport.GetCommandData(backupTeleportSettingsRaw, errorMessageStart, depth + 1, commandStringText)
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
            backupTeleportSettings = commandValues.backupTeleportSettings,
            destinationTypeDescription = commandValues.destinationTypeDescription,
            thisAttemptPosition = nil,
            spawnerDistances = {}
        }
    )
end

--- When the actual teleport action needs to be planned and done (post scheduled delay).
--- Refereshs all player data on each load as waiting for pathfinder requests can make subsequent executions have different player stata data.
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
        ---@typelist uint, LuaForce, MapPosition
        local targetPlayer_surface_index, targetPlayer_force, targetPlayer_position = targetPlayer.surface.index, targetPlayer.force, targetPlayer.position
        local targetPlayer_force_name = targetPlayer_force.name

        -- Populate data.spawnerDistance with valid enemy spawners on the player's current surface if needed, otherwise handle last bad result.
        if data.targetAttempt > 1 then
            -- This target position has been found to be bad so remove any spawners too close to this bad location for this player.
            ---@typelist double, double, double
            local distanceXDiff, distanceYDiff, spawnerDistance
            for index, spawnerDistanceDetails in pairs(data.spawnerDistances) do
                -- CODE NOTE: Do locally rather than via function call as we call this a lot and its so simple logic.
                distanceXDiff = targetPlayer_position.x - spawnerDistanceDetails.spawnerDetails.position.x
                distanceYDiff = targetPlayer_position.y - spawnerDistanceDetails.spawnerDetails.position.y
                spawnerDistance = math.sqrt(distanceXDiff * distanceXDiff + distanceYDiff * distanceYDiff)
                --if Utils.GetDistance(data.destinationTargetPosition, spawnerDistanceDetails.spawnerDetails.position) < 30 then
                if spawnerDistance < 30 then
                    -- Potential spawner is too close to a bad previous target attempt, so remove it from our list.
                    data.spawnerDistances[index] = nil
                end
            end
        else
            -- Is a first loop for this target player so build up the spawner list.
            ---@typelist double, double, double
            local spawnerDistance, distanceXDiff, distanceYDiff
            for spawnersForceName, forcesSpawnerDetails in pairs(global.teleport.surfaceBiterNests[targetPlayer_surface_index]) do
                -- Check the force is an enemy. So we ignore all non-enemy spawners in bulk.
                if targetPlayer_force_name ~= spawnersForceName and spawnersForceName ~= "neutral" and not targetPlayer_force.get_cease_fire(spawnersForceName) and not targetPlayer_force.get_friend(spawnersForceName) then
                    for _, spawnerDetails in pairs(forcesSpawnerDetails) do
                        -- Work out it's distance from the target player and add it to our table.

                        -- CODE NOTE: Do locally rather than via function call as we call this a lot and its so simple logic.
                        distanceXDiff = targetPlayer_position.x - spawnerDetails.position.x
                        distanceYDiff = targetPlayer_position.y - spawnerDetails.position.y
                        spawnerDistance = math.sqrt(distanceXDiff * distanceXDiff + distanceYDiff * distanceYDiff)
                        --spawnerDistance = Utils.GetDistance(targetPlayer_position, spawnerDetails.position)

                        if spawnerDistance <= data.maxDistance and spawnerDistance >= data.minDistance then
                            table.insert(data.spawnerDistances, {distance = spawnerDistance, spawnerDetails = spawnerDetails}) -- While this is inserted as consistent key ID's it can be manipulated later to be gappy.
                        end
                    end
                end
            end
        end

        -- Handle if no valid spawners to try.
        if next(data.spawnerDistances) == nil then
            game.print({"message.muppet_streamer_teleport_no_biter_nest_found", targetPlayer.name})
            Teleport.DoBackupTeleport(data)
            return
        end

        -- Sort the spawners to find the nearest one and set it as the target position.
        if data.targetAttempt == 1 then
            table.sort(
                data.spawnerDistances,
                function(a, b)
                    return a.distance < b.distance
                end
            )
        end

        -- Check the nearest one is still valid. Do this way as unless its the spawner we are aiming for it doesn't matter if its invalid.
        ---@typelist uint, Teleport_TargetPlayerSpawnerDistanceDetails
        local firstSpawnerDistancesIndex, nearestSpawnerDistanceDetails
        while nearestSpawnerDistanceDetails == nil do
            firstSpawnerDistancesIndex = next(data.spawnerDistances)
            nearestSpawnerDistanceDetails = data.spawnerDistances[firstSpawnerDistancesIndex]
            if nearestSpawnerDistanceDetails == nil then
                -- Have already removed the last possible spawner as its invalid, so no valid targets.
                game.print({"message.muppet_streamer_teleport_no_biter_nest_found", targetPlayer.name})
                Teleport.DoBackupTeleport(data)
                return
            end
            ---@cast nearestSpawnerDistanceDetails Teleport_TargetPlayerSpawnerDistanceDetails

            -- Check if the nearest spawner is still valid. Its possible to remove spawners without us knowing about it, i.e. via Editor or via script and not raising an event for it. So we have to check.
            if not nearestSpawnerDistanceDetails.spawnerDetails.entity.valid then
                -- Remove the spawner from this search.
                data.spawnerDistances[firstSpawnerDistancesIndex] = nil

                -- Remove the spawner from the global spawner lsit.
                global.teleport.surfaceBiterNests[targetPlayer_surface_index][nearestSpawnerDistanceDetails.spawnerDetails.forceName][nearestSpawnerDistanceDetails.spawnerDetails.unitNumber] = nil

                -- Clear the spawner result so the while loop continues to look at the nearest remaining one.
                nearestSpawnerDistanceDetails = nil
            end
        end

        -- Set the target position to the valid spawner.
        data.destinationTargetPosition = nearestSpawnerDistanceDetails.spawnerDetails.position
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
    if vehicle == nil or not vehicle.valid then
        return false
    end
    local vehicle_type = vehicle.type
    if vehicle_type == "car" or vehicle_type == "spider-vehicle" then
        return true
    else
        return false
    end
end

--- Find a position near the target for the player to go and start a pathing request if enabled.
--- Refereshs all player data on each load as waiting for pathfinder requests can make subsequent executions have different player stata data.
---@param data Teleport_TeleportDetails
Teleport.PlanTeleportLocation = function(data)
    local targetPlayer = data.targetPlayer
    local targetPlayer_character = targetPlayer.character
    local targetPlayerPathingEntity, targetPlayerPlacementEntity = targetPlayer_character, targetPlayer_character

    local targetPlayer_vehicle = targetPlayer.vehicle
    if Teleport.IsTeleportableVehicle(targetPlayer_vehicle) then
        targetPlayerPlacementEntity = targetPlayer_vehicle
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
        -- Create the path request. We use the player's real character for this as in worst case they can get out of their vehicle and walk back through the narrow terrain.
        local targetPlayerPathingEntity_prototype = targetPlayerPathingEntity.prototype
        local pathRequestId =
            targetPlayer.surface.request_path {
            bounding_box = targetPlayerPathingEntity_prototype.collision_box,
            collision_mask = targetPlayerPathingEntity_prototype.collision_mask,
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
    local targetPlayer_vehicle = targetPlayer.vehicle
    if Teleport.IsTeleportableVehicle(targetPlayer_vehicle) then
        teleportResult = targetPlayer_vehicle.teleport(data.thisAttemptPosition)
    else
        if targetPlayer_vehicle ~= nil and targetPlayer_vehicle.valid then
            -- Player is in a non suitable vehicle, so get them out of it before teleporting.
            if targetPlayer_vehicle.get_driver() then
                wasDriving = targetPlayer_vehicle
            elseif targetPlayer_vehicle.get_passenger() then
                wasPassengerIn = targetPlayer_vehicle
            end
            targetPlayer.driving = false
        end
        teleportResult = targetPlayer.teleport(data.thisAttemptPosition)
    end

    -- If the teleport failed then put the player back in their non teleportable vehicle.
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
    global.teleport.chunkGeneratedId = global.teleport.chunkGeneratedId + 1
    -- Check the chunk in 1 ticks time to let any other mod or scenario complete its actions first.
    EventScheduler.ScheduleEvent(event.tick + 1, "Teleport.OnChunkGenerated_Scheduled", global.teleport.chunkGeneratedId, event)
end

--- When a chunk is generated we wait for 1 tick and then this function is called. Lets any other mod/scenario mess with the spawner prior to use caching its details.
---@param eventData any
Teleport.OnChunkGenerated_Scheduled = function(eventData)
    local event = eventData.data ---@type on_chunk_generated
    local spawners = event.surface.find_entities_filtered {area = event.area, type = "unit-spawner"}
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
    global.teleport.surfaceBiterNests[spawner_surface_index] = global.teleport.surfaceBiterNests[spawner_surface_index] or {}
    -- Record the spawner.
    local spawner_unitNumber, spawner_force_name = spawner.unit_number, spawner.force.name
    global.teleport.surfaceBiterNests[spawner_surface_index][spawner_force_name] = global.teleport.surfaceBiterNests[spawner_surface_index][spawner_force_name] or {}
    global.teleport.surfaceBiterNests[spawner_surface_index][spawner_force_name][spawner_unitNumber] = {unitNumber = spawner_unitNumber, entity = spawner, forceName = spawner_force_name, position = spawner.position}
end

--- Called when a spawner has been removed from the map and we need to remove it from our records.
---@param spawner LuaEntity
Teleport.SpawnerRemoved = function(spawner)
    local thisSurfaceBiterNests = global.teleport.surfaceBiterNests[spawner.surface.index]
    if thisSurfaceBiterNests == nil then
        -- No records for this surface so nothing to remove. Shouldn't be possible to reach, but is safer.
        return
    end
    local thisSurfaceForceBiterNests = thisSurfaceBiterNests[spawner.force.name]
    if thisSurfaceForceBiterNests == nil then
        -- No records for this force on this surface so nothing to remove. Shouldn't be possible to reach, but is safer.
        return
    end
    thisSurfaceForceBiterNests[spawner.unit_number] = nil
end

--- Find all existing spawners on all surfaces and record them. For use at mods initial load to handle being added to a map mid game.
---@return surfaceForceBiterNests surfacesSpawners
Teleport.FindExistingSpawnersOnAllSurfaces = function()
    local surfacesSpawners = {} ---@type surfaceForceBiterNests
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        surfacesSpawners[surface_index] = {}
        local spawners = surface.find_entities_filtered {type = "unit-spawner"}
        for _, spawner in pairs(spawners) do
            local spawner_unitNumber, spawner_force_name = spawner.unit_number, spawner.force.name
            surfacesSpawners[surface_index][spawner_force_name] = surfacesSpawners[surface_index][spawner_force_name] or {}
            surfacesSpawners[surface_index][spawner_force_name][spawner_unitNumber] = {unitNumber = spawner_unitNumber, entity = spawner, forceName = spawner_force_name, position = spawner.position}
        end
    end
    return surfacesSpawners
end

return Teleport
