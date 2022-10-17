local CallForHelp = {} ---@class CallForHelp
local CommandsUtils = require("utility.helper-utils.commands-utils")
local LoggingUtils = require("utility.helper-utils.logging-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local PositionUtils = require("utility.helper-utils.position-utils")
local Events = require("utility.manager-libraries.events")
local PlayerTeleport = require("utility.functions.player-teleport")
local StringUtils = require("utility.helper-utils.string-utils")
local MathUtils = require("utility.helper-utils.math-utils")
local Common = require("scripts.common")
local DirectionUtils = require("utility.helper-utils.direction-utils")

---@enum CallForHelp_CallSelection
local CallSelection = {
    random = "random",
    nearest = "nearest"
}

local SinglePlayerTesting = false -- Set to true to let yourself go to your own support.
local MaxRandomPositionsAroundTargetToTry = 50 -- Was 10, but upped to reduce odd vehicle rotation issues.
local MaxDistancePositionAroundTarget = 10.0 ---@type double
local MaxPathfinderAttemptsForTargetLocation = 5 -- How many times the mod tries per player once it finds a valid placement position that then has a pathing request return false.

---@class CallForHelp_DelayedCommandDetails
---@field callForHelpId uint
---@field target string # Player's name.
---@field arrivalRadius double
---@field callRadius? double|nil
---@field sameTeamOnly boolean
---@field sameSurfaceOnly boolean
---@field blacklistedPlayerNames table<string, true>|nil # Table of player names as the key.
---@field whitelistedPlayerNames table<string, true>|nil # Table of player names as the key.
---@field callSelection CallForHelp_CallSelection
---@field number uint
---@field activePercentage double
---@field suppressMessages boolean

---@class CallForHelp_CallForHelpObject
---@field callForHelpId uint
---@field pendingPathRequests table<uint, CallForHelp_PathRequestObject> # Key'd to the path request Id.

---@class CallForHelp_PathRequestObject # Details on a path request so that when it completes its results can be handled and back traced to the Call For Help it relates too.
---@field callForHelpId uint
---@field pathRequestId uint
---@field helpPlayer LuaPlayer
---@field helpPlayerPlacementEntity LuaEntity # The helping player's character or teleportable vehicle.
---@field helpPlayerForce LuaForce
---@field helpPlayerSurface LuaSurface
---@field targetPlayer LuaPlayer
---@field targetPlayerPosition MapPosition
---@field targetPlayerEntity LuaEntity
---@field surface LuaSurface
---@field position MapPosition
---@field attempt uint
---@field arrivalRadius double
---@field sameSurfaceOnly boolean
---@field sameTeamOnly boolean
---@field suppressMessages boolean

---@class CallForHelp_HelpPlayerInRange
---@field player LuaPlayer
---@field distance double

local CommandName = "muppet_streamer_call_for_help"

CallForHelp.CreateGlobals = function()
    global.callForHelp = global.callForHelp or {} ---@class CallForHelp_Global
    global.callForHelp.nextId = global.callForHelp.nextId or 0 ---@type uint
    global.callForHelp.pathingRequests = global.callForHelp.pathingRequests or {} ---@type table<uint, CallForHelp_PathRequestObject> # Key'd to the pathing request Ids,
    global.callForHelp.callForHelpIds = global.callForHelp.callForHelpIds or {} ---@type table<uint, CallForHelp_CallForHelpObject> # Key'd to the callForHelp Ids.
end

CallForHelp.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_call_for_help", { "api-description.muppet_streamer_call_for_help" }, CallForHelp.CallForHelpCommand, true)
    EventScheduler.RegisterScheduledEventType("CallForHelp.CallForHelp", CallForHelp.CallForHelp)
    Events.RegisterHandlerEvent(defines.events.on_script_path_request_finished, "CallForHelp.OnScriptPathRequestFinished", CallForHelp.OnScriptPathRequestFinished)
    MOD.Interfaces.Commands.CallForHelp = CallForHelp.CallForHelpCommand
end

---@param command CustomCommandData
CallForHelp.CallForHelpCommand = function(command)

    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, CommandName, { "delay", "target", "arrivalRadius", "callRadius", "sameSurfaceOnly", "sameTeamOnly", "blacklistedPlayerNames", "whitelistedPlayerNames", "callSelection", "number", "activePercentage", "suppressMessages" })
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

    local arrivalRadius = commandData.arrivalRadius
    if not CommandsUtils.CheckNumberArgument(arrivalRadius, "double", false, CommandName, "arrivalRadius", 1, nil, command.parameter) then
        return
    end ---@cast arrivalRadius double|nil
    if arrivalRadius == nil then
        arrivalRadius = 10.0
    end

    local callRadius = commandData.callRadius
    if not CommandsUtils.CheckNumberArgument(callRadius, "double", false, CommandName, "callRadius", 1, nil, command.parameter) then
        return
    end ---@cast callRadius double|nil

    local sameSurfaceOnly = commandData.sameSurfaceOnly
    if not CommandsUtils.CheckBooleanArgument(sameSurfaceOnly, false, CommandName, "sameSurfaceOnly", command.parameter) then
        return
    end ---@cast sameSurfaceOnly boolean|nil
    if sameSurfaceOnly == nil then
        sameSurfaceOnly = true
    end
    -- If not same surface then there's no callRadius result to be processed.
    if not sameSurfaceOnly then
        callRadius = nil
    end

    local sameTeamOnly = commandData.sameTeamOnly
    if not CommandsUtils.CheckBooleanArgument(sameTeamOnly, false, CommandName, "sameTeamOnly", command.parameter) then
        return
    end ---@cast sameTeamOnly boolean|nil
    if sameTeamOnly == nil then
        sameTeamOnly = true
    end

    local blacklistedPlayerNames_string = commandData.blacklistedPlayerNames
    if not CommandsUtils.CheckStringArgument(blacklistedPlayerNames_string, false, CommandName, "blacklistedPlayerNames", nil, command.parameter) then
        return
    end ---@cast blacklistedPlayerNames_string string|nil
    local blacklistedPlayerNames ---@type table<string, true>|nil
    if blacklistedPlayerNames_string ~= nil and blacklistedPlayerNames_string ~= "" then
        blacklistedPlayerNames = StringUtils.SplitStringOnCharactersToDictionary(blacklistedPlayerNames_string, ",")
    end

    local whitelistedPlayerNames_string = commandData.whitelistedPlayerNames
    if not CommandsUtils.CheckStringArgument(whitelistedPlayerNames_string, false, CommandName, "whitelistedPlayerNames", nil, command.parameter) then
        return
    end ---@cast whitelistedPlayerNames_string string|nil
    local whitelistedPlayerNames ---@type table<string, true>|nil
    if whitelistedPlayerNames_string ~= nil and whitelistedPlayerNames_string ~= "" then
        whitelistedPlayerNames = StringUtils.SplitStringOnCharactersToDictionary(whitelistedPlayerNames_string, ",")
    end

    local callSelection_string = commandData.callSelection
    if not CommandsUtils.CheckStringArgument(callSelection_string, true, CommandName, "callSelection", CallSelection, command.parameter) then
        return
    end ---@cast callSelection_string string
    local callSelection = CallSelection[callSelection_string] ---@type CallForHelp_CallSelection

    local number = commandData.number
    if not CommandsUtils.CheckNumberArgument(number, "int", false, CommandName, "number", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast number uint|nil
    if number == nil then
        number = 0
    end

    local activePercentage = commandData.activePercentage
    if not CommandsUtils.CheckNumberArgument(activePercentage, "double", false, CommandName, "activePercentage", 0, nil, command.parameter) then
        return
    end ---@cast activePercentage double|nil
    if activePercentage ~= nil then
        activePercentage = activePercentage / 100
    else
        activePercentage = 0
    end

    -- At least one of number or activePercentage must have been set above 0.
    if number == 0 and activePercentage == 0 then
        CommandsUtils.LogPrintError(CommandName, nil, "either number or activePercentage must be provided", command.parameter)
        return
    end

    local suppressMessages = commandData.suppressMessages
    if not CommandsUtils.CheckBooleanArgument(suppressMessages, false, CommandName, "suppressMessages", command.parameter) then
        return
    end ---@cast suppressMessages boolean|nil
    if suppressMessages == nil then
        suppressMessages = false
    end

    global.callForHelp.nextId = global.callForHelp.nextId + 1
    ---@type CallForHelp_DelayedCommandDetails
    local delayedCommandDetails = { callForHelpId = global.callForHelp.nextId, target = target, arrivalRadius = arrivalRadius, callRadius = callRadius, sameTeamOnly = sameTeamOnly, sameSurfaceOnly = sameSurfaceOnly, blacklistedPlayerNames = blacklistedPlayerNames, whitelistedPlayerNames = whitelistedPlayerNames, callSelection = callSelection, number = number, activePercentage = activePercentage, suppressMessages = suppressMessages }
    if scheduleTick ~= -1 then
        EventScheduler.ScheduleEventOnce(scheduleTick, "CallForHelp.CallForHelp", global.callForHelp.nextId, delayedCommandDetails)
    else
        ---@type UtilityScheduledEvent_CallbackObject
        local eventData = { tick = command.tick, name = "CallForHelp.CallForHelp", instanceId = global.callForHelp.nextId, data = delayedCommandDetails }
        CallForHelp.CallForHelp(eventData)
    end
end

---@param eventData UtilityScheduledEvent_CallbackObject
CallForHelp.CallForHelp = function(eventData)
    local data = eventData.data ---@type CallForHelp_DelayedCommandDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(CommandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character then
        if not data.suppressMessages then game.print({ "message.muppet_streamer_call_for_help_not_character_controller", data.target }) end
        return
    end

    local targetPlayerEntity, targetPlayerInVehicle = CallForHelp.GetTargetPlayersEntity(targetPlayer, data.suppressMessages)
    if targetPlayerEntity == nil then
        return
    end

    local targetPlayerPosition, targetPlayerSurface = targetPlayer.position, targetPlayer.surface

    -- Work out the initial available players list.
    local availablePlayers ---@type LuaPlayer[]
    if data.whitelistedPlayerNames == nil then
        -- No whitelist so all online players is the starting list.
        availablePlayers = game.connected_players
    else
        -- Only whitelisted online players are in the starting list.
        availablePlayers = {}
        for _, onlinePlayer in pairs(game.connected_players) do
            if data.whitelistedPlayerNames[onlinePlayer.name] then
                availablePlayers[#availablePlayers + 1] = onlinePlayer
            end
        end
    end

    -- Remove any black listed players from the list.
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
        if not data.suppressMessages then game.print({ "message.muppet_streamer_call_for_help_no_players_found", targetPlayer.name }) end
        return
    end

    -- Check the available players distance and viability for teleporting to help.

    local helpPlayersInRange = {} ---@type CallForHelp_HelpPlayerInRange[]
    local targetPlayerForce = targetPlayer.force
    local helpPlayer_surface, distance
    for _, helpPlayer in pairs(availablePlayers) do
        if SinglePlayerTesting or helpPlayer ~= targetPlayer then
            if (not data.sameTeamOnly) or helpPlayer.force == targetPlayerForce then
                helpPlayer_surface = helpPlayer.surface
                if (not data.sameSurfaceOnly or helpPlayer_surface == targetPlayerSurface) and helpPlayer.controller_type == defines.controllers.character and helpPlayer.character ~= nil then
                    if helpPlayer_surface ~= targetPlayerSurface then
                        distance = 4294967295 -- Maximum distance away to de-prioritise these players vs ones on the same surface.
                    else
                        distance = PositionUtils.GetDistance(targetPlayerPosition, helpPlayer.position)
                    end

                    if data.callRadius == nil or distance <= data.callRadius then
                        helpPlayersInRange[#helpPlayersInRange + 1] = { player = helpPlayer, distance = distance }
                    end
                end
            end
        end
    end
    if #helpPlayersInRange == 0 then
        if not data.suppressMessages then game.print({ "message.muppet_streamer_call_for_help_no_players_found", targetPlayer.name }) end
        return
    end

    -- Select the players to teleport to help.
    local helpPlayers = {} ---@type LuaPlayer[]
    if data.callSelection == CallSelection.random then
        for i = 1, maxPlayers do
            local random = math.random(1, #helpPlayersInRange)
            helpPlayers[#helpPlayers + 1] = helpPlayersInRange[random].player
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
            helpPlayers[#helpPlayers + 1] = helpPlayersInRange[i].player
        end
    end

    -- Work out if the requesting player is in a vehicle that can have some players added to it.
    local teleportHelpToVehicle, canSetDriver, canSetPassenger = false, false, false
    local freeTrainCarriages ---@type LuaEntity[]
    if targetPlayerInVehicle then
        local targetPlayerEntity_type = targetPlayerEntity.type
        if targetPlayerEntity_type == "car" or targetPlayerEntity_type == "spider-vehicle" then
            -- Is a 2 seat vehicle, but as our requester is in 1 seat only 1 can be free, but possibly both seats may already be full.
            if targetPlayerEntity.get_driver() == nil then
                canSetDriver = true
                teleportHelpToVehicle = true
            elseif targetPlayerEntity.get_passenger() == nil then
                canSetPassenger = true
                teleportHelpToVehicle = true
            end
        else
            -- Is a train carriage type.
            freeTrainCarriages = {}
            for _, carriage in pairs(targetPlayerEntity.train.carriages) do
                if carriage.get_driver() == nil then
                    -- Carriage doesn't already have a player in it, so is free.
                    freeTrainCarriages[#freeTrainCarriages + 1] = carriage
                    teleportHelpToVehicle = true
                end
            end
        end
    end

    -- Store the initial details for the call and start the process for each player trying to come to help.
    if not data.suppressMessages then game.print({ "message.muppet_streamer_call_for_help_start", targetPlayer.name }) end
    global.callForHelp.callForHelpIds[data.callForHelpId] = { callForHelpId = data.callForHelpId, pendingPathRequests = {} }
    local helpPlayer_moved, freeTrainCarriage, freeTrainCarriage_index, helpPlayer_vehicle, helpPlayer_vehicle_type, helpPlayer_canGoInTargetsVehicle
    for _, helpPlayer in pairs(helpPlayers) do

        -- Put player in to the current player's vehicle first if possible.
        helpPlayer_moved = false
        if teleportHelpToVehicle then
            -- Check the helping player isn't already in a vehicle.
            helpPlayer_vehicle = helpPlayer.vehicle
            helpPlayer_canGoInTargetsVehicle = true
            if helpPlayer_vehicle ~= nil then
                helpPlayer_vehicle_type = helpPlayer_vehicle.type
                if helpPlayer_vehicle_type == "car" or helpPlayer_vehicle_type == "spider-vehicle" then
                    helpPlayer_canGoInTargetsVehicle = false
                end
            end

            -- If the helping player can go in a vehicle try to do it.
            if helpPlayer_canGoInTargetsVehicle then
                if canSetDriver then
                    targetPlayerEntity.set_driver(helpPlayer)
                    helpPlayer_moved = true
                    canSetDriver = false
                    teleportHelpToVehicle = false
                elseif canSetPassenger then
                    targetPlayerEntity.set_passenger(helpPlayer)
                    helpPlayer_moved = true
                    canSetPassenger = false
                    teleportHelpToVehicle = false
                else
                    -- Find a free train carriage.
                    freeTrainCarriage_index, freeTrainCarriage = next(freeTrainCarriages, freeTrainCarriage_index)
                    if freeTrainCarriage ~= nil then
                        freeTrainCarriage.set_driver(helpPlayer)
                        helpPlayer_moved = true
                    else
                        helpPlayer_moved = false
                        teleportHelpToVehicle = false
                    end
                end
            end
        end

        -- Teleport the helping player if we couldn't put them in the target players vehicle/train.
        if not helpPlayer_moved then
            CallForHelp.PlanTeleportHelpPlayer(helpPlayer, data.arrivalRadius, targetPlayer, targetPlayerPosition, targetPlayerSurface, targetPlayerEntity, data.callForHelpId, 1, data.sameSurfaceOnly, data.sameTeamOnly, data.suppressMessages)
        end
    end
end

--- Finds somewhere to teleport the helping player too and make the pathing request for it.
---@param helpPlayer LuaPlayer
---@param arrivalRadius double
---@param targetPlayer LuaPlayer
---@param targetPlayerPosition MapPosition
---@param targetPlayerSurface LuaSurface
---@param targetPlayerEntity LuaEntity
---@param callForHelpId uint
---@param attempt uint
---@param sameSurfaceOnly boolean
---@param sameTeamOnly boolean
---@param suppressMessages boolean
CallForHelp.PlanTeleportHelpPlayer = function(helpPlayer, arrivalRadius, targetPlayer, targetPlayerPosition, targetPlayerSurface, targetPlayerEntity, callForHelpId, attempt, sameSurfaceOnly, sameTeamOnly, suppressMessages)
    -- Make the teleport request to near by the target identified.
    local teleportResponse = PlayerTeleport.RequestTeleportToNearPosition(helpPlayer, targetPlayerSurface, targetPlayerPosition, arrivalRadius, MaxRandomPositionsAroundTargetToTry, MaxDistancePositionAroundTarget, helpPlayer.surface == targetPlayerSurface and targetPlayerPosition or nil)

    -- Handle the teleport response.
    local pathRequestId = teleportResponse.pathRequestId -- Variables existence is a workaround for Sumneko missing object field nil detection.
    if teleportResponse.teleportSucceeded == true then
        -- All completed.
        return
    elseif pathRequestId ~= nil then
        -- A pathing request has been made, monitor it and react when it completes.

        -- Record the path request to globals.
        ---@type CallForHelp_PathRequestObject
        local pathRequestObject = {
            callForHelpId = callForHelpId,
            pathRequestId = pathRequestId,
            helpPlayer = helpPlayer,
            helpPlayerPlacementEntity = teleportResponse.targetPlayerTeleportEntity,
            helpPlayerForce = helpPlayer.force --[[@as LuaForce # read/write work around]] ,
            helpPlayerSurface = helpPlayer.surface,
            targetPlayer = targetPlayer,
            targetPlayerPosition = targetPlayerPosition,
            targetPlayerEntity = targetPlayerEntity,
            surface = targetPlayerSurface,
            position = teleportResponse.targetPosition,
            attempt = attempt,
            arrivalRadius = arrivalRadius,
            sameSurfaceOnly = sameSurfaceOnly,
            sameTeamOnly = sameTeamOnly,
            suppressMessages = suppressMessages
        }
        global.callForHelp.pathingRequests[pathRequestId] = pathRequestObject
        global.callForHelp.callForHelpIds[callForHelpId].pendingPathRequests[pathRequestId] = pathRequestObject

        return
    elseif teleportResponse.errorNoValidPositionFound then
        -- No valid position was found to try and teleport too.
        if not suppressMessages then game.print({ "message.muppet_streamer_call_for_help_no_teleport_location_found", helpPlayer.name, targetPlayer.name }) end
        return
    elseif teleportResponse.errorTeleportFailed then
        -- Failed to teleport the entity to the specific position.
        CommandsUtils.LogPrintWarning(CommandName, nil, "Teleport action for player " .. helpPlayer.name .. " to position " .. LoggingUtils.PositionToString(teleportResponse.targetPosition) .. " failed (Factorio request rejected)", nil)
        return
    end
end

--- React to path requests being completed. If the path request was for a teleport request then we need to validate things again as there could be a significant gap between the path request being made and the response coming back.
---@param event on_script_path_request_finished
CallForHelp.OnScriptPathRequestFinished = function(event)
    -- Check if this path request related to a Call For Help.
    local pathRequest = global.callForHelp.pathingRequests[event.id]
    if pathRequest == nil then
        -- Not our path request
        return
    end

    -- Update the globals.
    global.callForHelp.callForHelpIds[pathRequest.callForHelpId].pendingPathRequests[pathRequest.pathRequestId] = nil
    global.callForHelp.pathingRequests[event.id] = nil

    local helpPlayer = pathRequest.helpPlayer

    -- Check some key LuaObjects still exist. This is to avoid risk of crashes during any checks for changes.
    if not pathRequest.surface.valid then
        CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
        return
    end

    -- Check the target player is still valid to be teleported too. Not technically used in positive path and teleport logic, but used in most negative routes.
    local targetPlayerEntity = CallForHelp.GetTargetPlayersEntity(pathRequest.targetPlayer, pathRequest.suppressMessages)
    if targetPlayerEntity == nil then
        return
    end

    if event.path == nil then
        -- Path request failed
        pathRequest.attempt = pathRequest.attempt + 1
        if pathRequest.attempt > MaxPathfinderAttemptsForTargetLocation then
            if not pathRequest.suppressMessages then game.print({ "message.muppet_streamer_call_for_help_no_teleport_location_found", helpPlayer.name, pathRequest.targetPlayer.name }) end
        else
            -- Make another request. Obtain fresh data where needed, but by and large try again with the same target location and details to join others already teleported.
            CallForHelp.PlanTeleportHelpPlayer(helpPlayer, pathRequest.arrivalRadius, pathRequest.targetPlayer, pathRequest.targetPlayerPosition, pathRequest.surface, targetPlayerEntity, pathRequest.callForHelpId, pathRequest.attempt, pathRequest.sameSurfaceOnly, pathRequest.sameTeamOnly, pathRequest.suppressMessages)
        end
    else
        -- Path request succeeded.

        -- CODE NOTE: As this has an unknown delay between request and result we need to validate everything important is unchanged before accepting the result and teleporting the player there. If something critical has changed we repeat the entire placement selection to avoid complicated code. But we don't increment the attempts so it's a free retry. Obtain fresh data where needed, but by and large try again with the same target location and details to join others already teleported.

        -- Check the helping player is still alive and in a suitable game state (not editor) to be teleported. If they aren't suitable just abandon the teleport.
        if helpPlayer.controller_type ~= defines.controllers.character then
            CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
            return
        end

        -- Check the helping player's surface hasn't changed and if it has that this doesn't make them invalid for selection due to sameSurface option being enabled.
        if helpPlayer.surface ~= pathRequest.helpPlayerSurface then
            if pathRequest.sameSurfaceOnly then
                -- They must have been same surface before, but now aren't so abandon the teleport.
                CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
                return
            end
        end

        -- Check the helping player's force is the same as start of pathing request.
        if helpPlayer.force ~= pathRequest.helpPlayerForce then
            if not pathRequest.sameTeamOnly or (pathRequest.sameTeamOnly and helpPlayer.force == pathRequest.targetPlayer.force) then
                -- Only try again if the force setting still allows it.
                CallForHelp.PlanTeleportHelpPlayer(helpPlayer, pathRequest.arrivalRadius, pathRequest.targetPlayer, pathRequest.targetPlayerPosition, pathRequest.surface, targetPlayerEntity, pathRequest.callForHelpId, pathRequest.attempt, pathRequest.sameSurfaceOnly, pathRequest.sameTeamOnly, pathRequest.suppressMessages)
            end
            CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
            return
        end

        -- Get the players current placement entity and vehicle facing.
        local currentPlayerPlacementEntity, currentPlayerPlacementEntity_isVehicle = PlayerTeleport.GetPlayerTeleportPlacementEntity(helpPlayer, nil)
        if currentPlayerPlacementEntity == nil then
            -- If the helper player doesn't have an entity then nothing further to do for this player.
            if not pathRequest.suppressMessages then game.print({ "message.muppet_streamer_call_for_help_teleport_action_failed", helpPlayer.name, LoggingUtils.PositionToString(pathRequest.position) }) end
            CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
            return
        end

        -- If a vehicle get its current nearest cardinal (4) direction to orientation.
        local currentPlayerPlacementEntity_vehicleDirectionFacing ---@type defines.direction|nil
        if currentPlayerPlacementEntity_isVehicle then
            currentPlayerPlacementEntity_vehicleDirectionFacing = DirectionUtils.OrientationToNearestCardinalDirection(currentPlayerPlacementEntity.orientation)
        end

        -- Check the helping player's character/vehicle is still as expected.
        if currentPlayerPlacementEntity ~= pathRequest.helpPlayerPlacementEntity then
            CallForHelp.PlanTeleportHelpPlayer(helpPlayer, pathRequest.arrivalRadius, pathRequest.targetPlayer, pathRequest.targetPlayerPosition, pathRequest.surface, targetPlayerEntity, pathRequest.callForHelpId, pathRequest.attempt, pathRequest.sameSurfaceOnly, pathRequest.sameTeamOnly, pathRequest.suppressMessages)
            CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
            return
        end

        -- Check the target location hasn't been blocked since we made the path request. This also checks the entity can be placed with its current orientation rounded to a direction, so if its changed from when the pathfinder request was made it will either be confirmed as being fine or fail and be retried.
        if not pathRequest.surface.can_place_entity { name = currentPlayerPlacementEntity.name, position = pathRequest.position, direction = currentPlayerPlacementEntity_vehicleDirectionFacing, force = pathRequest.helpPlayerForce, build_check_type = defines.build_check_type.manual } then
            CallForHelp.PlanTeleportHelpPlayer(helpPlayer, pathRequest.arrivalRadius, pathRequest.targetPlayer, pathRequest.targetPlayerPosition, pathRequest.surface, targetPlayerEntity, pathRequest.callForHelpId, pathRequest.attempt, pathRequest.sameSurfaceOnly, pathRequest.sameTeamOnly, pathRequest.suppressMessages)
            CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
            return
        end
        if currentPlayerPlacementEntity_vehicleDirectionFacing ~= nil then
            -- Change the vehicles orientation to match the direction we checked. This will be a slight angle change, but the teleport should hide it.
            currentPlayerPlacementEntity.orientation = currentPlayerPlacementEntity_vehicleDirectionFacing / 8 --[[@as RealOrientation]]
        end

        -- Everything is as expected still, so teleport can commence.
        local teleportSucceeded = PlayerTeleport.TeleportToSpecificPosition(helpPlayer, pathRequest.surface, pathRequest.position)

        -- If the teleport of the player's entity/vehicle to the specific position failed then nothing further to do for this player.
        if not teleportSucceeded then
            CommandsUtils.LogPrintWarning(CommandName, nil, "Teleport action for player " .. helpPlayer.name .. " to position " .. LoggingUtils.PositionToString(pathRequest.position) .. " failed (Factorio request rejected)", nil)
            CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
            return
        end
    end

    -- If there's no pending path requests left then this call for help is completed.
    CallForHelp.CheckIfCallForHelpCompleted(pathRequest)
end

--- If there's no pending path requests left then this call for help is completed.
---@param pathRequest CallForHelp_PathRequestObject
CallForHelp.CheckIfCallForHelpCompleted = function(pathRequest)
    if next(global.callForHelp.callForHelpIds[pathRequest.callForHelpId].pendingPathRequests) == nil then
        if not pathRequest.suppressMessages then game.print({ "message.muppet_streamer_call_for_help_stop", pathRequest.targetPlayer.name }) end
        global.callForHelp.callForHelpIds[pathRequest.callForHelpId] = nil
    end
end

--- Gets the target players current entity or nil if they aren't valid to be helped.
---@param targetPlayer LuaPlayer
---@param suppressMessages boolean
---@return LuaEntity|nil targetPlayerEntity
---@return boolean isVehicle
CallForHelp.GetTargetPlayersEntity = function(targetPlayer, suppressMessages)
    local targetPlayer_vehicle = targetPlayer.vehicle
    local targetPlayerEntity = targetPlayer_vehicle or targetPlayer.character
    if targetPlayerEntity == nil then
        -- Being in a character controller without a character is possible and Space Exploration may do it...
        if not suppressMessages then game.print({ "message.muppet_streamer_call_for_help_no_character", targetPlayer.name }) end
        return nil, false
    end
    return targetPlayerEntity, targetPlayer_vehicle ~= nil
end

return CallForHelp
