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
    if existingEntities == nil and existingEntities ~= "destroy" and existingEntities ~= "overlap" and existingEntities ~= "avoid" then
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
    local data, targetPlayer = eventData.data

    if type(data.target) == "string" then
        targetPlayer = game.get_player(data.target)
        if targetPlayer == nil then
            Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
            return
        end
    end

    --TODO do the creation logic from the settings
end

SpawnAroundPlayer.EntityTypeFunctions = {
    --return entity name and and optional ammo item name
    tree = function(surface, position)
        if remote.interfaces["biter_reincarnation"] == nil then
            return global.spawnAroundPlayer.randomTrees[math.random(#global.spawnAroundPlayer.randomTrees)]
        else
            return remote.call("biter_reincarnation", "get_random_tree_type_for_position", surface, position)
        end
    end,
    rock = function()
        local random = math.random()
        if random < 0.2 then
            return "rock-huge"
        elseif random < 0.6 then
            return "rock-big"
        else
            return "sand-rock-big"
        end
    end,
    laserTurret = function()
        return "laser-turret"
    end,
    gunTurretRegularAmmo = function()
        return "gun-turret", "firearm-magazine"
    end,
    gunTurretPiercingAmmo = function()
        return "gun-turret", "piercing-rounds-magazine"
    end,
    gunTurretUraniumAmmo = function()
        return "gun-turret", "uranium-rounds-magazine"
    end,
    fire = function()
        return "fire-flame"
    end,
    defenderCapsule = function()
        return "defender-capsule"
    end,
    distractorCapsule = function()
        return "distractor-capsule"
    end,
    destroyedCapsule = function()
        return "destroyer-capsule"
    end
}

SpawnAroundPlayer.PopulateRandomTrees = function()
    global.spawnAroundPlayer.randomTrees = {}
    for treeName in pairs(game.get_filtered_entity_prototypes({filter = "type", type = "tree"})) do
        table.insert(global.spawnAroundPlayer.randomTrees, treeName)
    end
end

return SpawnAroundPlayer
