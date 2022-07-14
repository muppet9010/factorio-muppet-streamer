local SpawnAroundPlayer = {}
local Commands = require("utility.managerLibraries.commands")
local LoggingUtils = require("utility.helperUtils.logging-utils")
local EventScheduler = require("utility.managerLibraries.event-scheduler")
local PositionUtils = require("utility.helperUtils.position-utils")
local BiomeTrees = require("utility.functions.biome-trees")
local BooleanUtils = require("utility.helperUtils.boolean-utils")
local Common = require("scripts.common")

---@class SpawnAroundPlayer_ExistingEntities
---@class SpawnAroundPlayer_ExistingEntities.__index
local ExistingEntitiesTypes = {
    overlap = ("overlap") --[[@as SpawnAroundPlayer_ExistingEntities]],
    avoid = ("avoid") --[[@as SpawnAroundPlayer_ExistingEntities]]
}

---@class SpawnAroundPlayer_ScheduledDetails
---@field target string
---@field entityName string
---@field radiusMax uint
---@field radiusMin uint
---@field existingEntities SpawnAroundPlayer_ExistingEntities
---@field quantity uint|nil
---@field density double|nil
---@field ammoCount uint|nil
---@field followPlayer boolean|nil
---@field forceString string|nil

---@alias SpawnAroundPlayer_EntityTypes table<string, SpawnAroundPlayer_EntityTypeDetails>

---@class SpawnAroundPlayer_EntityTypeDetails
---@field GetEntityName fun(surface: LuaSurface, position: MapPosition): string
---@field GetEntityAlignedPosition fun(position: MapPosition): MapPosition
---@field FindValidPlacementPosition fun(surface: LuaSurface, entityName: string, position: MapPosition, searchRadius, double): MapPosition|nil
---@field PlaceEntity fun(data: SpawnAroundPlayer_PlaceEntityDetails) @ No return or indication if it worked, its a try and forget.
---@field GetPlayersMaxBotFollowers? fun(targetPlayer: LuaPlayer): uint
---@field gridPlacementSize uint|nil @ If the thing needs to be placed on a grid and how big that grid is. Used for things that can't go off grid and have larger collision boxes.

---@class SpawnAroundPlayer_PlaceEntityDetails
---@field surface LuaSurface
---@field entityName string @ Prototype entity name.
---@field position MapPosition
---@field targetPlayer LuaPlayer
---@field ammoCount uint|nil
---@field followPlayer boolean
---@field force LuaForce

SpawnAroundPlayer.quantitySearchRadius = 3
SpawnAroundPlayer.densitySearchRadius = 0.6
SpawnAroundPlayer.offgridPlacementJitter = 0.3

SpawnAroundPlayer.CreateGlobals = function()
    global.spawnAroundPlayer = global.spawnAroundPlayer or {}
    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId or 0
end

SpawnAroundPlayer.OnLoad = function()
    Commands.Register("muppet_streamer_spawn_around_player", {"api-description.muppet_streamer_spawn_around_player"}, SpawnAroundPlayer.SpawnAroundPlayerCommand, true)
    EventScheduler.RegisterScheduledEventType("SpawnAroundPlayer.SpawnAroundPlayerScheduled", SpawnAroundPlayer.SpawnAroundPlayerScheduled)
end

SpawnAroundPlayer.OnStartup = function()
    BiomeTrees.OnStartup()
end

---@param command CustomCommandData
SpawnAroundPlayer.SpawnAroundPlayerCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_spawn_around_player command "
    local commandName = "muppet_streamer_spawn_around_player"
    local commandData
    if command.parameter ~= nil then
        commandData = game.json_to_table(command.parameter)
    end
    if commandData == nil or type(commandData) ~= "table" then
        LoggingUtils.LogPrintError(errorMessageStart .. "requires details in JSON format.")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local delaySecondsRaw = commandData.delay ---@type any
    if not Commands.ParseNumberArgument(delaySecondsRaw, "double", false, commandName, "delay", 0, nil, command.parameter) then
        return
    end
    ---@cast delaySecondsRaw uint
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySecondsRaw, command.tick, commandName, "delay")

    local target = commandData.target
    if target == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "target is mandatory")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    elseif game.get_player(target) == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "target is invalid player name")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    --TODO: not typed. left for now as part of: https://github.com/sumneko/lua-language-server/discussions/1333
    local forceString = commandData.force
    if forceString ~= nil then
        if game.forces[forceString] == nil then
            LoggingUtils.LogPrintError(errorMessageStart .. "optional force provided, but isn't a valid force name")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    local entityName = commandData.entityName ---@type string|nil
    if entityName == nil or SpawnAroundPlayer.EntityTypeDetails[entityName] == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "entityName is mandatory and must be a supported type")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    ---@cast entityName - nil
    end

    local radiusMax = tonumber(commandData.radiusMax)
    if radiusMax == nil or radiusMax <= 0 then
        LoggingUtils.LogPrintError(errorMessageStart .. "radiusMax is mandatory and must be a number greater than 0")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end
    ---@cast radiusMax uint

    local radiusMin = tonumber(commandData.radiusMin)
    if radiusMin == nil or radiusMin < 0 then
        radiusMin = 0
    end
    ---@cast radiusMin uint

    local existingEntitiesString = commandData.existingEntities ---@type string|nil
    if existingEntitiesString == nil or ExistingEntitiesTypes[existingEntitiesString] == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "existingEntities is mandatory and must be a supported setting type")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end
    local existingEntities = ExistingEntitiesTypes[existingEntitiesString]

    local quantity = tonumber(commandData.quantity)
    ---@cast quantity uint|nil
    local density = tonumber(commandData.density)
    if quantity == nil and density == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "either quantity or density must be provided, otherwise the command will create nothing.")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local ammoCount = tonumber(commandData.ammoCount)
    ---@cast ammoCount uint|nil

    local followPlayer = false ---@type boolean|nil
    if commandData.followPlayer ~= nil then
        followPlayer = BooleanUtils.ToBoolean(commandData.followPlayer)
        if followPlayer == nil then
            LoggingUtils.LogPrintError(errorMessageStart .. "followPlayer is Optional, but if provided must be a boolean")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId + 1
    ---@type SpawnAroundPlayer_ScheduledDetails
    local scheduledDetails = {target = target, entityName = entityName, radiusMax = radiusMax, radiusMin = radiusMin, existingEntities = existingEntities, quantity = quantity, density = density, ammoCount = ammoCount, followPlayer = followPlayer, forceString = forceString}
    EventScheduler.ScheduleEventOnce(scheduleTick, "SpawnAroundPlayer.SpawnAroundPlayerScheduled", global.spawnAroundPlayer.nextId, scheduledDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
SpawnAroundPlayer.SpawnAroundPlayerScheduled = function(eventData)
    local data = eventData.data ---@type SpawnAroundPlayer_ScheduledDetails

    local targetPlayer = game.get_player(data.target)
    local targetPos, surface, followsLeft = targetPlayer.position, targetPlayer.surface, 0
    local entityTypeDetails = SpawnAroundPlayer.EntityTypeDetails[data.entityName]
    if data.followPlayer and entityTypeDetails.GetPlayersMaxBotFollowers ~= nil then
        followsLeft = entityTypeDetails.GetPlayersMaxBotFollowers(targetPlayer)
    end
    local force
    if data.forceString == nil then
        force = targetPlayer.force
    else
        force = game.forces[data.forceString]
    end
    ---@cast force LuaForce

    if data.quantity ~= nil then
        local placed, targetPlaced, attempts, maxAttempts = 0, data.quantity, 0, data.quantity * 5
        while placed < targetPlaced do
            local position = PositionUtils.RandomLocationInRadius(targetPos, data.radiusMax, data.radiusMin)
            local entityName = entityTypeDetails.GetEntityName(surface, position)
            if entityName ~= nil then
                local entityAlignedPosition = entityTypeDetails.GetEntityAlignedPosition(position) ---@type MapPosition|nil
                if data.existingEntities == "avoid" then
                    entityAlignedPosition = entityTypeDetails.FindValidPlacementPosition(surface, entityName, entityAlignedPosition --[[@as MapPosition]], SpawnAroundPlayer.quantitySearchRadius)
                end
                if entityAlignedPosition ~= nil then
                    local thisOneFollows = false
                    if followsLeft > 0 then
                        thisOneFollows = true
                        followsLeft = followsLeft - 1
                    end

                    ---@type SpawnAroundPlayer_PlaceEntityDetails
                    local placeEntityDetails = {surface = surface, entityName = entityName, position = entityAlignedPosition, targetPlayer = targetPlayer, ammoCount = data.ammoCount, followPlayer = thisOneFollows, force = force}
                    entityTypeDetails.PlaceEntity(placeEntityDetails)
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

        -- Do outer perimiter first. Does a grid across the circle circumference.
        for yOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
            SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, 1, yOffset, followsLeftTable, force)
            SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, -1, yOffset, followsLeftTable, force)
        end

        -- Fill inwards from the perimiter up to the required depth (max radius to min radius).
        if data.radiusMin ~= data.radiusMax then
            -- Fill in between circles
            for yOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                for xOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                    local placementPos = PositionUtils.ApplyOffsetToPosition({x = xOffset, y = yOffset}, targetPos)
                    if PositionUtils.IsPositionWithinCircled(targetPos, data.radiusMax, placementPos) and not PositionUtils.IsPositionWithinCircled(targetPos, data.radiusMin, placementPos) then
                        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, placementPos, surface, targetPlayer, data, followsLeftTable, force)
                    end
                end
            end
        end
    end
end

--- Place an entity where a stright line crosses the circumference of a circle. When done in a grid of lines across the circumference then the perimeter of the circle will have been filled in.
---@param entityTypeDetails any
---@param data SpawnAroundPlayer_ScheduledDetails
---@param targetPos MapPosition
---@param surface LuaSurface
---@param targetPlayer LuaPlayer
---@param radius uint
---@param lineSlope uint
---@param lineYOffset int
---@param followsLeftTable any
---@param force LuaForce
SpawnAroundPlayer.PlaceEntityAroundPerimiterOnLine = function(entityTypeDetails, data, targetPos, surface, targetPlayer, radius, lineSlope, lineYOffset, followsLeftTable, force)
    local crossPos1, crossPos2 = PositionUtils.FindWhereLineCrossesCircle(radius, lineSlope, lineYOffset)
    if crossPos1 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, PositionUtils.ApplyOffsetToPosition(crossPos1, targetPos), surface, targetPlayer, data, followsLeftTable, force)
    end
    if crossPos2 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, PositionUtils.ApplyOffsetToPosition(crossPos2, targetPos), surface, targetPlayer, data, followsLeftTable, force)
    end
end

--- Place an entity near the targetted position.
---@param entityTypeDetails any
---@param position MapPosition
---@param surface LuaSurface
---@param targetPlayer LuaPlayer
---@param data SpawnAroundPlayer_ScheduledDetails
---@param followsLeftTable any
---@param force LuaForce
SpawnAroundPlayer.PlaceEntityNearPosition = function(entityTypeDetails, position, surface, targetPlayer, data, followsLeftTable, force)
    if math.random() > data.density then
        return
    end
    local entityName = entityTypeDetails.GetEntityName(surface, position)
    if entityName == nil then
        --no tree name is suitable for this tile, likely non land tile
        return
    end
    local entityAlignedPosition = entityTypeDetails.GetEntityAlignedPosition(position)
    if data.existingEntities == "avoid" then
        entityAlignedPosition = entityTypeDetails.FindValidPlacementPosition(surface, entityName, entityAlignedPosition, SpawnAroundPlayer.densitySearchRadius)
    end
    local thisOneFollows = false
    if followsLeftTable[1] > 0 then
        thisOneFollows = true
        followsLeftTable[1] = followsLeftTable[1] - 1
    end
    if entityAlignedPosition ~= nil then
        ---@type SpawnAroundPlayer_PlaceEntityDetails
        local placeEntityDetails = {surface = surface, entityName = entityName, position = entityAlignedPosition, targetPlayer = targetPlayer, ammoCount = data.ammoCount, followPlayer = thisOneFollows, force = force}
        entityTypeDetails.PlaceEntity(placeEntityDetails)
    end
end

--- Handler for the generic combat robot types.
---
--- CODE NOTE: must be before SpawnAroundPlayer.EntityTypeDetails() in file so that function can find this one at load (not run) time.
---@param setEntityName string @ Prototype entity name
---@param canFollow boolean @ If the robots should be set to follow the player.
---@return SpawnAroundPlayer_EntityTypeDetails
SpawnAroundPlayer.CombatBotEntityTypeDetails = function(setEntityName, canFollow)
    ---@type SpawnAroundPlayer_EntityTypeDetails
    local entityTypeDetails = {
        GetEntityName = function()
            return setEntityName
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        PlaceEntity = function(data)
            local target
            if canFollow and data.followPlayer then
                target = data.targetPlayer.character
            end
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force, target = target}
        end,
        GetPlayersMaxBotFollowers = function(targetPlayer)
            return SpawnAroundPlayer.GetPlayerMaxBotFollows(targetPlayer)
        end
    }
    return entityTypeDetails
end

--- Handler for the generic gun turret with ammo types.
---
--- CODE NOTE: must be before SpawnAroundPlayer.EntityTypeDetails() in file so that function can find this one at load (not run) time.
---@param ammoName string @ Prototype item name
---@return SpawnAroundPlayer_EntityTypeDetails
SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails = function(ammoName)
    ---@type SpawnAroundPlayer_EntityTypeDetails
    local entityTypeDetails = {
        GetEntityName = function()
            return "gun-turret"
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RoundPosition(position, 0)
        end,
        gridPlacementSize = 2,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1)
        end,
        PlaceEntity = function(data)
            local turret = data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
            if turret ~= nil then
                turret.insert({name = ammoName, count = data.ammoCount})
            end
        end
    }
    return entityTypeDetails
end

-- CODE NOTE: the inner functions don't know their data types (same in the sub generator functions). Raised as enhancement request with Sumneko: https://github.com/sumneko/lua-language-server/issues/1332
---@type SpawnAroundPlayer_EntityTypes
SpawnAroundPlayer.EntityTypeDetails = {
    tree = {
        GetEntityName = function(surface, position)
            return BiomeTrees.GetBiomeTreeName(surface, position)
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        PlaceEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = "neutral"}
        end
    },
    rock = {
        GetEntityName = function()
            local random = math.random()
            if random < 0.2 then
                return "rock-huge"
            elseif random < 0.6 then
                return "rock-big"
            else
                return "sand-rock-big"
            end
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 2,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        PlaceEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = "neutral"}
        end
    },
    laserTurret = {
        GetEntityName = function()
            return "laser-turret"
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RoundPosition(position, 0)
        end,
        gridPlacementSize = 2,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1)
        end,
        PlaceEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
        end
    },
    gunTurretRegularAmmo = SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails("firearm-magazine"),
    gunTurretPiercingAmmo = SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails("piercing-rounds-magazine"),
    gunTurretUraniumAmmo = SpawnAroundPlayer.AmmoGunTurretEntityTypeDetails("uranium-rounds-magazine"),
    wall = {
        GetEntityName = function()
            return "stone-wall"
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RoundPosition(position, 0)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1, true)
        end,
        PlaceEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
        end
    },
    landmine = {
        GetEntityName = function()
            return "land-mine"
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1, true)
        end,
        PlaceEntity = function(data)
            data.surface.create_entity {name = data.entityName, position = data.position, force = data.force}
        end
    },
    fire = {
        GetEntityName = function()
            return "fire-flame"
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offgridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        PlaceEntity = function(data)
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

---Get how many bots can be set to follow the player currently.
---@param targetPlayer LuaPlayer
---@return uint
SpawnAroundPlayer.GetPlayersMaxBotFollowers = function(targetPlayer)
    if targetPlayer.character == nil then
        return 0
    end
    local max = targetPlayer.character_maximum_following_robot_count_bonus + targetPlayer.force.maximum_following_robot_count --[[@as uint]]
    local current = #targetPlayer.following_robots --[[@as uint]]
    return max - current --[[@as uint]]
end

return SpawnAroundPlayer
