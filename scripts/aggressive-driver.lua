--[[
    Assumptions:
        - All vehicles of type "car", "locomotive" and "spider-vehicle" have the ability to move themselves. I can't see a way via the API to check if they are actually capable of producing movement. I also assume all these vehicles can go backwards, as we just try and move backwards if forwards is blocked.
]]

local AggressiveDriver = {} ---@class AggressiveDriver
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local PositionUtils = require("utility.helper-utils.position-utils")
local Events = require("utility.manager-libraries.events")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")
local VehicleUtils = require("utility.helper-utils.vehicle-utils")
local StringUtils = require("utility.helper-utils.string-utils")

---@enum AggressiveDriver_ControlTypes
local ControlTypes = {
    full = "full",
    random = "random"
}

---@enum AggressiveDriver_EffectEndStatus
local EffectEndStatus = {
    completed = "completed",
    died = "died",
    invalid = "invalid"
}

---@enum AggressiveDriver_AggressiveWalkingTypes
local AggressiveWalkingTypes = {
    never = "never",
    noVehicle = "noVehicle",
    vehicleLost = "vehicleLost",
    both = "both"
}

---@class AggressiveDriver_DelayedCommandDetails
---@field target string # Player's name.
---@field duration uint # Ticks
---@field control AggressiveDriver_ControlTypes
---@field aggressiveWalkingNoStartingVehicle boolean
---@field aggressiveWalkingOnVehicleDeath boolean
---@field commandeerVehicle boolean
---@field teleportDistance double
---@field teleportWhitelistTypes table<string, string>|nil
---@field teleportWhitelistNames table<string, string>|nil
---@field suppressMessages boolean

---@class AggressiveDriver_DriveEachTickDetails
---@field player_index uint
---@field player LuaPlayer
---@field beenInVehicle boolean # Has the player been in a vehicle since the effect started.
---@field duration uint # Ticks
---@field control AggressiveDriver_ControlTypes
---@field aggressiveWalkingNoStartingVehicle boolean
---@field aggressiveWalkingOnVehicleDeath boolean
---@field accelerationTicks uint # How many ticks the vehicle has been trying to move in its current direction (forwards or backwards).
---@field accelerationState defines.riding.acceleration # Should only ever be either accelerating or reversing.
---@field directionDurationTicks uint # How many more ticks the vehicle will carry on going in its steering direction. Only used/updated if the steering is "random".
---@field ridingDirection defines.riding.direction # For if in a car or train vehicle.
---@field walkingDirection defines.direction # For when walking in a spider vehicle or on foot.

---@class AggressiveDriver_SortedVehicleEntry
---@field distance double
---@field vehicle LuaEntity

---@class AggressiveDriver_AffectedPlayerDetails
---@field suppressMessages boolean


---@alias AggressiveDriver_CheckedTrainFuelStates table<uint, boolean> # The trains fuel state when checked during this effect already.


local CommandName = "muppet_streamer_aggressive_driver"
local PrimaryVehicleTypes = { ["car"] = "car", ["locomotive"] = "locomotive", ["spider-vehicle"] = "spider-vehicle" }
local SecondaryVehicleTypes = { ["cargo-wagon"] = "cargo-wagon", ["fluid-wagon"] = "fluid-wagon", ["artillery-wagon"] = "artillery-wagon" }
local AllVehicleEntityTypes = { ["car"] = "car", ["locomotive"] = "locomotive", ["spider-vehicle"] = "spider-vehicle", ["cargo-wagon"] = "cargo-wagon", ["fluid-wagon"] = "fluid-wagon", ["artillery-wagon"] = "artillery-wagon" }

AggressiveDriver.CreateGlobals = function()
    global.aggressiveDriver = global.aggressiveDriver or {}
    global.aggressiveDriver.nextId = global.aggressiveDriver.nextId or 0 ---@type uint
    global.aggressiveDriver.affectedPlayers = global.aggressiveDriver.affectedPlayers or {} ---@type table<uint, AggressiveDriver_AffectedPlayerDetails> # Key'd by player_index.
end

AggressiveDriver.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_aggressive_driver", { "api-description.muppet_streamer_aggressive_driver" }, AggressiveDriver.AggressiveDriverCommand, true)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "AggressiveDriver.OnPrePlayerDied", AggressiveDriver.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("AggressiveDriver.Drive", AggressiveDriver.Drive)
    EventScheduler.RegisterScheduledEventType("AggressiveDriver.ApplyToPlayer", AggressiveDriver.ApplyToPlayer)
    MOD.Interfaces.Commands.AggressiveDriver = AggressiveDriver.AggressiveDriverCommand
end

AggressiveDriver.OnStartup = function()
    AggressiveDriver.GetOrCreatePermissionGroup()
end

---@param command CustomCommandData
AggressiveDriver.AggressiveDriverCommand = function(command)

    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, CommandName, { "delay", "target", "duration", "control", "aggressiveWalking", "commandeerVehicle", "teleportDistance", "teleportWhitelistTypes", "teleportWhitelistNames", "suppressMessages" })
    if commandData == nil then
        return
    end

    local delaySeconds = commandData.delay
    if not CommandsUtils.CheckNumberArgument(delaySeconds, "double", false, CommandName, "delay", 0, nil, command.parameter) then
        return
    end ---@cast delaySeconds double|nil
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySeconds, command.tick, CommandName, "delay")

    local target = commandData.target
    if not Common.CheckPlayerNameSettingValue(target, CommandName, "target", command.parameter) then
        return
    end ---@cast target string

    local durationSeconds = commandData.duration
    if not CommandsUtils.CheckNumberArgument(durationSeconds, "double", true, CommandName, "duration", 1, math.floor(MathUtils.uintMax / 60), command.parameter) then
        return
    end ---@cast durationSeconds double
    local duration = math.floor(durationSeconds * 60) --[[@as uint # Duration was validated as not exceeding a uint during input validation.]]

    local control = commandData.control
    if not CommandsUtils.CheckStringArgument(control, false, CommandName, "control", ControlTypes, command.parameter) then
        return
    end ---@cast control AggressiveDriver_ControlTypes|nil
    if control == nil then
        control = ControlTypes.random
    end

    local aggressiveWalking = commandData.aggressiveWalking
    if not CommandsUtils.CheckStringArgument(aggressiveWalking, false, CommandName, "aggressiveWalking", AggressiveWalkingTypes, command.parameter) then
        return
    end ---@cast aggressiveWalking AggressiveDriver_AggressiveWalkingTypes|nil
    if aggressiveWalking == nil then
        aggressiveWalking = AggressiveWalkingTypes.both
    end
    local aggressiveWalkingNoStartingVehicle, aggressiveWalkingOnVehicleDeath
    if aggressiveWalking == AggressiveWalkingTypes.noVehicle or aggressiveWalking == AggressiveWalkingTypes.both then
        aggressiveWalkingNoStartingVehicle = true
    else
        aggressiveWalkingNoStartingVehicle = false
    end
    if aggressiveWalking == AggressiveWalkingTypes.vehicleLost or aggressiveWalking == AggressiveWalkingTypes.both then
        aggressiveWalkingOnVehicleDeath = true
    else
        aggressiveWalkingOnVehicleDeath = false
    end

    local commandeerVehicle = commandData.commandeerVehicle
    if not CommandsUtils.CheckBooleanArgument(commandeerVehicle, false, CommandName, "commandeerVehicle", command.parameter) then
        return
    end ---@cast commandeerVehicle boolean|nil
    if commandeerVehicle == nil then
        commandeerVehicle = true
    end

    local teleportDistance = commandData.teleportDistance
    if not CommandsUtils.CheckNumberArgument(teleportDistance, "double", false, CommandName, "teleportDistance", 0, nil, command.parameter) then
        return
    end ---@cast teleportDistance double|nil
    if teleportDistance == nil then
        teleportDistance = 0.0
    end

    local teleportWhitelistTypes_string = commandData.teleportWhitelistTypes
    if not CommandsUtils.CheckStringArgument(teleportWhitelistTypes_string, false, CommandName, "teleportWhitelistTypes", nil, command.parameter) then
        return
    end ---@cast teleportWhitelistTypes_string string|nil
    local teleportWhitelistTypes ---@type table<string, string>|nil
    if teleportWhitelistTypes_string ~= nil and teleportWhitelistTypes_string ~= "" then
        local teleportWhitelistTypes_raw = StringUtils.SplitStringOnCharactersToDictionary(teleportWhitelistTypes_string, ",")
        teleportWhitelistTypes = {}
        for entityTypeName in pairs(teleportWhitelistTypes_raw) do
            if AllVehicleEntityTypes[entityTypeName] == nil then
                CommandsUtils.LogPrintError(CommandName, "teleportWhitelistTypes", "invalid vehicle type name: '" .. entityTypeName .. "'", command.parameter)
                return
            end
            teleportWhitelistTypes[entityTypeName] = entityTypeName
        end
    end

    local teleportWhitelistNames_string = commandData.teleportWhitelistNames
    if not CommandsUtils.CheckStringArgument(teleportWhitelistNames_string, false, CommandName, "teleportWhitelistNames", nil, command.parameter) then
        return
    end ---@cast teleportWhitelistNames_string string|nil
    local teleportWhitelistNames ---@type table<string, string>|nil
    if teleportWhitelistNames_string ~= nil and teleportWhitelistNames_string ~= "" then
        local teleportWhitelistNames_raw = StringUtils.SplitStringOnCharactersToDictionary(teleportWhitelistNames_string, ",")
        teleportWhitelistNames = {}
        for entityName in pairs(teleportWhitelistNames_raw) do
            if game.entity_prototypes[entityName] == nil then
                CommandsUtils.LogPrintError(CommandName, "teleportWhitelistNames", "invalid vehicle entity name: '" .. entityName .. "'", command.parameter)
                return
            end
            teleportWhitelistNames[entityName] = entityName
        end
    end

    -- Set default type and name values if none are populated.
    if teleportWhitelistTypes == nil and teleportWhitelistNames == nil then
        teleportWhitelistTypes = AllVehicleEntityTypes
        teleportWhitelistNames = nil
    end

    local suppressMessages = commandData.suppressMessages
    if not CommandsUtils.CheckBooleanArgument(suppressMessages, false, CommandName, "suppressMessages", command.parameter) then
        return
    end ---@cast suppressMessages boolean|nil
    if suppressMessages == nil then
        suppressMessages = false
    end

    global.aggressiveDriver.nextId = global.aggressiveDriver.nextId + 1
    ---@type AggressiveDriver_DelayedCommandDetails
    local delayedCommandDetails = { target = target, duration = duration, control = control, aggressiveWalkingNoStartingVehicle = aggressiveWalkingNoStartingVehicle, aggressiveWalkingOnVehicleDeath = aggressiveWalkingOnVehicleDeath, commandeerVehicle = commandeerVehicle, teleportDistance = teleportDistance, teleportWhitelistTypes = teleportWhitelistTypes, teleportWhitelistNames = teleportWhitelistNames, suppressMessages = suppressMessages }
    EventScheduler.ScheduleEventOnce(scheduleTick, "AggressiveDriver.ApplyToPlayer", global.aggressiveDriver.nextId, delayedCommandDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
AggressiveDriver.ApplyToPlayer = function(eventData)
    local data = eventData.data ---@type AggressiveDriver_DelayedCommandDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(CommandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    local targetPlayer_character = targetPlayer.character
    -- Check the player has a character they can control. The character may be inside the vehicle at present.
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer_character == nil then
        if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_driver_not_character_controller", data.target }) end
        return
    end

    if global.aggressiveDriver.affectedPlayers[targetPlayer.index] ~= nil then
        -- Player already being affected by this effect so just silently ignore it.
        if not data.suppressMessages then game.print({ "message.muppet_streamer_duplicate_command_ignored", "Aggressive Driver", data.target }) end
        return
    end

    -- Check if the player is already in a suitable vehicle based on the effect settings.
    local playersVehicle = targetPlayer.vehicle
    local checkedTrainFuelStates = {} ---@type AggressiveDriver_CheckedTrainFuelStates
    local inSuitableVehicle
    if playersVehicle == nil then
        -- Player not in a vehicle.
        inSuitableVehicle = false
    else
        -- Player is in a vehicle.

        -- If the vehicle has a good fuel state then check it's seats situation deeper.
        if AggressiveDriver.CheckVehiclesFuelState(playersVehicle, playersVehicle.type, checkedTrainFuelStates) then
            -- Check seats in current vehicle.
            local driver = playersVehicle.get_driver()
            if driver == nil then
                -- No current driver, so player must be in the passengers seat. We can always just move them across to the drivers seat.
                inSuitableVehicle = true
                playersVehicle.set_driver(targetPlayer)
                if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_commandeer_vehicle", targetPlayer.name }) end
            else
                -- There's a driver of the vehicle.
                if data.commandeerVehicle then
                    -- Commandeer a vehicle.
                    if driver == targetPlayer or driver == targetPlayer_character then
                        -- Player is already driving
                        inSuitableVehicle = true
                    else
                        -- Player must be in the passenger seat currently, so will need moving to the driver's seat (swap players seats) before checking for any other vehicle (readme logic).
                        inSuitableVehicle = true
                        playersVehicle.set_passenger(driver)
                        playersVehicle.set_driver(targetPlayer)
                        if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_commandeer_vehicle_from_other", targetPlayer.name, AggressiveDriver.GetVehicleOccupierPlayer(driver).name }) end
                    end
                else
                    -- Respect vehicle drivers.
                    if driver == targetPlayer or driver == targetPlayer_character then
                        -- Player is already driving
                        inSuitableVehicle = true
                    else
                        -- Player must be in passenger seat, so will need moving.
                        inSuitableVehicle = false
                    end
                end
            end
        else
            -- Current vehicle is lacking fuel.
            inSuitableVehicle = false
        end
    end

    -- Look for suitable vehicles if not already in one.
    if not inSuitableVehicle and data.teleportDistance > 0 then
        local targetPlayer_position = targetPlayer.position

        -- We sort vehicles based on their preference. We aim to dislodge as few other players as we can within the effect's setting's constraints.
        ---@type AggressiveDriver_SortedVehicleEntry[], AggressiveDriver_SortedVehicleEntry[], AggressiveDriver_SortedVehicleEntry[], AggressiveDriver_SortedVehicleEntry[], AggressiveDriver_SortedVehicleEntry[], AggressiveDriver_SortedVehicleEntry[]
        local primaryDistanceSortedFreeVehicles, primaryDistanceSortedDriverOccupiedVehicles, primaryDistanceSortedFullyOccupiedVehicles, secondaryDistanceSortedFreeVehicles, secondaryDistanceSortedDriverOccupiedVehicles, secondaryDistanceSortedFullyOccupiedVehicles = {}, {}, {}, {}, {}, {}

        -- Search for specified vehicles within the teleport radius. Have to get by type and names separately as otherwise if both populated they restricted over each other.
        local vehicles
        if data.teleportWhitelistTypes ~= nil then
            vehicles = targetPlayer.surface.find_entities_filtered { position = targetPlayer_position, radius = data.teleportDistance, force = targetPlayer.force, type = data.teleportWhitelistTypes }
        end
        if data.teleportWhitelistNames ~= nil then
            local vehicles_names = targetPlayer.surface.find_entities_filtered { position = targetPlayer_position, radius = data.teleportDistance, force = targetPlayer.force, name = data.teleportWhitelistNames }
            if vehicles == nil then
                vehicles = vehicles_names
            else
                for _, vehicle in pairs(vehicles_names) do
                    vehicles[#vehicles + 1] = vehicle
                end
            end
        end

        -- Check which of the vehicles are suitable.
        local list, driver, passenger, distance, vehicle_type
        for _, vehicle in pairs(vehicles) do
            -- Check which list to add the vehicle too based on the effect settings.
            driver, vehicle_type = vehicle.get_driver(), vehicle.type
            if driver == nil then
                -- No driver so always include.
                if PrimaryVehicleTypes[vehicle_type] ~= nil then
                    list = primaryDistanceSortedFreeVehicles
                else
                    list = secondaryDistanceSortedFreeVehicles
                end
            else
                -- Is a driver so option based logic.
                if data.commandeerVehicle then
                    -- Can commandeer a vehicle.
                    if vehicle_type == "car" or vehicle_type == "spider-vehicle" then
                        -- Vehicle allows passenger and driver.

                        -- Check if there's a passenger already.
                        passenger = vehicle.get_passenger()
                        if passenger == nil then
                            -- No passenger so include.
                            if PrimaryVehicleTypes[vehicle_type] ~= nil then
                                list = primaryDistanceSortedDriverOccupiedVehicles
                            else
                                list = secondaryDistanceSortedDriverOccupiedVehicles
                            end
                        else
                            -- Both driver and passenger seats are occupied.
                            if PrimaryVehicleTypes[vehicle_type] ~= nil then
                                list = primaryDistanceSortedFullyOccupiedVehicles
                            else
                                list = secondaryDistanceSortedFullyOccupiedVehicles
                            end
                        end
                    else
                        -- Vehicle is a single seat vehicle.
                        if PrimaryVehicleTypes[vehicle_type] ~= nil then
                            list = primaryDistanceSortedFullyOccupiedVehicles
                        else
                            list = secondaryDistanceSortedFullyOccupiedVehicles
                        end
                    end
                else
                    -- Respect vehicle drivers.

                    -- We will never eject a driver so don't record occupied vehicles.
                    list = nil
                end
            end

            -- If the vehicle has an appropriate driver/passenger state for our effect's options then check it's not lacking fuel.
            if list ~= nil then
                -- If the vehicle has a good fuel state then record it.
                if AggressiveDriver.CheckVehiclesFuelState(vehicle, vehicle_type, checkedTrainFuelStates) then
                    distance = PositionUtils.GetDistance(targetPlayer_position, vehicle.position)
                    list[#list + 1] = { distance = distance, vehicle = vehicle }
                end
            end
        end

        -- Work over the various primary and secondary lists of vehicles in a descending player dislocation order to check the best ones first. If a list has vehicles sort them and put the player in the nearest one.
        for _, vehicleList in pairs({ primaryDistanceSortedFreeVehicles, secondaryDistanceSortedFreeVehicles }) do
            if #vehicleList > 0 then
                table.sort(
                    vehicleList,
                    function(a, b)
                        return a.distance < b.distance
                    end
                )
                -- Can just put us in the free drivers seat.
                vehicleList[1].vehicle.set_driver(targetPlayer)
                inSuitableVehicle = true
                playersVehicle = vehicleList[1].vehicle
                if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_commandeer_vehicle", targetPlayer.name }) end
                break
            end
        end
        if not inSuitableVehicle then
            for _, vehicleList in pairs({ primaryDistanceSortedDriverOccupiedVehicles, secondaryDistanceSortedDriverOccupiedVehicles }) do
                if #vehicleList > 0 then
                    table.sort(
                        vehicleList,
                        function(a, b)
                            return a.distance < b.distance
                        end
                    )
                    -- Move old driver to passenger seat and put us in there.
                    local oldDriver = vehicleList[1].vehicle.get_driver() ---@cast oldDriver - nil
                    vehicleList[1].vehicle.set_passenger(oldDriver)
                    vehicleList[1].vehicle.set_driver(targetPlayer)
                    inSuitableVehicle = true
                    playersVehicle = vehicleList[1].vehicle
                    if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_commandeer_vehicle_from_other", targetPlayer.name, AggressiveDriver.GetVehicleOccupierPlayer(oldDriver).name }) end
                    break
                end
            end
        end
        if not inSuitableVehicle then
            for _, vehicleList in pairs({ primaryDistanceSortedFullyOccupiedVehicles, secondaryDistanceSortedFullyOccupiedVehicles }) do
                if #vehicleList > 0 then
                    table.sort(
                        vehicleList,
                        function(a, b)
                            return a.distance < b.distance
                        end
                    )
                    -- Eject the old driver and put us in there. The passenger seat is already full so just leave it be.
                    local oldDriver = vehicleList[1].vehicle.get_driver() ---@cast oldDriver - nil
                    vehicleList[1].vehicle.set_driver(targetPlayer)
                    inSuitableVehicle = true
                    playersVehicle = vehicleList[1].vehicle
                    if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_commandeer_vehicle_from_other", targetPlayer.name, AggressiveDriver.GetVehicleOccupierPlayer(oldDriver).name }) end
                    break
                end
            end
        end
    end
    if not inSuitableVehicle then
        if not data.aggressiveWalkingNoStartingVehicle then
            -- No aggressive walking for lack of starting vehicle, so the effect has failed to start.
            if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_driver_no_vehicle", data.target }) end
            return
        end

        -- If the player is in a vehicle then eject them as it can't be auto driven, so they need to be on foot to walk.
        if playersVehicle ~= nil then
            targetPlayer.vehicle = nil
        end
    end

    -- Store the players current permission group. Left as the previously stored group if an effect was already being applied to the player, or captured if no present effect affects them.
    global.originalPlayersPermissionGroup[targetPlayer.index] = global.originalPlayersPermissionGroup[targetPlayer.index] or targetPlayer.permission_group

    targetPlayer.permission_group = AggressiveDriver.GetOrCreatePermissionGroup()
    global.aggressiveDriver.affectedPlayers[targetPlayer.index] = { suppressMessages = data.suppressMessages }

    if not data.suppressMessages then game.print({ "message.muppet_streamer_aggressive_driver_start", targetPlayer.name }) end
    -- A train will continue moving in its current direction, effectively ignoring the accelerationState value at the start. But a car and tank will always start going forwards regardless of their previous movement, as they are much faster forwards than backwards.

    ---@type AggressiveDriver_DriveEachTickDetails
    local driveEachTickDetails = { player_index = targetPlayer.index, player = targetPlayer, beenInVehicle = inSuitableVehicle, duration = data.duration, control = data.control, aggressiveWalkingNoStartingVehicle = data.aggressiveWalkingNoStartingVehicle, aggressiveWalkingOnVehicleDeath = data.aggressiveWalkingOnVehicleDeath, accelerationTicks = 0, accelerationState = defines.riding.acceleration.accelerating, directionDurationTicks = 0 }
    ---@type UtilityScheduledEvent_CallbackObject
    local driveCallbackObject = { tick = game.tick, instanceId = driveEachTickDetails.player_index, data = driveEachTickDetails }
    AggressiveDriver.Drive(driveCallbackObject)
end

---@param eventData UtilityScheduledEvent_CallbackObject
AggressiveDriver.Drive = function(eventData)
    local data = eventData.data ---@type AggressiveDriver_DriveEachTickDetails
    local player, playerIndex = data.player, data.player_index
    if not player.valid then
        AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- Check the player has a character they can control. The character may be inside the vehicle at present.
    local player_character = player.character
    if player.controller_type ~= defines.controllers.character or player_character == nil then
        AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    local vehicle = player.vehicle
    if vehicle == nil then
        -- Player doesn't have a vehicle currently.

        if (not data.beenInVehicle) and data.aggressiveWalkingNoStartingVehicle then
            -- Player has never been in a vehicle and should walk until having entered a vehicle.
        elseif data.beenInVehicle and data.aggressiveWalkingOnVehicleDeath then
            -- Player has been in a vehicle and should walk after its death.
        else
            -- Player shouldn't walk after having left their vehicle or never having one.
            AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
            return
        end
    else
        -- Player has a vehicle

        -- So just update that they'd had one during this effect at some point. No harm in over writing this constantly.
        data.beenInVehicle = true

        -- Check the player is still the driver and not a passenger.
        local driver = vehicle.get_driver()
        if driver ~= player and driver ~= player_character then
            AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
            return
        end
    end

    local vehicle_type
    if vehicle ~= nil then
        vehicle_type = vehicle.type
    else
        vehicle_type = "walking"
    end
    if vehicle_type == "spider-vehicle" or vehicle_type == "walking" then
        -- Spider vehicles are special.

        -- Overwrite the players input control for this tick based on the settings.
        if data.control == ControlTypes.full then
            -- Player can still steer, so just force to move "forwards".

            -- Every 10 ticks we have to stop controlling the spiders movement so that the players direction input is registered and we can pick it up.
            if data.accelerationTicks > 10 then
                -- Just reset the counter this tick, lets user input be captured.
                data.accelerationTicks = 1
            else
                -- Walk in the current direction.
                player.walking_state = { walking = true, direction = player.walking_state.direction }
            end
        else
            -- Player has no control so we will set both acceleration and direction.

            -- Either find a new direction if the directionDuration has run out, or just count it down 1.
            if data.directionDurationTicks == 0 then
                data.directionDurationTicks = math.random(30, 180) --[[@as uint]]
                data.walkingDirection = math.random(0, 7) --[[@as defines.direction]]
            else
                data.directionDurationTicks = data.directionDurationTicks - 1
            end

            player.walking_state = { walking = true, direction = data.walkingDirection }
        end
    else
        -- Cars and trains.
        ---@cast vehicle - nil

        -- Train carriages need special handling.
        if vehicle_type == "locomotive" or vehicle_type == "cargo-wagon" or vehicle_type == "fluid-wagon" or vehicle_type == "artillery-wagon" then
            local train = vehicle.train ---@cast train -nil # A rolling_stock entity always has a train field.

            -- If the train isn't in manual mode then set it. We do this every tick if needed so that other players setting it to automatic gets overridden.
            if train.manual_mode ~= true then
                -- Don't set every tick blindly as it resets the players key directions on that tick to be forced to straight forwards.
                train.manual_mode = true
            end

            -- If the train is already moving work out if accelerating or reversing the players carriage keeps the train moving in its current direction.
            -- If the train isn't moving then later in the function the standard flip movement detection will start moving the train in the other direction.
            -- For a train just starting its scripted control this will also avoid flipping the trains direction, so it continues in its current travel direction. As it would loose the feel of an out of control train and would take a while to stop and build up reversing speed. If the train starts with no speed then the standard direction start logic will make the train move "forwards" in direct relation to the player's carriage facing, not the train's, as there's no known "good" start direction here.
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
        if data.accelerationTicks > 3 and vehicle.speed == 0 then
            data.accelerationTicks = 0
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
            if data.directionDurationTicks == 0 then
                if vehicle_type == "locomotive" or vehicle_type == "cargo-wagon" or vehicle_type == "fluid-wagon" or vehicle_type == "artillery-wagon" then
                    -- Train carriages should change every tick as very fast trains may cross rail points very fast.
                    data.directionDurationTicks = 1
                else
                    -- Cars/tanks should keep turning for a while so the steering is more definite.
                    data.directionDurationTicks = math.random(10, 30) --[[@as uint]]
                end
                data.ridingDirection = math.random(0, 2) --[[@as defines.riding.direction]]
            else
                data.directionDurationTicks = data.directionDurationTicks - 1
            end

            player.riding_state = {
                acceleration = data.accelerationState,
                direction = data.ridingDirection
            }
        end
    end

    -- Iterate the various counters for this effect.
    data.accelerationTicks = data.accelerationTicks + 1
    data.duration = data.duration - 1

    -- Schedule next ticks action unless the effect has timed out.
    if data.duration >= 0 then
        EventScheduler.ScheduleEventOnce(eventData.tick + 1, "AggressiveDriver.Drive", playerIndex, data)
    else
        AggressiveDriver.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
    end
end

--- Called when a player has died, but before their character is turned in to a corpse.
---@param event on_pre_player_died
AggressiveDriver.OnPrePlayerDied = function(event)
    AggressiveDriver.StopEffectOnPlayer(event.player_index, nil, EffectEndStatus.died)
end

--- Called when the effect has been stopped and the effects state and weapon changes should be undone.
--- Called when the player is alive or if they have died before their character has been affected.
---@param playerIndex uint
---@param player? LuaPlayer|nil # Obtains player if needed from playerIndex.
---@param status AggressiveDriver_EffectEndStatus
AggressiveDriver.StopEffectOnPlayer = function(playerIndex, player, status)
    local affectedPlayerDetails = global.aggressiveDriver.affectedPlayers[playerIndex]
    if affectedPlayerDetails == nil then
        return
    end

    -- Remove the flag against this player as being currently affected by the malfunctioning weapon.
    global.aggressiveDriver.affectedPlayers[playerIndex] = nil

    player = player or game.get_player(playerIndex)
    if player == nil then
        CommandsUtils.LogPrintWarning(CommandName, nil, "Target player has been deleted while the effect was running.", nil)
        return
    end

    -- Return the player to their initial permission group.
    if player.permission_group.name == "AggressiveDriver" then
        -- If the permission group has been changed by something else don't set it back to the last non modded one.
        player.permission_group = global.originalPlayersPermissionGroup[playerIndex]
        global.originalPlayersPermissionGroup[playerIndex] = nil
    end

    -- Set the final state of the train to braking and straight as this ticks input. As soon as any player in the train tries to control it they will get control.
    player.riding_state = {
        acceleration = defines.riding.acceleration.braking,
        direction = defines.riding.direction.straight
    }

    -- Print a message based on ending status.
    if status == EffectEndStatus.completed then
        if not affectedPlayerDetails.suppressMessages then game.print({ "message.muppet_streamer_aggressive_driver_stop", player.name }) end
    end
end

--- Gets the permission group for this feature. Will create it if needed.
---@return LuaPermissionGroup
AggressiveDriver.GetOrCreatePermissionGroup = function()
    local group = game.permissions.get_group("AggressiveDriver") or game.permissions.create_group("AggressiveDriver") ---@cast group -nil # Script always has permission to create groups.
    group.set_allows_action(defines.input_action.toggle_driving, false)
    return group
end

--- Gets the occupying player of a vehicle seat. As this can be a players character or just a player (editor mode).
---@param occupier LuaEntity|LuaPlayer
---@return LuaPlayer
AggressiveDriver.GetVehicleOccupierPlayer = function(occupier)
    return occupier.is_player() and occupier or occupier.player --[[@as LuaPlayer]]
end

--- Checks that the vehicle has a good fuel state. This handles train carriages in a smart manner.
---@param vehicle LuaEntity
---@param vehicle_type string
---@param checkedTrainFuelStates AggressiveDriver_CheckedTrainFuelStates
---@return boolean fuelStateGood
AggressiveDriver.CheckVehiclesFuelState = function(vehicle, vehicle_type, checkedTrainFuelStates)
    if vehicle_type == "locomotive" or vehicle_type == "cargo-wagon" or vehicle_type == "fluid-wagon" or vehicle_type == "artillery-wagon" then
        -- Train type vehicle, so we need to check that any of the locomotives in the train aren't lacking fuel, not just this specific carriage.
        local train = vehicle.train ---@cast train - nil
        local train_id = train.id

        -- Use the cached fuel state if we know it, otherwise get and store it.
        local trainGoodFuelState = checkedTrainFuelStates[train_id]
        if trainGoodFuelState == nil then
            -- Not cached so get the value and cache it.
            local locos = train.locomotives
            trainGoodFuelState = false
            for _, directionLocos in pairs(locos) do
                for _, loco in pairs(directionLocos) do
                    local loco_burner = loco.burner
                    if loco_burner == nil then
                        -- No burner so vehicle requires no fuel to move.
                        trainGoodFuelState = true
                        break
                    else
                        -- Vehicle needs fuel, so check it has some.
                        local currentFuel = VehicleUtils.GetVehicleCurrentFuelPrototype(loco, loco_burner)
                        if currentFuel ~= nil then
                            trainGoodFuelState = true
                            break
                        end
                    end
                end
                if trainGoodFuelState then
                    break
                end
            end
            checkedTrainFuelStates[train_id] = trainGoodFuelState
        end

        return trainGoodFuelState
    else
        -- Single vehicle, so we can just check its direct fuel needs.
        local vehicle_burner = vehicle.burner
        if vehicle_burner == nil then
            -- No burner so vehicle requires no fuel to move.
            return true
        else
            -- Vehicle needs fuel, so check it has some.
            local currentFuel = VehicleUtils.GetVehicleCurrentFuelPrototype(vehicle, vehicle_burner)
            if currentFuel ~= nil then
                return true
            end
        end
        return false
    end
end

return AggressiveDriver
