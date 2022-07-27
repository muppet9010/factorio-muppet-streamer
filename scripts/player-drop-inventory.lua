local PlayerDropInventory = {} ---@class PlayerDropInventory
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Events = require("utility.manager-libraries.events")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@enum PlayerDropInventory_QuantityType
local QuantityType = {
    constant = "constant",
    startingPercentage = "startingPercentage",
    realtimePercentage = "realtimePercentage"
}

---@class PlayerDropInventory_ApplyDropItemsData
---@field target string
---@field quantityType PlayerDropInventory_QuantityType
---@field quantityValue uint
---@field dropOnBelts boolean
---@field gap uint @ Must be > 0.
---@field occurrences uint
---@field dropEquipment boolean

---@class PlayerDropInventory_ScheduledDropItemsData
---@field player_index uint
---@field player LuaPlayer
---@field gap uint @ Must be > 0.
---@field totalOccurrences uint
---@field dropOnBelts boolean
---@field dropEquipment boolean
---@field staticItemCount uint|nil
---@field dynamicPercentageItemCount uint|nil
---@field currentOccurrences uint

---@alias PlayerDropInventory_InventoryItemCounts table<defines.inventory|'cursorStack', uint> @ Dictionary of each inventory to a cached total count across all items (count of each item all added together) were in that inventory.
---@alias PlayerDropInventory_InventoryContents table<defines.inventory|'cursorStack', table<string, uint>> @ Dictionary of each inventory to a cached list of item name and counts in that inventory.

local commandName = "muppet_streamer_player_drop_inventory"

PlayerDropInventory.CreateGlobals = function()
    global.playerDropInventory = global.playerDropInventory or {}
    global.playerDropInventory.affectedPlayers = global.playerDropInventory.affectedPlayers or {} ---@type table<uint, true> @ A dictionary of player indexes that have the effect active on them currently.
    global.playerDropInventory.nextId = global.playerDropInventory.nextId or 0 ---@type uint
end

PlayerDropInventory.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_player_drop_inventory", {"api-description.muppet_streamer_player_drop_inventory"}, PlayerDropInventory.PlayerDropInventoryCommand, true)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.PlayerDropItems_Scheduled", PlayerDropInventory.PlayerDropItems_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "PlayerDropInventory.OnPrePlayerDied", PlayerDropInventory.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.ApplyToPlayer", PlayerDropInventory.ApplyToPlayer)
    MOD.Interfaces.Commands.PlayerDropInventory = PlayerDropInventory.PlayerDropInventoryCommand
end

---@param command CustomCommandData
PlayerDropInventory.PlayerDropInventoryCommand = function(command)
    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, {"delay", "target", "quantityType", "quantityValue", "dropOnBelts", "gap", "occurrences", "dropEquipment"})
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

    local quantityType_string = commandData.quantityType
    if not CommandsUtils.CheckStringArgument(quantityType_string, true, commandName, "quantityType", QuantityType, command.parameter) then
        return
    end ---@cast quantityType_string string
    local quantityType = QuantityType[quantityType_string] ---@type PlayerDropInventory_QuantityType

    local quantityValue = commandData.quantityValue
    if not CommandsUtils.CheckNumberArgument(quantityValue, "int", true, commandName, "quantityValue", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast quantityValue uint

    local dropOnBelts = commandData.dropOnBelts
    if not CommandsUtils.CheckBooleanArgument(dropOnBelts, false, commandName, "dropOnBelts", command.parameter) then
        return
    end ---@cast dropOnBelts boolean|nil
    if dropOnBelts == nil then
        dropOnBelts = false
    end

    local gapSeconds = commandData.gap
    if not CommandsUtils.CheckNumberArgument(gapSeconds, "double", true, commandName, "gap", 1 / 60, math.floor(MathUtils.uintMax / 60), command.parameter) then
        return
    end ---@cast gapSeconds double
    local gap = math.floor(gapSeconds * 60) --[[@as uint @ gapSeconds was validated as not exceeding a uint during input validation.]]

    local occurrences = commandData.occurrences
    if not CommandsUtils.CheckNumberArgument(occurrences, "int", true, commandName, "occurrences", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast occurrences uint

    local dropEquipment = commandData.dropEquipment
    if not CommandsUtils.CheckBooleanArgument(dropEquipment, false, commandName, "dropEquipment", command.parameter) then
        return
    end ---@cast dropEquipment boolean|nil
    if dropEquipment == nil then
        dropEquipment = true
    end

    global.playerDropInventory.nextId = global.playerDropInventory.nextId + 1
    ---@type PlayerDropInventory_ApplyDropItemsData
    local applyDropItemsData = {
        target = target,
        quantityType = quantityType,
        quantityValue = quantityValue,
        dropOnBelts = dropOnBelts,
        gap = gap,
        occurrences = occurrences,
        dropEquipment = dropEquipment
    }
    EventScheduler.ScheduleEventOnce(scheduleTick, "PlayerDropInventory.ApplyToPlayer", global.playerDropInventory.nextId, applyDropItemsData)
end

--- Prepare to apply the effect to the player.
PlayerDropInventory.ApplyToPlayer = function(event)
    local data = event.data ---@type PlayerDropInventory_ApplyDropItemsData

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        -- Target player has been deleted since the command was run.
        return
    end
    local targetPlayer_index = targetPlayer.index
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        -- Player not alive or in non playing mode.
        game.print({"message.muppet_streamer_player_drop_inventory_not_character_controller", data.target})
        return
    end

    -- If the effect is always set on this player don't start a new one.
    if global.playerDropInventory.affectedPlayers[targetPlayer_index] ~= nil then
        return
    end

    -- Work out how many items to drop per cycle here if its a starting number type.
    ---@type uint|nil, uint|nil
    local staticItemCount, dynamicPercentageItemCount
    if data.quantityType == QuantityType.constant then
        staticItemCount = data.quantityValue
    elseif data.quantityType == QuantityType.startingPercentage then
        local totalItemCount = PlayerDropInventory.GetPlayersItemCount(targetPlayer, data.dropEquipment)
        staticItemCount = math.max(1, math.floor(totalItemCount / (100 / data.quantityValue))) -- Output will always be a uint based on the input values prior validation.
    elseif data.quantityType == QuantityType.realtimePercentage then
        dynamicPercentageItemCount = data.quantityValue
    end

    -- Record the player as having this effect running on them so it can't be started a second time.
    global.playerDropInventory.affectedPlayers[targetPlayer_index] = true

    -- Do the first effect now.
    game.print({"message.muppet_streamer_player_drop_inventory_start", targetPlayer.name})
    ---@type PlayerDropInventory_ScheduledDropItemsData
    local scheduledDropItemsData = {
        player_index = targetPlayer_index,
        player = targetPlayer,
        gap = data.gap,
        totalOccurrences = data.occurrences,
        dropOnBelts = data.dropOnBelts,
        dropEquipment = data.dropEquipment,
        staticItemCount = staticItemCount,
        dynamicPercentageItemCount = dynamicPercentageItemCount,
        currentOccurrences = 0
    }
    PlayerDropInventory.PlayerDropItems_Scheduled({tick = event.tick, instanceId = scheduledDropItemsData.player_index, data = scheduledDropItemsData})
end

--- Apply the drop item effect to the player.
---@param event UtilityScheduledEvent_CallbackObject
PlayerDropInventory.PlayerDropItems_Scheduled = function(event)
    local data = event.data ---@type PlayerDropInventory_ScheduledDropItemsData
    local player, playerIndex = data.player, data.player_index
    if player == nil or (not player.valid) or player.character == nil or (not player.character.valid) then
        PlayerDropInventory.StopEffectOnPlayer(playerIndex)
        return
    end

    -- Get the details about the items in the inventory. This allows us to do most of the processing off this cached data.
    -- Updates these item stats as it loops over them and drops one item at a time.
    -- Includes:
    --      - total items in all inventories - used to work out the range of our random item selection (by index).
    --      - total items in each inventory - used to work out which inventory has the item we want as can just use these totals, rather than having to repeatedly count the cached contents counts.
    --      - item name and count in each inventory - used to define what item to drop for a given index in an inventory.
    local totalItemCount, itemsCountsInInventories, inventoriesContents = PlayerDropInventory.GetPlayersInventoryItemDetails(player, data.dropEquipment)

    -- Get the number of items to drop this event.
    local itemCountToDrop
    if data.staticItemCount ~= nil then
        itemCountToDrop = data.staticItemCount
    else
        itemCountToDrop = math.max(1, math.floor(totalItemCount / (100 / data.dynamicPercentageItemCount))) --[[@as uint @ End value will always end up as a uint from the validated input values.]]
    end ---@cast itemCountToDrop - nil

    -- Only try and drop items if there are any to drop in the player's inventories. We want the code to keep on running for future iterations until the occurrence count has completed.
    if totalItemCount > 0 then
        local itemCountDropped = 0
        local surface, position = player.surface, player.position

        -- Drop a single random item from across the range of inventories at a time until the required number of items have been dropped.
        -- CODE NOTE: This is quite Lua code inefficient, but does ensure truly random items are dropped.
        while itemCountDropped < itemCountToDrop do
            -- Select the single random item number to be dropped from across the total item count.
            local itemNumberToDrop = math.random(1, totalItemCount)

            -- Find the inventory with this item number in it. Update the per inventory total item counts.
            local inventoryNameOfItemNumberToDrop, itemNumberInSpecificInventory
            local itemCountedUpTo = 0
            for inventoryName, countInInventory in pairs(itemsCountsInInventories) do
                itemCountedUpTo = itemCountedUpTo + countInInventory
                if itemCountedUpTo >= itemNumberToDrop then
                    inventoryNameOfItemNumberToDrop = inventoryName
                    itemNumberInSpecificInventory = itemNumberToDrop - (itemCountedUpTo - countInInventory)
                    itemsCountsInInventories[inventoryName] = countInInventory - 1
                    break
                end
            end
            if inventoryNameOfItemNumberToDrop == nil then
                CommandsUtils.LogPrintError(commandName, nil, "didn't find item number " .. itemNumberToDrop .. " when looking over " .. player.name .. "'s inventories.", nil)
                return
            end

            -- Find the name of the numbered item in the specific inventory. Update the cached lists to remove 1 from this item's count.
            local itemNameToDrop
            local inventoryItemsCounted = 0
            for itemName, itemCount in pairs(inventoriesContents[inventoryNameOfItemNumberToDrop]) do
                inventoryItemsCounted = inventoryItemsCounted + itemCount
                if inventoryItemsCounted >= itemNumberInSpecificInventory then
                    itemNameToDrop = itemName
                    inventoriesContents[inventoryNameOfItemNumberToDrop][itemName] = itemCount - 1
                    break
                end
            end
            if itemNameToDrop == nil then
                CommandsUtils.LogPrintError(commandName, nil, "didn't find item name for number " .. itemNumberToDrop .. " in " .. player.name .. "'s inventory id " .. inventoryNameOfItemNumberToDrop, nil)
                return
            end

            -- Drop the specific item.
            local itemStackToDropFrom  ---@type LuaItemStack|nil
            if inventoryNameOfItemNumberToDrop == "cursorStack" then
                -- Special case as not a real inventory.
                itemStackToDropFrom = player.cursor_stack
            else
                local inventory = player.get_inventory(inventoryNameOfItemNumberToDrop)
                if inventory == nil then
                    CommandsUtils.LogPrintError(commandName, nil, "didn't find inventory id " .. inventoryNameOfItemNumberToDrop .. "' for " .. player.name, nil)
                    return
                end
                itemStackToDropFrom = inventory.find_item_stack(itemNameToDrop)
                if itemStackToDropFrom == nil then
                    CommandsUtils.LogPrintError(commandName, nil, "didn't find item stack for item '" .. itemNameToDrop .. "' in " .. player.name .. "'s inventory id " .. inventoryNameOfItemNumberToDrop, nil)
                    return
                end
            end
            local itemStackToDropFrom_count = itemStackToDropFrom.count
            if itemStackToDropFrom_count == 1 then
                -- Single item in the itemStack so drop it and all done. This handles any extra attributes the itemStack may have naturally.
                surface.spill_item_stack(position, itemStackToDropFrom, false, nil, data.dropOnBelts)
                itemStackToDropFrom.count = 0
            else
                -- Multiple items in the itemStack so can just drop 1 copy of the itemStack details and remove 1 from count.
                -- CODE NOTE: ItemStacks are grouped by Factorio in to full health or damaged (health averaged across all items in itemStack).
                -- CODE NOTE: ItemStacks have a single durability and ammo stat which effectively is for the first item in the itemStack, with the other items in the itemStack all being full.
                -- CODE NOTE: when the itemStack's count is reduced by 1 the itemStacks durability and ammo fields are reset to full. As the first item is considered to be the partially used items.
                local itemToDrop = {name = itemStackToDropFrom.name, count = 1, health = itemStackToDropFrom.health, durability = itemStackToDropFrom.durability}
                if itemStackToDropFrom.type == "ammo" then
                    itemToDrop.ammo = itemStackToDropFrom.ammo
                end
                if itemStackToDropFrom.is_item_with_tags then
                    itemToDrop.tags = itemStackToDropFrom.tags
                end
                surface.spill_item_stack(position, itemToDrop, false, nil, data.dropOnBelts)
                itemStackToDropFrom.count = itemStackToDropFrom_count - 1
            end

            -- Count that the item was dropped and update the total items in all inventory count.
            itemCountDropped = itemCountDropped + 1
            totalItemCount = totalItemCount - 1

            -- If no items left stop trying to drop things this event and await the next one.
            if totalItemCount == 0 then
                itemCountDropped = itemCountToDrop
            end
        end
    end

    -- Schedule the next occurrence if we haven't completed them all yet.
    data.currentOccurrences = data.currentOccurrences + 1
    if data.currentOccurrences < data.totalOccurrences then
        EventScheduler.ScheduleEventOnce(event.tick + data.gap, "PlayerDropInventory.PlayerDropItems_Scheduled", playerIndex, data)
    else
        PlayerDropInventory.StopEffectOnPlayer(playerIndex)
        game.print({"message.muppet_streamer_player_drop_inventory_stop", player.name})
    end
end

---@param event on_pre_player_died
PlayerDropInventory.OnPrePlayerDied = function(event)
    PlayerDropInventory.StopEffectOnPlayer(event.player_index)
end

---@parm playerIndex uint
PlayerDropInventory.StopEffectOnPlayer = function(playerIndex)
    if global.playerDropInventory.affectedPlayers[playerIndex] == nil then
        return
    end

    global.playerDropInventory.affectedPlayers[playerIndex] = nil
    EventScheduler.RemoveScheduledOnceEvents("PlayerDropInventory.PlayerDropItems_Scheduled", playerIndex)
end

---@param player LuaPlayer
---@param includeEquipment boolean
---@return uint totalItemsCount
PlayerDropInventory.GetPlayersItemCount = function(player, includeEquipment)
    local totalItemsCount = 0 ---@type uint
    for _, inventoryName in pairs({defines.inventory.character_main, defines.inventory.character_trash}) do
        for _, count in pairs(player.get_inventory(inventoryName).get_contents()) do
            totalItemsCount = totalItemsCount + count
        end
    end
    local cursorStack = player.cursor_stack
    if cursorStack.valid_for_read then
        totalItemsCount = totalItemsCount + cursorStack.count
    end

    if includeEquipment then
        for _, inventoryName in pairs({defines.inventory.character_armor, defines.inventory.character_guns, defines.inventory.character_ammo}) do
            for _, count in pairs(player.get_inventory(inventoryName).get_contents()) do
                totalItemsCount = totalItemsCount + count
            end
        end
    end

    return totalItemsCount
end

---@param player LuaPlayer
---@param includeEquipment boolean
---@return uint totalItemsCount
---@return PlayerDropInventory_InventoryItemCounts inventoryItemCounts
---@return PlayerDropInventory_InventoryContents inventoryContents
PlayerDropInventory.GetPlayersInventoryItemDetails = function(player, includeEquipment)
    local totalItemsCount = 0 ---@type uint
    local inventoryItemCounts = {} ---@type PlayerDropInventory_InventoryItemCounts
    local inventoryContents = {} ---@type PlayerDropInventory_InventoryContents
    for _, inventoryName in pairs({defines.inventory.character_main, defines.inventory.character_trash}) do
        local contents = player.get_inventory(inventoryName).get_contents()
        inventoryContents[inventoryName] = contents
        local inventoryTotalCount = 0 ---@type uint
        for _, count in pairs(contents) do
            inventoryTotalCount = inventoryTotalCount + count
        end
        totalItemsCount = totalItemsCount + inventoryTotalCount
        inventoryItemCounts[inventoryName] = inventoryTotalCount
    end
    local cursorStack = player.cursor_stack
    if cursorStack.valid_for_read then
        local count = cursorStack.count
        totalItemsCount = totalItemsCount + count
        inventoryItemCounts["cursorStack"] = count
        inventoryContents["cursorStack"] = {[cursorStack.name] = count}
    end

    if includeEquipment then
        for _, inventoryName in pairs({defines.inventory.character_armor, defines.inventory.character_guns, defines.inventory.character_ammo}) do
            local contents = player.get_inventory(inventoryName).get_contents()
            inventoryContents[inventoryName] = contents
            local inventoryTotalCount = 0 ---@type uint
            for _, count in pairs(contents) do
                inventoryTotalCount = inventoryTotalCount + count
            end
            totalItemsCount = totalItemsCount + inventoryTotalCount
            inventoryItemCounts[inventoryName] = inventoryTotalCount
        end
    end

    return totalItemsCount, inventoryItemCounts, inventoryContents
end

return PlayerDropInventory
