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

    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId + 1
    EventScheduler.ScheduleEvent(
        command.tick + delay,
        "SpawnAroundPlayer.SpawnAroundPlayerScheduled",
        global.spawnAroundPlayer.nextId,
        {target = target, entityName = entityName, radiusMax = radiusMax, radiusMin = radiusMin, existingEntities = existingEntities, quantity = quantity, density = density, ammoCount = ammoCount, followPlayer = followPlayer, forceString = forceString}
    )
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
    local force
    if data.forceString == nil then
        force = targetPlayer.force
    else
        force = game.forces[data.forceString]
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
                    entityTypeDetails.placeEntity({surface = surface, entityName = entityName, position = entityAlignedPosition, targetPlayer = targetPlayer, ammoCount = data.ammoCount, followPlayer = thisOneFollows, force = force})
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
            SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, 1, yOffset, followsLeftTable, force)
            SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, -1, yOffset, followsLeftTable, force)
        end
        if data.radiusMin ~= data.radiusMax then
            -- Fill in between circles
            for yOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                for xOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                    local placementPos = Utils.ApplyOffsetToPosition({x = xOffset, y = yOffset}, targetPos)
                    if Utils.IsPositionWithinCircled(targetPos, data.radiusMax, placementPos) and not Utils.IsPositionWithinCircled(targetPos, data.radiusMin, placementPos) then
                        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, placementPos, surface, targetPlayer, data, followsLeftTable, force)
                    end
                end
            end
        end
    end
end

SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine = function(entityTypeDetails, data, targetPos, surface, targetPlayer, radius, lineSlope, lineYOffset, followsLeftTable, force)
    local crossPos1, crossPos2 = Utils.FindWhereLineCrossesCircle(radius, lineSlope, lineYOffset)
    if crossPos1 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, Utils.ApplyOffsetToPosition(crossPos1, targetPos), surface, targetPlayer, data, followsLeftTable, force)
    end
    if crossPos2 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, Utils.ApplyOffsetToPosition(crossPos2, targetPos), surface, targetPlayer, data, followsLeftTable, force)
    end
end

SpawnAroundPlayer.PlaceEntityNearPosition = function(entityTypeDetails, position, surface, targetPlayer, data, followsLeftTable, force)
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
        entityTypeDetails.placeEntity({surface = surface, entityName = entityName, position = entityAlignedPosition, targetPlayer = targetPlayer, ammoCount = data.ammoCount, followPlayer = thisOneFollows, force = force})
    end
end

SpawnAroundPlayer.quantitySearchRadius = 3
SpawnAroundPlayer.densitySearchRadius = 0.6
SpawnAroundPlayer.offgridPlacementJitter = 0.3

SpawnAroundPlayer.CombatBotEntityTypeDetails = function(setEntityName, canFollow)
    return {
        getEntityName = function()
            return setEntityName
        end,
        getEntityAlignedPosition = function(position)
            return Utils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        searchPlacement = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        placeEntity = function(data)
            local target
            if canFollow and data.followPlayer then
                target = data.targetPlayer.character
            end
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force, target = target}
        end,
        followPlayerMax = function(targetPlayer)
            return SpawnAroundPlayer.GetPlayerMaxBotFollows(targetPlayer)
        end
    }
end

SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails = function(ammoName)
    return {
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
        placeEntity = function(data)
            local turret = data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
            if turret ~= nil then
                turret.insert({name = ammoName, count = data.ammoCount})
            end
        end
    }
end

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
        placeEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = "neutral"}
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
        placeEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = "neutral"}
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
        placeEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
        end
    },
    gunTurretRegularAmmo = SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails("firearm-magazine"),
    gunTurretPiercingAmmo = SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails("piercing-rounds-magazine"),
    gunTurretUraniumAmmo = SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails("uranium-rounds-magazine"),
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
        placeEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
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
        placeEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
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
        placeEntity = function(data)
            if data.ammoCount ~= nil then
                data.ammoCount = math.min(data.ammoCount, 250)
            end
            data.surface.create_entity {name = data.entityName, position = data.position, force = "neutral", initial_ground_flame_count = data.ammoCount}
        end
    },
    defenderBot = SpawnAroundPlayer.CombatBotEntityTypeDetails("defender", true),
    distractorBot = SpawnAroundPlayer.CombatBotEntityTypeDetails("distractor", false),
    destroyerBot = SpawnAroundPlayer.CombatBotEntityTypeDetails("destroyer", true)
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
