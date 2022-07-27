--[[
    Library to support using player alerts that handles all of the complicated edge cases for applying alerts to forces.
    Force alerts apply to all players currently on the force and the library automatically handles new players joining a force, players changing forces and forces being merged.
    This library is used by calling the RegisterPlayerAlerts() function once in root of control.lua. With the public functions then being called as required to add and remove alerts.
--]]
--

local PlayerAlerts = {} ---@class Utility_PlayerAlerts
local Events = require("utility.manager-libraries.events")

---@class UtilityPlayerAlerts_ForceAlertObject @ The cached details of an alert applied to all players on a force. Used to track the alerts and remove them, but also to allow adding/removing from players as they join/leave a force.
---@field id UtilityPlayerAlerts_AlertId @ Id of the alert object.
---@field force LuaForce @ The force that this alert applies to.
---@field alertEntity LuaEntity @ The entity the alert targets.
---@field alertPrototypeName string
---@field alertPosition MapPosition
---@field alertSurface LuaSurface
---@field alertSignalId SignalID
---@field alertMessage LocalisedString
---@field showOnMap boolean

---@alias UtilityPlayerAlerts_AlertId uint|string

--------------------------------------------------------------------------------------------
--                                    Setup Functions
--------------------------------------------------------------------------------------------

--- Called from the root of Control.lua
---
--- Only needs to be called once by the mod.
PlayerAlerts.RegisterPlayerAlerts = function()
    Events.RegisterHandlerEvent(defines.events.on_player_joined_game, "PlayerAlerts._OnPlayerJoinedGame", PlayerAlerts._OnPlayerJoinedGame)
    Events.RegisterHandlerEvent(defines.events.on_player_changed_force, "PlayerAlerts._OnPlayerChangedForce", PlayerAlerts._OnPlayerChangedForce)
    Events.RegisterHandlerEvent(defines.events.on_forces_merging, "PlayerAlerts._OnForcesMerging", PlayerAlerts._OnForcesMerging)
end

--------------------------------------------------------------------------------------------
--                                    Public Functions
--------------------------------------------------------------------------------------------

--- Add a custom alert to all players on the specific force.
---@param force LuaForce
---@param alertId? UtilityPlayerAlerts_AlertId|nil @ A globally unique Id that we will use to track duplicate requests for the same alert. If nil is provided a sequential number shall be affixed to "auto" as the Id.
---@param alertEntity LuaEntity
---@param alertSignalId SignalID
---@param alertMessage LocalisedString
---@param showOnMap boolean
---@return UtilityPlayerAlerts_AlertId alertId @ The Id of the created alert.
---@deprecated An alert only lasts for 5-10 (?) seconds and then auto finishes. We need to have an option for a continuous alert that auto adds a new one just before the hard coded timer runs out.
PlayerAlerts.AddCustomAlertToForce = function(force, alertId, alertEntity, alertSignalId, alertMessage, showOnMap)
    local forceId = force.index
    local forceAlerts = PlayerAlerts._GetCreateForceAlertsGlobalObject(forceId)

    -- Get an alertId if one not provided
    if alertId == nil then
        alertId = "auto_" .. global.UTILITYPLAYERALERTS.forceAlertsNextAutoId
        global.UTILITYPLAYERALERTS.forceAlertsNextAutoId = global.UTILITYPLAYERALERTS.forceAlertsNextAutoId + 1
    end

    -- Can't have duplicate alertId's across forces as if we ever need to merge forces it would break.
    if global.UTILITYPLAYERALERTS.forceAlertsByAlert[alertId] ~= nil then
        error("duplicate force alert Id added: " .. alertId)
    end

    --- Apply the alert to the players currently on the force and create the global object to track the alert in the future.
    for _, player in pairs(force.players) do
        player.add_custom_alert(alertEntity, alertSignalId, alertMessage, showOnMap)
    end
    ---@type UtilityPlayerAlerts_ForceAlertObject
    local newForceAlert = {
        id = alertId,
        force = force,
        alertEntity = alertEntity,
        alertPrototypeName = alertEntity.name,
        alertPosition = alertEntity.position,
        alertSurface = alertEntity.surface,
        alertSignalId = alertSignalId,
        alertMessage = alertMessage,
        showOnMap = showOnMap
    }
    forceAlerts[alertId] = newForceAlert
    global.UTILITYPLAYERALERTS.forceAlertsByAlert[alertId] = newForceAlert

    return alertId
end

--- Remove a custom alert from all players on the force and delete it from the force's alert global table.
---@param force LuaForce
---@param alertId UtilityPlayerAlerts_AlertId @ The unique Id of the alert.
PlayerAlerts.RemoveCustomAlertFromForce = function(force, alertId)
    local forceIndex = force.index

    -- Get the alert if it exists.
    local forceAlert = PlayerAlerts._GetForceAlert(alertId)
    if forceAlert == nil then
        return
    end

    -- Remove the alert from all players.
    for _, player in pairs(force.players) do
        -- When the alerting entity becomes invalid the player alert will automatically vanish after a few seconds. So we can just skip removing it and just tidy up the state data as usual. Also no way to filter to just our alert without the entity being valid.
        if player.valid then
            PlayerAlerts._RemoveAlertFromPlayer(forceAlert, player)
        end
    end

    -- Remove the alert from the force's global object.
    global.UTILITYPLAYERALERTS.forceAlertsByForce[forceIndex][alertId] = nil
    global.UTILITYPLAYERALERTS.forceAlertsByAlert[alertId] = nil
end

--- Removes ALL custom alerts this mod created from this force.
---@param force LuaForce
PlayerAlerts.RemoveAllCustomAlertsFromForce = function(force)
    local forceAlerts = PlayerAlerts._GetForceAlerts(force.index)
    if forceAlerts == nil then
        return
    end
    for _, forceAlert in pairs(forceAlerts) do
        PlayerAlerts.RemoveCustomAlertFromForce(force, forceAlert.id)
    end
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Remove the actual alert from a player. Handles if the entity is valid or invalid.
---@param forceAlert UtilityPlayerAlerts_ForceAlertObject
---@param player LuaPlayer
PlayerAlerts._RemoveAlertFromPlayer = function(forceAlert, player)
    if forceAlert.alertEntity.valid then
        player.remove_alert {
            entity = forceAlert.alertEntity,
            type = defines.alert_type.custom,
            icon = forceAlert.alertSignalId,
            message = forceAlert.alertMessage
        }
    else
        player.remove_alert {
            prototype = forceAlert.alertPrototypeName --[[@as LuaEntityPrototype]], -- Force typed work around for bug: https://forums.factorio.com/viewtopic.php?f=7&t=102860 -- TODO: this should be the prototype not the name now as per 1.1.62. Need to test before just doing it thought.
            position = forceAlert.alertPosition,
            surface = forceAlert.alertSurface,
            type = defines.alert_type.custom,
            icon = forceAlert.alertSignalId,
            message = forceAlert.alertMessage
        }
    end
end

--- Creates (if needed) and returns a force's alerts Factorio global table.
---@param forceIndex uint @ the index of the LuaForce.
---@return table<UtilityPlayerAlerts_AlertId, UtilityPlayerAlerts_ForceAlertObject> forceAlerts
PlayerAlerts._GetCreateForceAlertsGlobalObject = function(forceIndex)
    if global.UTILITYPLAYERALERTS == nil then
        global.UTILITYPLAYERALERTS = {}
    end

    if global.UTILITYPLAYERALERTS.forceAlertsByForce == nil then
        global.UTILITYPLAYERALERTS.forceAlertsByForce = {} ---@type table<uint, table<UtilityPlayerAlerts_AlertId, UtilityPlayerAlerts_ForceAlertObject>>
    end
    local forceAlerts = global.UTILITYPLAYERALERTS.forceAlertsByForce[forceIndex]
    if forceAlerts == nil then
        global.UTILITYPLAYERALERTS.forceAlertsByForce[forceIndex] = global.UTILITYPLAYERALERTS.forceAlertsByForce[forceIndex] or {}
        forceAlerts = global.UTILITYPLAYERALERTS.forceAlertsByForce[forceIndex]
    end

    if global.UTILITYPLAYERALERTS.forceAlertsNextAutoId == nil then
        global.UTILITYPLAYERALERTS.forceAlertsNextAutoId = 1
    end

    if global.UTILITYPLAYERALERTS.forceAlertsByAlert == nil then
        global.UTILITYPLAYERALERTS.forceAlertsByAlert = {} ---@type table<UtilityPlayerAlerts_AlertId, UtilityPlayerAlerts_ForceAlertObject>
    end

    return forceAlerts
end

--- Returns a force's alerts Factorio global table if it exists.
---@param forceIndex uint @ the index of the LuaForce.
---@return table<uint, UtilityPlayerAlerts_ForceAlertObject>|nil forceAlerts @ nil if no alerts for this force.
PlayerAlerts._GetForceAlerts = function(forceIndex)
    if global.UTILITYPLAYERALERTS == nil or global.UTILITYPLAYERALERTS.forceAlertsByForce == nil then
        return nil
    else
        return global.UTILITYPLAYERALERTS.forceAlertsByForce[forceIndex]
    end
end

--- Returns a force's specific alert from the Factorio global table if it exists.
---@param alertId UtilityPlayerAlerts_AlertId
---@return UtilityPlayerAlerts_ForceAlertObject|nil forceAlert
PlayerAlerts._GetForceAlert = function(alertId)
    if global.UTILITYPLAYERALERTS == nil or global.UTILITYPLAYERALERTS.forceAlertsByAlert == nil then
        return nil
    else
        return global.UTILITYPLAYERALERTS.forceAlertsByAlert[alertId]
    end
end

--- Called when a player joins a game.
---@param event on_player_joined_game
PlayerAlerts._OnPlayerJoinedGame = function(event)
    local player = game.get_player(event.player_index)
    if player == nil then
        -- Player was deleted upon joining, so just ignore.
        return
    end

    -- Get the alerts for this player's force if there are any.
    local forceAlerts = PlayerAlerts._GetForceAlerts(player.force.index)
    if forceAlerts == nil then
        return
    end

    -- Apply the alerts to the player.
    for _, forceAlert in pairs(forceAlerts) do
        player.add_custom_alert(forceAlert.alertEntity, forceAlert.alertSignalId, forceAlert.alertMessage, forceAlert.showOnMap)
    end
end

--- Called when a player changes forces either individually or when 2 forces are merged and this is called once for every player in the old force.
---@param event on_player_changed_force
PlayerAlerts._OnPlayerChangedForce = function(event)
    local player = game.get_player(event.player_index)
    if player == nil then
        -- Player was deleted upon changing force, so just ignore.
        return
    end
    local newForce, oldForce = player.force, event.force

    -- Get the alerts for this player's old force and if there are any remove them from the player.
    local oldForceAlerts = PlayerAlerts._GetForceAlerts(oldForce.index)
    if oldForceAlerts ~= nil then
        for _, oldForceAlert in pairs(oldForceAlerts) do
            PlayerAlerts._RemoveAlertFromPlayer(oldForceAlert, player)
        end
    end

    -- If there are alerts for the new force apply the alerts to the player.
    local newForceAlerts = PlayerAlerts._GetForceAlerts(newForce.index)
    if newForceAlerts ~= nil then
        for _, newForceAlert in pairs(newForceAlerts) do
            player.add_custom_alert(newForceAlert.alertEntity, newForceAlert.alertSignalId, newForceAlert.alertMessage, newForceAlert.showOnMap)
        end
    end
end

--- Called when 2 forces are merging together. Is triggered before each player on the old force has PlayerAlerts._OnPlayerChangedForce() triggered.
---@param event on_forces_merging
PlayerAlerts._OnForcesMerging = function(event)
    local removedForce_index, mergedForce, mergedForce_index = event.source.index, event.destination, event.destination.index

    -- If there were alerts on the old force handle them.
    local removedForceAlerts = PlayerAlerts._GetForceAlerts(removedForce_index)
    if removedForceAlerts ~= nil then
        local mergedForceAlerts = PlayerAlerts._GetCreateForceAlertsGlobalObject(mergedForce_index)
        local mergedForcePlayers = mergedForce.players

        -- Handle each alert to be moved.
        for removedForceAlertId, removedForceAlert in pairs(removedForceAlerts) do
            -- Move across the alerts from the removed force to the merged force.
            removedForceAlert.force = mergedForce
            mergedForceAlerts[removedForceAlertId] = removedForceAlert

            -- Add any moved across alerts on the merged force's current players only. The removed force's players will be updated by PlayerAlerts._OnPlayerChangedForce() automatically.
            for _, player in pairs(mergedForcePlayers) do
                player.add_custom_alert(removedForceAlert.alertEntity, removedForceAlert.alertSignalId, removedForceAlert.alertMessage, removedForceAlert.showOnMap)
            end
        end

        -- Remove the old global for the force. The alert globals can remain unchanged.
        global.UTILITYPLAYERALERTS.forceAlertsByForce[removedForce_index] = nil
    end
end

return PlayerAlerts
