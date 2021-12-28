local PantsOnFire = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Events = require("utility/events")

local EffectEndStatus = {completed = "completed", died = "died", invalid = "invalid"}

PantsOnFire.CreateGlobals = function()
    global.PantsOnFire = global.PantsOnFire or {}
    global.PantsOnFire.nextId = global.PantsOnFire.nextId or 0
    global.PantsOnFire.playerSteps = global.PantsOnFire.playerSteps or {}
end

PantsOnFire.OnLoad = function()
    Commands.Register("muppet_streamer_pants_on_fire", {"api-description.muppet_streamer_pants_on_fire"}, PantsOnFire.PantsOnFireCommand, true)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "PantsOnFire.OnPrePlayerDied", PantsOnFire.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("PantsOnFire.WalkCheck", PantsOnFire.WalkCheck)
    EventScheduler.RegisterScheduledEventType("PantsOnFire.ApplyToPlayer", PantsOnFire.ApplyToPlayer)
end

PantsOnFire.PantsOnFireCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_pants_on_fire command "
    local commandData
    if command.parameter ~= nil then
        commandData = game.json_to_table(command.parameter)
    end
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

    local duration = tonumber(commandData.duration)
    if duration == nil then
        Logging.LogPrint(errorMessageStart .. "duration is Mandatory, must be 0 or greater")
        return
    end
    duration = duration * 60

    local fireGap = 3
    if commandData.fireGap ~= nil then
        fireGap = tonumber(commandData.fireGap)
        if fireGap == nil or fireGap < 0 then
            Logging.LogPrint(errorMessageStart .. "fireGap is Optional, but must be 0 or greater if supplied")
            return
        end
    end

    local fireSleep = 6
    if commandData.fireSleep ~= nil then
        fireSleep = tonumber(commandData.fireSleep)
        if fireSleep == nil or fireSleep <= 0 then
            Logging.LogPrint(errorMessageStart .. "fireSleep is Optional, but must be 1 or greater if supplied")
            return
        end
    end

    global.PantsOnFire.nextId = global.PantsOnFire.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "PantsOnFire.ApplyToPlayer", global.PantsOnFire.nextId, {target = target, duration = duration, fireGap = fireGap, fireSleep = fireSleep})
end

PantsOnFire.ApplyToPlayer = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_pants_on_fire command "
    local data = eventData.data

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({"message.muppet_streamer_pants_on_fire_not_character_controller", data.target})
        return
    end

    if global.PantsOnFire.playerSteps[targetPlayer.index] ~= nil then
        return
    end

    global.PantsOnFire.playerSteps[targetPlayer.index] = {}

    game.print({"message.muppet_streamer_pants_on_fire_start", targetPlayer.name})

    -- stepPos starts at 0 so the first step happens at offset 1
    PantsOnFire.WalkCheck({tick = game.tick, instanceId = targetPlayer.index, data = {player = targetPlayer, duration = data.duration, fireGap = data.fireGap, fireSleep = data.fireSleep, startFire = false, stepPos = 0}})
end

PantsOnFire.WalkCheck = function(eventData)
    local data, player, playerIndex = eventData.data, eventData.data.player, eventData.instanceId
    if player == nil or (not player.valid) then
        PantsOnFire.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- steps is a circular buffer
    local steps = global.PantsOnFire.playerSteps[player.index]
    if steps == nil then
        -- player has died? stop the effect
        return
    end

    data.stepPos = data.stepPos + 1
    if data.stepPos >= data.fireGap then
        data.stepPos = 1
        data.start_fire = true
    end

    if data.start_fire then
        local step = steps[data.stepPos]

        if step.surface.valid then
            -- factorio auto deletes the fire-flame entity for us
            step.surface.create_entity({name = 'fire-flame', position = step.position})
        end
    end

    -- We must store both surface and position as player's surface may change
    steps[data.stepPos] = {surface = player.surface, position = player.position}

    data.duration = data.duration - data.fireSleep
    if data.duration >= 0 then
        EventScheduler.ScheduleEvent(eventData.tick + data.fireSleep, "PantsOnFire.WalkCheck", playerIndex, data)
    else
        PantsOnFire.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
    end
end

PantsOnFire.OnPrePlayerDied = function(event)
    PantsOnFire.StopEffectOnPlayer(event.player_index, nil, EffectEndStatus.died)
end

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
