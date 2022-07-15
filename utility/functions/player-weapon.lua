--[[
    Functionaility related to player's weapons. Includes options to force a specific weapon to be given and/or equipped. Returns details so the preivous weapon/options can be returned if desired.

    Usage: Call any public functions (not starting with "_") as required.
]]
local PlayerWeapon = {}

----------------------------------------------------------------------------------
--                          PUBLIC FUNCTIONS
----------------------------------------------------------------------------------

---@class UtilityPlayerWeapon_RemovedWeaponToEnsureWeapon
---@field gunInventoryIndex uint @ The index in the gun and ammo inventory where the weapon was removed.
---@field weaponItemName? string|nil @ Nil if no weapon was in the slot.
---@field weaponFilterName? string|nil @ Nil if no weapon filter was set on the slot.
---@field ammoItemName? string|nil @ Nil if no ammo was in the slot.
---@field ammoFilterName? string|nil @ Nil if no ammo filter was set on the slot.
---@field beforeSelectedWeaponGunIndex uint @ The weapon slot that the player had selected before the weapon was removed.

--- Ensure the player has the specified weapon, clearing any filters if needed. If the weapon has to be given/equiped then it will clear the related ammo slot and any filter on it.
---@param player LuaPlayer
---@param weaponName string
---@param forceWeaponToWeaponInventorySlot boolean @ If the weapon should be forced to be equiped, otherwise it may end up in their inventory.
---@param selectWeapon boolean
---@return boolean|nil weaponGiven @ If the weapon item had to be given to the player, compared to them already having it and it possibly just being moved between their inventories. Returns nil for invalid situations, i.e. called on a player with no gun inventory.
---@return UtilityPlayerWeapon_RemovedWeaponToEnsureWeapon|nil removedWeaponDetails @ Details on the weapon that was removed to add the new wepaon. Is nil if no active weapon was set/found, i.e. weapon was found/put in to the players main inventory and not as an equiped weapon.
PlayerWeapon.EnsureHasWeapon = function(player, weaponName, forceWeaponToWeaponInventorySlot, selectWeapon)
    if player == nil or not player.valid then
        return nil, nil
    end

    ---@type UtilityPlayerWeapon_RemovedWeaponToEnsureWeapon
    local removedWeaponDetails = {
        beforeSelectedWeaponGunIndex = player.character.selected_gun_index
    }

    -- See if the gun is already equipped by the player in their active gun inventory, or find which of their weapon slots is best to assign too.
    ---@typelist boolean, uint|nil, uint|nil, uint|nil
    local weaponGiven, weaponFoundIndex, freeGunIndex, freeButFilteredGunIndex = false, nil, nil, nil
    local gunInventory = player.get_inventory(defines.inventory.character_guns)
    if gunInventory == nil then
        return nil, nil
    end
    for gunInventoryIndex = 1, #gunInventory do
        ---@cast gunInventoryIndex uint
        local gunItemStack = gunInventory[gunInventoryIndex]
        if gunItemStack.valid_for_read then
            -- Weapon in this slot.
            if gunItemStack.name == weaponName then
                -- Player already has this gun equiped.
                weaponFoundIndex = gunInventoryIndex
                break
            end
        else
            -- No weapon in slot.
            local filteredName = gunInventory.get_filter(gunInventoryIndex)
            if filteredName == nil or filteredName == weaponName then
                -- Non filtered weapon slot or filtered to the weapon we want to assign.
                freeGunIndex = gunInventoryIndex
                break
            else
                -- Filtered weapon slot to a different weapon.
                freeButFilteredGunIndex = gunInventoryIndex
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
                    weaponFoundIndex = math.random(1, #gunInventory) --[[@as uint]]
                end

                -- Clear the gun slot ready for the weapon.
                local gunItemStack = gunInventory[weaponFoundIndex]
                if gunItemStack ~= nil and gunItemStack.valid_for_read then
                    local currentName, currentCount = gunItemStack.name, gunItemStack.count
                    local gunInsertedCount = player.insert({name = currentName, count = currentCount})
                    if gunInsertedCount < currentCount then
                        player.surface.spill_item_stack(player.position, {name = currentName, count = currentCount - gunInsertedCount --[[@as uint]]}, true, nil, false)
                    end
                    removedWeaponDetails.weaponItemName = currentName
                end
                removedWeaponDetails.weaponFilterName = gunInventory.get_filter(weaponFoundIndex)
                gunInventory.set_filter(weaponFoundIndex, nil) ---@diagnostic disable-line:param-type-mismatch -- Mistake in API Docs, bugged: https://forums.factorio.com/viewtopic.php?f=7&t=102859
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
        end ---@cast weaponFoundIndex - nil

        -- Clear the ammo slot ready for the weapon and its possible ammo.
        local ammoInventory = player.get_inventory(defines.inventory.character_ammo)
        local ammoItemStack = ammoInventory[weaponFoundIndex]
        if ammoItemStack ~= nil and ammoItemStack.valid_for_read then
            -- Ammo in the slot so move it to the players inventory, or the floor.
            local currentName, currentCount = ammoItemStack.name, ammoItemStack.count
            local ammoInsertedCount = player.insert({name = currentName, count = currentCount, ammo = ammoItemStack.ammo})
            if ammoInsertedCount < currentCount then
                player.surface.spill_item_stack(player.position, {name = currentName, count = currentCount - ammoInsertedCount --[[@as uint]]}, true, nil, false)
            end
            removedWeaponDetails.ammoItemName = currentName
            ammoItemStack.clear()
        end

        -- Clear the filter on the slot.
        removedWeaponDetails.ammoFilterName = ammoInventory.get_filter(weaponFoundIndex)
        if removedWeaponDetails.ammoFilterName ~= nil then
            ammoInventory.set_filter(weaponFoundIndex, nil) ---@diagnostic disable-line:param-type-mismatch  -- Mistake in API Docs, bugged: https://forums.factorio.com/viewtopic.php?f=7&t=102859
        end

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
    if selectWeapon then
        player.character.selected_gun_index = weaponFoundIndex
    end

    -- Record the weapon index that was used in the end.
    removedWeaponDetails.gunInventoryIndex = weaponFoundIndex

    return weaponGiven, removedWeaponDetails
end

--- Sets the players weapon filter back to what was removed. Assumes that anything put in the wepaon slot in the mean time is to be overridden.
--- If the player's character is currently alive then it also equips the weapon and ammo from their inventory (assuming they still have them).
---@param player any
---@param removedWeaponDetails any
PlayerWeapon.ReturnRemovedWeapon = function(player, removedWeaponDetails)
    ---@typelist LuaInventory, LuaInventory, LuaInventory
    local playerGunInventory, playerAmmoInventory, playerCharacterInventory = nil, nil, nil
    if removedWeaponDetails.weaponFilterName ~= nil then
        playerGunInventory = playerGunInventory or player.get_inventory(defines.inventory.character_guns)
        playerGunInventory.set_filter(removedWeaponDetails.gunInventoryIndex, removedWeaponDetails.weaponFilterName)
    end
    if removedWeaponDetails.ammoFilterName ~= nil then
        playerAmmoInventory = playerAmmoInventory or player.get_inventory(defines.inventory.character_ammo)
        playerAmmoInventory.set_filter(removedWeaponDetails.gunInventoryIndex, removedWeaponDetails.ammoFilterName)
    end

    -- Return the player's weapon and/or ammo if one was removed and the player has an alive character.
    if player.character then
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

        -- Restore the player's active weapon back to what it was before.
        player.character.selected_gun_index = removedWeaponDetails.beforeSelectedWeaponGunIndex
    end
end

--- Take the flamethrower from the player (weapon slot, inventory or dropped on ground).
---@param player LuaPlayer
---@param itemName string
---@param itemCount uint
---@return uint
PlayerWeapon.TakeItemFromPlayerOrGround = function(player, itemName, itemCount)
    local removed = 0 ---@type uint
    removed = removed + player.remove_item({name = itemName, count = itemCount}) --[[@as uint]]
    if itemCount == 0 then
        return removed
    end

    local itemsOnGround = player.surface.find_entities_filtered {position = player.position, radius = 10, name = "item-on-ground"}
    for _, itemOnGround in pairs(itemsOnGround) do
        if itemOnGround.valid and itemOnGround.stack ~= nil and itemOnGround.stack.valid and itemOnGround.stack.name == itemName then
            itemOnGround.destroy()
            removed = removed + 1 --[[@as uint]]
            itemCount = itemCount - 1 --[[@as uint]]
            if itemCount == 0 then
                break
            end
        end
    end
    return removed
end

----------------------------------------------------------------------------------
--                          PRIVATE FUNCTIONS
----------------------------------------------------------------------------------

return PlayerWeapon
