local PantsOnFire = {} ---@class PantsOnFire
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Events = require("utility.manager-libraries.events")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@class PantsOnFire_ScheduledEventDetails
---@field target string # Target player's name.
---@field finishTick uint
---@field fireHeadStart uint
---@field fireGap uint # Must be > 0.
---@field flameCount uint8 # Must be > 0.
---@field firePrototype LuaEntityPrototype
---@field suppressMessages boolean

---@class PantsOnFire_EffectDetails
---@field player_index uint
---@field player LuaPlayer
---@field nextFireTick uint
---@field finishTick uint
---@field fireHeadStart uint
---@field fireGap uint # Must be > 0.
---@field flameCount uint8 # Must be > 0.
---@field startFire boolean
---@field stepPos uint
---@field ticksInVehicle uint
---@field firePrototype LuaEntityPrototype
---@field suppressMessages boolean

---@class PantsOnFire_AffectedPlayerDetails
---@field steps table<uint, PantsOnFire_PlayerStep> # Steps is a buffer of a player's step (past position) every fireGap tick interval.
---@field suppressMessages boolean

---@class PantsOnFire_PlayerStep -- Details of a unique step of the player for that tick.
---@field surface LuaSurface
---@field position MapPosition

---@enum PantsOnFire_EffectEndStatus
local EffectEndStatus = {
    completed = "completed",
    died = "died",
    invalid = "invalid"
}

local commandName = "muppet_streamer_pants_on_fire"

PantsOnFire.CreateGlobals = function()
    global.PantsOnFire = global.PantsOnFire or {}
    global.PantsOnFire.nextId = global.PantsOnFire.nextId or 0 ---@type uint
    global.PantsOnFire.affectedPlayers = global.PantsOnFire.affectedPlayers or {} ---@type table<uint, PantsOnFire_AffectedPlayerDetails> # Key'd by player_index.
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

    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "duration", "fireHeadStart", "fireGap", "flameCount", "fireType", "suppressMessages" })
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
        finishTick = scheduleTick --[[@as uint # The scheduleTick can only be -1 or a uint, and the criteria of <0 ensures a uint.]]
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
    -- Flame count above 250 gives odd results.
    if not CommandsUtils.CheckNumberArgument(flameCount, "int", false, commandName, "flameCount", 1, 250, command.parameter) then
        return
    end ---@cast flameCount uint8|nil
    if flameCount == nil then
        flameCount = 30
    end

    local firePrototype, valid = Common.GetEntityPrototypeFromCommandArgument(commandData.fireType, "fire", false, commandName, "fireType", command.parameter)
    if not valid then return end
    if firePrototype == nil then
        -- No custom weapon set, so use the base game weapon and confirm its valid.
        firePrototype = Common.GetBaseGameEntityByName("fire-flame", "fire", commandName, command.parameter)
        if firePrototype == nil then
            return
        end
    end

    local suppressMessages = commandData.suppressMessages
    if not CommandsUtils.CheckBooleanArgument(suppressMessages, false, commandName, "suppressMessages", command.parameter) then
        return
    end ---@cast suppressMessages boolean|nil
    if suppressMessages == nil then
        suppressMessages = false
    end

    global.PantsOnFire.nextId = global.PantsOnFire.nextId + 1
    ---@type PantsOnFire_ScheduledEventDetails
    local scheduledEventDetails = { target = target, finishTick = finishTick, fireHeadStart = fireHeadStart, fireGap = fireGap, flameCount = flameCount, firePrototype = firePrototype, suppressMessages = suppressMessages }
    EventScheduler.ScheduleEventOnce(scheduleTick, "PantsOnFire.ApplyToPlayer", global.PantsOnFire.nextId, scheduledEventDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
PantsOnFire.ApplyToPlayer = function(eventData)
    local data = eventData.data ---@type PantsOnFire_ScheduledEventDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        if not data.suppressMessages then game.print({ "message.muppet_streamer_pants_on_fire_not_character_controller", data.target }) end
        return
    end
    local targetPlayer_index = targetPlayer.index

    -- Check the firePrototype is still valid (unchanged).
    if not data.firePrototype.valid then
        CommandsUtils.LogPrintWarning(commandName, nil, "The in-game fire prototype has been changed/removed since the command was run.", nil)
        return
    end

    -- Effect is already applied to player so don't start a new one.
    if global.PantsOnFire.affectedPlayers[targetPlayer_index] ~= nil then
        if not data.suppressMessages then game.print({ "message.muppet_streamer_duplicate_command_ignored", "Pants On Fire", data.target }) end
        return
    end

    -- Start the process on the player.
    global.PantsOnFire.affectedPlayers[targetPlayer_index] = { suppressMessages = data.suppressMessages, steps = {} }
    if not data.suppressMessages then game.print({ "message.muppet_streamer_pants_on_fire_start", targetPlayer.name }) end

    -- stepPos starts at 0 so the first step happens at offset 1
    ---@type PantsOnFire_EffectDetails
    local effectDetails = { player_index = targetPlayer_index, player = targetPlayer, nextFireTick = eventData.tick, finishTick = data.finishTick, fireHeadStart = data.fireHeadStart, fireGap = data.fireGap, flameCount = data.flameCount, startFire = false, stepPos = 0, ticksInVehicle = 0, firePrototype = data.firePrototype, suppressMessages = data.suppressMessages }
    ---@type UtilityScheduledEvent_CallbackObject
    local walkCheckCallbackObject = { tick = eventData.tick, instanceId = targetPlayer_index, data = effectDetails }
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

    -- Steps is a buffer of the players past position every fireGap tick interval.
    local affectedPlayerDetails = global.PantsOnFire.affectedPlayers[playerIndex]
    if affectedPlayerDetails == nil then
        -- Don't process this tick as the effect has been stopped by an external event.
        return
    end

    -- Every tick eject the player should they be in a vehicle. While we don't create fire entities every tick, we don't want to let players escape the fire by getting in a vehicle for short periods.
    player.driving = false

    -- Only continue to create a fire entity if its correct for this tick, otherwise just schedule the effect to continue next tick and end this function.
    if data.nextFireTick ~= eventData.tick then
        EventScheduler.ScheduleEventOnce(eventData.tick + 1, "PantsOnFire.WalkCheck", playerIndex, data)
        return
    end

    -- Check the firePrototype is still valid (unchanged).
    if not data.firePrototype.valid then
        CommandsUtils.LogPrintWarning(commandName, nil, "The in-game fire prototype has been changed/removed since the command was run.", nil)
        return
    end

    -- Increment position in step buffer.
    data.stepPos = data.stepPos + 1

    if data.startFire == false and data.stepPos > data.fireHeadStart then
        -- Flag to start creating the fire entities on each cycle from now on.
        data.startFire = true
    end

    -- Create the fire entity if appropriate.
    if data.startFire then
        -- Get where the player was X steps back, or where they are right now.
        local step = affectedPlayerDetails.steps[data.stepPos - data.fireHeadStart] or { surface = player.surface, position = player.position }
        if step.surface.valid then
            -- Factorio auto deletes the fire-flame entity for us.
            -- 20 flames seems the minimum to set a tree on fire.
            step.surface.create_entity({ name = data.firePrototype.name, position = step.position, initial_ground_flame_count = data.flameCount, force = global.Forces.muppet_streamer_enemy, create_build_effect_smoke = false, raise_built = true })
        end
    end

    -- We must store both surface and position as player's surface may change.
    affectedPlayerDetails.steps[data.stepPos] = { surface = player.surface, position = player.position }

    -- Schedule the next loop if not finished yet.
    if eventData.tick < data.finishTick then
        data.nextFireTick = eventData.tick + data.fireGap
        EventScheduler.ScheduleEventOnce(data.nextFireTick, "PantsOnFire.WalkCheck", playerIndex, data)
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
    local affectedPlayerDetails = global.PantsOnFire.affectedPlayers[playerIndex]
    if affectedPlayerDetails == nil then
        return
    end

    -- Remove the flag against this player as being currently affected by pants on fire.
    global.PantsOnFire.affectedPlayers[playerIndex] = nil

    player = player or game.get_player(playerIndex)
    if player == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted while the effect was running.", nil)
        return
    end

    if status == EffectEndStatus.completed then
        if not affectedPlayerDetails.suppressMessages then game.print({ "message.muppet_streamer_pants_on_fire_stop", player.name }) end
    end
end

return PantsOnFire
