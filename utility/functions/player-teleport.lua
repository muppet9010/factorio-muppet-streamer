--[[
    Can teleport a player to near a target. Handles vehicles, finding valid placements and checking walkable paths based on settings.

    Usage: Call any public functions (not starting with "_") as required to request a teleport for a player. Other public functions can also be utilised as required.
]]
local MathUtils = require("utility.helper-utils.math-utils")
local PositionUtils = require("utility.helper-utils.position-utils")

local PlayerTeleport = {}

----------------------------------------------------------------------------------
--                          PUBLIC FUNCTIONS
----------------------------------------------------------------------------------

--- Request a teleport for a player with the provided settings. If everything is good it will teleport the player if no reachablePosition is provided now, otherwise it will return the pathfinder request Id for monitoring by the calling mod. In failure scenario an error object is returned with details of the failures cause.
---@param targetPlayer LuaPlayer @ The player to teleport.
---@param targetSurface LuaSurface @ The surface to teleport them too.
---@param destinationTargetPosition MapPosition @ The position on the map to teleport them near.
---@param inaccuracyToTargetPosition double @ How inaccurate the desired random placement of the player to the target position should be up too. Used to give intentional inaccuracy to the placement attempt position.
---@param placementAttempts int @ How many times we should try random placement attempts within the inaccuracy of the target.
---@param placementAccuracy double @ Max range from the placement attempt position to look for a valid position for the player within. Code will try and place as close to the placement attempt position as possible.
---@param reachablePosition? MapPosition|nil @ If the player needs to be able to walk from where they are teleported too, to this position. Commonly used to check they can walk from their teleport target back to where they were, to avoid teleports on to islands. If provided then the path request Id will be returned in the responseDetails for monitoring by the calling mod. As the state of the player and target should be re-verified by the mod based on its exact usage scenario upon this pathing request completing; As the game world will likely have changed in between and so it may not be approperiate for the teleport to be completed.
---@return UtilityPlayerTeleport_TeleportRequestResponseDetails responseDetails? @ A table with details of the teleport request, including if the teleport was succeeded, if a pathing request was made its Id, any error if one occured.
PlayerTeleport.RequestTeleportToNearPosition = function(targetPlayer, targetSurface, destinationTargetPosition, inaccuracyToTargetPosition, placementAttempts, placementAccuracy, reachablePosition)
    -- The response object with the result in it.
    ---@type UtilityPlayerTeleport_TeleportRequestResponseDetails
    local responseDetails = {
        --targetPlayerTeleportEntity = nil @ Always populated later in function.
        targetPosition = nil,
        teleportSucceeded = false,
        pathRequestId = nil,
        errorNoValidPositionFound = false
    }

    -- Get the working data.
    local targetPlayer_force = targetPlayer.force
    local targetPlayer_character = targetPlayer.character
    local targetPlayerPlacementEntity, targetPlayerPlacementEntity_isVehicle = PlayerTeleport.GetPlayerTeleportPlacementEntity(targetPlayer, targetPlayer_character)

    -- If a vehicle, get its current nearest cardinal direction (4 direction) to orientation.
    -- CODE NOTE: This isn't perfect, but is better than nothing until this Interface Request is done: https://forums.factorio.com/viewtopic.php?f=28&t=102792
    local playersVehicle_directionToCheck  ---@type defines.direction|nil
    if targetPlayerPlacementEntity_isVehicle then
        playersVehicle_directionToCheck = MathUtils.RoundNumberToDecimalPlaces(targetPlayerPlacementEntity.orientation * 4, 0) * 2 --[[@as defines.direction]]
    end

    -- Record the current placement entity for checking post path request.
    responseDetails.targetPlayerTeleportEntity = targetPlayerPlacementEntity

    local arrivalPos
    local randomPositionsToTry = math.max(1, math.min(placementAttempts, inaccuracyToTargetPosition ^ inaccuracyToTargetPosition)) -- Avoid looking around lots of positions all within very small arrival radiuses of the target. The arrival radius can be as low as 0.
    for _ = 1, randomPositionsToTry do
        -- Select a random position near the target and look for a valid placement near it.
        local randomPos = PositionUtils.RandomLocationInRadius(destinationTargetPosition, inaccuracyToTargetPosition, 1)
        randomPos = PositionUtils.RoundPosition(randomPos, 0) -- Make it tile border aligned as most likely place to get valid placements from when in a base. We search in whole tile increments from this tile border.
        arrivalPos = targetSurface.find_non_colliding_position(targetPlayerPlacementEntity.name, randomPos, placementAccuracy, 1.0, false)

        if playersVehicle_directionToCheck ~= nil then
            -- Check the entity can be placed with its current nearest cardinal direction to orientation, as the searching API doesn't check for this.
            if arrivalPos ~= nil and not targetSurface.can_place_entity {name = targetPlayerPlacementEntity.name, position = arrivalPos, direction = playersVehicle_directionToCheck, force = targetPlayer_force, build_check_type = defines.build_check_type.manual} then
                -- Can't be placed here. As we can't exclude this location from a find_non_colliding_position, we have to declare this entire random position bad and try a new random location.
                arrivalPos = nil
            end
        end

        -- If the arrivalPos is still populated then its good.
        if arrivalPos ~= nil then
            break
        end
    end
    if arrivalPos == nil then
        responseDetails.errorNoValidPositionFound = true
        return responseDetails
    end
    responseDetails.targetPosition = arrivalPos

    -- Either do a path request to check the position found if reachable is enabled, otherwise just do the teleport action now.
    if reachablePosition ~= nil then
        -- Create the path request. We use the player's real character for this as in worst case they can get out of their vehicle and walk back through the narrow terrain.
        local targetPlayer_character_prototype = targetPlayer_character.prototype
        local pathRequestId =
            targetSurface.request_path {
            bounding_box = targetPlayer_character_prototype.collision_box,
            collision_mask = targetPlayer_character_prototype.collision_mask,
            start = arrivalPos,
            goal = reachablePosition,
            force = targetPlayer_force,
            radius = 1.0,
            can_open_gates = true,
            entity_to_ignore = targetPlayerPlacementEntity,
            pathfind_flags = {allow_paths_through_own_entities = true, cache = false}
        }
        responseDetails.pathRequestId = pathRequestId
        return responseDetails
    else
        responseDetails.teleportSucceeded = PlayerTeleport.TeleportToSpecificPosition(targetPlayer, targetSurface, arrivalPos)
        if not responseDetails.teleportSucceeded then
            responseDetails.errorTeleportFailed = true
        end
        return responseDetails
    end
end

--- Do the actual teleport of the target player to the specified location. Will handle taking the players vehcile with them or removing them from a non teleportable vehicle (train) as required.
--- For calling in known good conditions or in response to a successful pathing request response and post state validation.
--- If the teleport action fails the player is left in a good state; returned to any vehicle they left.
---@param targetPlayer LuaPlayer @ The player to teleport.
---@param targetSurface LuaSurface @ The surface to teleport them too.
---@param targetPosition MapPosition @ The exact position on the map to teleport them to.
---@return boolean teleportSucceeded @ If the actual teleport command to the player/vehicle failed.
PlayerTeleport.TeleportToSpecificPosition = function(targetPlayer, targetSurface, targetPosition)
    local teleportSucceeded, wasDriving, wasPassengerIn
    local targetPlayer_vehicle = targetPlayer.vehicle

    -- Teleport the approperiate entity to the specified position.
    if PlayerTeleport.IsTeleportableVehicle(targetPlayer_vehicle) then
        teleportSucceeded = targetPlayer_vehicle.teleport(targetPosition, targetSurface)
    else
        if targetPlayer_vehicle ~= nil and targetPlayer_vehicle.valid then
            -- Player is in a non teleportable vehicle, so get them out of it before teleporting the player (character).
            if targetPlayer_vehicle.get_driver() then
                wasDriving = targetPlayer_vehicle
            elseif targetPlayer_vehicle.get_passenger() then
                wasPassengerIn = targetPlayer_vehicle
            end
            targetPlayer.driving = false
        end
        teleportSucceeded = targetPlayer.teleport(targetPosition, targetSurface)
    end

    -- If the teleport failed and the player was in a non teleportable vehicle, put them back in their seat.
    if not teleportSucceeded then
        if wasDriving then
            wasDriving.set_driver(targetPlayer)
        elseif wasPassengerIn then
            wasPassengerIn.set_passenger(targetPlayer)
        end
    end

    return teleportSucceeded
end

--- Confirms if the vehicle is teleportable (non train).
---@param vehicle LuaEntity
---@return boolean isVehicleTeleportable
PlayerTeleport.IsTeleportableVehicle = function(vehicle)
    if vehicle == nil then
        return false
    end
    local vehicle_type = vehicle.type
    if vehicle_type == "car" or vehicle_type == "spider-vehicle" then
        return true
    else
        return false
    end
end

--- Get the entity that will be placed when the teleport is done, either a teleportable vehicle or the players character.
---@param targetPlayer LuaPlayer
---@param targetPlayer_character? LuaEntity|nil @ If nil is passed in and the player's character entity is needed it will be obtained.
---@return LuaEntity placementEntity
---@return boolean isVehicle
PlayerTeleport.GetPlayerTeleportPlacementEntity = function(targetPlayer, targetPlayer_character)
    local targetPlayer_vehicle = targetPlayer.vehicle
    if PlayerTeleport.IsTeleportableVehicle(targetPlayer_vehicle) then
        return targetPlayer_vehicle, true
    else
        return targetPlayer_character or targetPlayer.character, false
    end
end

----------------------------------------------------------------------------------
--                          PRIVATE FUNCTIONS
----------------------------------------------------------------------------------

---@class UtilityPlayerTeleport_TeleportRequestResponseDetails @ A table with details of the teleport request, including if the teleport was succeeded, if a pathing request was made its Id, any error if one occured.
---@field targetPlayerTeleportEntity LuaEntity @ The entity we did the teleport request for.
---@field targetPosition? MapPosition|nil @ The exact position the teleport was attempted to, if one was found.
---@field teleportSucceeded boolean @ If the teleport was completed. Will be false if a pathing request was made as part of a reachablePosition option.
---@field pathRequestId? uint|nil @ If a reachablePosition was given then the path request Id to monitor for is returned. The state of the player and target should be re-verified upon this pathing request result as the game worls will likely have changed in between and so it may not be approperiate for the teleport to be completed.
---@field errorNoValidPositionFound boolean @ If the teleport failed as there was no valid position found near the target position (prior to any walkability check if enabled).
---@field errorTeleportFailed boolean @ If the actual teleport command to the player/vehicle failed.

return PlayerTeleport
