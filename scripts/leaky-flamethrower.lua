local LeakyFlamethrower = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Events = require("utility/events")

LeakyFlamethrower.CreateGlobals = function()
    global.leakyFlamethrower = global.leakyFlamethrower or {}
    global.leakyFlamethrower.affectedPlayers = global.leakyFlamethrower.affectedPlayers or {}
    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId or 0
end

LeakyFlamethrower.OnLoad = function()
    Commands.Register("muppet_streamer_leaky_flamethrower", {"api-description.muppet_streamer_leaky_flamethrower"}, LeakyFlamethrower.LeakyFlamethrowerCommand)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ShootFlamethrower", LeakyFlamethrower.ShootFlamethrower)
    Events.RegisterEvent(defines.events.on_player_died)
    Events.RegisterHandler(defines.events.on_player_died, "LeakyFlamethrower.OnPlayerDied", LeakyFlamethrower.OnPlayerDied)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ApplyToPlayer", LeakyFlamethrower.ApplyToPlayer)
end

LeakyFlamethrower.OnStartup = function()
    if not game.permissions.get_group("LeakyFlamethrower") then
        local group = game.permissions.create_group("LeakyFlamethrower")
        group.set_allows_action(defines.input_action.select_next_valid_gun, false)
        group.set_allows_action(defines.input_action.toggle_driving, false)
        group.set_allows_action(defines.input_action.change_shooting_state, false)
    end
end

LeakyFlamethrower.LeakyFlamethrowerCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_leaky_flamethrower command "
    local commandData = game.json_to_table(command.parameter)
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
    end
    local player = game.get_player(target)
    if player == nil then
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
    EventScheduler.ScheduleEvent(command.tick + delay, "LeakyFlamethrower.ApplyToPlayer", global.leakyFlamethrower.nextId, {player = player, ammoCount = ammoCount})
end

LeakyFlamethrower.ApplyToPlayer = function(eventData)
    local player, ammoCount = eventData.data.player, eventData.data.ammoCount
    if global.leakyFlamethrower.affectedPlayers[player.index] ~= nil then
        return
    end
    if player == nil or (not player.valid) or player.character == nil or (not player.character.valid) then
        return
    end

    player.driving = false

    local flamethrowerFoundIndex, flamethrowerGiven = 0, false
    local gunInventory = player.get_inventory(defines.inventory.character_guns)
    for i = 1, #gunInventory do
        local gunItemStack = gunInventory[i]
        if gunItemStack ~= nil and gunItemStack.valid_for_read then
            if gunItemStack.name == "flamethrower" then
                flamethrowerFoundIndex = i
                break
            end
        end
    end

    if flamethrowerFoundIndex == 0 then
        flamethrowerGiven = true
        if not gunInventory.can_insert({name = "flamethrower", count = 1}) then
            flamethrowerFoundIndex = math.random(1, 3)
            local gunItemStack = gunInventory[flamethrowerFoundIndex]
            if gunItemStack ~= nil and gunItemStack.valid_for_read then
                local gunInsertedCount = player.insert({name = gunItemStack.name, count = gunItemStack.count})
                if gunInsertedCount < gunItemStack.count then
                    player.surface.spill_item_stack({name = gunItemStack.name, count = gunItemStack.count - gunInsertedCount})
                end
            end
            gunItemStack.clear()

            local ammoInventory = player.get_inventory(defines.inventory.character_ammo)
            local ammoItemStack = ammoInventory[flamethrowerFoundIndex]
            if ammoItemStack ~= nil and ammoItemStack.valid_for_read then
                local ammoInsertedCount = player.insert({name = ammoItemStack.name, count = ammoItemStack.count})
                if ammoInsertedCount < ammoItemStack.count then
                    player.surface.spill_item_stack({name = ammoItemStack.name, count = ammoItemStack.count - ammoInsertedCount})
                end
            end
            ammoItemStack.clear()
        end

        gunInventory.insert({name = "flamethrower", count = 1})
        for i = 1, #gunInventory do
            local gunItemStack = gunInventory[i]
            if gunItemStack ~= nil and gunItemStack.valid_for_read then
                if gunItemStack.name == "flamethrower" then
                    flamethrowerFoundIndex = i
                    break
                end
            end
        end
    end

    player.get_inventory(defines.inventory.character_ammo).insert({name = "flamethrower-ammo", count = ammoCount})
    player.character.selected_gun_index = flamethrowerFoundIndex
    local oldPermissionGroup = player.permission_group
    player.permission_group = game.permissions.get_group("LeakyFlamethrower")
    global.leakyFlamethrower.affectedPlayers[player.index] = {flamethrowerGiven = flamethrowerGiven, oldPermissionGroup = oldPermissionGroup}

    local startingAngle = math.random(0, 360)
    local startingDistance = math.random(2, 10)
    LeakyFlamethrower.ShootFlamethrower({tick = game.tick, instanceId = player.index, data = {player = player, angle = startingAngle, distance = startingDistance, currentBurstTicks = 0, burstsDone = 0, maxBursts = ammoCount}})
end

LeakyFlamethrower.ShootFlamethrower = function(eventData)
    local data, player, playerIndex = eventData.data, eventData.data.player, eventData.instanceId
    if player == nil or (not player.valid) or player.character == nil or (not player.character.valid) then
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
    end
    player.permission_group = affectedPlayer.oldPermissionGroup
    global.leakyFlamethrower.affectedPlayers[playerIndex] = nil
end

return LeakyFlamethrower
