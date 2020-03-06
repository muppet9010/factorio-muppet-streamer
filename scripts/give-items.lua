local GiveItems = {}
local Interfaces = require("utility/interfaces")
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")

GiveItems.CreateGlobals = function()
    global.giveItems = global.giveItems or {}
    global.giveItems.nextId = global.giveItems.nextId or 0
end

GiveItems.OnLoad = function()
    Interfaces.RegisterInterface("GiveItems.EnsureHasWeapon", GiveItems.EnsureHasWeapon)
    Commands.Register("muppet_streamer_give_player_weapon_ammo", {"api-description.muppet_streamer_give_player_weapon_ammo"}, GiveItems.GivePlayerWeaponAmmoCommand)
    EventScheduler.RegisterScheduledEventType("GiveItems.GiveWeaponAmmoScheduled", GiveItems.GiveWeaponAmmoScheduled)
end

GiveItems.EnsureHasWeapon = function(player, weaponName, forceWeaponToWeaponInventorySlot, selectWeapon)
    -- If forceWeaponToWeaponInventorySlot is true and the player has full gun slots then a weapon is randomly selected and moved to the player inventory with its ammo. So that our weapon can be put there.
    local weaponFoundIndex, weaponGiven = 0, false
    local gunInventory = player.get_inventory(defines.inventory.character_guns)
    for i = 1, #gunInventory do
        local gunItemStack = gunInventory[i]
        if gunItemStack ~= nil and gunItemStack.valid_for_read then
            if gunItemStack.name == weaponName then
                weaponFoundIndex = i
                break
            end
        end
    end

    if weaponFoundIndex == 0 then
        if not gunInventory.can_insert({name = weaponName, count = 1}) and forceWeaponToWeaponInventorySlot then
            weaponFoundIndex = math.random(1, 3)
            local gunItemStack = gunInventory[weaponFoundIndex]
            if gunItemStack ~= nil and gunItemStack.valid_for_read then
                local gunInsertedCount = player.insert({name = gunItemStack.name, count = gunItemStack.count})
                if gunInsertedCount < gunItemStack.count then
                    player.surface.spill_item_stack({name = gunItemStack.name, count = gunItemStack.count - gunInsertedCount})
                end
            end
            gunInventory.set_filter(weaponFoundIndex, nil)
            gunItemStack.clear()

            local ammoInventory = player.get_inventory(defines.inventory.character_ammo)
            local ammoItemStack = ammoInventory[weaponFoundIndex]
            if ammoItemStack ~= nil and ammoItemStack.valid_for_read then
                local ammoInsertedCount = player.insert({name = ammoItemStack.name, count = ammoItemStack.count})
                if ammoInsertedCount < ammoItemStack.count then
                    player.surface.spill_item_stack({name = ammoItemStack.name, count = ammoItemStack.count - ammoInsertedCount})
                end
            end
            ammoInventory.set_filter(weaponFoundIndex, nil)
            ammoItemStack.clear()
        end

        local characterInventory = player.get_main_inventory()
        if characterInventory.get_item_count(weaponName) == 0 then
            weaponGiven = true
        else
            characterInventory.remove({name = weaponName, count = 1})
        end

        gunInventory.insert({name = weaponName, count = 1})
    end

    if selectWeapon then
        if weaponFoundIndex == 0 then
            for i = 1, #gunInventory do
                local gunItemStack = gunInventory[i]
                if gunItemStack ~= nil and gunItemStack.valid_for_read then
                    if gunItemStack.name == weaponName then
                        weaponFoundIndex = i
                        break
                    end
                end
            end
        end
        if weaponFoundIndex > 0 then
            player.character.selected_gun_index = weaponFoundIndex
        end
    end

    return weaponGiven
end

GiveItems.GivePlayerWeaponAmmoCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_give_player_weapon_ammo command "
    local commandData = game.json_to_table(command.parameter)
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

    local weaponTypeString, weaponType = commandData.weaponType
    if weaponTypeString ~= nil and weaponTypeString ~= "" then
        weaponType = game.item_prototypes[weaponTypeString]
        if weaponType == nil or weaponType.type ~= "gun" then
            Logging.LogPrint(errorMessageStart .. "optional weaponType provide, but isn't a valid type")
            return
        end
    end

    local forceWeaponToSlot = commandData.forceWeaponToSlot
    if forceWeaponToSlot ~= nil then
        if type(forceWeaponToSlot) ~= "boolean" then
            Logging.LogPrint(errorMessageStart .. "optional forceWeaponToSlot provided, but isn't a boolean true/false")
            return
        end
    end

    local selectWeapon = commandData.selectWeapon
    if selectWeapon ~= nil then
        if type(selectWeapon) ~= "boolean" then
            Logging.LogPrint(errorMessageStart .. "optional selectWeapon provided, but isn't a boolean true/false")
            return
        end
    end

    local ammoTypeString, ammoType = commandData.ammoType
    if ammoTypeString ~= nil and ammoTypeString ~= "" then
        ammoType = game.item_prototypes[ammoTypeString]
        if ammoType == nil or ammoType.type ~= "ammo" then
            Logging.LogPrint(errorMessageStart .. "optional ammoType provide, but isn't a valid type")
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
    local data, targetPlayer = eventData.data

    if type(data.target) == "string" then
        targetPlayer = game.get_player(data.target)
        if targetPlayer == nil then
            Logging.LogPrint("ERROR: muppet_streamer_give_player_weapon_ammo command target player not found at delivery time: " .. data.target)
            return
        end
    end

    if data.weaponType ~= nil and data.weaponType.valid then
        GiveItems.EnsureHasWeapon(targetPlayer, data.weaponType.name, data.forceWeaponToSlot, data.selectWeapon)
    end
    if data.ammoType ~= nil and data.ammoType.valid and data.ammoCount > 0 then
        local inserted = targetPlayer.get_inventory(defines.inventory.character_ammo).insert({name = data.ammoType.name, count = data.ammoCount})
        if inserted < data.ammoCount then
            targetPlayer.surface.spill_item_stack({name = data.ammoType.name, count = data.ammoCount - inserted})
        end
    end
end

return GiveItems
