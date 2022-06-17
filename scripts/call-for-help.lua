local CallForHelp = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Events = require("utility/events")

---@class CallForHelp_CallSelection
local CallSelection = {random = "random", nearest = "nearest"}

local SPTesting = false -- Set to true to let yourself go to your own support.
local MaxRandomPositionsAroundTarget = 10
local MaxDistancePositionAroundTarget = 10

---@class CallForHelp_DelayedCommandDetails
---@field callForHelpId Id
---@field target string @ Player's name.
---@field arrivalRadius double
---@field callRadius double|null
---@field sameTeamOnly boolean
---@field sameSurfaceOnly boolean
---@field blacklistedPlayerNames table<string, True> @ Table of player names as the key.
---@field whitelistedPlayerNames table<string, True> @ Table of player names as the key.
---@field callSelection CallForHelp_CallSelection
---@field number uint
---@field activePercentage double

---@class CallForHelp_CallForHelpObject
---@field callForHelpId Id
---@field pendingPathRequests table<Id, CallForHelp_PathRequestObject>

---@class CallForHelp_PathRequestObject @ Details on a path request so that when it completes its results can be handled and back traced to the Call For Help it relates too.
---@field callForHelpId Id
---@field pathRequestId Id
---@field helpPlayer LuaPlayer
---@field targetPlayer LuaPlayer
---@field targetPlayerPosition MapPosition
---@field targetPlayerEntity LuaEntity
---@field surface LuaSurface
---@field position MapPosition
---@field attempt uint
---@field arrivalRadius double

---@class CallForHelp_HelpPlayerInRange
---@field player LuaPlayer
---@field distance double

CallForHelp.CreateGlobals = function()
    global.callForHelp = global.aggressiveDriver or {}
    global.callForHelp.nextId = global.callForHelp.nextId or 0 ---@type Id
    global.callForHelp.pathingRequests = global.callForHelp.pathingRequests or {} ---@type table<Id, CallForHelp_PathRequestObject>
    global.callForHelp.callForHelpIds = global.callForHelp.callForHelpIds or {} ---@type table<Id, CallForHelp_CallForHelpObject>
end

CallForHelp.OnLoad = function()
    Commands.Register("muppet_streamer_call_for_help", {"api-description.muppet_streamer_call_for_help"}, CallForHelp.CallForHelpCommand, true)
    EventScheduler.RegisterScheduledEventType("CallForHelp.CallForHelp", CallForHelp.CallForHelp)
    Events.RegisterHandlerEvent(defines.events.on_script_path_request_finished, "CallForHelp.OnScriptPathRequestFinished", CallForHelp.OnScriptPathRequestFinished)
end

---@param command CustomCommandData
CallForHelp.CallForHelpCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_call_for_help command "
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

    local arrivalRadius = tonumber(commandData.arrivalRadius)
    if arrivalRadius == nil or arrivalRadius <= 0 then
        Logging.LogPrint(errorMessageStart .. "arrivalRadius is Mandatory, and must be greater than 0")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    -- Nil is a valid final value if the argument isn't provided.
    local callRadius = tonumber(commandData.callRadius)
    if callRadius ~= nil then
        callRadius = tonumber(callRadius)
        if callRadius == nil or callRadius <= 0 then
            Logging.LogPrint(errorMessageStart .. "callRadius is Optional, but if provided must be greater than 0")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    local sameSurfaceOnly = commandData.sameSurfaceOnly
    if sameSurfaceOnly ~= nil then
        sameSurfaceOnly = Utils.ToBoolean(sameSurfaceOnly)
        if sameSurfaceOnly == nil then
            Logging.LogPrint(errorMessageStart .. "sameSurfaceOnly is Optional, but must be a valid boolean if provided")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    else
        sameSurfaceOnly = true
    end
    -- If not same surface then there's no callRadius result to be processed.
    if not sameSurfaceOnly then
        callRadius = nil
    end

    local sameTeamOnly = commandData.sameTeamOnly
    if sameTeamOnly ~= nil then
        sameTeamOnly = Utils.ToBoolean(sameTeamOnly)
        if sameTeamOnly == nil then
            Logging.LogPrint(errorMessageStart .. "sameTeamOnly is Optional, but must be a valid boolean if provided")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    else
        sameTeamOnly = true
    end

    local blacklistedPlayerNames_string = commandData.blacklistedPlayerNames
    local blacklistedPlayerNames  ---@type table<string, True>|null
    if blacklistedPlayerNames_string ~= nil and blacklistedPlayerNames_string ~= "" then
        blacklistedPlayerNames = Utils.SplitStringOnCharacters(blacklistedPlayerNames_string, ",", true)
    end

    local whitelistedPlayerNames_string = commandData.whitelistedPlayerNames
    local whitelistedPlayerNames  ---@type table<string, True>|null
    if whitelistedPlayerNames_string ~= nil and whitelistedPlayerNames_string ~= "" then
        whitelistedPlayerNames = Utils.SplitStringOnCharacters(whitelistedPlayerNames_string, ",", true)
    end

    local callSelection = CallSelection[commandData.callSelection]
    if callSelection == nil then
        Logging.LogPrint(errorMessageStart .. "callSelection is Mandatory and must be a valid type")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local number = commandData.number
    if number ~= nil then
        number = tonumber(number)
        if number == nil then
            Logging.LogPrint(errorMessageStart .. "number is Optional, but must be a valid number if provided")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
        number = math.floor(number)
    else
        number = 0
    end

    local activePercentage = commandData.activePercentage
    if activePercentage ~= nil then
        activePercentage = tonumber(activePercentage)
        if activePercentage == nil then
            Logging.LogPrint(errorMessageStart .. "activePercentage is Optional, but must be a valid number if provided")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
        activePercentage = activePercentage / 100
    else
        activePercentage = 0
    end

    if number == 0 and activePercentage == 0 then
        Logging.LogPrint(errorMessageStart .. "either number or activePercentage must be provided")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    global.callForHelp.nextId = global.callForHelp.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "CallForHelp.CallForHelp", global.callForHelp.nextId, {callForHelpId = global.callForHelp.nextId, target = target, arrivalRadius = arrivalRadius, callRadius = callRadius, sameTeamOnly = sameTeamOnly, sameSurfaceOnly = sameSurfaceOnly, blacklistedPlayerNames = blacklistedPlayerNames, whitelistedPlayerNames = whitelistedPlayerNames, callSelection = callSelection, number = number, activePercentage = activePercentage})
end

CallForHelp.CallForHelp = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_call_for_help command "
    local data = eventData.data ---@type CallForHelp_DelayedCommandDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character then
        game.print({"message.muppet_streamer_call_for_help_not_character_controller", data.target})
        return
    end

    local targetPlayerPosition, targetPlayerSurface = targetPlayer.position, targetPlayer.surface

    -- Work out the initial available players list.
    local availablePlayers  ---@type LuaPlayer[]
    if data.whitelistedPlayerNames == nil then
        -- No whitelist so all online players is the starting list.
        availablePlayers = game.connected_players
    else
        -- Only whitelisted online players are in the starting list.
        availablePlayers = {}
        for _, onlinePlayer in pairs(game.connected_players) do
            if data.whitelistedPlayerNames[onlinePlayer.name] then
                table.insert(availablePlayers, onlinePlayer)
            end
        end
    end

    -- remove any black listed players from the list.
    if data.blacklistedPlayerNames ~= nil then
        -- Iterate the list backwards so we can safely remove from it without skipping subsequent entries due to messing up the index placement.
        for i = #availablePlayers, 1, -1 do
            if data.blacklistedPlayerNames[availablePlayers[i].name] then
                table.remove(availablePlayers, i)
            end
        end
    end

    -- Work out the max number of players that can be called to help at present.
    local maxPlayers = math.max(data.number, math.floor(data.activePercentage * #availablePlayers))
    if maxPlayers <= 0 then
        game.print({"message.muppet_streamer_call_for_help_no_players_found", targetPlayer.name})
        return
    end

    -- Check the available players distance and viability for teleporting to help.

    local helpPlayersInRange = {} ---@type CallForHelp_HelpPlayerInRange[]
    local targetPlayerForce = targetPlayer.force
    for _, helpPlayer in pairs(availablePlayers) do
        if SPTesting or helpPlayer ~= targetPlayer then
            local helpPlayer_surface = helpPlayer.surface
            if (not data.sameTeamOnly or helpPlayer.force == targetPlayerForce) and (not data.sameSurfaceOnly or helpPlayer_surface == targetPlayerSurface) and helpPlayer.controller_type == defines.controllers.character and targetPlayer.character ~= nil then
                local distance
                if helpPlayer_surface ~= targetPlayerSurface then
                    distance = 4294967295 -- Maximum distance away to de-prioritise these players vs ones on the same surface.
                else
                    distance = Utils.GetDistance(targetPlayerPosition, helpPlayer.position)
                end

                if data.callRadius == nil or distance <= data.callRadius then
                    table.insert(helpPlayersInRange, {player = helpPlayer, distance = distance})
                end
            end
        end
    end
    if #helpPlayersInRange == 0 then
        game.print({"message.muppet_streamer_call_for_help_no_players_found", targetPlayer.name})
        return
    end

    -- Select the players to teleport to help.
    local helpPlayers = {} ---@type LuaPlayer[]
    if data.callSelection == CallSelection.random then
        for i = 1, maxPlayers do
            local random = math.random(1, #helpPlayersInRange)
            table.insert(helpPlayers, helpPlayersInRange[random].player)
            table.remove(helpPlayersInRange, random)
            if #helpPlayersInRange == 0 then
                break
            end
        end
    elseif data.callSelection == CallSelection.nearest then
        table.sort(
            helpPlayersInRange,
            function(a, b)
                return a.distance < b.distance
            end
        )
        for i = 1, maxPlayers do
            if helpPlayersInRange[i] == nil then
                break
            end
            table.insert(helpPlayers, helpPlayersInRange[i].player)
        end
    end

    -- Store the initial details for the call and start the process for each player trying to come to help.
    game.print({"message.muppet_streamer_call_for_help_start", targetPlayer.name})
    global.callForHelp.callForHelpIds[data.callForHelpId] = {callForHelpId = data.callForHelpId, pendingPathRequests = {}}
    local targetPlayerEntity
    local targetPlayerVehicle = targetPlayer.vehicle
    if targetPlayerVehicle ~= nil and targetPlayerVehicle.valid then
        -- Player in vehicle so target it.
        targetPlayerEntity = targetPlayerVehicle
    else
        -- Player not in a vehicle.
        targetPlayerEntity = targetPlayer.character
    end
    for _, helpPlayer in pairs(helpPlayers) do
        CallForHelp.PlanTeleportHelpPlayer(helpPlayer, data.arrivalRadius, targetPlayer, targetPlayerPosition, targetPlayerSurface, targetPlayerEntity, data.callForHelpId, 1)
    end
end

--- Confirms if the vehicle is teleportable (non train).
---@param vehicle LuaEntity
---@return boolean isVehicleTeleportable
CallForHelp.IsTeleportableVehicle = function(vehicle)
    return vehicle ~= nil and vehicle.valid and (vehicle.name == "car" or vehicle.name == "tank" or vehicle.name == "spider-vehicle")
end

--- Finds somewhere to teleport the help player too and makes the pathing request for it.
---@param helpPlayer LuaPlayer
---@param arrivalRadius double
---@param targetPlayer LuaPlayer
---@param targetPlayerPosition MapPosition
---@param targetPlayerSurface LuaSurface
---@param targetPlayerEntity LuaEntity
---@param callForHelpId Id
---@param attempt uint
CallForHelp.PlanTeleportHelpPlayer = function(helpPlayer, arrivalRadius, targetPlayer, targetPlayerPosition, targetPlayerSurface, targetPlayerEntity, callForHelpId, attempt)
    local helpPlayerPathingEntity = helpPlayer.character

    local helpPlayerPlacementEntity
    if CallForHelp.IsTeleportableVehicle(helpPlayer.vehicle) then
        helpPlayerPlacementEntity = helpPlayer.vehicle
    else
        helpPlayerPlacementEntity = helpPlayer.character
    end

    local arrivalPos
    for _ = 1, MaxRandomPositionsAroundTarget do
        local randomPos = Utils.RandomLocationInRadius(targetPlayerPosition, arrivalRadius, 1)
        randomPos = Utils.RoundPosition(randomPos, 0) -- Make it tile border aligned as most likely place to get valid placements from when in a base. We search in whole tile increments from this tile border.
        arrivalPos = targetPlayerSurface.find_non_colliding_position(helpPlayerPlacementEntity.name, randomPos, MaxDistancePositionAroundTarget, 1, false)
        if arrivalPos ~= nil then
            break
        end
    end
    if arrivalPos == nil then
        game.print({"message.muppet_streamer_call_for_help_no_teleport_location_found", helpPlayer.name, targetPlayer.name})
        return
    end

    -- Create the path request.
    local pathRequestId =
        targetPlayerSurface.request_path {
        bounding_box = helpPlayerPathingEntity.prototype.collision_box, -- Work around for (but unknown what the non work-around logic was): https://forums.factorio.com/viewtopic.php?f=182&t=90146
        collision_mask = helpPlayerPathingEntity.prototype.collision_mask,
        start = arrivalPos,
        goal = targetPlayerPosition,
        force = helpPlayer.force,
        radius = 1,
        can_open_gates = true,
        entity_to_ignore = targetPlayerEntity,
        pathfind_flags = {allow_paths_through_own_entities = true, cache = false}
    }

    -- Record the path request to globals.
    ---@type CallForHelp_PathRequestObject
    local pathRequestObject = {
        callForHelpId = callForHelpId,
        pathRequestId = pathRequestId,
        helpPlayer = helpPlayer,
        targetPlayer = targetPlayer,
        targetPlayerPosition = targetPlayerPosition,
        targetPlayerEntity = targetPlayerEntity,
        surface = targetPlayerSurface,
        position = arrivalPos,
        attempt = attempt,
        arrivalRadius = arrivalRadius
    }
    global.callForHelp.pathingRequests[pathRequestId] = pathRequestObject
    global.callForHelp.callForHelpIds[callForHelpId].pendingPathRequests[pathRequestId] = pathRequestObject
end

--- Triggered when a path request completes to check and handle the results.
---@param event on_script_path_request_finished
CallForHelp.OnScriptPathRequestFinished = function(event)
    local pathRequest = global.callForHelp.pathingRequests[event.id]

    -- Check if this path request related to a Call For Help.
    if pathRequest == nil then
        -- Not our path request
        return
    end

    global.callForHelp.callForHelpIds[pathRequest.callForHelpId].pendingPathRequests[pathRequest.pathRequestId] = nil
    global.callForHelp.pathingRequests[event.id] = nil
    local helpPlayer = pathRequest.helpPlayer
    if event.path == nil then
        -- Path request failed
        pathRequest.attempt = pathRequest.attempt + 1
        if pathRequest.attempt > 3 then
            game.print({"message.muppet_streamer_call_for_help_no_teleport_location_found", helpPlayer.name, pathRequest.targetPlayer.name})
        else
            CallForHelp.PlanTeleportHelpPlayer(helpPlayer, pathRequest.arrivalRadius, pathRequest.targetPlayer, pathRequest.targetPlayerPosition, pathRequest.surface, pathRequest.targetPlayerEntity, pathRequest.callForHelpId, pathRequest.attempt)
        end
    else
        local helpPlayer_vehicle = helpPlayer.vehicle
        if CallForHelp.IsTeleportableVehicle(helpPlayer_vehicle) then
            helpPlayer.vehicle.teleport(pathRequest.position)
        else
            local wasDriving, wasPassengerIn
            if helpPlayer_vehicle ~= nil and helpPlayer_vehicle.valid then
                -- Player is in a non suitable vehicle, so get them out of it before teleporting.
                if helpPlayer_vehicle.get_driver() then
                    wasDriving = helpPlayer_vehicle
                elseif helpPlayer_vehicle.get_passenger() then
                    wasPassengerIn = helpPlayer_vehicle
                end
                helpPlayer.driving = false
            end
            local teleportResult = helpPlayer.teleport(pathRequest.position, pathRequest.surface)
            if not teleportResult then
                if wasDriving then
                    wasDriving.set_driver(helpPlayer)
                elseif wasPassengerIn then
                    wasPassengerIn.set_passenger(helpPlayer)
                end
                game.print("Muppet Streamer Error - teleport failed")
            end
        end
    end

    -- If theres no pending path requests left then this call for help is completed.
    if next(global.callForHelp.callForHelpIds[pathRequest.callForHelpId].pendingPathRequests) == nil then
        game.print({"message.muppet_streamer_call_for_help_stop", pathRequest.targetPlayer.name})
        global.callForHelp.callForHelpIds[pathRequest.callForHelpId] = nil
    end
end

return CallForHelp
