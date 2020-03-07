local SpawnAroundPlayer = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")

SpawnAroundPlayer.CreateGlobals = function()
    global.spawnAroundPlayer = global.spawnAroundPlayer or {}
    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId or 0
    global.spawnAroundPlayer.randomTrees = global.spawnAroundPlayer.randomTrees or {}
end

SpawnAroundPlayer.OnLoad = function()
    Commands.Register("muppet_streamer_spawn_around_player", {"api-description.muppet_streamer_spawn_around_player"}, SpawnAroundPlayer.SpawnAroundPlayerCommand)
    EventScheduler.RegisterScheduledEventType("SpawnAroundPlayer.SpawnAroundPlayerScheduled", SpawnAroundPlayer.SpawnAroundPlayerScheduled)
end

SpawnAroundPlayer.OnStartup = function()
    SpawnAroundPlayer.PopulateRandomTrees()
end

SpawnAroundPlayer.SpawnAroundPlayerCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_spawn_around_player command "
    local commandData = game.json_to_table(command.parameter)
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
    if entityName == nil or SpawnAroundPlayer.EntityTypeFunctions[entityName] == nil then
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

    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "SpawnAroundPlayer.SpawnAroundPlayerScheduled", global.spawnAroundPlayer.nextId, {target = target, entityName = entityName, radiusMax = radiusMax, radiusMin = radiusMin, existingEntities = existingEntities, quantity = quantity, density = density, ammoCount = ammoCount})
end

SpawnAroundPlayer.SpawnAroundPlayerScheduled = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_spawn_around_player command "
    local data = eventData.data

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    local targetPos, surface = targetPlayer.position, targetPlayer.surface

    local entityTypeFunction = SpawnAroundPlayer.EntityTypeFunctions[data.entityName]

    if data.quantity ~= nil then
        local placed, targetPlaced, attempts, maxAttempts = 0, data.quantity, 0, data.quantity * 5
        while placed < targetPlaced do
            local pos = Utils.RandomLocationInRadius(targetPos, data.radiusMax, data.radiusMin)
            local entityName = entityTypeFunction.getEntityName()
            local entityAlignedPosition = entityTypeFunction.getEntityAlignedPosition(pos)
            if data.existingEntities == "avoid" then
                entityAlignedPosition = entityTypeFunction.searchPlacement(surface, entityName, entityAlignedPosition)
            end
            if entityAlignedPosition ~= nil then
                entityTypeFunction.placeEntity(surface, entityName, entityAlignedPosition, targetPlayer.force, data.ammoCount)
                placed = placed + 1
            end
            attempts = attempts + 1
            if attempts >= maxAttempts then
                break
            end
        end
    elseif data.density ~= nil then
    --TODO do the creation logic from the settings
    end
end

SpawnAroundPlayer.quantitySearchRadius = 3

SpawnAroundPlayer.EntityTypeFunctions = {
    tree = {
        getEntityName = function(surface, position)
            if remote.interfaces["biter_reincarnation"] == nil then
                return global.spawnAroundPlayer.randomTrees[math.random(#global.spawnAroundPlayer.randomTrees)]
            else
                return remote.call("biter_reincarnation", "get_random_tree_type_for_position", surface, position)
            end
        end,
        getEntityAlignedPosition = function(position)
            return position
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, force)
            surface.create_entity {name = entityName, position = position, force = force}
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
            return position
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position)
            surface.create_entity {name = entityName, position = position, force = "neutral"}
        end
    },
    laserTurret = {
        getEntityName = function()
            return "laser-turret"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.FloorPosition(position)
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, force)
            surface.create_entity {name = entityName, position = position, force = force}
        end
    },
    gunTurretRegularAmmo = {
        getEntityName = function()
            return "gun-turret"
        end,
        getEntityAlignedPosition = function(position)
            return Utils.FloorPosition(position)
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, force, ammoCount)
            local turret = surface.create_entity {name = entityName, position = position, force = force}
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
            return Utils.FloorPosition(position)
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, force, ammoCount)
            local turret = surface.create_entity {name = entityName, position = position, force = force}
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
            return Utils.FloorPosition(position)
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 1)
        end,
        placeEntity = function(surface, entityName, position, force, ammoCount)
            local turret = surface.create_entity {name = entityName, position = position, force = force}
            if turret ~= nil then
                turret.insert({name = "uranium-rounds-magazine", count = ammoCount})
            end
        end
    },
    fire = {
        getEntityName = function()
            return "fire-flame"
        end,
        getEntityAlignedPosition = function(position)
            return position
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, _, ammoCount)
            surface.create_entity {name = entityName, position = position, force = "neutral", initial_ground_flame_count = ammoCount}
        end
    },
    defenderCapsule = {
        getEntityName = function()
            return "defender-capsule"
        end,
        getEntityAlignedPosition = function(position)
            return position
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, force)
            surface.create_entity {name = entityName, position = position, force = force}
        end
    },
    distractorCapsule = {
        getEntityName = function()
            return "distractor-capsule"
        end,
        getEntityAlignedPosition = function(position)
            return position
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, force)
            surface.create_entity {name = entityName, position = position, force = force}
        end
    },
    destroyedCapsule = {
        getEntityName = function()
            return "destroyer-capsule"
        end,
        getEntityAlignedPosition = function(position)
            return position
        end,
        searchPlacement = function(surface, entityName, position)
            return surface.find_non_colliding_position(entityName, position, SpawnAroundPlayer.quantitySearchRadius, 0.2)
        end,
        placeEntity = function(surface, entityName, position, force)
            surface.create_entity {name = entityName, position = position, force = force}
        end
    }
}

SpawnAroundPlayer.PopulateRandomTrees = function()
    global.spawnAroundPlayer.randomTrees = {}
    for treeName in pairs(game.get_filtered_entity_prototypes({{filter = "type", type = "tree"}})) do
        table.insert(global.spawnAroundPlayer.randomTrees, treeName)
    end
end

return SpawnAroundPlayer
