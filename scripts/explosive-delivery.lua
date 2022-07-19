local ExplosiveDelivery = {}
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local PositionUtils = require("utility.helper-utils.position-utils")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@class ExplosiveDelivery_DelayedCommandDetails
---@field explosiveCount uint
---@field explosiveType ExplosiveDelivery_ExplosiveType
---@field accuracyRadiusMin double
---@field accuracyRadiusMax double
---@field target string
---@field targetPosition MapPosition|nil
---@field targetOffset MapPosition|nil
---@field salvoWaveId uint|nil
---@field finalSalvo boolean

---@class ExplosiveDelivery_SalvoWaveDetails
---@field targetPosition MapPosition
---@field targetSurface LuaSurface

ExplosiveDelivery.CreateGlobals = function()
    global.explosiveDelivery = global.explosiveDelivery or {}
    global.explosiveDelivery.nextId = global.explosiveDelivery.nextId or 0 ---@type uint
    global.explosiveDelivery.nextSalvoWaveId = global.explosiveDelivery.nextSalvoWaveId or 0 ---@type uint
    global.explosiveDelivery.salvoWaveDetails = global.explosiveDelivery.salvoWaveDetails or {} ---@type table<int,ExplosiveDelivery_SalvoWaveDetails>
end

ExplosiveDelivery.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_schedule_explosive_delivery", {"api-description.muppet_streamer_schedule_explosive_delivery"}, ExplosiveDelivery.ScheduleExplosiveDeliveryCommand, true)
    EventScheduler.RegisterScheduledEventType("ExplosiveDelivery.DeliverExplosives", ExplosiveDelivery.DeliverExplosives)
end

---@param command CustomCommandData
ExplosiveDelivery.ScheduleExplosiveDeliveryCommand = function(command)
    local commandName = "muppet_streamer_schedule_explosive_delivery"

    local commandData = CommandsUtils.GetSettingsTableFromCommandParamaterString(command.parameter, true, commandName, {"delay", "explosiveCount", "explosiveType", "target", "targetPosition", "targetOffset", "accuracyRadiusMin", "accuracyRadiusMax", "salvoSize", "salvoDelay"})
    if commandData == nil then
        return
    end

    local delaySeconds = commandData.delay
    if not CommandsUtils.CheckNumberArgument(delaySeconds, "double", false, commandName, "delay", 0, nil, command.parameter) then
        return
    end ---@cast delaySeconds double|nil
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySeconds, command.tick, commandName, "delay")

    local explosiveCount = commandData.explosiveCount
    if not CommandsUtils.CheckNumberArgument(explosiveCount, "int", true, commandName, "explosiveCount", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast explosiveCount uint

    if not CommandsUtils.CheckStringArgument(commandData.explosiveType, true, commandName, "explosiveType", ExplosiveDelivery.ExplosiveTypes, command.parameter) then
        return
    end
    local explosiveType = ExplosiveDelivery.ExplosiveTypes[commandData.explosiveType --[[@as string]]] ---@type ExplosiveDelivery_ExplosiveType

    local target = commandData.target
    if not Common.CheckPlayerNameSettingValue(target, commandName, "target", command.parameter) then
        return
    end ---@cast target string

    local targetPosition = commandData.targetPosition
    if not CommandsUtils.CheckTableArgument(targetPosition, false, commandName, "targetPosition", PositionUtils.MapPositionConvertableTableValidKeysList, command.parameter) then
        return
    end ---@cast targetPosition MapPosition|nil
    if targetPosition ~= nil then
        targetPosition = PositionUtils.TableToProperPosition(targetPosition --[[@as MapPosition]])
        if targetPosition == nil then
            CommandsUtils.LogPrintError(commandName, "targetPosition", "must be a valid position table string", command.parameter)
            return
        end
    end

    local targetOffset = commandData.targetOffset ---@type MapPosition|nil
    if not CommandsUtils.CheckTableArgument(targetOffset, false, commandName, "targetOffset", PositionUtils.MapPositionConvertableTableValidKeysList, command.parameter) then
        return
    end ---@cast targetOffset MapPosition|nil
    if targetOffset ~= nil then
        targetOffset = PositionUtils.TableToProperPosition(targetOffset)
        if targetOffset == nil then
            CommandsUtils.LogPrintError(commandName, "targetOffset", "must be a valid position table string", command.parameter)
            return
        end
    end

    local accuracyRadiusMin = commandData.accuracyRadiusMin
    if not CommandsUtils.CheckNumberArgument(accuracyRadiusMin, "double", false, commandName, "accuracyRadiusMin", 0, nil, command.parameter) then
        return
    end ---@cast accuracyRadiusMin double|nil
    if accuracyRadiusMin == nil then
        accuracyRadiusMin = 0.0
    end

    local accuracyRadiusMax = commandData.accuracyRadiusMax
    if not CommandsUtils.CheckNumberArgument(accuracyRadiusMax, "double", false, commandName, "accuracyRadiusMax", 0, nil, command.parameter) then
        return
    end ---@cast accuracyRadiusMax double|nil
    if accuracyRadiusMax == nil then
        accuracyRadiusMax = 0.0
    end

    local salvoSize = commandData.salvoSize
    if not CommandsUtils.CheckNumberArgument(salvoSize, "int", false, commandName, "salvoSize", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast salvoSize uint|nil
    salvoSize = salvoSize or explosiveCount

    local salvoDelayTicks = commandData.salvoDelay
    if not CommandsUtils.CheckNumberArgument(salvoDelayTicks, "int", false, commandName, "salvoDelay", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast salvoDelayTicks uint|nil
    salvoDelayTicks = salvoDelayTicks or 0

    -- If this is a multi salvo wave we need to cache the target position from the first delivery for the subsequent deliveryies of that wave. So setup the salvoWaveId for later population.
    local maxBatchNumber = 0 ---@type uint @ Batch 0 is the first batch.
    local salvoWaveId  ---@type uint|nil
    if explosiveCount > salvoSize then
        global.explosiveDelivery.nextSalvoWaveId = global.explosiveDelivery.nextSalvoWaveId + 1
        salvoWaveId = global.explosiveDelivery.nextSalvoWaveId
        maxBatchNumber = math.floor(explosiveCount / salvoSize) --[[@as uint]] -- Counting starts at 0 so flooring gives the -1 from total needed by loop.
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
            accuracyRadiusMin = accuracyRadiusMin,
            accuracyRadiusMax = accuracyRadiusMax,
            target = target,
            targetPosition = targetPosition,
            targetOffset = targetOffset,
            salvoWaveId = salvoWaveId,
            finalSalvo = (batchNumber == maxBatchNumber)
        }

        local batchScheduleTick  ---@type UtilityScheduledEvent_UintNegative1
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
    -- Don't need to check if the target is alive or anything. We will happily bomb their corpse.

    ---@type MapPosition, LuaSurface
    local targetPos, surface
    -- Check if we need to obtain a target position from the salvo wave rather than calculate it now.
    if data.salvoWaveId ~= nil and global.explosiveDelivery.salvoWaveDetails[data.salvoWaveId] ~= nil then
        targetPos = global.explosiveDelivery.salvoWaveDetails[data.salvoWaveId].targetPosition
        surface = global.explosiveDelivery.salvoWaveDetails[data.salvoWaveId].targetSurface
        if data.finalSalvo then
            global.explosiveDelivery.salvoWaveDetails[data.salvoWaveId] = nil
        end
    else
        -- Calculate the target position now.
        if data.targetPosition ~= nil then
            targetPos = data.targetPosition --[[@as MapPosition]] -- This is never nil within this IF block.
        else
            targetPos = targetPlayer.position
        end
        if data.targetOffset ~= nil then
            targetPos.x = targetPos.x + data.targetOffset.x
            targetPos.y = targetPos.y + data.targetOffset.y
        end
        surface = targetPlayer.surface
        if data.salvoWaveId ~= nil then
            -- Cache the salvo wave target position for the rest of the salvo wave.
            global.explosiveDelivery.salvoWaveDetails[data.salvoWaveId] = {
                targetPosition = targetPos,
                targetSurface = surface
            }
        end
    end

    -- Check the surface is still valid as it could have been deleted mid salvo.
    if not surface.valid then
        -- Just give up on this salvo if the surface is gone.
        return
    end

    local explosiveType = data.explosiveType
    for _ = 1, data.explosiveCount do
        -- The explosives have to be fired at something, so we make a temporary dummy target entity at the desired explosion position.
        local targetEntityPos = PositionUtils.RandomLocationInRadius(targetPos, data.accuracyRadiusMax, data.accuracyRadiusMin)
        local targetEntity = surface.create_entity {name = "muppet_streamer-explosive-delivery-target", position = targetEntityPos}

        -- Spawn the explosives off the players screen (non map view). Have to allow enough distance for explosives crossing players screen, i.e. the targetPos being NW of the player and the explosives spawn SE of the player, they need to be far away enough away to spawn off the player's screen before flying over their head.
        local explosiveCreateDistance = math.max(100, data.accuracyRadiusMax * 2)
        local explosiveCreatePos = PositionUtils.RandomLocationInRadius(targetPos, explosiveCreateDistance, explosiveCreateDistance)

        if explosiveType.projectileName ~= nil then
            surface.create_entity {name = explosiveType.projectileName, position = explosiveCreatePos, target = targetEntity, speed = explosiveType.speed}
        elseif explosiveType.beamName ~= nil then
            surface.create_entity {name = explosiveType.beamName, position = explosiveCreatePos, target = targetEntity, source_position = explosiveCreatePos}
        end

        -- Remove the temporary dummy target entity.
        targetEntity.destroy()
    end
end

---@class ExplosiveDelivery_ExplosiveType
---@field projectileName string
---@field speed double

---@class ExplosiveDelivery_ExplosiveTypes
ExplosiveDelivery.ExplosiveTypes = {
    ---@class ExplosiveDelivery_ExplosiveType
    grenade = {
        projectileName = "grenade",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    clusterGrenade = {
        projectileName = "cluster-grenade",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    slowdownCapsule = {
        projectileName = "slowdown-capsule",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    poisonCapsule = {
        projectileName = "poison-capsule",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    artilleryShell = {
        projectileName = "artillery-projectile",
        speed = 1.0
    },
    ---@class ExplosiveDelivery_ExplosiveType
    explosiveRocket = {
        projectileName = "explosive-rocket",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    atomicRocket = {
        projectileName = "atomic-rocket",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    smallSpit = {
        beamName = "acid-stream-spitter-small",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    mediumSpit = {
        beamName = "acid-stream-worm-medium",
        speed = 0.3
    },
    ---@class ExplosiveDelivery_ExplosiveType
    largeSpit = {
        beamName = "acid-stream-worm-behemoth",
        speed = 0.3
    }
}

return ExplosiveDelivery
