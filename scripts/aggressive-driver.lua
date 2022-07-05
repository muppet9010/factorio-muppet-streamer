local AggressiveDriver = {}
local Commands = require("utility.commands")
local Logging = require("utility.logging")
local EventScheduler = require("utility.event-scheduler")
local PositionUtils = require("utility.position-utils")
local Events = require("utility.events")

---@class AggressiveDriver_ControlTypes
local ControlTypes = {full = "full", random = "random"}

---@class AggressiveDriver_EffectEndStatus
local EffectEndStatus = {completed = "completed", died = "died", invalid = "invalid"}

---@class AggressiveDriver_DelayedCommandDetails
---@field target string @ Player's name.
---@field duration Tick
---@field control AggressiveDriver_ControlTypes
---@field teleportDistance uint

---@class AggressiveDriver_DriveEachTickDetails
---@field player LuaPlayer
---@field duration Tick
---@field control AggressiveDriver_ControlTypes
---@field accelerationTime Tick @ How many ticks the vehicle has been trying to move in its current direction (forwards or backwards).
---@field accelerationState defines.riding.acceleration @ Should only ever be either accelerating or reversing.
---@field directionDuration Tick @ How many more ticks the vehicle will carry on going in its steering direction. Only used/updated if the steering is "random".
---@field direction defines.riding.direction @ Can be any of the 3 directions (left, straight, right).

AggressiveDriver.CreateGlobals = function()
    global.aggressiveDriver = global.aggressiveDriver or {}
    global.aggressiveDriver.nextId = global.aggressiveDriver.nextId or 0
    global.aggressiveDriver.affectedPlayers = global.aggressiveDriver.affectedPlayers or {} ---@type table<PlayerIndex, True>
end

AggressiveDriver.OnLoad = function()
    Commands.Register("muppet_streamer_aggressive_driver", {"api-description.muppet_streamer_aggressive_driver"}, AggressiveDriver.AggressiveDriverCommand, true)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "AggressiveDriver.OnPrePlayerDied", AggressiveDriver.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("AggressiveDriver.Drive", AggressiveDriver.Drive)
    EventScheduler.RegisterScheduledEventType("AggressiveDriver.ApplyToPlayer", AggressiveDriver.ApplyToPlayer)
end

AggressiveDriver.OnStartup = function()
    local group = game.permissions.get_group("AggressiveDriver") or game.permissions.create_group("AggressiveDriver")
    group.set_allows_action(defines.input_action.toggle_driving, false)
end

---@param command CustomCommandData
AggressiveDriver.AggressiveDriverCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_aggressive_driver command "
    local commandData
    if command.parameter ~= nil then
        commandData = game.json_to_table(command.parameter)
    end
    if commandData == nil or type(commandData) ~= "table" then
        Logging.LogPrint(errorMessageStart .. "requires details in JSON format.")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local delay = 0
    if commandData.delay ~= nil then
        delay = tonumber(commandData.delay)
        if delay == nil then
            Logging.LogPrint(errorMessageStart .. "delay is Optional, but must be a non-negative number if supplied")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
        delay = math.max(delay * 60, 0)
    end

    local target = commandData.target
    if target == nil then
        Logging.LogPrint(errorMessageStart .. "target is mandatory")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    elseif game.get_player(target) == nil then
        Logging.LogPrint(errorMessageStart .. "target is invalid player name")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local duration = tonumber(commandData.duration)
    if duration == nil then
        Logging.LogPrint(errorMessageStart .. "duration is Mandatory, must be 0 or greater")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end
    duration = math.floor(duration * 60)

    local control = commandData.control
    if control ~= nil then
        control = ControlTypes[control]
        if control == nil then
            Logging.LogPrint(errorMessageStart .. "control is Optional, but must be a valid type if supplied")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    else
        control = ControlTypes.full
    end

    local teleportDistanceString = commandData.teleportDistance
    local teleportDistance
    if teleportDistanceString ~= nil then
        teleportDistance = tonumber(teleportDistanceString)
        if teleportDistance == nil or teleportDistance < 0 then
            Logging.LogPrint(errorMessageStart .. "teleportDistance is Optional, but must a number of 0 or greater")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
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
    local data = eventData.data ---@type AggressiveDriver_DelayedCommandDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({"message.muppet_streamer_aggressive_driver_not_character_controller", data.target})
        return
    end

    local inVehicle = targetPlayer.vehicle ~= nil and targetPlayer.vehicle.valid
    if not inVehicle and data.teleportDistance > 0 then
        local vehicles = targetPlayer.surface.find_entities_filtered {position = targetPlayer.position, radius = data.teleportDistance, force = targetPlayer.force, type = {"car", "locomotive", "spider-vehicle"}}
        local distanceSortedVehicles = {}
        for _, vehicle in pairs(vehicles) do
            local vehicleValid = true
            if vehicle.get_driver() ~= nil then
                vehicleValid = false
            end
            local vehicleFuelInventory = vehicle.get_fuel_inventory()
            if vehicleFuelInventory ~= nil and vehicle.get_fuel_inventory().is_empty() then
                -- There is a fuel inventory for this vehcile and it is empty.
                vehicleValid = false
            end
            if vehicleValid then
                local distance = PositionUtils.GetDistance(targetPlayer.position, vehicle.position)
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
            inVehicle = targetPlayer.vehicle
        end
    end
    if not inVehicle then
        return
    end

    if global.aggressiveDriver.affectedPlayers[targetPlayer.index] ~= nil then
        return
    end

    -- Store the players current permission group. Left as the previously stored group if an effect was already being applied to the player, or captured if no present effect affects them.
    global.origionalPlayersPermissionGroup[targetPlayer.index] = global.origionalPlayersPermissionGroup[targetPlayer.index] or targetPlayer.permission_group

    targetPlayer.permission_group = game.permissions.get_group("AggressiveDriver")
    global.aggressiveDriver.affectedPlayers[targetPlayer.index] = true

    game.print({"message.muppet_streamer_aggressive_driver_start", targetPlayer.name})
    -- A train will continue moving in its current direction, effectively ignoring the accelerationState value at the start. But a car and tank will always start going forwards regardless of their previous movement, as they are much faster forwards than backwards.
    AggressiveDriver.Drive({tick = game.tick, instanceId = targetPlayer.index, data = {player = targetPlayer, duration = data.duration, control = data.control, accelerationTime = 0, accelerationState = defines.riding.acceleration.accelerating, directionDuration = 0}})
end

AggressiveDriver.Drive = function(eventData)
    ---@typelist AggressiveDriver_DriveEachTickDetails, LuaPlayer, PlayerIndex
    local data, player, playerIndex = eventData.data, eventData.data.player, eventData.instanceId
    local vehicle = player.vehicle
    if player == nil or (not player.valid) or vehicle == nil or (not vehicle.valid) then
        AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end
    local vehicle_type = vehicle.type

    if vehicle_type == "spider-vehicle" then
        -- Spider vehicles are special.

        -- Overwrite the players input control for this tick based on the settings.
        if data.control == ControlTypes.full then
            -- Player can still steer, so just force to move "forwards".

            -- Every 10 ticks we have to stop controlling the spiders movement so that the players direction input is registered and we can pick it up.
            if data.accelerationTime > 10 then
                -- Just reset the counter this tick, lets user input be captured.
                data.accelerationTime = 0
            else
                -- Walk in the current direction.
                player.walking_state = {walking = true, direction = player.walking_state.direction}
            end
        else
            -- Player has no control so we will set both acceleration and direction.

            -- Either find a new direction if the directionDuration has run out, or just count it down 1.
            if data.directionDuration == 0 then
                data.directionDuration = math.random(30, 180)
                data.direction = math.random(0, 7)
            else
                data.directionDuration = data.directionDuration - 1
            end

            player.walking_state = {walking = true, direction = data.direction}
        end
    else
        -- Cars and trains.

        -- Train carriages need special handling.
        if vehicle_type == "locomotive" or vehicle_type == "cargo-wagon" or vehicle_type == "fluid-wagon" or vehicle_type == "artillery-wagon" then
            local train = vehicle.train

            -- If the train isn't in manual mode then set it. We do this every tick if needed so that other palyers setting it to automatic gets overridden.
            if train.manual_mode ~= true then
                -- Don't set every tick blindly as it resets the players key directions on that tick to be forced to straight forwards.
                train.manual_mode = true
            end

            -- If the train is already moving work out if accelerating or reversing the players carriage keeps the train moving in its current direction.
            -- If the train isn't moving then later in the function the standand flip movement detection will start moving the train in the other direction.
            -- For a train just starting its scripted control this will also avoid flipping the trains direction, so it continues in its current travel direction. As it would loose the feel of an out of control train and would take a while to stop and build up reversing speed. If the train starts with no speed then the standard direction start logic will make the train move "forwards" in direct relation to the player's carriage facing, not the train's, as theres no known "good" start direction here.
            local vehicle_speed = vehicle.speed
            if vehicle_speed ~= 0 then
                local train_speed = train.speed
                if (vehicle_speed > 0 and vehicle_speed == train_speed) or (vehicle_speed < 0 and vehicle_speed ~= train_speed) then
                    data.accelerationState = defines.riding.acceleration.accelerating
                else
                    data.accelerationState = defines.riding.acceleration.reversing
                end
            end
        end

        -- Check if the vehicle needs to have its movement flipped (accelerating vs reversing), if it has been trying to move forwards for 3 ticks and still doesn't have any speed.
        if data.accelerationTime > 3 and vehicle.speed == 0 then
            data.accelerationTime = 0
            if data.accelerationState == defines.riding.acceleration.accelerating then
                data.accelerationState = defines.riding.acceleration.reversing
            else
                data.accelerationState = defines.riding.acceleration.accelerating
            end
        end

        -- Overwrite the players input control for this tick based on the settings.
        if data.control == ControlTypes.full then
            -- Player can still steer, so just overwrite the acceleration.
            player.riding_state = {
                acceleration = data.accelerationState,
                direction = player.riding_state.direction
            }
        elseif data.control == ControlTypes.random then
            -- Player has no control so we will set both acceleration and direction.

            -- Either find a new direction if the directionDuration has run out, or just count it down 1.
            if data.directionDuration == 0 then
                if vehicle_type == "locomotive" or vehicle_type == "cargo-wagon" or vehicle_type == "fluid-wagon" or vehicle_type == "artillery-wagon" then
                    -- Train carriages should change every tick as very fast trains may cross rail points very fast.
                    data.directionDuration = 1
                else
                    -- Cars/tanks should keep turning for a while so the steering is more definite.
                    data.directionDuration = math.random(10, 30)
                end
                data.direction = math.random(0, 2)
            else
                data.directionDuration = data.directionDuration - 1
            end

            player.riding_state = {
                acceleration = data.accelerationState,
                direction = data.direction
            }
        end
    end

    -- Iterate the various counters for this effect.
    data.accelerationTime = data.accelerationTime + 1
    data.duration = data.duration - 1

    -- Schedule next ticks action unless the effect has timed out.
    if data.duration >= 0 then
        EventScheduler.ScheduleEvent(eventData.tick + 1, "AggressiveDriver.Drive", playerIndex, data)
    else
        AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
    end
end

--- Called when a player has died, but before thier character is turned in to a corpse.
---@param event on_pre_player_died
AggressiveDriver.OnPrePlayerDied = function(event)
    AggressiveDriver.StopEffectOnPlayer(event.player_index, nil, EffectEndStatus.died)
end

--- Called when the effect has been stopped and the effects state and weapon changes should be undone.
--- Called when the player is alive or if they have died before their character has been affected.
---@param playerIndex PlayerIndex
---@param player LuaPlayer
---@param status AggressiveDriver_EffectEndStatus
AggressiveDriver.StopEffectOnPlayer = function(playerIndex, player, status)
    local affectedPlayer = global.aggressiveDriver.affectedPlayers[playerIndex]
    if affectedPlayer == nil then
        return
    end

    player = player or game.get_player(playerIndex)

    -- Return the player to their initial permission group.
    if player.permission_group.name == "AggressiveDriver" then
        -- If the permission group has been changed by something else don't set it back to the last non modded one.
        player.permission_group = global.origionalPlayersPermissionGroup[playerIndex]
        global.origionalPlayersPermissionGroup[playerIndex] = nil
    end

    -- Remove the flag aginst this player as being currently affected by the leaky flamethrower.
    global.aggressiveDriver.affectedPlayers[playerIndex] = nil

    -- Set the final state of the train to braking and straight as this ticks input. As soon as any player in the train tries to control it they will get control.
    player.riding_state = {
        acceleration = defines.riding.acceleration.braking,
        direction = defines.riding.direction.straight
    }

    -- Print a message based on ending status.
    if status == EffectEndStatus.completed then
        game.print({"message.muppet_streamer_aggressive_driver_stop", player.name})
    end
end

return AggressiveDriver
