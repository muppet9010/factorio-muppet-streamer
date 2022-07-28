local PantsOnFire = {} ---@class PantsOnFire
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Events = require("utility.manager-libraries.events")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@class PantsOnFire_ScheduledEventDetails
---@field target string @ Target player's name.
---@field finishTick uint
---@field fireHeadStart uint
---@field fireGap uint @ Must be > 0.
---@field flameCount uint8 @ Must be > 0.

---@class PantsOnFire_EffectDetails
---@field player_index uint
---@field player LuaPlayer
---@field finishTick uint
---@field fireHeadStart uint
---@field fireGap uint @ Must be > 0.
---@field flameCount uint8 @ Must be > 0.
---@field startFire boolean
---@field stepPos uint
---@field force LuaForce
---@field ticksInVehicle uint

---@alias PantsOnFire_PlayersSteps table<uint, PantsOnFire_PlayerSteps> @ A dictionary of player_index to the player's step buffer.
---@alias PantsOnFire_PlayerSteps table<uint, PantsOnFire_PlayerStep> @ Steps is a circular buffer of a player's step that cycles on the fireHeadStart setting of the effect.
---@class PantsOnFire_PlayerStep -- Details of a unique step of the player for that tick.
---@field surface LuaSurface
---@field position MapPosition

---@enum PantsOnFire_EffectEndStatus
local EffectEndStatus = {
    completed = "completed",
    died = "died",
    invalid = "invalid"
}

PantsOnFire.CreateGlobals = function()
    global.PantsOnFire = global.PantsOnFire or {}
    global.PantsOnFire.nextId = global.PantsOnFire.nextId or 0 ---@type uint
    global.PantsOnFire.playersSteps = global.PantsOnFire.playersSteps or {} ---@type PantsOnFire_PlayersSteps
end

PantsOnFire.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_pants_on_fire", { "api-description.muppet_streamer_pants_on_fire" }, PantsOnFire.PantsOnFireCommand, true)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "PantsOnFire.OnPrePlayerDied", PantsOnFire.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("PantsOnFire.WalkCheck", PantsOnFire.WalkCheck)
    EventScheduler.RegisterScheduledEventType("PantsOnFire.ApplyToPlayer", PantsOnFire.ApplyToPlayer)
    MOD.Interfaces.Commands.PantsOnFire = PantsOnFire.PantsOnFireCommand
end

---@param command CustomCommandData
PantsOnFire.PantsOnFireCommand = function(command)
    local commandName = "muppet_streamer_pants_on_fire"

    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "duration", "fireHeadStart", "fireGap", "flameCount" })
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

    local durationSeconds = commandData.duration
    if not CommandsUtils.CheckNumberArgument(durationSeconds, "double", true, commandName, "duration", 1, math.floor(MathUtils.uintMax / 60), command.parameter) then
        return
    end ---@cast durationSeconds double
    local finishTick ---@type uint
    if scheduleTick > 0 then
        finishTick = scheduleTick --[[@as uint @ The scheduleTick can only be -1 or a uint, and the criteria of <0 ensures a uint.]]
    else
        finishTick = command.tick
    end
    finishTick = MathUtils.ClampToUInt(finishTick + math.floor(durationSeconds * 60))

    local fireHeadStart = commandData.fireHeadStart
    if not CommandsUtils.CheckNumberArgument(fireHeadStart, "int", false, commandName, "fireHeadStart", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast fireHeadStart uint|nil
    if fireHeadStart == nil then
        fireHeadStart = 3
    end

    local fireGap = commandData.fireGap
    if not CommandsUtils.CheckNumberArgument(fireGap, "int", false, commandName, "fireGap", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast fireGap uint|nil
    if fireGap == nil then
        fireGap = 6
    end

    local flameCount = commandData.flameCount
    if not CommandsUtils.CheckNumberArgument(flameCount, "int", false, commandName, "flameCount", 1, MathUtils.uint8Max, command.parameter) then
        return
    end ---@cast flameCount uint8|nil
    if flameCount == nil then
        flameCount = 20
    end

    global.PantsOnFire.nextId = global.PantsOnFire.nextId + 1
    ---@type PantsOnFire_ScheduledEventDetails
    local scheduledEventDetails = { target = target, finishTick = finishTick, fireHeadStart = fireHeadStart, fireGap = fireGap, flameCount = flameCount }
    EventScheduler.ScheduleEventOnce(scheduleTick, "PantsOnFire.ApplyToPlayer", global.PantsOnFire.nextId, scheduledEventDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
PantsOnFire.ApplyToPlayer = function(eventData)
    local data = eventData.data ---@type PantsOnFire_ScheduledEventDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        -- Target player has been deleted since the command was run.
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({ "message.muppet_streamer_pants_on_fire_not_character_controller", data.target })
        return
    end
    local targetPlayer_index = targetPlayer.index

    -- Effect is already applied to player so don't start a new one.
    if global.PantsOnFire.playersSteps[targetPlayer_index] ~= nil then
        return
    end

    -- Start the process on the player.
    global.PantsOnFire.playersSteps[targetPlayer_index] = {}
    game.print({ "message.muppet_streamer_pants_on_fire_start", targetPlayer.name })

    -- stepPos starts at 0 so the first step happens at offset 1
    ---@type PantsOnFire_EffectDetails
    local effectDetails = { player_index = targetPlayer_index, player = targetPlayer, finishTick = data.finishTick, fireHeadStart = data.fireHeadStart, fireGap = data.fireGap, flameCount = data.flameCount, startFire = false, stepPos = 0, force = targetPlayer.force --[[@as LuaForce @ read/write work around]] , ticksInVehicle = 0 }
    ---@type UtilityScheduledEvent_CallbackObject
    local walkCheckCallbackObject = { tick = game.tick, instanceId = targetPlayer_index, data = effectDetails }
    PantsOnFire.WalkCheck(walkCheckCallbackObject)
end

---@param eventData UtilityScheduledEvent_CallbackObject
PantsOnFire.WalkCheck = function(eventData)
    local data = eventData.data ---@type PantsOnFire_EffectDetails
    local player, playerIndex = data.player, data.player_index
    if player == nil or (not player.valid) then
        PantsOnFire.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- steps is a circular buffer
    local steps = global.PantsOnFire.playersSteps[playerIndex]
    if steps == nil then
        -- player has died? stop the effect
        return
    end

    -- Increment position in step buffer.
    data.stepPos = data.stepPos + 1

    if data.stepPos >= data.fireHeadStart then
        -- Restart the circular buffer cycle and start the fire creation if not already (first cycle without).
        data.stepPos = 1
        data.startFire = true
    end

    -- Create the fire entity if appropriate.
    local fireEntity
    if data.startFire then
        local step = steps[data.stepPos]
        if step.surface.valid then
            -- Factorio auto deletes the fire-flame entity for us.
            -- 20 flames seems the minimum to set a tree on fire.
            fireEntity = step.surface.create_entity({ name = "fire-flame", position = step.position, initial_ground_flame_count = data.flameCount, force = data.force })

            -- If the player is in a vehicle do direct health damage to stop them hiding from the effects in armored vehicles.
            if player.vehicle then
                local playerCharacter = player.character
                if playerCharacter then
                    data.ticksInVehicle = data.ticksInVehicle + data.fireGap
                    -- Damage is square of how long they are in a vehicle to give a scale between those with no shields/armor and heavily shielded players. Total damage is done as an amount per second regardless of how often the fire gap delay has the ground effect created and thus this function called.
                    local secondsInVehicle = math.ceil(data.ticksInVehicle / 60)
                    local damageForPeriodOfSecond = MathUtils.ClampToFloat((secondsInVehicle ^ 4) / (60 / data.fireGap)) -- We don't care if the value is clamped within the allowed range as its already so large.
                    playerCharacter.damage(damageForPeriodOfSecond, data.force, "fire", fireEntity)
                end
            end
        end
    end

    -- We must store both surface and position as player's surface may change.
    steps[data.stepPos] = { surface = player.surface, position = player.position }

    -- Schedule the next loop if not finished yet.
    if eventData.tick < data.finishTick then
        EventScheduler.ScheduleEventOnce(eventData.tick + data.fireGap, "PantsOnFire.WalkCheck", playerIndex, data)
    else
        PantsOnFire.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
    end
end

--- Called when a player has died, but before their character is turned in to a corpse.
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
    local steps = global.PantsOnFire.playersSteps[playerIndex]
    if steps == nil then
        return
    end

    -- Remove the flag against this player as being currently affected by pants on fire.
    global.PantsOnFire.playersSteps[playerIndex] = nil

    player = player or game.get_player(playerIndex)
    if player == nil then
        -- Player has been deleted while the effect was running.
        return
    end

    if status == EffectEndStatus.completed then
        game.print({ "message.muppet_streamer_pants_on_fire_stop", player.name })
    end
end

return PantsOnFire
