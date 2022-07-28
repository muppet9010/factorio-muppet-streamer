local LeakyFlamethrower = {} ---@class LeakyFlamethrower
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Events = require("utility.manager-libraries.events")
local PlayerWeapon = require("utility.functions.player-weapon")
local PositionUtils = require("utility.helper-utils.position-utils")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@enum LeakyFlamethrower_EffectEndStatus
local EffectEndStatus = {
    completed = "completed",
    died = "died",
    invalid = "invalid"
}

---@class LeakyFlamethrower_ScheduledEventDetails
---@field target string @ Target player's name.
---@field ammoCount uint

---@class LeakyFlamethrower_ShootFlamethrowerDetails
---@field player LuaPlayer
---@field player_index uint
---@field angle double
---@field distance double
---@field currentBurstTicks uint
---@field burstsDone uint
---@field maxBursts uint
---@field usedSomeAmmo boolean @ If the player has actually used some of their ammo, otherwise the player's weapons are still on cooldown.
---@field startingAmmoItemStacksCount uint @ How many item stacks of ammo the player had when we start trying to fire the weapon.
---@field startingAmmoItemStackAmmo uint @ The "ammo" property of the ammo item stack the player had when we start trying to fire the weapon.

---@class LeakyFlamethrower_AffectedPlayersDetails
---@field flamethrowerGiven boolean @ If a flamethrower weapon had to be given to the player or if they already had one.
---@field burstsLeft uint
---@field removedWeaponDetails UtilityPlayerWeapon_RemovedWeaponToEnsureWeapon

local commandName = "muppet_streamer_leaky_flamethrower"

LeakyFlamethrower.CreateGlobals = function()
    global.leakyFlamethrower = global.leakyFlamethrower or {}
    global.leakyFlamethrower.affectedPlayers = global.leakyFlamethrower.affectedPlayers or {} ---@type table<uint, LeakyFlamethrower_AffectedPlayersDetails> @ Key'd by player_index.
    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId or 0 ---@type uint
end

LeakyFlamethrower.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_leaky_flamethrower", { "api-description.muppet_streamer_leaky_flamethrower" }, LeakyFlamethrower.LeakyFlamethrowerCommand, true)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ShootFlamethrower", LeakyFlamethrower.ShootFlamethrower)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "LeakyFlamethrower.OnPrePlayerDied", LeakyFlamethrower.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ApplyToPlayer", LeakyFlamethrower.ApplyToPlayer)
    MOD.Interfaces.Commands.LeakyFlamethrower = LeakyFlamethrower.LeakyFlamethrowerCommand
end

LeakyFlamethrower.OnStartup = function()
    local group = game.permissions.get_group("LeakyFlamethrower") or game.permissions.create_group("LeakyFlamethrower") ---@cast group - nil @ Script always has permission to create groups.
    group.set_allows_action(defines.input_action.select_next_valid_gun, false)
    group.set_allows_action(defines.input_action.toggle_driving, false)
    group.set_allows_action(defines.input_action.change_shooting_state, false)
end

---@param command CustomCommandData
LeakyFlamethrower.LeakyFlamethrowerCommand = function(command)
    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "ammoCount" })
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

    local ammoCount = commandData.ammoCount
    if not CommandsUtils.CheckNumberArgument(ammoCount, "int", true, commandName, "ammoCount", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast ammoCount uint

    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId + 1 ---@type uint @ Needed for weird bug reason, maybe in Sumneko or maybe the plugin with its fake global.
    ---@type LeakyFlamethrower_ScheduledEventDetails
    local scheduledEventDetails = { target = target, ammoCount = ammoCount }
    EventScheduler.ScheduleEventOnce(scheduleTick, "LeakyFlamethrower.ApplyToPlayer", global.leakyFlamethrower.nextId, scheduledEventDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
LeakyFlamethrower.ApplyToPlayer = function(eventData)
    local data = eventData.data ---@type LeakyFlamethrower_ScheduledEventDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({ "message.muppet_streamer_leaky_flamethrower_not_character_controller", data.target })
        return
    end
    local targetPlayer_index = targetPlayer.index

    if global.leakyFlamethrower.affectedPlayers[targetPlayer_index] ~= nil then
        return
    end

    targetPlayer.driving = false
    local flamethrowerGiven, removedWeaponDetails = PlayerWeapon.EnsureHasWeapon(targetPlayer, "flamethrower", true, true, "flamethrower-ammo") ---@cast removedWeaponDetails - nil @ removedWeaponDetails is always populated in our use case as we are forcing the weapon to be equipped (not allowing it to go in to the player's inventory).

    if flamethrowerGiven == nil then
        CommandsUtils.LogPrintError(commandName, nil, "target player can't be given a flamethrower for some odd reason: " .. data.target, nil)
        return
    end

    -- Put the required ammo in the guns related ammo slot.
    local selectedAmmoItemStack = targetPlayer.get_inventory(defines.inventory.character_ammo)[removedWeaponDetails.gunInventoryIndex]
    if selectedAmmoItemStack.valid_for_read then
        -- There's a stack there and it will be flamethrower ammo from when we forced the weapon to the player.
        -- Just give the ammo to the player and it will auto assign it correctly.
        local inserted = targetPlayer.insert({ name = "flamethrower-ammo", count = data.ammoCount })
        if inserted < data.ammoCount then
            targetPlayer.surface.spill_item_stack(targetPlayer.position, { name = "flamethrower-ammo", count = data.ammoCount - inserted }, true, nil, false)
        end
    else
        -- No current ammo in the slot. So just set our required one.
        selectedAmmoItemStack.set_stack({ name = "flamethrower-ammo", count = data.ammoCount })
    end

    -- Check the player has the weapon equipped as expected. (same as checking logic as when it tries to fire the weapon).
    local selectedGunIndex = targetPlayer.character.selected_gun_index
    local selectedGunInventory = targetPlayer.get_inventory(defines.inventory.character_guns)[selectedGunIndex]
    if selectedGunInventory == nil or (not selectedGunInventory.valid_for_read) or selectedGunInventory.name ~= "flamethrower" then
        -- Flamethrower has been removed as active weapon by some script.
        CommandsUtils.LogPrintError(commandName, nil, "target player weapon state isn't right for some odd reason: " .. data.target, nil)
        return
    end
    -- Check the player has the weapon's ammo equipped as expected. (same as checking logic as when it tries to fire the weapon).
    local selectedAmmoInventory = targetPlayer.get_inventory(defines.inventory.character_ammo)[selectedGunIndex]
    if selectedAmmoInventory == nil or (not selectedAmmoInventory.valid_for_read) or selectedAmmoInventory.name ~= "flamethrower-ammo" then
        -- Ammo has been removed by some script. As we wouldn't have reached this point in a managed loop as its beyond the last burst.
        CommandsUtils.LogPrintError(commandName, nil, "target player ammo state isn't right for some odd reason: " .. data.target, nil)
        return
    end

    -- Get the starting ammo item and ammo counts. As they may already have had flamer ammo and we've added to it.
    local startingAmmoItemStacksCount, startingAmmoItemStackAmmo = selectedAmmoItemStack.count, selectedAmmoItemStack.ammo

    -- Store the players current permission group. Left as the previously stored group if an effect was already being applied to the player, or captured if no present effect affects them.
    global.originalPlayersPermissionGroup[targetPlayer_index] = global.originalPlayersPermissionGroup[targetPlayer_index] or targetPlayer.permission_group

    local group = game.permissions.get_group("LeakyFlamethrower") or game.permissions.create_group("LeakyFlamethrower") ---@cast group - nil @ Script always has permission to create groups.
    targetPlayer.permission_group = group
    global.leakyFlamethrower.affectedPlayers[targetPlayer_index] = { flamethrowerGiven = flamethrowerGiven, burstsLeft = data.ammoCount, removedWeaponDetails = removedWeaponDetails }

    local startingAngle = math.random(0, 360)
    local startingDistance = math.random(2, 10)
    game.print({ "message.muppet_streamer_leaky_flamethrower_start", targetPlayer.name })

    ---@type LeakyFlamethrower_ShootFlamethrowerDetails
    local shootFlamethrowerDetails = { player = targetPlayer, angle = startingAngle, distance = startingDistance, currentBurstTicks = 0, burstsDone = 0, maxBursts = data.ammoCount, player_index = targetPlayer_index, usedSomeAmmo = false, startingAmmoItemStacksCount = startingAmmoItemStacksCount, startingAmmoItemStackAmmo = startingAmmoItemStackAmmo }
    ---@type UtilityScheduledEvent_CallbackObject
    local shootFlamethrowerCallbackObject = { tick = eventData.tick, instanceId = targetPlayer_index, data = shootFlamethrowerDetails }
    LeakyFlamethrower.ShootFlamethrower(shootFlamethrowerCallbackObject)
end

---@param eventData UtilityScheduledEvent_CallbackObject
LeakyFlamethrower.ShootFlamethrower = function(eventData)
    local data = eventData.data ---@type LeakyFlamethrower_ShootFlamethrowerDetails
    local player, playerIndex = data.player, data.player_index
    if (not player.valid) or player.character == nil or (not player.character.valid) or player.vehicle ~= nil then
        LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- Check the player has the weapon equipped as expected.
    local selectedGunIndex = player.character.selected_gun_index
    local selectedGunInventory = player.get_inventory(defines.inventory.character_guns)[selectedGunIndex]
    if selectedGunInventory == nil or (not selectedGunInventory.valid_for_read) or selectedGunInventory.name ~= "flamethrower" then
        -- Flamethrower has been removed as active weapon by some script.
        LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- Check the player has the weapon's ammo equipped as expected.
    local selectedAmmoInventory = player.get_inventory(defines.inventory.character_ammo)[selectedGunIndex]
    if selectedAmmoInventory == nil or (not selectedAmmoInventory.valid_for_read) or selectedAmmoInventory.name ~= "flamethrower-ammo" then
        -- Ammo has been removed by some script. As we wouldn't have reached this point in a managed loop as its beyond the last burst.
        LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- When first trying to fire the weapon detect when we successfully expend some ammo. As an existing weapon cooldown at effect start will delay us starting to shoot the flamethrower. Leading to the player being left with a tiny bit of ammo at the end.
    -- This will accept a scripted removal of ammo as being equivalent to the ammo started being fired, but this should be fine and we can't tell the difference, so meh.
    -- CODE NOTE: No way to read or set a player's gun cooldown, so this monitoring is the best option I can think of.
    if not data.usedSomeAmmo then
        local currentAmmoItemStacksCount, currentAmmoItemStackAmmo = selectedAmmoInventory.count, selectedAmmoInventory.ammo
        if currentAmmoItemStacksCount < data.startingAmmoItemStacksCount then
            -- Players shot some ammo and its finished an item off, so ignore the ammo property and assume all is good.
            data.usedSomeAmmo = true
        elseif currentAmmoItemStacksCount == data.startingAmmoItemStacksCount then
            if currentAmmoItemStackAmmo < data.startingAmmoItemStackAmmo then
                -- Players shot some of the ammo property on the current item stack count, so assume all is good.
                data.usedSomeAmmo = true
            elseif currentAmmoItemStackAmmo == data.startingAmmoItemStackAmmo then
                -- Nothings changed so continue to monitor.
                data.currentBurstTicks = data.currentBurstTicks - 1 -- Take one off as nothing's really started yet.
            else
                -- Ammo prototype has increased, so players picked up ammo. So update counts and we will continue monitoring next tick from these new values.
                data.startingAmmoItemStacksCount = currentAmmoItemStacksCount
                data.startingAmmoItemStackAmmo = currentAmmoItemStackAmmo
            end
        else
            -- Ammo stacks has increased, son players picked up ammo. So update counts and we will continue monitoring next tick from these new values.
            data.startingAmmoItemStacksCount = currentAmmoItemStacksCount
            data.startingAmmoItemStackAmmo = currentAmmoItemStackAmmo
        end
    end

    local nextShootDelay ---@type uint
    data.currentBurstTicks = data.currentBurstTicks + 1
    -- Do the action for this tick.
    if data.currentBurstTicks > 100 then
        -- End of shooting ticks. Ready for next shooting and take break.
        data.currentBurstTicks = 0
        data.burstsDone = data.burstsDone + 1
        global.leakyFlamethrower.affectedPlayers[playerIndex].burstsLeft = global.leakyFlamethrower.affectedPlayers[playerIndex].burstsLeft - 1
        player.shooting_state = { state = defines.shooting.not_shooting }
        if data.burstsDone == data.maxBursts then
            LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
            return
        end
        data.angle = math.random(0, 360)
        data.distance = math.random(2, 10)
        nextShootDelay = 180
    else
        -- Shoot this tick as a small random wonder from last ticks target.
        data.distance = math.min(math.max(data.distance + ((math.random() * 2) - 1), 2), 10)
        data.angle = data.angle + (math.random(-10, 10))
        local targetPos = PositionUtils.GetPositionForAngledDistance(player.position, data.distance, data.angle)
        player.shooting_state = { state = defines.shooting.shooting_selected, position = targetPos }
        nextShootDelay = 1
    end

    EventScheduler.ScheduleEventOnce(eventData.tick + nextShootDelay, "LeakyFlamethrower.ShootFlamethrower", playerIndex, data)
end

--- Called when a player has died, but before their character is turned in to a corpse.
---@param event on_pre_player_died
LeakyFlamethrower.OnPrePlayerDied = function(event)
    LeakyFlamethrower.StopEffectOnPlayer(event.player_index, nil, EffectEndStatus.died)
end

--- Called when the effect has been stopped and the effects state and weapon changes should be undone.
--- Called when the player is alive or if they have died before their character has been affected.
---@param playerIndex uint
---@param player LuaPlayer|nil @ Obtained if needed and not provided.
---@param status LeakyFlamethrower_EffectEndStatus
LeakyFlamethrower.StopEffectOnPlayer = function(playerIndex, player, status)
    local affectedPlayer = global.leakyFlamethrower.affectedPlayers[playerIndex]
    if affectedPlayer == nil then
        return
    end

    -- Remove the flag against this player as being currently affected by the leaky flamethrower.
    global.leakyFlamethrower.affectedPlayers[playerIndex] = nil

    player = player or game.get_player(playerIndex)
    if player == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted while the effect was running.", nil)
        return
    end
    local playerHasCharacter = player ~= nil and player.character ~= nil

    -- Take back any weapon and ammo from a player with a character (alive or just dead).
    if playerHasCharacter then
        if affectedPlayer.flamethrowerGiven then
            PlayerWeapon.TakeItemFromPlayerOrGround(player, "flamethrower", 1)
        end
        if affectedPlayer.burstsLeft > 0 then
            PlayerWeapon.TakeItemFromPlayerOrGround(player, "flamethrower-ammo", affectedPlayer.burstsLeft)
        end
    end

    -- Return the player's weapon and ammo filters (alive or just dead) if there were any.
    PlayerWeapon.ReturnRemovedWeapon(player, affectedPlayer.removedWeaponDetails)

    -- Return the player to their initial permission group.
    if player.permission_group.name == "LeakyFlamethrower" then
        -- If the permission group has been changed by something else don't set it back to the last non modded one.
        player.permission_group = global.originalPlayersPermissionGroup[playerIndex]
        global.originalPlayersPermissionGroup[playerIndex] = nil
    end

    -- Remove any shooting state set and maintained from previous ticks.
    player.shooting_state = { state = defines.shooting.not_shooting }

    -- Print a message based on ending status.
    if status == EffectEndStatus.completed then
        game.print({ "message.muppet_streamer_leaky_flamethrower_stop", player.name })
    end
end

return LeakyFlamethrower
