local GiveItems = {}
local Interfaces = require("utility/interfaces")
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")

---@class GiveItems_GiveWeaponAmmoScheduled
---@field target string @ Target player's name.
---@field ammoType LuaItemPrototype
---@field ammoCount uint
---@field weaponType LuaItemPrototype
---@field forceWeaponToSlot boolean
---@field selectWeapon boolean

---@class GiveItems_RemovedWeaponToEnsureWeapon
---@field gunInventoryIndex uint @ The index in the gun and ammo inventory where the weapon was removed.
---@field weaponItemName string|null @ Nil if no weapon was in the slot.
---@field weaponFilterName string|null @ Nil if no weapon filter was set on the slot.
---@field ammoItemName string|null @ Nil if no ammo was in the slot.
---@field ammoFilterName string|null @ Nil if no ammo filter was set on the slot.
---@field beforeSelectedWeaponGunIndex uint @ The weapon slot that the player had selected before the weapon was removed.

GiveItems.CreateGlobals = function()
    global.giveItems = global.giveItems or {}
    global.giveItems.nextId = global.giveItems.nextId or 0
end

GiveItems.OnLoad = function()
    Interfaces.RegisterInterface("GiveItems.EnsureHasWeapon", GiveItems.EnsureHasWeapon)
    Commands.Register("muppet_streamer_give_player_weapon_ammo", {"api-description.muppet_streamer_give_player_weapon_ammo"}, GiveItems.GivePlayerWeaponAmmoCommand, true)
    EventScheduler.RegisterScheduledEventType("GiveItems.GiveWeaponAmmoScheduled", GiveItems.GiveWeaponAmmoScheduled)
end

--- Ensure the player has the specified weapon.
---@param player LuaPlayer
---@param weaponName string
---@param forceWeaponToWeaponInventorySlot boolean
---@param selectWeapon boolean
---@return boolean|nil weaponGiven @ If the weapon item had to be given to the player, compared to them already having it and it possibly just being mvoed between their inventories. Returns nil for invalid situations, i.e. called on a palyer with no gun inventory.
---@return GiveItems_RemovedWeaponToEnsureWeapon|nil removedWeaponDetails @ Details on the weapon that was removed to add the new wepaon. Is nil if no active weapon was set/found, i.e. weapon was found/put in to the players main inventory and not as an equiped weapon.
GiveItems.EnsureHasWeapon = function(player, weaponName, forceWeaponToWeaponInventorySlot, selectWeapon)
    if player == nil or not player.valid then
        return nil, nil
    end

    ---@type GiveItems_RemovedWeaponToEnsureWeapon
    local removedWeaponDetails = {
        beforeSelectedWeaponGunIndex = player.character.selected_gun_index
    }

    -- See if the gun is already equipped by the player in their active gun inventory, or find which of their weapon slots is best to assign too.
    local weaponGiven, weaponFoundIndex, freeGunIndex, freeButFilteredGunIndex = false, nil, nil, nil
    local gunInventory = player.get_inventory(defines.inventory.character_guns)
    if gunInventory == nil then
        return nil, nil
    end
    for i = 1, #gunInventory do
        local gunItemStack = gunInventory[i]
        if gunItemStack.valid_for_read then
            -- Weapon in this slot.
            if gunItemStack.name == weaponName then
                -- Player already has this gun equiped.
                weaponFoundIndex = i
                break
            end
        else
            -- No weapon in slot.
            local filteredName = gunInventory.get_filter(i)
            if filteredName == nil or filteredName == weaponName then
                -- Non filtered weapon slot or filtered to the weapon we want to assign.
                freeGunIndex = i
                break
            else
                -- Filtered weapon slot to a different weapon.
                freeButFilteredGunIndex = i
            end
        end
    end

    -- Handle if the player doesn't already have the gun equiped.
    if weaponFoundIndex == nil then
        local characterInventory = player.get_main_inventory()

        if freeGunIndex ~= nil then
            -- Player has a free slot, so we can just use it.
            weaponFoundIndex = freeGunIndex
        else
            -- Player doesn't have a free slot.
            if forceWeaponToWeaponInventorySlot then
                -- As forceWeaponToWeaponInventorySlot is true and as the player has full gun slots then a weapon (and ammo) slot is "cleared" so that our weapon can then be put there. We select the least inconvient weapon slot to clear.

                -- Get the best gun slot to clear out and use.
                if freeButFilteredGunIndex ~= nil then
                    -- The player has a gun slot with no weapon, but it is filtered. So use this for our gun.
                    weaponFoundIndex = freeButFilteredGunIndex
                else
                    -- The player only has gun slots with other weapons in them, so select one randomly for our gun.
                    weaponFoundIndex = math.random(1, #gunInventory)
                end

                -- Clear the gun slot ready for the weapon.
                local gunItemStack = gunInventory[weaponFoundIndex]
                if gunItemStack ~= nil and gunItemStack.valid_for_read then
                    local currentName, currentCount = gunItemStack.name, gunItemStack.count
                    local gunInsertedCount = player.insert({name = currentName, count = currentCount})
                    if gunInsertedCount < currentCount then
                        player.surface.spill_item_stack(player.position, {name = currentName, count = currentCount - gunInsertedCount}, true, nil, false)
                    end
                    removedWeaponDetails.weaponItemName = currentName
                end
                removedWeaponDetails.weaponFilterName = gunInventory.get_filter(weaponFoundIndex)
                gunInventory.set_filter(weaponFoundIndex, nil)
                gunItemStack.clear()
            else
                -- As we won't force the weapon it should go in to the characters inventory if they don't already have one.
                -- As we can't select the weapon the function is done after this.
                if characterInventory.get_item_count(weaponName) == 0 then
                    -- Player doesn't have this weapon in their inventory, so give them one.
                    characterInventory.insert({name = weaponName, count = 1})
                    return true, nil
                else
                    -- Player has the weapon in their inventory already.
                    return false, nil
                end
            end
        end

        -- Clear the ammo slot ready for the weapon and its possible ammo.
        local ammoInventory = player.get_inventory(defines.inventory.character_ammo)
        local ammoItemStack = ammoInventory[weaponFoundIndex]
        if ammoItemStack ~= nil and ammoItemStack.valid_for_read then
            local currentName, currentCount = ammoItemStack.name, ammoItemStack.count
            local ammoInsertedCount = player.insert({name = currentName, count = currentCount, ammo = ammoItemStack.ammo})
            if ammoInsertedCount < currentCount then
                player.surface.spill_item_stack(player.position, {name = currentName, count = currentCount - ammoInsertedCount}, true, nil, false)
            end
            removedWeaponDetails.ammoItemName = currentName
        end
        removedWeaponDetails.ammoFilterName = ammoInventory.get_filter(weaponFoundIndex)
        ammoInventory.set_filter(weaponFoundIndex, nil)
        ammoItemStack.clear()

        -- Remove 1 item of the weapon type from the players inventory if they had one, to simulate equiping the weapon. Otherwise we will flag this as giving the player a weapon.
        if characterInventory.get_item_count(weaponName) == 0 then
            -- No instacne of the weapon in the player's inventory.
            weaponGiven = true
        else
            -- Weapon in players inventory, so remove 1.
            characterInventory.remove({name = weaponName, count = 1})
        end

        -- Put the weapon in the player's actual gun slot.
        gunInventory[weaponFoundIndex].set_stack({name = weaponName, count = 1})
    end

    -- Set the players active weapon if this is desired.
    if selectWeapon and weaponFoundIndex ~= nil then
        player.character.selected_gun_index = weaponFoundIndex
    end

    -- Record the weapon index that was used in the end.
    removedWeaponDetails.gunInventoryIndex = weaponFoundIndex

    return weaponGiven, removedWeaponDetails
end

---@param command CustomCommandData
GiveItems.GivePlayerWeaponAmmoCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_give_player_weapon_ammo command "
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

    local weaponTypeString, weaponType = commandData.weaponType, nil
    if weaponTypeString ~= nil and weaponTypeString ~= "" then
        weaponType = game.item_prototypes[weaponTypeString]
        if weaponType == nil or weaponType.type ~= "gun" then
            Logging.LogPrint(errorMessageStart .. "optional weaponType provide, but isn't a valid type")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    local forceWeaponToSlot = false
    if commandData.forceWeaponToSlot ~= nil then
        forceWeaponToSlot = Utils.ToBoolean(commandData.forceWeaponToSlot)
        if forceWeaponToSlot == nil then
            Logging.LogPrint(errorMessageStart .. "optional forceWeaponToSlot provided, but isn't a boolean true/false")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    local selectWeapon = false
    if commandData.selectWeapon ~= nil then
        selectWeapon = Utils.ToBoolean(commandData.selectWeapon)
        if selectWeapon == nil then
            Logging.LogPrint(errorMessageStart .. "optional selectWeapon provided, but isn't a boolean true/false")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    local ammoTypeString, ammoType = commandData.ammoType, nil
    if ammoTypeString ~= nil and ammoTypeString ~= "" then
        ammoType = game.item_prototypes[ammoTypeString]
        if ammoType == nil or ammoType.type ~= "ammo" then
            Logging.LogPrint(errorMessageStart .. "optional ammoType provide, but isn't a valid type")
            Logging.LogPrint(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    local ammoCount = tonumber(commandData.ammoCount)
    if ammoCount == nil or ammoCount <= 0 then
        ammoType = nil
    end

    global.giveItems.nextId = global.giveItems.nextId + 1
    EventScheduler.ScheduleEvent(command.tick + delay, "GiveItems.GiveWeaponAmmoScheduled", global.giveItems.nextId, {target = target, ammoType = ammoType, ammoCount = ammoCount, weaponType = weaponType, forceWeaponToSlot = forceWeaponToSlot, selectWeapon = selectWeapon})
end

GiveItems.GiveWeaponAmmoScheduled = function(eventData)
    local data = eventData.data ---@type GiveItems_GiveWeaponAmmoScheduled

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint("ERROR: muppet_streamer_give_player_weapon_ammo command target player not found at delivery time: " .. data.target)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({"message.muppet_streamer_give_player_weapon_ammo_not_character_controller", data.target})
        return
    end

    if data.weaponType ~= nil and data.weaponType.valid then
        GiveItems.EnsureHasWeapon(targetPlayer, data.weaponType.name, data.forceWeaponToSlot, data.selectWeapon)
    end
    if data.ammoType ~= nil and data.ammoType.valid and data.ammoCount > 0 then
        local inserted = targetPlayer.insert({name = data.ammoType.name, count = data.ammoCount})
        if inserted < data.ammoCount then
            targetPlayer.surface.spill_item_stack(targetPlayer.position, {name = data.ammoType.name, count = data.ammoCount - inserted}, true, nil, false)
        end
    end
end

return GiveItems
