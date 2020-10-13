local SpawnAroundPlayer = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local BiomeTrees = require("utility/functions/biome-trees")

SpawnAroundPlayer.CreateGlobals = function()
    global.spawnAroundPlayer = global.spawnAroundPlayer or {}
    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId or 0
end

SpawnAroundPlayer.OnLoad = function()
    Commands.Register("muppet_streamer_spawn_around_player", {"api-description.muppet_streamer_spawn_around_player"}, SpawnAroundPlayer.SpawnAroundPlayerCommand, true)
    EventScheduler.RegisterScheduledEventType("SpawnAroundPlayer.SpawnAroundPlayerScheduled", SpawnAroundPlayer.SpawnAroundPlayerScheduled)
end

SpawnAroundPlayer.OnStartup = function()
end

SpawnAroundPlayer.SpawnAroundPlayerCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_spawn_around_player command "
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

    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "SpawnAroundPlayer.SpawnAroundPlayerScheduled", global.spawnAroundPlayer.nextId, {target = target, entityName = entityName, radiusMax = radiusMax, radiusMin = radiusMin, existingEntities = existingEntities, quantity = quantity, density = density, ammoCount = ammoCount, followPlayer = followPlayer})
end

SpawnAroundPlayer.SpawnAroundPlayerScheduled = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_spawn_around_player command "
    local data = eventData.data

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    local targetPos, surface, followsLeft = targetPlayer.position, targetPlayer.surface, 0
    local entityTypeDetails = SpawnAroundPlayer.EntityTypeDetails[data.entityName]
    if data.followPlayer and entityTypeDetails.followPlayerMax ~= nil then
        followsLeft = entityTypeDetails.followPlayerMax(targetPlayer)
    end

    if data.quantity ~= nil then
        local placed, targetPlaced, attempts, maxAttempts = 0, data.quantity, 0, data.quantity * 5
        while placed < targetPlaced do
            local position = Utils.RandomLocationInRadius(targetPos, data.radiusMax, data.radiusMin)
            local entityName = entityTypeDetails.getEntityName(surface, position)
            if entityName ~= nil then
                local entityAlignedPosition = entityTypeDetails.getEntityAlignedPosition(position)
                if data.existingEntities == "avoid" then
                    entityAlignedPosition = entityTypeDetails.searchPlacement(surface, entityName, entityAlignedPosition, SpawnAroundPlayer.quantitySearchRadius)
                end
                if entityAlignedPosition ~= nil then
                    local thisOneFollows = false
                    if followsLeft > 0 then
                        thisOneFollows = true
                        followsLeft = followsLeft - 1
                    end
                    entityTypeDetails.placeEntity(surface, entityName, entityAlignedPosition, targetPlayer, data.ammoCount, thisOneFollows)
                    placed = placed + 1
                end
            end
            attempts = attempts + 1
            if attempts >= maxAttempts then
                break
            end
        end
    elseif data.density ~= nil then
        local followsLeftTable = {followsLeft} -- Do as table so it can be passed by reference in to functions
        -- Do outer perimiter first
        for yOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
            SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, 1, yOffset, followsLeftTable)
            SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, -1, yOffset, followsLeftTable)
        end
        if data.radiusMin ~= data.radiusMax then
            -- Fill in between circles
            for yOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                for xOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                    local placementPos = Utils.ApplyOffsetToPosition({x = xOffset, y = yOffset}, targetPos)
                    if Utils.IsPositionWithinCircled(targetPos, data.radiusMax, placementPos) and not Utils.IsPositionWithinCircled(targetPos, data.radiusMin, placementPos) then
                        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, placementPos, surface, targetPlayer, data, followsLeftTable)
                    end
                end
            end
        end
    end
end

SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine = function(entityTypeDetails, data, targetPos, surface, targetPlayer, radius, lineSlope, lineYOffset, followsLeftTable)
    local crossPos1, crossPos2 = Utils.FindWhereLineCrossesCircle(radius, lineSlope, lineYOffset)
    if crossPos1 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, Utils.ApplyOffsetToPosition(crossPos1, targetPos), surface, targetPlayer, data, followsLeftTable)
    end
    if crossPos2 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, Utils.ApplyOffsetToPosition(crossPos2, targetPos), surface, targetPlayer, data, followsLeftTable)
    end
end

SpawnAroundPlayer.PlaceEntityNearPosition = function(entityTypeDetails, position, surface, targetPlayer, data, followsLeftTable)
    if math.random() > data.density then
        return
    end
    local entityName = entityTypeDetails.getEntityName(surface, position)
    if entityName == nil then
        --no tree name is suitable for this tile, likely non land tile
        return
    end
    local entityAlignedPosition = entityTypeDetails.getEntityAlignedPosition(position)
    if data.existingEntities == "avoid" then
        entityAlignedPosition = entityTypeDetails.searchPlacement(surface, entityName, entityAlignedPosition, SpawnAroundPlayer.densitySearchRadius)
    end
    local thisOneFollows = false
    if followsLeftTable[1] > 0 then
        thisOneFollows = true
        followsLeftTable[1] = followsLeftTable[1] - 1
    end
    if entityAlignedPosition ~= nil then
        entityTypeDetails.placeEntity(surface, entityName, entityAlignedPosition, targetPlayer, data.ammoCount, thisOneFollows)
    end
end

SpawnAroundPlayer.quantitySearchRadius = 3
SpawnAroundPlayer.densitySearchRadius = 0.6
SpawnAroundPlayer.offgridPlacementJitter = 0.3

SpawnAroundPlayer.EntityTypeDetails = {
    tree = {
        getEntityName = function(surface, position)
            return BiomeTrees.GetBiomeTreeName(surface, position)
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, _, _)
            surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
        end
    },
    rock = {
        getEntityName = function()
            local random = math.random()
            if random < 0.2 then
                return "rock-huge"
            elseif random < 0.6 then
                return "rock-big"
            else
                return "sand-rock-big"
            end
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 2,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, _, _, _)
            surface.create_entity {name = entityName, position = position, force = "neutral"}
        end
    },
    laserTurret = {
        getEntityName = function()
            return "laser-turret"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RoundPosition(position)
        end,
        gridPlacementSize = 2,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, _, _)
            surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
        end
    },
    gunTurretRegularAmmo = {
        getEntityName = function()
            return "gun-turret"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RoundPosition(position)
        end,
        gridPlacementSize = 2,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, ammoCount, _)
            local turret = surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
            if turret ~= nil then
                turret.insert({name = "firearm-magazine", count = ammoCount})
            end
        end
    },
    gunTurretPiercingAmmo = {
        getEntityName = function()
            return "gun-turret"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RoundPosition(position)
        end,
        gridPlacementSize = 2,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, ammoCount, _)
            local turret = surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
            if turret ~= nil then
                turret.insert({name = "piercing-rounds-magazine", count = ammoCount})
            end
        end
    },
    gunTurretUraniumAmmo = {
        getEntityName = function()
            return "gun-turret"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RoundPosition(position)
        end,
        gridPlacementSize = 2,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, ammoCount, _)
            local turret = surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
            if turret ~= nil then
                turret.insert({name = "uranium-rounds-magazine", count = ammoCount})
            end
        end
    },
    wall = {
        getEntityName = function()
            return "stone-wall"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RoundPosition(position)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1, true)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, _, _)
            surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
        end
    },
    landmine = {
        getEntityName = function()
            return "land-mine"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1, true)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, _, _)
            surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
        end
    },
    fire = {
        getEntityName = function()
            return "fire-flame"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, _, ammoCount, _)
            if ammoCount ~= nil then
                ammoCount = math.min(ammoCount, 250)
            end
            surface.create_entity {name = entityName, position = position, force = "neutral", initial_ground_flame_count = ammoCount}
        end
    },
    defenderBot = {
        getEntityName = function()
            return "defender"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, _, followPlayer)
            local target
            if followPlayer then
                target = targetPlayer.character
            end
            surface.create_entity {name = entityName, position = position, force = targetPlayer.force, target = target}
        end,
        followPlayerMax = function(targetPlayer)
            return SpawnAroundPlayer.GetPlayerMaxBotFollows(targetPlayer)
        end
    },
    distractorBot = {
        getEntityName = function()
            return "distractor"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, _, _)
            surface.create_entity {name = entityName, position = position, force = targetPlayer.force}
        end
    },
    destroyerBot = {
        getEntityName = function()
            return "destroyer"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, targetPlayer, _, followPlayer)
            local target
            if followPlayer then
                target = targetPlayer.character
            end
            surface.create_entity {name = entityName, position = position, force = targetPlayer.force, target = target}
        end,
        followPlayerMax = function(targetPlayer)
            return SpawnAroundPlayer.GetPlayerMaxBotFollows(targetPlayer)
        end
    }
}

SpawnAroundPlayer.GetPlayerMaxBotFollows = function(targetPlayer)
    if targetPlayer.character == nil then
        return 0
    end
    local max = targetPlayer.character_maximum_following_robot_count_bonus + targetPlayer.force.maximum_following_robot_count
    local current = #targetPlayer.following_robots
    return max - current
end

return SpawnAroundPlayer
