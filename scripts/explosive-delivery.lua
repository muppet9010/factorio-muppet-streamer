local ExplosiveDelivery = {}
local Commands = require("utility.managerLibraries.commands")
local LoggingUtils = require("utility.helperUtils.logging-utils")
local EventScheduler = require("utility.managerLibraries.event-scheduler")
local PositionUtils = require("utility.helperUtils.position-utils")
local Common = require("scripts.common")

---@class ExplosiveDelivery_DelayedCommandDetails
---@field explosiveCount int
---@field explosiveType ExplosiveDelivery_ExplosiveType
---@field accuracyRadiusMin float
---@field accuracyRadiusMax float
---@field target string
---@field targetPosition MapPosition|nil
---@field targetOffset MapPosition|nil
---@field salvoWaveId int|nil
---@field finalSalvo boolean

---@class ExplosiveDelivery_SalvoWaveDetails
---@field targetPosition MapPosition
---@field targetSurface LuaSurface

ExplosiveDelivery.CreateGlobals = function()
    global.explosiveDelivery = global.explosiveDelivery or {}
    global.explosiveDelivery.nextId = global.explosiveDelivery.nextId or 0 ---@type int
    global.explosiveDelivery.nextSalvoWaveId = global.explosiveDelivery.nextSalvoWaveId or 0 ---@type int
    global.explosiveDelivery.salvoWaveDetails = global.explosiveDelivery.salvoWaveDetails or {} ---@type table<int,ExplosiveDelivery_SalvoWaveDetails>
end

ExplosiveDelivery.OnLoad = function()
    Commands.Register("muppet_streamer_schedule_explosive_delivery", {"api-description.muppet_streamer_schedule_explosive_delivery"}, ExplosiveDelivery.ScheduleExplosiveDeliveryCommand, true)
    EventScheduler.RegisterScheduledEventType("ExplosiveDelivery.DeliverExplosives", ExplosiveDelivery.DeliverExplosives)
end

ExplosiveDelivery.ScheduleExplosiveDeliveryCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_schedule_explosive_delivery command "
    local commandName = "muppet_streamer_schedule_explosive_delivery"
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

    local explosiveCount = tonumber(commandData.explosiveCount)
    if explosiveCount == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "explosiveCount is mandatory as a number")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    elseif explosiveCount <= 0 then
        return
    end

    local explosiveType = ExplosiveDelivery.ExplosiveTypes[commandData.explosiveType] ---@type ExplosiveDelivery_ExplosiveType
    if explosiveType == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "explosiveType is mandatory and must be a supported type")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

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

    local targetPosition = commandData.targetPosition ---@type MapPosition|nil
    if targetPosition ~= nil then
        targetPosition = PositionUtils.TableToProperPosition(targetPosition)
        if targetPosition == nil then
            LoggingUtils.LogPrintError(errorMessageStart .. "targetPosition is Optional, but if provided must be a valid position table string")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    local targetOffset = commandData.targetOffset ---@type MapPosition|nil
    if targetOffset ~= nil then
        targetOffset = PositionUtils.TableToProperPosition(targetOffset)
        if targetOffset == nil then
            LoggingUtils.LogPrintError(errorMessageStart .. "targetOffset is Optional, but if provided must be a valid position table string")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    ---@type number|nil
    local accuracyRadiusMin = 0
    if commandData.accuracyRadiusMin ~= nil then
        accuracyRadiusMin = tonumber(commandData.accuracyRadiusMin)
        if accuracyRadiusMin == nil or accuracyRadiusMin < 0 then
            LoggingUtils.LogPrintError(errorMessageStart .. "accuracyRadiusMin is Optional, but must be a non-negative number if supplied")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    ---@type number|nil
    local accuracyRadiusMax = 0
    if commandData.accuracyRadiusMax ~= nil then
        accuracyRadiusMax = tonumber(commandData.accuracyRadiusMax)
        if accuracyRadiusMax == nil or accuracyRadiusMax < 0 then
            LoggingUtils.LogPrintError(errorMessageStart .. "accuracyRadiusMax is Optional, but must be a non-negative number if supplied")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    ---@type number|nil
    local salvoSize = explosiveCount
    if commandData.salvoSize ~= nil then
        salvoSize = tonumber(commandData.salvoSize)
        if salvoSize == nil or salvoSize < 0 then
            LoggingUtils.LogPrintError(errorMessageStart .. "salvoSize is Optional, but must be a non-negative number if supplied")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    ---@type number|nil
    local salvoDelay = 0
    if commandData.salvoDelay ~= nil then
        salvoDelay = tonumber(commandData.salvoDelay)
        if salvoDelay == nil or salvoDelay < 0 then
            LoggingUtils.LogPrintError(errorMessageStart .. "salvoDelay is Optional, but must be a non-negative number if supplied")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    -- If this is a multi salvo wave we need to cache the target position from the first delivery for the subsequent deliveryies of that wave. So setup the salvoWaveId for later population.
    local maxBatchNumber = 0 -- Batch 0 is the first batch.
    local salvoWaveId
    if explosiveCount > salvoSize then
        global.explosiveDelivery.nextSalvoWaveId = global.explosiveDelivery.nextSalvoWaveId + 1
        salvoWaveId = global.explosiveDelivery.nextSalvoWaveId
        maxBatchNumber = math.ceil(explosiveCount / salvoSize) - 1
    end

    local explosiveCountRemaining = explosiveCount
    for batchNumber = 0, maxBatchNumber do
        explosiveCount = math.min(salvoSize, explosiveCountRemaining)
        explosiveCountRemaining = explosiveCountRemaining - explosiveCount

        global.explosiveDelivery.nextId = global.explosiveDelivery.nextId + 1
        EventScheduler.ScheduleEventOnce(
            scheduleTick + (batchNumber * salvoDelay) --[[@as uint]],
            "ExplosiveDelivery.DeliverExplosives",
            global.explosiveDelivery.nextId,
            {
                explosiveCount = explosiveCount,
                explosiveType = explosiveType,
                accuracyRadiusMin = accuracyRadiusMin,
                accuracyRadiusMax = accuracyRadiusMax,
                target = target,
                targetPosition = targetPosition,
                targetOffset = targetOffset,
                salvoWaveId = salvoWaveId,
                finalSalvo = batchNumber == maxBatchNumber
            }
        )
    end
end

ExplosiveDelivery.DeliverExplosives = function(eventData)
    local data = eventData.data ---@type ExplosiveDelivery_DelayedCommandDetails

    local targetPlayer = game.get_player(data.target)
    -- Don't need to check if the target is alive or anything. We will happily bomb their corpse.

    ---@typelist MapPosition, LuaSurface
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
    for i = 1, data.explosiveCount do
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
