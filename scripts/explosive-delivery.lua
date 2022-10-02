local ExplosiveDelivery = {} ---@class ExplosiveDelivery
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local PositionUtils = require("utility.helper-utils.position-utils")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@class ExplosiveDelivery_DelayedCommandDetails
---@field explosiveCount uint
---@field explosiveType ExplosiveDelivery_Type
---@field explosivePrototype LuaEntityPrototype
---@field accuracyRadiusMin double
---@field accuracyRadiusMax double
---@field target string
---@field targetPosition MapPosition|nil
---@field targetOffset MapPosition|nil
---@field salvoWaveId uint|nil
---@field finalSalvo boolean
---@field salvoFollowPlayer boolean

---@class ExplosiveDelivery_SalvoWaveDetails
---@field targetPosition MapPosition
---@field targetSurface LuaSurface

local CommandName = "muppet_streamer_schedule_explosive_delivery"

ExplosiveDelivery.CreateGlobals = function()
    global.explosiveDelivery = global.explosiveDelivery or {}
    global.explosiveDelivery.nextId = global.explosiveDelivery.nextId or 0 ---@type uint
    global.explosiveDelivery.nextSalvoWaveId = global.explosiveDelivery.nextSalvoWaveId or 0 ---@type uint
    global.explosiveDelivery.salvoWaveDetails = global.explosiveDelivery.salvoWaveDetails or {} ---@type table<int,ExplosiveDelivery_SalvoWaveDetails>
end

ExplosiveDelivery.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_schedule_explosive_delivery", { "api-description.muppet_streamer_schedule_explosive_delivery" }, ExplosiveDelivery.ScheduleExplosiveDeliveryCommand, true)
    EventScheduler.RegisterScheduledEventType("ExplosiveDelivery.DeliverExplosives", ExplosiveDelivery.DeliverExplosives)
    MOD.Interfaces.Commands.ExplosiveDelivery = ExplosiveDelivery.ScheduleExplosiveDeliveryCommand
end

---@param command CustomCommandData
ExplosiveDelivery.ScheduleExplosiveDeliveryCommand = function(command)
    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, CommandName, { "delay", "explosiveCount", "explosiveType", "customExplosiveType", "customExplosiveSpeed", "target", "targetPosition", "targetOffset", "accuracyRadiusMin", "accuracyRadiusMax", "salvoSize", "salvoDelay", "salvoFollowPlayer" })
    if commandData == nil then
        return
    end

    local delaySeconds = commandData.delay
    if not CommandsUtils.CheckNumberArgument(delaySeconds, "double", false, CommandName, "delay", 0, nil, command.parameter) then
        return
    end ---@cast delaySeconds double|nil
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySeconds, command.tick, CommandName, "delay")

    local explosiveCount = commandData.explosiveCount
    if not CommandsUtils.CheckNumberArgument(explosiveCount, "int", true, CommandName, "explosiveCount", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast explosiveCount uint

    -- Just get these settings and make sure they are the right data type, validate their sanity later.
    local customExplosiveType_string = commandData.customExplosiveType
    if not CommandsUtils.CheckStringArgument(customExplosiveType_string, false, CommandName, "customExplosiveType", nil, command.parameter) then
        return
    end ---@cast customExplosiveType_string string|nil
    local customExplosiveSpeed = commandData.customExplosiveSpeed
    if not CommandsUtils.CheckNumberArgument(customExplosiveSpeed, 'double', false, CommandName, "customExplosiveSpeed", 0.1, nil, command.parameter) then
        return
    end ---@cast customExplosiveSpeed double|nil

    local explosiveType_string = commandData.explosiveType
    if not CommandsUtils.CheckStringArgument(explosiveType_string, true, CommandName, "explosiveType", ExplosiveDelivery.Types, command.parameter) then
        return
    end ---@cast explosiveType_string string
    local explosiveType = ExplosiveDelivery.Types[explosiveType_string] ---@type ExplosiveDelivery_Type
    local explosivePrototype, explosivePrototype_name
    local explosiveTypeWasCustom = false
    if explosiveType.type == "projectile" then
        ---@cast explosiveType ExplosiveDelivery_Type_Projectile
        explosivePrototype_name = explosiveType.projectileName
    elseif explosiveType.type == "stream" then
        ---@cast explosiveType ExplosiveDelivery_Type_Stream
        explosivePrototype_name = explosiveType.streamName
    elseif explosiveType.type == "custom" then
        -- Populate a standard details from the custom settings to make it look "normal" to later code. Lots of validation needed for this.
        if customExplosiveType_string == nil then
            CommandsUtils.LogPrintError(CommandName, "customExplosiveType", "customExplosiveType wasn't provided, but is required as the explosiveType is 'custom'.", command.parameter)
            return
        end
        explosivePrototype = game.entity_prototypes[customExplosiveType_string]
        if explosivePrototype == nil then
            CommandsUtils.LogPrintError(CommandName, "customExplosiveType", "entity '" .. customExplosiveType_string .. "' wasn't a valid entity name", command.parameter)
            return
        end
        local explosivePrototype_type = explosivePrototype.type
        explosivePrototype_name = customExplosiveType_string
        explosiveTypeWasCustom = true
        if explosivePrototype_type == "projectile" or explosivePrototype_type == "artillery-projectile" then
            -- The projectile and artillery-projectile are treated equally as they have the same creation options.
            ---@type ExplosiveDelivery_Type_Projectile
            explosiveType = {
                type = "projectile",
                projectileName = explosivePrototype_name,
                speed = customExplosiveSpeed or 0.3
            }
        elseif explosivePrototype_type == "stream" then
            ---@type ExplosiveDelivery_Type_Stream
            explosiveType = {
                type = "stream",
                streamName = explosivePrototype_name
            }
        else
            CommandsUtils.LogPrintError(CommandName, "customExplosiveType", "entity '" .. customExplosiveType_string .. "' wasn't a projectile, artillery-projectile or stream entity type, instead it was a type: " .. tostring(explosivePrototype_type), command.parameter)
            return
        end
    end

    -- Check non custom explosive type's names match their expected type, in case a mod has changed something odd.
    if not explosiveTypeWasCustom then
        local validPrototypeTypes
        if explosiveType.type == "projectile" then
            validPrototypeTypes = { "projectile", "artillery-projectile" }
        elseif explosiveType.type == "stream" then
            validPrototypeTypes = "stream"
        else
            error("unsupported explosiveType.type: " .. tostring(explosiveType.type))
        end
        explosivePrototype = Common.GetBaseGameEntityByName(explosivePrototype_name, validPrototypeTypes, CommandName, command.parameter)
        if explosivePrototype == nil then
            return
        end
    end

    -- Check no ignored custom explosive related settings.
    if not explosiveTypeWasCustom then
        -- Was a built-in option and so these should never be populated.
        if customExplosiveType_string ~= nil then
            CommandsUtils.LogPrintWarning(CommandName, "customExplosiveType", "customExplosiveType was provided, but being ignored as the explosiveType wasn't 'custom'.", command.parameter)
        end
        if customExplosiveSpeed ~= nil then
            CommandsUtils.LogPrintWarning(CommandName, "customExplosiveSpeed", "customExplosiveSpeed was provided, but being ignored as the explosiveType wasn't 'custom'.", command.parameter)
        end
    else
        -- Was a custom explosive type, so check if speed was populated and valid for this type.
        if customExplosiveSpeed ~= nil and explosiveType.type == "stream" then
            CommandsUtils.LogPrintWarning(CommandName, "customExplosiveSpeed", "customExplosiveSpeed was provided, but being ignored as the custom explosive type isn't a 'projectile' or 'artillery-projectile'.", command.parameter)
        end
    end

    local target = commandData.target
    if not Common.CheckPlayerNameSettingValue(target, CommandName, "target", command.parameter) then
        return
    end ---@cast target string

    local targetPosition = commandData.targetPosition
    if not CommandsUtils.CheckTableArgument(targetPosition, false, CommandName, "targetPosition", PositionUtils.MapPositionConvertibleTableValidKeysList, command.parameter) then
        return
    end ---@cast targetPosition MapPosition|nil
    if targetPosition ~= nil then
        targetPosition = PositionUtils.TableToProperPosition(targetPosition)
        if targetPosition == nil then
            CommandsUtils.LogPrintError(CommandName, "targetPosition", "must be a valid position table string", command.parameter)
            return
        end
    end

    local targetOffset = commandData.targetOffset ---@type MapPosition|nil
    if not CommandsUtils.CheckTableArgument(targetOffset, false, CommandName, "targetOffset", PositionUtils.MapPositionConvertibleTableValidKeysList, command.parameter) then
        return
    end ---@cast targetOffset MapPosition|nil
    if targetOffset ~= nil then
        targetOffset = PositionUtils.TableToProperPosition(targetOffset)
        if targetOffset == nil then
            CommandsUtils.LogPrintError(CommandName, "targetOffset", "must be a valid position table string", command.parameter)
            return
        end
    end

    local accuracyRadiusMin = commandData.accuracyRadiusMin
    if not CommandsUtils.CheckNumberArgument(accuracyRadiusMin, "double", false, CommandName, "accuracyRadiusMin", 0, nil, command.parameter) then
        return
    end ---@cast accuracyRadiusMin double|nil
    if accuracyRadiusMin == nil then
        accuracyRadiusMin = 0.0
    end

    local accuracyRadiusMax = commandData.accuracyRadiusMax
    if not CommandsUtils.CheckNumberArgument(accuracyRadiusMax, "double", false, CommandName, "accuracyRadiusMax", 0, nil, command.parameter) then
        return
    end ---@cast accuracyRadiusMax double|nil
    if accuracyRadiusMax == nil then
        accuracyRadiusMax = 0.0
    end

    local salvoSize = commandData.salvoSize
    if not CommandsUtils.CheckNumberArgument(salvoSize, "int", false, CommandName, "salvoSize", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast salvoSize uint|nil
    salvoSize = salvoSize or explosiveCount

    local salvoDelayTicks = commandData.salvoDelay
    if not CommandsUtils.CheckNumberArgument(salvoDelayTicks, "int", false, CommandName, "salvoDelay", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast salvoDelayTicks uint|nil
    salvoDelayTicks = salvoDelayTicks or 0

    -- If this is a multi salvo wave we need to cache the target position from the first delivery for the subsequent deliveries of that wave. So setup the salvoWaveId for later population.
    local maxBatchNumber = 0 ---@type uint # Batch 0 is the first batch.
    local salvoWaveId ---@type uint|nil
    if explosiveCount > salvoSize then
        global.explosiveDelivery.nextSalvoWaveId = global.explosiveDelivery.nextSalvoWaveId + 1
        salvoWaveId = global.explosiveDelivery.nextSalvoWaveId
        maxBatchNumber = math.floor(explosiveCount / salvoSize) --[[@as uint # Both inputs are verified uints and with the math.floor() it can't go below 0]]
        -- Counting starts at 0 so flooring gives the -1 from total needed by loop.
    end

    local salvoFollowPlayer = commandData.salvoFollowPlayer
    if not CommandsUtils.CheckBooleanArgument(salvoFollowPlayer, false, CommandName, "salvoFollowPlayer", command.parameter) then
        return
    end ---@cast salvoFollowPlayer boolean|nil
    if salvoFollowPlayer == nil then
        salvoFollowPlayer = false
    end

    local explosiveCountRemaining = explosiveCount
    ---@type uint
    for batchNumber = 0, maxBatchNumber do
        explosiveCount = math.min(salvoSize, explosiveCountRemaining) --[[@as uint]]
        explosiveCountRemaining = explosiveCountRemaining - explosiveCount

        global.explosiveDelivery.nextId = global.explosiveDelivery.nextId + 1
        ---@type ExplosiveDelivery_DelayedCommandDetails
        local delayedCommandDetails = {
            explosiveCount = explosiveCount,
            explosiveType = explosiveType,
            explosivePrototype = explosivePrototype,
            accuracyRadiusMin = accuracyRadiusMin,
            accuracyRadiusMax = accuracyRadiusMax,
            target = target,
            targetPosition = targetPosition,
            targetOffset = targetOffset,
            salvoWaveId = salvoWaveId,
            finalSalvo = (batchNumber == maxBatchNumber),
            salvoFollowPlayer = salvoFollowPlayer
        }

        local batchScheduleTick ---@type UtilityScheduledEvent_UintNegative1
        local batchSalvoDelay = batchNumber * salvoDelayTicks
        if batchSalvoDelay > 0 then
            -- There's a salvo delay.
            if scheduleTick == -1 then
                -- Is the special do it now value.
                batchScheduleTick = command.tick + batchSalvoDelay
            else
                -- Is greater than 0.
                batchScheduleTick = scheduleTick + batchSalvoDelay
            end
        else
            -- No salvo delay so do at main delayed time.
            if scheduleTick == -1 then
                -- Is the special do it now value.
                batchScheduleTick = -1
            else
                -- Is greater than 0.
                batchScheduleTick = scheduleTick + batchSalvoDelay
            end
        end
        EventScheduler.ScheduleEventOnce(batchScheduleTick, "ExplosiveDelivery.DeliverExplosives", global.explosiveDelivery.nextId, delayedCommandDetails)
    end
end

---@param eventData UtilityScheduledEvent_CallbackObject
ExplosiveDelivery.DeliverExplosives = function(eventData)
    local data = eventData.data ---@type ExplosiveDelivery_DelayedCommandDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        return
    end
    -- Don't need to check if the target is alive or anything. We will happily bomb their corpse.

    -- Check the explosive is still valid (unchanged).
    if not data.explosivePrototype.valid then
        CommandsUtils.LogPrintWarning(CommandName, nil, "The in-game explosive prototype has been changed/removed since the command was run.", nil)
        return
    end

    ---@type MapPosition, LuaSurface
    local targetPos, surface
    local salvoWaveId = data.salvoWaveId -- Variables existence is a work around for Sumneko's missing object field nil detection.
    -- Check if we need to obtain a target position from the salvo wave rather than calculate it now. SalvoWaveId is nil if its a single explosive grouping.
    if salvoWaveId ~= nil and global.explosiveDelivery.salvoWaveDetails[salvoWaveId] ~= nil then
        if not data.salvoFollowPlayer then
            -- Load the initial salvo target position for every subsequent salvo.
            targetPos = global.explosiveDelivery.salvoWaveDetails[salvoWaveId].targetPosition
        else
            -- Calculate the target position for every salvo.
            targetPos = data.targetPosition or targetPlayer.position
            if data.targetOffset ~= nil then
                targetPos.x = targetPos.x + data.targetOffset.x
                targetPos.y = targetPos.y + data.targetOffset.y
            end
        end
        surface = global.explosiveDelivery.salvoWaveDetails[salvoWaveId].targetSurface
        if data.finalSalvo then
            global.explosiveDelivery.salvoWaveDetails[salvoWaveId] = nil
        end

        -- Check the surface is still valid as it could have been deleted mid salvo.
        if not surface.valid then
            -- Just give up on this salvo if the surface is gone.
            return
        end
    else
        -- Calculate the target position now.
        targetPos = data.targetPosition or targetPlayer.position
        if data.targetOffset ~= nil then
            targetPos.x = targetPos.x + data.targetOffset.x
            targetPos.y = targetPos.y + data.targetOffset.y
        end
        surface = targetPlayer.surface
        if salvoWaveId ~= nil then
            -- Cache the salvo wave target position for the rest of the salvo wave.
            global.explosiveDelivery.salvoWaveDetails[salvoWaveId] = {
                targetPosition = targetPos,
                targetSurface = surface
            }
        end
    end

    local explosiveType = data.explosiveType
    for _ = 1, data.explosiveCount do
        -- The explosives have to be fired at something, so we make a temporary dummy target entity at the desired explosion position.
        local targetEntityPos = PositionUtils.RandomLocationInRadius(targetPos, data.accuracyRadiusMax, data.accuracyRadiusMin)
        local targetEntity = surface.create_entity { name = "muppet_streamer-explosive-delivery-target", position = targetEntityPos }

        -- If the entity fails to create (should never happen) just skip this explosive.
        if targetEntity == nil then
            goto CreateExplosiveLoop_End
        end

        -- Spawn the explosives off the players screen (non map view). Have to allow enough distance for explosives crossing players screen, i.e. the targetPos being NW of the player and the explosives spawn SE of the player, they need to be far away enough away to spawn off the player's screen before flying over their head.
        local explosiveCreateDistance = math.max(100, data.accuracyRadiusMax * 2)
        local explosiveCreatePos = PositionUtils.RandomLocationInRadius(targetPos, explosiveCreateDistance, explosiveCreateDistance)

        if explosiveType.type == "projectile" then
            ---@cast explosiveType ExplosiveDelivery_Type_Projectile
            surface.create_entity { name = explosiveType.projectileName, position = explosiveCreatePos, target = targetEntity, speed = explosiveType.speed, force = global.Forces.muppet_streamer_enemy, create_build_effect_smoke = false, raise_built = true }
        elseif explosiveType.type == "stream" then
            ---@cast explosiveType ExplosiveDelivery_Type_Stream
            surface.create_entity { name = explosiveType.streamName, position = explosiveCreatePos, target = targetEntity, source_position = explosiveCreatePos, force = global.Forces.muppet_streamer_enemy, create_build_effect_smoke = false, raise_built = true }
        end

        -- Remove the temporary dummy target entity.
        targetEntity.destroy()

        ::CreateExplosiveLoop_End::
    end
end

---@class ExplosiveDelivery_Type
---@field type "projectile"|"stream"|"custom"

---@class ExplosiveDelivery_Type_Projectile : ExplosiveDelivery_Type # Includes both projectile and artillery-projectile as they have the same attributes.
---@field projectileName string
---@field speed double

---@class ExplosiveDelivery_Type_Stream : ExplosiveDelivery_Type
---@field streamName string

---@class ExplosiveDelivery_Type_Custom_Generic : ExplosiveDelivery_Type

---@class ExplosiveDelivery_Types
ExplosiveDelivery.Types = {
    ---@class ExplosiveDelivery_Type_Projectile
    grenade = {
        type = "projectile",
        projectileName = "grenade",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_Type_Projectile
    clusterGrenade = {
        type = "projectile",
        projectileName = "cluster-grenade",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_Type_Projectile
    slowdownCapsule = {
        type = "projectile",
        projectileName = "slowdown-capsule",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_Type_Projectile
    poisonCapsule = {
        type = "projectile",
        projectileName = "poison-capsule",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_Type_Projectile
    artilleryShell = {
        type = "projectile",
        projectileName = "artillery-projectile",
        speed = 1
    },
    ---@class ExplosiveDelivery_Type_Projectile
    explosiveRocket = {
        type = "projectile",
        projectileName = "explosive-rocket",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_Type_Projectile
    atomicRocket = {
        type = "projectile",
        projectileName = "atomic-rocket",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_Type_Stream
    smallSpit = {
        type = "stream",
        streamName = "acid-stream-spitter-small"
    },
    ---@class ExplosiveDelivery_Type_Stream
    mediumSpit = {
        type = "stream",
        streamName = "acid-stream-worm-medium"
    },
    ---@class ExplosiveDelivery_Type_Stream
    largeSpit = {
        type = "stream",
        streamName = "acid-stream-worm-behemoth"
    },
    ---@class ExplosiveDelivery_Type_Custom_Generic
    custom = {
        type = "custom"
    }
}

return ExplosiveDelivery
