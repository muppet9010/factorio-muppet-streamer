local AggressiveDriver = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Events = require("utility/events")

local ControlTypes = {full = "full", random = "random"}
local EffectEndStatus = {completed = "completed", died = "died", invalid = "invalid"}

AggressiveDriver.CreateGlobals = function()
    global.aggressiveDriver = global.aggressiveDriver or {}
    global.aggressiveDriver.nextId = global.aggressiveDriver.nextId or 0
    global.aggressiveDriver.affectedPlayers = global.aggressiveDriver.affectedPlayers or {}
end

AggressiveDriver.OnLoad = function()
    Commands.Register("muppet_streamer_aggressive_driver", {"api-description.muppet_streamer_aggressive_driver"}, AggressiveDriver.AggressiveDriverCommand, true)
    Events.RegisterEvent(defines.events.on_pre_player_died)
    Events.RegisterHandler(defines.events.on_pre_player_died, "AggressiveDriver.OnPrePlayerDied", AggressiveDriver.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("AggressiveDriver.Drive", AggressiveDriver.Drive)
    EventScheduler.RegisterScheduledEventType("AggressiveDriver.ApplyToPlayer", AggressiveDriver.ApplyToPlayer)
end

AggressiveDriver.OnStartup = function()
    local group = game.permissions.get_group("AggressiveDriver") or game.permissions.create_group("AggressiveDriver")
    group.set_allows_action(defines.input_action.toggle_driving, false)
end

AggressiveDriver.AggressiveDriverCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_aggressive_driver command "
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

    local control = commandData.control
    if control ~= nil then
        control = ControlTypes[control]
        if control == nil then
            Logging.LogPrint(errorMessageStart .. "control is Optional, but must be a valid type if supplied")
            return
        end
    else
        control = ControlTypes.full
    end

    local teleportDistanceString, teleportDistance = commandData.teleportDistance
    if teleportDistanceString ~= nil then
        teleportDistance = tonumber(teleportDistanceString)
        if teleportDistance == nil or teleportDistance < 0 then
            Logging.LogPrint(errorMessageStart .. "teleportDistance is Optional, but must a number of 0 or greater")
            return
        end
    else
        teleportDistance = 0
    end

    global.aggressiveDriver.nextId = global.aggressiveDriver.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "AggressiveDriver.ApplyToPlayer", global.aggressiveDriver.nextId, {target = target, duration = duration, control = control, teleportDistance = teleportDistance})
end

AggressiveDriver.ApplyToPlayer = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_aggressive_driver command "
    local data = eventData.data

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end

    local inVehicle = targetPlayer.vehicle ~= nil and targetPlayer.vehicle.valid and targetPlayer.vehicle.type ~= "spider-vehicle"
    if not inVehicle and data.teleportDistance > 0 then
        local vehicles = targetPlayer.surface.find_entities_filtered {position = targetPlayer.position, radius = data.teleportDistance, force = targetPlayer.force, type = {"car", "tank", "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon"}}
        local distanceSortedVehicles = {}
        for _, vehicle in pairs(vehicles) do
            local vehicleValid = true
            if vehicle.get_driver() ~= nil then
                vehicleValid = false
            end
            if vehicle.get_fuel_inventory().is_empty() then
                vehicleValid = false
            end
            if vehicleValid then
                local distance = Utils.GetDistance(targetPlayer.position, vehicle.position)
                table.insert(distanceSortedVehicles, {distance = distance, vehicle = vehicle})
            end
        end
        if #distanceSortedVehicles > 0 then
            table.sort(
                distanceSortedVehicles,
                function(a, b)
                    return a.distance < b.distance
                end
            )
            distanceSortedVehicles[1].vehicle.set_driver(targetPlayer)
            inVehicle = true
        end
    end
    if not inVehicle then
        return
    end

    if global.aggressiveDriver.affectedPlayers[targetPlayer.index] ~= nil then
        return
    end

    global.origionalPlayersPermissionGroup[targetPlayer.index] = global.origionalPlayersPermissionGroup[targetPlayer.index] or targetPlayer.permission_group
    targetPlayer.permission_group = game.permissions.get_group("AggressiveDriver")
    global.aggressiveDriver.affectedPlayers[targetPlayer.index] = true

    game.print({"message.muppet_streamer_aggressive_driver_start", targetPlayer.name})
    AggressiveDriver.Drive({tick = game.tick, instanceId = targetPlayer.index, data = {player = targetPlayer, duration = data.duration, control = data.control, accelerationTime = 0, accelerationState = defines.riding.acceleration.accelerating}})
end

AggressiveDriver.Drive = function(eventData)
    local data, player, playerIndex = eventData.data, eventData.data.player, eventData.instanceId
    if player == nil or (not player.valid) or player.vehicle == nil or (not player.vehicle.valid) then
        AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    if data.accelerationTime > 3 and player.vehicle.speed == 0 then
        data.accelerationTime = 0
        if data.accelerationState == defines.riding.acceleration.accelerating then
            data.accelerationState = defines.riding.acceleration.reversing
        else
            data.accelerationState = defines.riding.acceleration.accelerating
        end
    end

    if data.control == ControlTypes.full then
        player.riding_state = {
            acceleration = data.accelerationState,
            direction = player.riding_state.direction
        }
    elseif data.control == ControlTypes.random then
        if data.directionDuration == nil or data.directionDuration == 0 then
            data.directionDuration = math.random(10, 30)
            data.direction = math.random(0, 2)
        else
            data.directionDuration = data.directionDuration - 1
        end
        player.riding_state = {
            acceleration = data.accelerationState,
            direction = data.direction
        }
    end

    data.accelerationTime = data.accelerationTime + 1
    data.duration = data.duration - 1
    if data.duration >= 0 then
        EventScheduler.ScheduleEvent(eventData.tick + 1, "AggressiveDriver.Drive", playerIndex, data)
    else
        AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
    end
end

AggressiveDriver.OnPrePlayerDied = function(event)
    AggressiveDriver.StopEffectOnPlayer(event.player_index, nil, EffectEndStatus.died)
end

AggressiveDriver.StopEffectOnPlayer = function(playerIndex, player, status)
    local affectedPlayer = global.aggressiveDriver.affectedPlayers[playerIndex]
    if affectedPlayer == nil then
        return
    end

    player = player or game.get_player(playerIndex)
    if player.permission_group.name == "AggressiveDriver" then
        -- If the permission group has been changed by something else don't set it back to the last non modded one.
        player.permission_group = global.origionalPlayersPermissionGroup[playerIndex]
        global.origionalPlayersPermissionGroup[playerIndex] = nil
    end
    global.aggressiveDriver.affectedPlayers[playerIndex] = nil
    player.riding_state = {
        acceleration = defines.riding.acceleration.braking,
        direction = defines.riding.direction.straight
    }
    if status == EffectEndStatus.completed then
        game.print({"message.muppet_streamer_aggressive_driver_stop", player.name})
    end
end

return AggressiveDriver
