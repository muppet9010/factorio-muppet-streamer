local LeakyFlamethrower = {}
local Commands = require("utility.commands")
local Logging = require("utility.logging")
local EventScheduler = require("utility.event-scheduler")
local Events = require("utility.events")
local PlayerWeapon = require("utility.functions.player-weapon")
local PositionUtils = require("utility.position-utils")
local Common = require("scripts.common")

---@class LeakyFlamethrower_EffectEndStatus
---@class LeakyFlamethrower_EffectEndStatus.__index
local EffectEndStatus = {
    completed = ("completed") --[[@as LeakyFlamethrower_EffectEndStatus]],
    died = ("died") --[[@as LeakyFlamethrower_EffectEndStatus]],
    invalid = ("invalid") --[[@as LeakyFlamethrower_EffectEndStatus]]
}

---@class LeakyFlamethrower_ScheduledEventDetails
---@field target string @ Target player's name.
---@field ammoCount uint

---@class LeakyFlamethrower_ShootFlamethrowerDetails
---@field player LuaPlayer
---@field player_index uint
---@field angle double
---@field distance double
---@field currentBurstTicks int
---@field burstsDone uint
---@field maxBursts uint
---@field usedSomeAmmo boolean @ If the player has actually used some of their ammo, otherwise the player's weapons are still on cooldown.
---@field startingAmmoItemstacksCount int @ How many itemstacks of ammo the player had when we start trying to fire the weapon.
---@field startingAmmoItemstackAmmo int @ The "ammo" property of the ammo itemstack the player had when we start trying to fire the weapon.

---@class LeakyFlamethrower_AffectedPlayersDetails
---@field flamethrowerGiven boolean @ If a flamethrower weapon had to be given to the player or if they already had one.
---@field burstsLeft uint
---@field removedWeaponDetails UtilityPlayerWeapon_RemovedWeaponToEnsureWeapon

LeakyFlamethrower.CreateGlobals = function()
    global.leakyFlamethrower = global.leakyFlamethrower or {}
    global.leakyFlamethrower.affectedPlayers = global.leakyFlamethrower.affectedPlayers or {} ---@type table<uint, LeakyFlamethrower_AffectedPlayersDetails> @ Key'd by player_index.
    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId or 0
end

LeakyFlamethrower.OnLoad = function()
    Commands.Register("muppet_streamer_leaky_flamethrower", {"api-description.muppet_streamer_leaky_flamethrower"}, LeakyFlamethrower.LeakyFlamethrowerCommand, true)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ShootFlamethrower", LeakyFlamethrower.ShootFlamethrower)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "LeakyFlamethrower.OnPrePlayerDied", LeakyFlamethrower.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("LeakyFlamethrower.ApplyToPlayer", LeakyFlamethrower.ApplyToPlayer)
end

LeakyFlamethrower.OnStartup = function()
    local group = game.permissions.get_group("LeakyFlamethrower") or game.permissions.create_group("LeakyFlamethrower")
    group.set_allows_action(defines.input_action.select_next_valid_gun, false)
    group.set_allows_action(defines.input_action.toggle_driving, false)
    group.set_allows_action(defines.input_action.change_shooting_state, false)
end

---@param command CustomCommandData
LeakyFlamethrower.LeakyFlamethrowerCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_leaky_flamethrower command "
    local commandName = "muppet_streamer_leaky_flamethrower"
    local commandData
    if command.parameter ~= nil then
        commandData = game.json_to_table(command.parameter)
    end
    if commandData == nil or type(commandData) ~= "table" then
        Logging.LogPrint(errorMessageStart .. "requires details in JSON format.")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local delaySecondsRaw = commandData.delay ---@type any
    if not Commands.ParseNumberArgument(delaySecondsRaw, "double", false, commandName, "delay", 0, nil, command.parameter) then
        return
    end
    ---@cast delaySecondsRaw uint
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySecondsRaw, command.tick, commandName, "delay")

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

    local ammoCount = tonumber(commandData.ammoCount)
    if ammoCount == nil then
        Logging.LogPrint(errorMessageStart .. "ammoCount is mandatory as a number")
        Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    else
        ammoCount = math.ceil(ammoCount)
    end
    if ammoCount <= 0 then
        return
    end

    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId + 1
    EventScheduler.ScheduleEventOnce(scheduleTick, "LeakyFlamethrower.ApplyToPlayer", global.leakyFlamethrower.nextId, {target = target, ammoCount = ammoCount})
end

LeakyFlamethrower.ApplyToPlayer = function(eventData)
    local errorMessageStart = "ERROR: muppet_streamer_leaky_flamethrower command "
    local data = eventData.data ---@type LeakyFlamethrower_ScheduledEventDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(errorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({"message.muppet_streamer_leaky_flamethrower_not_character_controller", data.target})
        return
    end
    local targetPlayer_index = targetPlayer.index

    if global.leakyFlamethrower.affectedPlayers[targetPlayer_index] ~= nil then
        return
    end

    targetPlayer.driving = false
    local flamethrowerGiven, removedWeaponDetails = PlayerWeapon.EnsureHasWeapon(targetPlayer, "flamethrower", true, true)
    if flamethrowerGiven == nil then
        Logging.LogPrint(errorMessageStart .. "target player can't be given a flamethrower for some odd reason: " .. data.target)
        return
    end
    -- CODE NOTE: removedWeaponDetails is always populated in our use case as we are forcing the weapon to be equiped (not allowing it to go in to the player's inventory).
    ---@cast removedWeaponDetails - nil

    targetPlayer.get_inventory(defines.inventory.character_ammo).insert({name = "flamethrower-ammo", count = data.ammoCount})

    -- Get the starting ammo item and ammo counts.
    local selectedAmmoInventory = targetPlayer.get_inventory(defines.inventory.character_ammo)[removedWeaponDetails.gunInventoryIndex]
    local startingAmmoItemstacksCount, startingAmmoItemstackAmmo = selectedAmmoInventory.count, selectedAmmoInventory.ammo

    -- Store the players current permission group. Left as the previously stored group if an effect was already being applied to the player, or captured if no present effect affects them.
    global.origionalPlayersPermissionGroup[targetPlayer_index] = global.origionalPlayersPermissionGroup[targetPlayer_index] or targetPlayer.permission_group

    targetPlayer.permission_group = game.permissions.get_group("LeakyFlamethrower")
    global.leakyFlamethrower.affectedPlayers[targetPlayer_index] = {flamethrowerGiven = flamethrowerGiven, burstsLeft = data.ammoCount, removedWeaponDetails = removedWeaponDetails}

    local startingAngle = math.random(0, 360)
    local startingDistance = math.random(2, 10)
    game.print({"message.muppet_streamer_leaky_flamethrower_start", targetPlayer.name})
    LeakyFlamethrower.ShootFlamethrower({tick = eventData.tick, instanceId = targetPlayer_index, data = {player = targetPlayer, angle = startingAngle, distance = startingDistance, currentBurstTicks = 0, burstsDone = 0, maxBursts = data.ammoCount, player_index = targetPlayer_index, usedSomeAmmo = false, startingAmmoItemstacksCount = startingAmmoItemstacksCount, startingAmmoItemstackAmmo = startingAmmoItemstackAmmo}})
end

LeakyFlamethrower.ShootFlamethrower = function(eventData)
    ---@typelist LeakyFlamethrower_ShootFlamethrowerDetails, LuaPlayer, uint
    local data, player, playerIndex = eventData.data, eventData.data.player, eventData.data.player_index
    if (not player.valid) or player.character == nil or (not player.character.valid) or player.vehicle ~= nil then
        LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    local selectedGunIndex = player.character.selected_gun_index
    local selectedGunInventory = player.get_inventory(defines.inventory.character_guns)[selectedGunIndex]
    if selectedGunInventory == nil or (not selectedGunInventory.valid_for_read) or selectedGunInventory.name ~= "flamethrower" then
        -- Flamethrower has been removed as active weapon by some script.
        LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    local selectedAmmoInventory = player.get_inventory(defines.inventory.character_ammo)[selectedGunIndex]
    if selectedAmmoInventory == nil or (not selectedAmmoInventory.valid_for_read) or selectedAmmoInventory.name ~= "flamethrower-ammo" then
        -- Ammo has been removed by some script. As we wouldn't have reached this point in a managed loop as its beyond the last burst.
        LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- When first trying to fire the weapon detect when we sucesfully expend some ammo. As an existing wepaon cooldown at effect start will delay us starting to shoot the flamethrower. Leading to the player being left with a tiny bit of ammo at the end.
    -- This will accept a scripted removal of ammo as being equivilent to the ammo started being fired, but this should be fine and we can't tell the difference, so meh.
    -- CODE NOTE: No way to read or set a player's gun cooldown, so this monitoring is the best option I can think of.
    if not data.usedSomeAmmo then
        local currentAmmoItemstacksCount, currentAmmoItemstackAmmo = selectedAmmoInventory.count, selectedAmmoInventory.ammo
        if currentAmmoItemstacksCount < data.startingAmmoItemstacksCount then
            -- Players shot some ammo and its finished an item off, so ignore the ammo property and assume all is good.
            data.usedSomeAmmo = true
        elseif currentAmmoItemstacksCount == data.startingAmmoItemstacksCount then
            if currentAmmoItemstackAmmo < data.startingAmmoItemstackAmmo then
                -- Players shot some of the ammo property on the current itemstack count, so assume all is good.
                data.usedSomeAmmo = true
            elseif currentAmmoItemstackAmmo == data.startingAmmoItemstackAmmo then
                -- Nothings changed so continue to monitor.
                data.currentBurstTicks = data.currentBurstTicks - 1 -- Take one off as nothing's relaly started yet.
            else
                -- Ammo prototype has increased, so players picked up ammo. So update counts and we will continue monitoring next tick from these new values.
                data.startingAmmoItemstacksCount = currentAmmoItemstacksCount
                data.startingAmmoItemstackAmmo = currentAmmoItemstackAmmo
            end
        else
            -- Ammo stacks has increased, son players picked up ammo. So update counts and we will continue monitoring next tick from these new values.
            data.startingAmmoItemstacksCount = currentAmmoItemstacksCount
            data.startingAmmoItemstackAmmo = currentAmmoItemstackAmmo
        end
    end

    local delay  ---@type uint
    data.currentBurstTicks = data.currentBurstTicks + 1
    -- Do the action for this tick.
    if data.currentBurstTicks > 100 then
        -- End of shooting ticks. Ready for next shooting and take break.
        data.currentBurstTicks = 0
        data.burstsDone = data.burstsDone + 1 --[[@as uint]]
        global.leakyFlamethrower.affectedPlayers[playerIndex].burstsLeft = global.leakyFlamethrower.affectedPlayers[playerIndex].burstsLeft - 1 --[[@as uint]]
        player.shooting_state = {state = defines.shooting.not_shooting}
        if data.burstsDone == data.maxBursts then
            LeakyFlamethrower.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
            return
        end
        data.angle = math.random(0, 360)
        data.distance = math.random(2, 10)
        delay = 180
    else
        -- Shoot this tick as a small random wonder from last ticks target.
        data.distance = math.min(math.max(data.distance + ((math.random() * 2) - 1), 2), 10)
        data.angle = data.angle + (math.random(-10, 10))
        local targetPos = PositionUtils.GetPositionForAngledDistance(player.position, data.distance, data.angle)
        player.shooting_state = {state = defines.shooting.shooting_selected, position = targetPos}
        delay = 0
    end

    EventScheduler.ScheduleEventOnce(eventData.tick + delay --[[@as uint]], "LeakyFlamethrower.ShootFlamethrower", playerIndex, data)
end

--- Called when a player has died, but before thier character is turned in to a corpse.
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

    player = player or game.get_player(playerIndex)
    local playerHasCharacter = player ~= nil and player.valid and player.character ~= nil and player.character.valid

    -- Take back any weapon and ammo from a player with a character (alive or just dead).
    if playerHasCharacter then
        if affectedPlayer.flamethrowerGiven then
            LeakyFlamethrower.TakeItemFromPlayerOrGround(player, "flamethrower", 1)
        end
        if affectedPlayer.burstsLeft > 0 then
            LeakyFlamethrower.TakeItemFromPlayerOrGround(player, "flamethrower-ammo", affectedPlayer.burstsLeft)
        end
    end

    -- Return the player's weapon and ammo filters (alive or just dead) if there were any.
    -- TODO: the returning of these details should be moved to the library function as the opposite to the ensuring player has weapon.
    ---@typelist LuaInventory, LuaInventory, LuaInventory
    local playerGunInventory, playerAmmoInventory, playerCharacterInventory = nil, nil, nil
    local removedWeaponDetails = affectedPlayer.removedWeaponDetails
    if removedWeaponDetails.weaponFilterName ~= nil then
        playerGunInventory = playerGunInventory or player.get_inventory(defines.inventory.character_guns)
        playerGunInventory.set_filter(removedWeaponDetails.gunInventoryIndex, removedWeaponDetails.weaponFilterName)
    end
    if removedWeaponDetails.ammoFilterName ~= nil then
        playerAmmoInventory = playerAmmoInventory or player.get_inventory(defines.inventory.character_ammo)
        playerAmmoInventory.set_filter(removedWeaponDetails.gunInventoryIndex, removedWeaponDetails.ammoFilterName)
    end

    -- Return the player's weapon and/or ammo if one was removed for the flamer and the player has a character (alive or just dead).
    if playerHasCharacter then
        -- If a weapon was removed from the slot, so assuming the player still has it in their inventory return it to the weapon slot.
        if removedWeaponDetails.weaponItemName ~= nil then
            playerCharacterInventory = playerCharacterInventory or player.get_main_inventory()
            playerGunInventory = playerGunInventory or player.get_inventory(defines.inventory.character_guns)
            if playerCharacterInventory.get_item_count(removedWeaponDetails.weaponItemName) >= 1 then
                playerCharacterInventory.remove({name = removedWeaponDetails.weaponItemName, count = 1})
                playerGunInventory[removedWeaponDetails.gunInventoryIndex].set_stack({name = removedWeaponDetails.weaponItemName, count = 1})
            end
        end

        -- If an ammo item was removed from the slot, so assuming the player still has it in their inventory return it to the ammo slot.
        if removedWeaponDetails.ammoItemName ~= nil then
            playerCharacterInventory = playerCharacterInventory or player.get_main_inventory()
            playerAmmoInventory = playerAmmoInventory or player.get_inventory(defines.inventory.character_ammo)
            local ammoItemStackToReturn = playerCharacterInventory.find_item_stack(removedWeaponDetails.ammoItemName)
            if ammoItemStackToReturn ~= nil then
                playerAmmoInventory[removedWeaponDetails.gunInventoryIndex].swap_stack(ammoItemStackToReturn)
            end
        end

        -- Restore the player's active weapon back to what it was before. To handle scenarios like we removed a nuke (non active) for the flamer and thne leave them with this.
        player.character.selected_gun_index = removedWeaponDetails.beforeSelectedWeaponGunIndex
    end

    -- Return the player to their initial permission group.
    if player.permission_group.name == "LeakyFlamethrower" then
        -- If the permission group has been changed by something else don't set it back to the last non modded one.
        player.permission_group = global.origionalPlayersPermissionGroup[playerIndex]
        global.origionalPlayersPermissionGroup[playerIndex] = nil
    end

    -- Remove any shooting state set and maintained from previous ticks.
    player.shooting_state = {state = defines.shooting.not_shooting}

    -- Remove the flag aginst this player as being currently affected by the leaky flamethrower.
    global.leakyFlamethrower.affectedPlayers[playerIndex] = nil

    -- Print a message based on ending status.
    if status == EffectEndStatus.completed then
        game.print({"message.muppet_streamer_leaky_flamethrower_stop", player.name})
    end
end

LeakyFlamethrower.TakeItemFromPlayerOrGround = function(player, itemName, itemCount)
    local removed = 0
    removed = removed + player.remove_item({name = itemName, count = itemCount})
    if itemCount == 0 then
        return removed
    end

    local itemsOnGround = player.surface.find_entities_filtered {position = player.position, radius = 10, name = "item-on-ground"}
    for _, itemOnGround in pairs(itemsOnGround) do
        if itemOnGround.valid and itemOnGround.stack ~= nil and itemOnGround.stack.valid and itemOnGround.stack.name == itemName then
            itemOnGround.destroy()
            removed = removed + 1
            itemCount = itemCount - 1
            if itemCount == 0 then
                break
            end
        end
    end
    return removed
end

return LeakyFlamethrower
