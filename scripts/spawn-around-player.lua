--[[
    This has grown rather messy in trying to implement factory type function collections for the different entity types. While it's fully functional it is a victim of iterative changes and enhancements, without a full refactor.
]]

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
---@field entityTypeDetails SpawnAroundPlayer_EntityTypeDetails
---@field radiusMax uint
---@field radiusMin uint
---@field existingEntities SpawnAroundPlayer_ExistingEntities
---@field quantity uint|nil
---@field density double|nil
---@field ammoCount uint|nil
---@field followPlayer boolean|nil
---@field forceString string|nil

---@enum SpawnAroundPlayer_EntityTypeNames
local EntityTypeNames = {
    tree = "tree",
    rock = "rock",
    laserTurret = "laserTurret",
    gunTurretRegularAmmo = "gunTurretRegularAmmo",
    gunTurretPiercingAmmo = "gunTurretPiercingAmmo",
    gunTurretUraniumAmmo = "gunTurretUraniumAmmo",
    wall = "wall",
    landmine = "landmine",
    fire = "fire",
    defenderBot = "defenderBot",
    distractorBot = "distractorBot",
    destroyerBot = "destroyerBot",
    custom = "custom"
}

---@alias SpawnAroundPlayer_EntityTypes table<SpawnAroundPlayer_EntityTypeNames, SpawnAroundPlayer_EntityTypeDetails>

---@class SpawnAroundPlayer_EntityTypeDetails
---@field ValidateEntityPrototypes fun(commandString?: string|nil): boolean # Checks that the LuaEntity for the entityName is as we expect; exists and correct type.
---@field GetDefaultForce fun(targetPlayer: LuaPlayer): LuaForce
---@field GetEntityName fun(surface: LuaSurface, position: MapPosition): string|nil # Should normally return something, but some advanced features may not, i.e. getting tree for void tiles.
---@field GetEntityAlignedPosition fun(position: MapPosition): MapPosition
---@field FindValidPlacementPosition fun(surface: LuaSurface, entityName: string, position: MapPosition, searchRadius, double): MapPosition|nil
---@field PlaceEntity fun(data: SpawnAroundPlayer_PlaceEntityDetails) # No return or indication if it worked, its a try and forget.
---@field GetPlayersMaxBotFollowers? fun(targetPlayer: LuaPlayer): uint
---@field gridPlacementSize uint|nil # If the thing needs to be placed on a grid and how big that grid is. Used for things that can't go off grid and have larger collision boxes.

---@class SpawnAroundPlayer_PlaceEntityDetails
---@field surface LuaSurface
---@field entityName string # Prototype entity name.
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

    -- Make the functions for the different entity types. We need game to be populated for this and while it is from the true OnLoad Factorio event, it isn't from the OnStartup type Factorio events.
    if game ~= nil then
        SpawnAroundPlayer.PopulateEntityTypeDetailsFunctions()
    end
end

SpawnAroundPlayer.OnStartup = function()
    BiomeTrees.OnStartup()
end

---@param command CustomCommandData
SpawnAroundPlayer.SpawnAroundPlayerCommand = function(command)

    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "force", "entityName", "customEntityName", "customSecondaryDetail", "radiusMax", "radiusMin", "existingEntities", "quantity", "density", "ammoCount", "followPlayer" })
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

    -- Just get these settings and make sure they are the right data type, validate their sanity later.
    local customEntityName = commandData.customEntityName
    if not CommandsUtils.CheckStringArgument(customEntityName, false, commandName, "customEntityName", nil, command.parameter) then
        return
    end ---@cast customEntityName string|nil
    local customSecondaryDetail = commandData.customSecondaryDetail
    if not CommandsUtils.CheckStringArgument(customSecondaryDetail, false, commandName, "customSecondaryDetail", nil, command.parameter) then
        return
    end ---@cast customSecondaryDetail string|nil

    local creationName = commandData.entityName
    if not CommandsUtils.CheckStringArgument(creationName, true, commandName, "entityName", EntityTypeNames, command.parameter) then
        return
    end ---@cast creationName string
    local entityTypeName = EntityTypeNames[creationName]
    local entityTypeDetails = SpawnAroundPlayer.EntityTypeDetails[entityTypeName]
    if entityTypeName == EntityTypeNames.custom then
        -- Populate a standard details from the custom settings to make it look "normal" to later code. Lots of validation needed for this.
        if customEntityName == nil then
            CommandsUtils.LogPrintError(commandName, "customEntityName", "customEntityName wasn't provided, but is required as the entityName is 'custom'.", command.parameter)
            return
        end
        local customEntityPrototype = game.entity_prototypes[customEntityName]
        if customEntityPrototype == nil then
            CommandsUtils.LogPrintError(commandName, "customEntityName", "entity '" .. customEntityName .. "' wasn't a valid entity name", command.parameter)
            return
        end
        local customEntityPrototype_type = customEntityPrototype.type
        local usedSecondaryData = false
        if customEntityPrototype_type == "fire" then
            entityTypeDetails = SpawnAroundPlayer.GenerateFireEntityTypeDetails(customEntityName)
        elseif customEntityPrototype_type == "combat-robot" then
            local canFollowPlayer = true -- Hard coded as no API way to get it at present. https://forums.factorio.com/viewtopic.php?f=28&t=103027
            entityTypeDetails = SpawnAroundPlayer.GenerateCombatBotEntityTypeDetails(customEntityName, canFollowPlayer)
        elseif customEntityPrototype_type == "ammo-turret" then
            usedSecondaryData = true
            if customSecondaryDetail ~= nil then
                local ammoItemPrototype = game.item_prototypes[customSecondaryDetail]
                if ammoItemPrototype == nil then
                    CommandsUtils.LogPrintError(commandName, "customSecondaryDetail", "item '" .. customSecondaryDetail .. "' wasn't a valid item name", command.parameter)
                    return
                end
                local ammoItemPrototype_type = ammoItemPrototype.type
                if ammoItemPrototype_type ~= 'ammo' then
                    CommandsUtils.LogPrintError(commandName, "customSecondaryDetail", "item '" .. customSecondaryDetail .. "' wasn't an ammo item type, instead it was a type: " .. tostring(ammoItemPrototype_type), command.parameter)
                    return
                end
            end
            entityTypeDetails = SpawnAroundPlayer.GenerateAmmoGunTurretEntityTypeDetails(customEntityName, customSecondaryDetail)
        else
            entityTypeDetails = SpawnAroundPlayer.GenerateStandardTileEntityTypeDetails(customEntityName, customEntityPrototype_type)
        end

        -- Check that customSecondaryDetail setting wasn't populated if it wasn't used.
        if not usedSecondaryData and customSecondaryDetail ~= nil then
            CommandsUtils.LogPrintWarning(commandName, "customSecondaryDetail", "customSecondaryDetail was provided, but being ignored as the customEntityName didn't require it.", command.parameter)
        end
    else
        -- Check no ignored custom settings for a non custom entityName.
        if customEntityName ~= nil then
            CommandsUtils.LogPrintWarning(commandName, "customEntityName", "customEntityName was provided, but being ignored as the entityName wasn't 'custom'.", command.parameter)
        end
        if customSecondaryDetail ~= nil then
            CommandsUtils.LogPrintWarning(commandName, "customSecondaryDetail", "customSecondaryDetail was provided, but being ignored as the entityName wasn't 'custom'.", command.parameter)
        end
    end
    if not entityTypeDetails.ValidateEntityPrototypes(command.parameter) then
        return
    end

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
    local scheduledDetails = { target = target, entityTypeDetails = entityTypeDetails, radiusMax = radiusMax, radiusMin = radiusMin, existingEntities = existingEntities, quantity = quantity, density = density, ammoCount = ammoCount, followPlayer = followPlayer, forceString = forceString }
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
    local targetPos, surface, followsLeft, entityTypeDetails = targetPlayer.position, targetPlayer.surface, 0, data.entityTypeDetails
    if not entityTypeDetails.ValidateEntityPrototypes() then
        return
    end
    if data.followPlayer and entityTypeDetails.GetPlayersMaxBotFollowers ~= nil then
        followsLeft = entityTypeDetails.GetPlayersMaxBotFollowers(targetPlayer)
    end
    local force
    if data.forceString ~= nil then
        force = game.forces[data.forceString--[[@as string # Filtered nil out.]] ]
    else
        force = data.entityTypeDetails.GetDefaultForce(targetPlayer)
    end

    if data.quantity ~= nil then
        local placed, targetPlaced, attempts, maxAttempts = 0, data.quantity, 0, data.quantity * 5
        while placed < targetPlaced do
            local position = PositionUtils.RandomLocationInRadius(targetPos, data.radiusMax, data.radiusMin)
            local entityName = entityTypeDetails.GetEntityName(surface, position)
            if entityName ~= nil then
                local entityAlignedPosition ---@type MapPosition|nil # While initially always set, it can be unset during its processing.
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

--- Populate the functions for the different entity types we support creating.
---
--- Do during features OnLoad so its always populated, but we as we need `game` to be populated to run this its falling needs to filter out the OnStartup events calling OnLoad. It will overwrite itself safely and no random generation or anything during its population.
SpawnAroundPlayer.PopulateEntityTypeDetailsFunctions = function()
    -- CODE NOTE: the inner functions don't know their data types (same in the sub generator functions). Raised as enhancement request with Sumneko: https://github.com/sumneko/lua-language-server/issues/1332. At present just copying params from the class for the functions that complain.
    ---@type SpawnAroundPlayer_EntityTypes
    SpawnAroundPlayer.EntityTypeDetails = {
        [EntityTypeNames.tree] = {
            ValidateEntityPrototypes = function()
                -- The BiomeTrees ensures it only returns valid trees and it will always find something, so nothing needs checking.
                return true
            end,
            GetDefaultForce = function()
                return game.forces["neutral"]
            end,
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
                data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
            end
        },
        [EntityTypeNames.rock] = {
            ValidateEntityPrototypes = function(commandString)
                if Common.GetBaseGameEntityByName("rock-huge", "simple-entity", commandName, commandString) == nil then
                    return false
                end
                if Common.GetBaseGameEntityByName("rock-big", "simple-entity", commandName, commandString) == nil then
                    return false
                end
                if Common.GetBaseGameEntityByName("sand-rock-big", "simple-entity", commandName, commandString) == nil then
                    return false
                end
                return true
            end,
            GetDefaultForce = function()
                return game.forces["neutral"]
            end,
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
                data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
            end
        },
        [EntityTypeNames.laserTurret] = SpawnAroundPlayer.GenerateStandardTileEntityTypeDetails("laser-turret", "electric-turret"),
        [EntityTypeNames.gunTurretRegularAmmo] = SpawnAroundPlayer.GenerateAmmoGunTurretEntityTypeDetails("gun-turret", "firearm-magazine"),
        [EntityTypeNames.gunTurretPiercingAmmo] = SpawnAroundPlayer.GenerateAmmoGunTurretEntityTypeDetails("gun-turret", "piercing-rounds-magazine"),
        [EntityTypeNames.gunTurretUraniumAmmo] = SpawnAroundPlayer.GenerateAmmoGunTurretEntityTypeDetails("gun-turret", "uranium-rounds-magazine"),
        [EntityTypeNames.wall] = SpawnAroundPlayer.GenerateStandardTileEntityTypeDetails("stone-wall", "wall"),
        [EntityTypeNames.landmine] = SpawnAroundPlayer.GenerateStandardTileEntityTypeDetails("land-mine", "land-mine"),
        [EntityTypeNames.fire] = SpawnAroundPlayer.GenerateFireEntityTypeDetails("fire-flame"),
        [EntityTypeNames.defenderBot] = SpawnAroundPlayer.GenerateCombatBotEntityTypeDetails("defender", true),
        [EntityTypeNames.distractorBot] = SpawnAroundPlayer.GenerateCombatBotEntityTypeDetails("distractor", false),
        [EntityTypeNames.destroyerBot] = SpawnAroundPlayer.GenerateCombatBotEntityTypeDetails("destroyer", true),
        [EntityTypeNames.custom] = {
            -- Intentionally blank. Will be populated upon receiving the custom entity name and discerning its type.
        }
    }
end

--- Handler for the generic combat robot types.
---@param setEntityName string # Prototype entity name
---@param canFollow boolean # If the robots should be set to follow the player.
---@return SpawnAroundPlayer_EntityTypeDetails
SpawnAroundPlayer.GenerateCombatBotEntityTypeDetails = function(setEntityName, canFollow)
    local gridSize, searchOnlyInTileCenter = SpawnAroundPlayer.GetEntityTypeFunctionPlacementDetails(setEntityName)

    ---@type SpawnAroundPlayer_EntityTypeDetails
    local entityTypeDetails = {
        ValidateEntityPrototypes = function(commandString)
            if Common.GetBaseGameEntityByName(setEntityName, "combat-robot", commandName, commandString) == nil then
                return false
            end
            return true
        end,
        GetDefaultForce = function(targetPlayer)
            return targetPlayer.force --[[@as LuaForce # Sumneko R/W workaround.]]
        end,
        GetEntityName = function()
            return setEntityName
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end,
        gridPlacementSize = gridSize,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2, searchOnlyInTileCenter)
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
---@param turretName string # Prototype entity name
---@param ammoName? string|nil # Prototype item name
---@return SpawnAroundPlayer_EntityTypeDetails
SpawnAroundPlayer.GenerateAmmoGunTurretEntityTypeDetails = function(turretName, ammoName)
    local gridSize, searchOnlyInTileCenter = SpawnAroundPlayer.GetEntityTypeFunctionPlacementDetails(turretName)

    ---@type SpawnAroundPlayer_EntityTypeDetails
    local entityTypeDetails = {
        ValidateEntityPrototypes = function(commandString)
            if Common.GetBaseGameEntityByName(turretName, "ammo-turret", commandName, commandString) == nil then
                return false
            end
            if ammoName ~= nil and Common.GetBaseGameItemByName(ammoName, "ammo", commandName, commandString) == nil then
                return false
            end
            return true
        end,
        GetDefaultForce = function(targetPlayer)
            return targetPlayer.force --[[@as LuaForce # Sumneko R/W workaround.]]
        end,
        GetEntityName = function()
            return turretName
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RoundPosition(position, 0)
        end,
        gridPlacementSize = gridSize,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1, searchOnlyInTileCenter)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            local turret = data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
            if turret ~= nil and ammoName ~= nil then
                turret.insert({ name = ammoName, count = data.ammoCount })
            end
        end
    }
    return entityTypeDetails
end

--- Handler for the generic fire type entities.
---@param setEntityName string # Prototype item name
---@return SpawnAroundPlayer_EntityTypeDetails
SpawnAroundPlayer.GenerateFireEntityTypeDetails = function(setEntityName)
    local gridSize = SpawnAroundPlayer.GetEntityTypeFunctionPlacementDetails(setEntityName)

    ---@type SpawnAroundPlayer_EntityTypeDetails
    local entityTypeDetails = {
        ValidateEntityPrototypes = function(commandString)
            if Common.GetBaseGameEntityByName(setEntityName, "fire", commandName, commandString) == nil then
                return false
            end
            return true
        end,
        GetDefaultForce = function()
            return global.Forces.muppet_streamer_enemy
        end,
        GetEntityName = function()
            return setEntityName
        end,
        GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end,
        gridPlacementSize = gridSize,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 0.2, false)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            local flameCount ---@type uint8|nil
            if data.ammoCount ~= nil then
                flameCount = MathUtils.ClampToUInt8(data.ammoCount)
            end
            data.surface.create_entity { name = data.entityName, position = data.position, force = data.force, initial_ground_flame_count = flameCount }
        end
    }
    return entityTypeDetails
end

--- Handler for the generic standard entities which have a placement size of 1 per tile area max (not dense like trees).
---@param entityName string
---@param entityType string
---@return SpawnAroundPlayer_EntityTypeDetails
SpawnAroundPlayer.GenerateStandardTileEntityTypeDetails = function(entityName, entityType)
    local gridSize, searchOnlyInTileCenter, placeInCenterOfTile = SpawnAroundPlayer.GetEntityTypeFunctionPlacementDetails(entityName)

    ---@type SpawnAroundPlayer_EntityTypeDetails
    local entityTypeDetails = {
        ValidateEntityPrototypes = function(commandString)
            if Common.GetBaseGameEntityByName(entityName, entityType, commandName, commandString) == nil then
                return false
            end
            return true
        end,
        GetDefaultForce = function(targetPlayer)
            return targetPlayer.force --[[@as LuaForce # Sumneko R/W workaround.]]
        end,
        GetEntityName = function()
            return entityName
        end,
        gridPlacementSize = gridSize,
        FindValidPlacementPosition = function(surface, entityName, position, searchRadius)
            return surface.find_non_colliding_position(entityName, position, searchRadius, 1, searchOnlyInTileCenter)
        end,
        ---@param data SpawnAroundPlayer_PlaceEntityDetails
        PlaceEntity = function(data)
            data.surface.create_entity { name = data.entityName, position = data.position, force = data.force }
        end
    }

    if placeInCenterOfTile then
        entityTypeDetails.GetEntityAlignedPosition = function(position)
            return PositionUtils.RoundPosition(position, 0)
        end
    else
        entityTypeDetails.GetEntityAlignedPosition = function(position)
            return PositionUtils.RandomLocationInRadius(position, SpawnAroundPlayer.offGridPlacementJitter)
        end
    end

    return entityTypeDetails
end

--- Gets details about an entity's placement attributes. Used when making the EntityTypeDetails functions object.
---
--- Often only some of the results will be used by the calling function as many entity types have hard coded results, i.e. fire is always placed off-grid.
---@param entityName string
---@return uint gridSize
---@return boolean searchOnlyInTileCenter
---@return boolean placeInCenterOfTile
SpawnAroundPlayer.GetEntityTypeFunctionPlacementDetails = function(entityName)
    local entityPrototype = game.entity_prototypes[entityName]

    local collisionBox = entityPrototype.collision_box
    local gridSize = math.ceil(math.max((collisionBox.right_bottom.x - collisionBox.left_top.x), (collisionBox.right_bottom.x - collisionBox.left_top.x), 1)) --[[@as uint # Min of gridSize 1 and its rounded up to an integer.]]

    local searchOnlyInTileCenter
    if gridSize % 2 == 0 then
        -- grid size is a multiple of 2 (even number).
        searchOnlyInTileCenter = false
    else
        -- grid size is an odd number.
        searchOnlyInTileCenter = true
    end

    local placeInCenterOfTile
    if entityPrototype.flags["placeable-off-grid"] then
        placeInCenterOfTile = false
    else
        placeInCenterOfTile = true
    end

    return gridSize, searchOnlyInTileCenter, placeInCenterOfTile
end

---Get how many bots can be set to follow the player currently.
---@param targetPlayer LuaPlayer
---@return uint
SpawnAroundPlayer.GetMaxBotFollowerCountForPlayer = function(targetPlayer)
    if targetPlayer.character == nil then
        return 0
    end
    local max = targetPlayer.character_maximum_following_robot_count_bonus + targetPlayer.force.maximum_following_robot_count
    local current = #targetPlayer.following_robots --[[@as uint # The game doesn't allow more than a uint max following robots, so the count can't be above a uint.]]
    return max - current
end

return SpawnAroundPlayer
