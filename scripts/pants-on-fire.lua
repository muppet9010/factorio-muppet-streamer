-- Provided by andredrews (JD-Plays community) and inspired by Comfy scenario.

local PantsOnFire = {}
local CommandsUtils = require("utility.helper-utils.commands-utils")
local LoggingUtils = require("utility.helper-utils.logging-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Events = require("utility.manager-libraries.events")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@class PantsOnFire_ScheduledEventDetails
---@field target string @ Target player's name.
---@field finishTick uint
---@field fireHeadStart uint
---@field fireGap uint @ Must be > 0.
---@field flameCount uint @ Must be > 0.

---@class PantsOnFire_EffectDetails
---@field player LuaPlayer
---@field finishTick uint
---@field fireHeadStart uint
---@field fireGap uint @ Must be > 0.
---@field flameCount uint @ Must be > 0.
---@field startFire boolean
---@field stepPos uint
---@field force LuaForce
---@field ticksInVehicle uint

---@class PantsOnFire_EffectEndStatus
---@class PantsOnFire_EffectEndStatus.__index
local EffectEndStatus = {
    completed = ("completed") --[[@as PantsOnFire_EffectEndStatus]],
    died = ("died") --[[@as PantsOnFire_EffectEndStatus]],
    invalid = ("invalid") --[[@as PantsOnFire_EffectEndStatus]]
}

PantsOnFire.CreateGlobals = function()
    global.PantsOnFire = global.PantsOnFire or {}
    global.PantsOnFire.nextId = global.PantsOnFire.nextId or 0
    global.PantsOnFire.playerSteps = global.PantsOnFire.playerSteps or {}
end

PantsOnFire.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_pants_on_fire", {"api-description.muppet_streamer_pants_on_fire"}, PantsOnFire.PantsOnFireCommand, true)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "PantsOnFire.OnPrePlayerDied", PantsOnFire.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("PantsOnFire.WalkCheck", PantsOnFire.WalkCheck)
    EventScheduler.RegisterScheduledEventType("PantsOnFire.ApplyToPlayer", PantsOnFire.ApplyToPlayer)
end

---@param command CustomCommandData
PantsOnFire.PantsOnFireCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_pants_on_fire command "
    local commandName = "muppet_streamer_pants_on_fire"
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
    if not CommandsUtils.ParseNumberArgument(delaySecondsRaw, "double", false, commandName, "delay", 0, nil, command.parameter) then
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

    local durationSeconds = tonumber(commandData.duration)
    if durationSeconds == nil then
        LoggingUtils.LogPrintError(errorMessageStart .. "duration is Mandatory, must be 0 or greater")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end
    local finishTick = (scheduleTick > 0 and scheduleTick or command.tick) + math.ceil(durationSeconds * 60) --[[@as uint]]

    ---@type number|nil
    local fireHeadStart = 3
    if commandData.fireHeadStart ~= nil then
        fireHeadStart = tonumber(commandData.fireHeadStart)
        if fireHeadStart == nil or fireHeadStart < 0 then
            LoggingUtils.LogPrintError(errorMessageStart .. "fireHeadStart is Optional, but must be 0 or greater if supplied")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end
    ---@cast fireHeadStart uint

    ---@type number|nil
    local fireGap = 6
    if commandData.fireGap ~= nil then
        fireGap = tonumber(commandData.fireGap)
        if fireGap == nil or fireGap <= 0 then
            LoggingUtils.LogPrintError(errorMessageStart .. "fireGap is Optional, but must be 1 or greater if supplied")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end
    ---@cast fireGap uint

    ---@type number|nil
    local flameCount = 20
    if commandData.flameCount ~= nil then
        flameCount = tonumber(commandData.flameCount)
        if flameCount == nil or flameCount <= 0 then
            LoggingUtils.LogPrintError(errorMessageStart .. "flameCount is Optional, but must be 1 or greater if supplied")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end
    ---@cast flameCount uint

    global.PantsOnFire.nextId = global.PantsOnFire.nextId + 1
    ---@type PantsOnFire_ScheduledEventDetails
    local scheduledEventDetails = {target = target, finishTick = finishTick, fireHeadStart = fireHeadStart, fireGap = fireGap, flameCount = flameCount}
    EventScheduler.ScheduleEventOnce(scheduleTick, "PantsOnFire.ApplyToPlayer", global.PantsOnFire.nextId, scheduledEventDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
PantsOnFire.ApplyToPlayer = function(eventData)
    local data = eventData.data ---@type PantsOnFire_ScheduledEventDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({"message.muppet_streamer_pants_on_fire_not_character_controller", data.target})
        return
    end
    local targetPlayer_index = targetPlayer.index

    -- Effect is already applied to player so don't start a new one.
    if global.PantsOnFire.playerSteps[targetPlayer_index] ~= nil then
        return
    end

    -- Start the process on the player.
    global.PantsOnFire.playerSteps[targetPlayer_index] = {}
    game.print({"message.muppet_streamer_pants_on_fire_start", targetPlayer.name})

    -- stepPos starts at 0 so the first step happens at offset 1
    ---@type PantsOnFire_EffectDetails
    local effectDetails = {player = targetPlayer, finishTick = data.finishTick, fireHeadStart = data.fireHeadStart, fireGap = data.fireGap, flameCount = data.flameCount, startFire = false, stepPos = 0, force = targetPlayer.force --[[@as LuaForce]], ticksInVehicle = 0}
    ---@type UtilityScheduledEvent_CallbackObject
    local walkCheckCallbackObject = {tick = game.tick, instanceId = targetPlayer_index, data = effectDetails}
    PantsOnFire.WalkCheck(walkCheckCallbackObject)
end

---@param eventData UtilityScheduledEvent_CallbackObject
PantsOnFire.WalkCheck = function(eventData)
    ---@typelist PantsOnFire_EffectDetails, LuaPlayer, uint
    local data, player, playerIndex = eventData.data, eventData.data.player, eventData.instanceId --[[@as uint]]
    if player == nil or (not player.valid) then
        PantsOnFire.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- steps is a circular buffer
    local steps = global.PantsOnFire.playerSteps[playerIndex]
    if steps == nil then
        -- player has died? stop the effect
        return
    end

    -- Increment position in step buffer.
    data.stepPos = data.stepPos + 1 --[[@as uint]]

    if data.stepPos >= data.fireHeadStart then
        -- Restart the circular buffer cycle and start the fire creation if not already (first cycle without).
        data.stepPos = 1
        data.startFire = true
    end

    -- Create the fire entity if approperiate.
    local fireEntity
    if data.startFire then
        local step = steps[data.stepPos]
        if step.surface.valid then
            -- Factorio auto deletes the fire-flame entity for us.
            -- 20 flames seems the minimum to set a tree on fire.
            fireEntity = step.surface.create_entity({name = "fire-flame", position = step.position, initial_ground_flame_count = data.flameCount, force = data.force})

            -- If the player is in a vehicle do direct health damage to stop them hiding from the effects in armoured vehicles.
            if player.vehicle then
                local playerCharacter = player.character
                if playerCharacter then
                    data.ticksInVehicle = data.ticksInVehicle + data.fireGap --[[@as uint]]
                    -- Damage is square of how long they are in a vehicle to give a scale between those with no shields/armour and heavily shielded players. Total damage is done as an amount per second regardless of how often the fire gap delay has the ground effect created and thus this function called.
                    local secondsInVehicle = math.ceil(data.ticksInVehicle / 60)
                    local damageForPeriodOfSecond = MathUtils.ClampToFloat((secondsInVehicle ^ 4) / (60 / data.fireGap)) -- We don't care if the value is clamped within the allowed range as its already so large.
                    playerCharacter.damage(damageForPeriodOfSecond, data.force, "fire", fireEntity)
                end
            end
        end
    end

    -- We must store both surface and position as player's surface may change.
    steps[data.stepPos] = {surface = player.surface, position = player.position}

    -- Schedule the next loop if not finished yet.
    if eventData.tick < data.finishTick then
        EventScheduler.ScheduleEventOnce(eventData.tick + data.fireGap --[[@as UtilityScheduledEvent_UintNegative1]], "PantsOnFire.WalkCheck", playerIndex, data)
    else
        PantsOnFire.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
    end
end

--- Called when a player has died, but before thier character is turned in to a corpse.
---@param event on_pre_player_died
PantsOnFire.OnPrePlayerDied = function(event)
    PantsOnFire.StopEffectOnPlayer(event.player_index, nil, EffectEndStatus.died)
end

--- Called when the effect has been stopped.
--- Called when the player is alive or if they have died before their character has been affected.
---@param playerIndex uint
---@param player? LuaPlayer|nil
---@param status PantsOnFire_EffectEndStatus
PantsOnFire.StopEffectOnPlayer = function(playerIndex, player, status)
    local steps = global.PantsOnFire.playerSteps[playerIndex]
    if steps == nil then
        return
    end

    player = player or game.get_player(playerIndex)
    global.PantsOnFire.playerSteps[playerIndex] = nil

    if status == EffectEndStatus.completed then
        game.print({"message.muppet_streamer_pants_on_fire_stop", player.name})
    end
end

return PantsOnFire
