local SpawnAroundPlayer = {} ---@class SpawnAroundPlayer
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local PositionUtils = require("utility.helper-utils.position-utils")
local BiomeTrees = require("utility.functions.biome-trees")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@enum SpawnAroundPlayer_ExistingEntities
local ExistingEntitiesTypes = {
    overlap = "overlap",
    avoid = "avoid"
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
SpawnAroundPlayer.offGridPlacementJitter = 0.3

local commandName = "muppet_streamer_spawn_around_player"

SpawnAroundPlayer.CreateGlobals = function()
    global.spawnAroundPlayer = global.spawnAroundPlayer or {}
    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId or 0 ---@type uint
end

SpawnAroundPlayer.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_spawn_around_player", { "api-description.muppet_streamer_spawn_around_player" }, SpawnAroundPlayer.SpawnAroundPlayerCommand, true)
    EventScheduler.RegisterScheduledEventType("SpawnAroundPlayer.SpawnAroundPlayerScheduled", SpawnAroundPlayer.SpawnAroundPlayerScheduled)
    MOD.Interfaces.Commands.SpawnAroundPlayer = SpawnAroundPlayer.SpawnAroundPlayerCommand
end

SpawnAroundPlayer.OnStartup = function()
    BiomeTrees.OnStartup()
end

---@param command CustomCommandData
SpawnAroundPlayer.SpawnAroundPlayerCommand = function(command)

    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "force", "entityName", "radiusMax", "radiusMin", "existingEntities", "quantity", "density", "ammoCount", "followPlayer" })
    if commandData == nil then
        return
    end

    local delaySeconds = commandData.delay
    if not CommandsUtils.CheckNumberArgument(delaySeconds, "double", false, commandName, "delay", 0, nil, command.parameter) then
        return
    end ---@cast delaySeconds double|nil
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySeconds, command.tick, commandName, "delay")

    local target = commandData.target
    if not Common.CheckPlayerNameSettingValue(target, commandName, "target", command.parameter) then
        return
    end ---@cast target string

    local forceString = commandData.force
    if not CommandsUtils.CheckStringArgument(forceString, false, commandName, "force", nil, command.parameter) then
        return
    end ---@cast forceString string|nil
    if forceString ~= nil then
        if game.forces[forceString] == nil then
            CommandsUtils.LogPrintError(commandName, "force", "has an invalid force name: " .. tostring(forceString), command.parameter)
            return
        end
    end

    local entityName = commandData.entityName
    if not CommandsUtils.CheckStringArgument(entityName, true, commandName, "entityName", SpawnAroundPlayer.EntityTypeDetails, command.parameter) then
        return
    end ---@cast entityName string

    local radiusMax = commandData.radiusMax
    if not CommandsUtils.CheckNumberArgument(radiusMax, "int", true, commandName, "radiusMax", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast radiusMax uint

    local radiusMin = commandData.radiusMin
    if not CommandsUtils.CheckNumberArgument(radiusMin, "int", false, commandName, "radiusMin", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast radiusMin uint|nil
    if radiusMin == nil then
        radiusMin = 0
    end

    local existingEntitiesString = commandData.existingEntities
    if not CommandsUtils.CheckStringArgument(existingEntitiesString, true, commandName, "existingEntities", ExistingEntitiesTypes, command.parameter) then
        return
    end ---@cast existingEntitiesString string
    local existingEntities = ExistingEntitiesTypes[existingEntitiesString] ---@type SpawnAroundPlayer_ExistingEntities

    local quantity = commandData.quantity
    if not CommandsUtils.CheckNumberArgument(quantity, "int", false, commandName, "quantity", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast quantity uint|nil

    local density = commandData.density
    if not CommandsUtils.CheckNumberArgument(density, "double", false, commandName, "density", 0, nil, command.parameter) then
        return
    end ---@cast density double|nil

    if quantity == nil and density == nil then
        CommandsUtils.LogPrintError(commandName, nil, "either quantity or density must be provided, otherwise the command will create nothing.", command.parameter)
        return
    end

    local ammoCount = commandData.ammoCount
    if not CommandsUtils.CheckNumberArgument(ammoCount, "int", false, commandName, "ammoCount", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast ammoCount uint|nil

    local followPlayer = commandData.followPlayer
    if not CommandsUtils.CheckBooleanArgument(followPlayer, false, commandName, "followPlayer", command.parameter) then
        return
    end ---@cast followPlayer boolean|nil

    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId + 1
    ---@type SpawnAroundPlayer_ScheduledDetails
    local scheduledDetails = { target = target, entityName = entityName, radiusMax = radiusMax, radiusMin = radiusMin, existingEntities = existingEntities, quantity = quantity, density = density, ammoCount = ammoCount, followPlayer = followPlayer, forceString = forceString }
    EventScheduler.ScheduleEventOnce(scheduleTick, "SpawnAroundPlayer.SpawnAroundPlayerScheduled", global.spawnAroundPlayer.nextId, scheduledDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
SpawnAroundPlayer.SpawnAroundPlayerScheduled = function(eventData)
    local data = eventData.data ---@type SpawnAroundPlayer_ScheduledDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    local targetPos, surface, followsLeft = targetPlayer.position, targetPlayer.surface, 0
    local entityTypeDetails = SpawnAroundPlayer.EntityTypeDetails[data.entityName]
    if data.followPlayer and entityTypeDetails.GetPlayersMaxBotFollowers ~= nil then
        followsLeft = entityTypeDetails.GetPlayersMaxBotFollowers(targetPlayer)
    end
    local force = data.forceString and game.forces[data.forceString] or (targetPlayer.force) --[[@as LuaForce @ Sumneko R/W workaround.]]

    if data.quantity ~= nil then
        local placed, targetPlaced, attempts, maxAttempts = 0, data.quantity, 0, data.quantity * 5
        while placed < targetPlaced do
            local position = PositionUtils.RandomLocationInRadius(targetPos, data.radiusMax, data.radiusMin)
            local entityName = entityTypeDetails.GetEntityName(surface, position)
            if entityName ~= nil then
                local entityAlignedPosition ---@type MapPosition|nil @ While initially always set, it can be unset during its processing.
                entityAlignedPosition = entityTypeDetails.GetEntityAlignedPosition(position)
                if data.existingEntities == "avoid" then
                    entityAlignedPosition = entityTypeDetails.FindValidPlacementPosition(surface, entityName, entityAlignedPosition, SpawnAroundPlayer.quantitySearchRadius)
                end
                if entityAlignedPosition ~= nil then
                    local thisOneFollows = false
                    if followsLeft > 0 then
                        thisOneFollows = true
                        followsLeft = followsLeft - 1
                    end

                    ---@type SpawnAroundPlayer_PlaceEntityDetails
                    local placeEntityDetails = { surface = surface, entityName = entityName, position = entityAlignedPosition, targetPlayer = targetPlayer, ammoCount = data.ammoCount, followPlayer = thisOneFollows, force = force }
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
        ---@class SpawnAroundPlayer_GroupPlacementDetails
        local groupPlacementDetails = { followsLeft = followsLeft } -- Do as table so it can be passed by reference in to functions and updated inline by each.

        -- Do outer perimeter first. Does a grid across the circle circumference.
        for yOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
            SpawnAroundPlayer.PlaceEntityAroundPerimeterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, 1, yOffset, groupPlacementDetails, force)
            SpawnAroundPlayer.PlaceEntityAroundPerimeterOnLine(entityTypeDetails, data, targetPos, surface, targetPlayer, data.radiusMax, -1, yOffset, groupPlacementDetails, force)
        end

        -- Fill inwards from the perimeter up to the required depth (max radius to min radius).
        if data.radiusMin ~= data.radiusMax then
            -- Fill in between circles
            for yOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                for xOffset = -data.radiusMax, data.radiusMax, entityTypeDetails.gridPlacementSize do
                    local placementPos = PositionUtils.ApplyOffsetToPosition({ x = xOffset, y = yOffset }, targetPos)
                    if PositionUtils.IsPositionWithinCircled(targetPos, data.radiusMax, placementPos) and not PositionUtils.IsPositionWithinCircled(targetPos, data.radiusMin, placementPos) then
                        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, placementPos, surface, targetPlayer, data, groupPlacementDetails, force)
                    end
                end
            end
        end
    end
end

--- Place an entity where a straight line crosses the circumference of a circle. When done in a grid of lines across the circumference then the perimeter of the circle will have been filled in.
---@param entityTypeDetails SpawnAroundPlayer_EntityTypeDetails
---@param data SpawnAroundPlayer_ScheduledDetails
---@param targetPos MapPosition
---@param surface LuaSurface
---@param targetPlayer LuaPlayer
---@param radius uint
---@param lineSlope uint
---@param lineYOffset int
---@param groupPlacementDetails SpawnAroundPlayer_GroupPlacementDetails
---@param force LuaForce
SpawnAroundPlayer.PlaceEntityAroundPerimeterOnLine = function(entityTypeDetails, data, targetPos, surface, targetPlayer, radius, lineSlope, lineYOffset, groupPlacementDetails, force)
    local crossPos1, crossPos2 = PositionUtils.FindWhereLineCrossesCircle(radius, lineSlope, lineYOffset)
    if crossPos1 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, PositionUtils.ApplyOffsetToPosition(crossPos1, targetPos), surface, targetPlayer, data, groupPlacementDetails, force)
    end
    if crossPos2 ~= nil then
        SpawnAroundPlayer.PlaceEntityNearPosition(entityTypeDetails, PositionUtils.ApplyOffsetToPosition(crossPos2, targetPos), surface, targetPlayer, data, groupPlacementDetails, force)
    end
end

--- Place an entity near the targetted position.
---@param entityTypeDetails SpawnAroundPlayer_EntityTypeDetails
---@param position MapPosition
---@param surface LuaSurface
---@param targetPlayer LuaPlayer
---@param data SpawnAroundPlayer_ScheduledDetails
---@param groupPlacementDetails SpawnAroundPlayer_GroupPlacementDetails
---@param force LuaForce
SpawnAroundPlayer.PlaceEntityNearPosition = function(entityTypeDetails, position, surface, targetPlayer, data, groupPlacementDetails, force)
    if math.random() > data.density then
        return
    end
    local entityName = entityTypeDetails.GetEntityName(surface, position)
    if entityName == nil then
        --no tree name is suitable for this tile, likely non land tile
        return
    end
    local entityAlignedPosition = entityTypeDetails.GetEntityAlignedPosition(position) ---@type MapPosition|nil
    if data.existingEntities == "avoid" then
        entityAlignedPosition = entityTypeDetails.FindValidPlacementPosition(surface, entityName, entityAlignedPosition--[[@as MapPosition]] , SpawnAroundPlayer.densitySearchRadius)
    end
    local thisOneFollows = false
    if groupPlacementDetails.followsLeft > 0 then
        thisOneFollows = true
        groupPlacementDetails.followsLeft = groupPlacementDetails.followsLeft - 1
    end
    if entityAlignedPosition ~= nil then
        ---@type SpawnAroundPlayer_PlaceEntityDetails
        local placeEntityDetails = { surface = surface, entityName = entityName, position = entityAlignedPosition, targetPlayer = targetPlayer, ammoCount = data.ammoCount, followPlayer = thisOneFollows, force = force }
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
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            local target
            if canFollow and data.followPlayer then
                target = data.targetPlayer.character
            end
            data.surface.create_entity { name = data.entityName, position = data.position, force = data.force, target = target }
        end,
        GetPlayersMaxBotFollowers = function(targetPlayer)
            return SpawnAroundPlayer.GetMaxBotFollowerCountForPlayer(targetPlayer)
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
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            local turret = data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
            if turret ~= nil then
                turret.insert({ name = ammoName, count = data.ammoCount })
            end
        end
    }
    return entityTypeDetails
end

-- CODE NOTE: the inner functions don't know their data types (same in the sub generator functions). Raised as enhancement request with Sumneko: https://github.com/sumneko/lua-language-server/issues/1332. At present just copying params from the class for the functions that complain.
---@type SpawnAroundPlayer_EntityTypes
SpawnAroundPlayer.EntityTypeDetails = {
    tree = {
        GetEntityName = function(surface, position)
            return BiomeTrees.GetBiomeTreeName(surface, position)
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            data.surface.create_entity { name = data.entityName, position = data.position, force = "neutral" }
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
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end,
        gridPlacementSize = 2,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            data.surface.create_entity { name = data.entityName, position = data.position, force = "neutral" }
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
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
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
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
        end
    },
    landmine = {
        GetEntityName = function()
            return "land-mine"
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1, true)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
        end
    },
    fire = {
        GetEntityName = function()
            return "fire-flame"
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end,
        gridPlacementSize = 1,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            local flameCount ---@type uint8|nil
            if data.ammoCount ~= nil then
                flameCount = MathUtils.ClampToUInt8(data.ammoCount)
            end
            data.surface.create_entity { name = data.entityName, position = data.position, force = "neutral", initial_ground_flame_count = flameCount }
        end
    },
    defenderBot = SpawnAroundPlayer.CombatBotEntityTypeDetails("defender", true),
    distractorBot = SpawnAroundPlayer.CombatBotEntityTypeDetails("distractor", false),
    destroyerBot = SpawnAroundPlayer.CombatBotEntityTypeDetails("destroyer", true)
}

---Get how many bots can be set to follow the player currently.
---@param targetPlayer LuaPlayer
---@return uint
SpawnAroundPlayer.GetMaxBotFollowerCountForPlayer = function(targetPlayer)
    if targetPlayer.character == nil then
        return 0
    end
    local max = targetPlayer.character_maximum_following_robot_count_bonus + targetPlayer.force.maximum_following_robot_count
    local current = #targetPlayer.following_robots --[[@as uint @ The game doesn't allow more than a uint max following robots, so the count can't be above a uint.]]
    return max - current
end

return SpawnAroundPlayer
