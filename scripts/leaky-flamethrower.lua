local LeakyFlamethrower = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Events = require("utility/events")
local Interfaces = require("utility/interfaces")

LeakyFlamethrower.CreateGlobals = function()
    global.leakyFlamethrower = global.leakyFlamethrower or {}
    global.leakyFlamethrower.affectedPlayers = global.leakyFlamethrower.affectedPlayers or {}
    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId or 0
end

LeakyFlamethrower.OnLoad = function()
    Commands.Register("muppet_streamer_leaky_flamethrower", {"api-description.muppet_streamer_leaky_flamethrower"}, LeakyFlamethrower.LeakyFlamethrowerCommand, true)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ShootFlamethrower", LeakyFlamethrower.ShootFlamethrower)
    Events.RegisterEvent(defines.events.on_player_died)
    Events.RegisterHandler(defines.events.on_player_died, "LeakyFlamethrower.OnPlayerDied", LeakyFlamethrower.OnPlayerDied)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ApplyToPlayer", LeakyFlamethrower.ApplyToPlayer)
end

LeakyFlamethrower.OnStartup = function()
    local group = game.permissions.get_group("LeakyFlamethrower") or game.permissions.create_group("LeakyFlamethrower")
    group.set_allows_action(defines.input_action.select_next_valid_gun, false)
    group.set_allows_action(defines.input_action.toggle_driving, false)
    group.set_allows_action(defines.input_action.change_shooting_state, false)
end

LeakyFlamethrower.LeakyFlamethrowerCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_leaky_flamethrower command "
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

    local ammoCount = tonumber(commandData.ammoCount)
    if ammoCount == nil then
        Logging.LogPrint(errorMessageStart .. "ammoCount is mandatory as a number")
        return
    elseif ammoCount <= 0 then
        return
    end

    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "LeakyFlamethrower.ApplyToPlayer", global.leakyFlamethrower.nextId, {target = target, ammoCount = ammoCount})
end

LeakyFlamethrower.ApplyToPlayer = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_leaky_flamethrower command "
    local data, ammoCount = eventData.data, eventData.data.ammoCount

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    if targetPlayer.character == nil or not targetPlayer.character.valid then
        return
    end

    if global.leakyFlamethrower.affectedPlayers[targetPlayer.index] ~= nil then
        return
    end

    targetPlayer.driving = false
    local flamethrowerGiven = Interfaces.Call("GiveItems.EnsureHasWeapon", targetPlayer, "flamethrower", true, true)

    targetPlayer.get_inventory(defines.inventory.character_ammo).insert({name = "flamethrower-ammo", count = ammoCount})
    global.origionalPlayersPermissionGroup[targetPlayer.index] = global.origionalPlayersPermissionGroup[targetPlayer.index] or targetPlayer.permission_group
    targetPlayer.permission_group = game.permissions.get_group("LeakyFlamethrower")
    global.leakyFlamethrower.affectedPlayers[targetPlayer.index] = {flamethrowerGiven = flamethrowerGiven}

    local startingAngle = math.random(0, 360)
    local startingDistance = math.random(2, 10)
    game.print({"message.muppet_streamer_leaky_flamethrower_start", targetPlayer.name})
    LeakyFlamethrower.ShootFlamethrower({tick = game.tick, instanceId = targetPlayer.index, data = {player = targetPlayer, angle = startingAngle, distance = startingDistance, currentBurstTicks = 0, burstsDone = 0, maxBursts = ammoCount}})
end

LeakyFlamethrower.ShootFlamethrower = function(eventData)
    local data, player, playerIndex = eventData.data, eventData.data.player, eventData.instanceId
    if player == nil or (not player.valid) or player.character == nil or (not player.character.valid) or player.vehicle ~= nil then
        LeakyFlamethrower.StopEffectOnPlayer(playerIndex)
        return
    end

    local targetPos = Utils.GetPositionForAngledDistance(player.position, data.distance, data.angle)
    player.shooting_state = {state = defines.shooting.shooting_selected, position = targetPos}

    local delay = 0
    data.currentBurstTicks = data.currentBurstTicks + 1
    if data.currentBurstTicks > 100 then
        data.currentBurstTicks = 0
        data.burstsDone = data.burstsDone + 1
        if data.burstsDone == data.maxBursts then
            LeakyFlamethrower.StopEffectOnPlayer(playerIndex)
            return
        end
        data.angle = math.random(0, 360)
        data.distance = math.random(2, 10)
        player.shooting_state = {state = defines.shooting.not_shooting}
        delay = 180
    else
        data.distance = math.min(math.max(data.distance + (math.random(-1, 1)), 2), 10)
        data.angle = data.angle + (math.random(-3, 3))
    end

    EventScheduler.ScheduleEvent(eventData.tick + delay, "LeakyFlamethrower.ShootFlamethrower", playerIndex, data)
end

LeakyFlamethrower.OnPlayerDied = function(event)
    local playerIndex = event.player_index
    LeakyFlamethrower.StopEffectOnPlayer(playerIndex)
end

LeakyFlamethrower.StopEffectOnPlayer = function(playerIndex)
    local affectedPlayer = global.leakyFlamethrower.affectedPlayers[playerIndex]
    if affectedPlayer == nil then
        return
    end

    local player = game.get_player(playerIndex)
    if player ~= nil and player.valid and player.character ~= nil and player.character.valid and affectedPlayer.flamethrowerGiven then
        local gunInventory = player.get_inventory(defines.inventory.character_guns)
        gunInventory.remove({name = "flamethrower", count = 1})
    --TODO: Need to remove any ammo given if effect is interupted mid run.
    end
    if player.permission_group.name == "LeakyFlamethrower" then
        -- If the permission group has been changed by something else don't set it back to the last non modded one.
        player.permission_group = global.origionalPlayersPermissionGroup[playerIndex]
        global.origionalPlayersPermissionGroup[playerIndex] = nil
    end
    global.leakyFlamethrower.affectedPlayers[playerIndex] = nil
    game.print({"message.muppet_streamer_leaky_flamethrower_stop", player.name})
end

return LeakyFlamethrower
