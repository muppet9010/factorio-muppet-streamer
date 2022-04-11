local PlayerDropInventory = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Events = require("utility/events")

---@class PlayerDropInventory_QuantityType
local QuantityType = {constant = "constant", startingPercentage = "startingPercentage", realtimePercentage = "realtimePercentage"}

local ErrorMessageStart = "ERROR: muppet_streamer_player_drop_inventory command "

PlayerDropInventory.CreateGlobals = function()
    global.playerDropInventory = global.playerDropInventory or {}
    global.playerDropInventory.affectedPlayers = global.playerDropInventory.affectedPlayers or {}
    global.playerDropInventory.nextId = global.playerDropInventory.nextId or 0
end

PlayerDropInventory.OnLoad = function()
    Commands.Register("muppet_streamer_player_drop_inventory", {"api-description.muppet_streamer_player_drop_inventory"}, PlayerDropInventory.PlayerDropInventoryCommand, true)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.PlayerDropItems_Scheduled", PlayerDropInventory.PlayerDropItems_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "PlayerDropInventory.OnPrePlayerDied", PlayerDropInventory.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.ApplyToPlayer", PlayerDropInventory.ApplyToPlayer)
end

---@param command CustomCommandData
PlayerDropInventory.PlayerDropInventoryCommand = function(command)
    local commandData
    if command.parameter ~= nil then
        commandData = game.json_to_table(command.parameter)
    end
    if commandData == nil or type(commandData) ~= "table" then
        Logging.LogPrint(ErrorMessageStart .. "requires details in JSON format.")
        return
    end

    local delay = 0
    if commandData.delay ~= nil then
        delay = tonumber(commandData.delay)
        if delay == nil then
            Logging.LogPrint(ErrorMessageStart .. "delay is Optional, but must be a non-negative number if supplied")
            return
        end
        delay = math.max(delay * 60, 0)
    end

    local target = commandData.target ---@type string
    if target == nil then
        Logging.LogPrint(ErrorMessageStart .. "target is mandatory")
        return
    elseif game.get_player(target) == nil then
        Logging.LogPrint(ErrorMessageStart .. "target is invalid player name")
        return
    end

    local quantityTypeString = commandData.quantityType
    if target == nil then
        Logging.LogPrint(ErrorMessageStart .. "quantityType is mandatory")
        return
    end
    local quantityType = QuantityType[quantityTypeString] ---@type PlayerDropInventory_QuantityType
    if quantityType == nil then
        Logging.LogPrint(ErrorMessageStart .. "quantityType is invalid quantityType string")
        return
    end

    local quantityValue = tonumber(commandData.quantityValue)
    if quantityValue == nil or quantityValue <= 0 then
        Logging.LogPrint(ErrorMessageStart .. "quantityValue is mandatory as a number and above 0")
        return
    end

    local dropOnBeltsString = commandData.dropOnBelts
    local dropOnBelts  ---@type boolean
    if dropOnBeltsString == nil then
        dropOnBelts = false
    else
        dropOnBelts = Utils.ToBoolean(dropOnBeltsString)
        if dropOnBelts == nil then
            Logging.LogPrint(ErrorMessageStart .. "if dropOnBelts is provided it must be a boolean: true, false")
            return
        end
    end

    local gap = tonumber(commandData.gap)
    if quantityValue == nil then
        Logging.LogPrint(ErrorMessageStart .. "gap is mandatory as a number")
        return
    end
    gap = math.max(gap * 60, 0)

    local occurrences = tonumber(commandData.occurrences)
    if occurrences == nil then
        Logging.LogPrint(ErrorMessageStart .. "occurrences is mandatory as a number")
        return
    end

    local dropEquipmentString = commandData.dropEquipment
    local dropEquipment  ---@type boolean
    if dropEquipmentString == nil then
        dropEquipment = true
    else
        dropEquipment = Utils.ToBoolean(dropEquipmentString)
        if dropEquipment == nil then
            Logging.LogPrint(ErrorMessageStart .. "if dropEquipment is provided it must be a boolean: true, false")
            return
        end
    end

    global.playerDropInventory.nextId = global.playerDropInventory.nextId + 1
    ---@class PlayerDropInventory_ApplyDropItemsData
    local data = {
        target = target,
        quantityType = quantityType,
        quantityValue = quantityValue,
        dropOnBelts = dropOnBelts,
        gap = gap,
        occurrences = occurrences,
        dropEquipment = dropEquipment
    }
    EventScheduler.ScheduleEvent(command.tick + delay, "PlayerDropInventory.ApplyToPlayer", global.playerDropInventory.nextId, data)
end

--- Prepare to apply the effect to the player.
PlayerDropInventory.ApplyToPlayer = function(event)
    local data = event.data ---@type PlayerDropInventory_ApplyDropItemsData

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil or not targetPlayer.valid then
        Logging.LogPrint(ErrorMessageStart .. "target player not found at creation time: " .. data.target)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        -- Player not alive or in non playing mode.
        game.print({"message.muppet_streamer_player_drop_inventory_not_character_controller", data.target})
        return
    end

    if global.playerDropInventory.affectedPlayers[targetPlayer.index] ~= nil then
        return
    end

    -- Work out how many items to drop per cycle here if its a starting number type.
    ---@typelist uint|null, uint|null
    local staticItemCount, dynamicPercentageItemCount
    if data.quantityType == QuantityType.constant then
        staticItemCount = math.floor(data.quantityValue)
    elseif data.quantityType == QuantityType.startingPercentage then
        local totalItemCount = PlayerDropInventory.GetPlayersItemCount(targetPlayer, data.dropEquipment)
        staticItemCount = math.max(1, math.floor(totalItemCount / (100 / data.quantityValue)))
    elseif data.quantityType == QuantityType.realtimePercentage then
        dynamicPercentageItemCount = data.quantityValue
    end

    -- Do the first effect now.
    game.print({"message.muppet_streamer_player_drop_inventory_start", targetPlayer.name})
    ---@class PlayerDropInventory_ScheduledDropItemsData
    local data = {
        player = targetPlayer,
        gap = data.gap,
        totaloccurrences = data.occurrences,
        dropOnBelts = data.dropOnBelts,
        dropEquipment = data.dropEquipment,
        staticItemCount = staticItemCount,
        dynamicPercentageItemCount = dynamicPercentageItemCount,
        currentoccurrences = 0
    }
    PlayerDropInventory.PlayerDropItems_Scheduled({tick = event.tick, instanceId = targetPlayer.index, data = data})
end

--- Apply the drop item effect to the player.
PlayerDropInventory.PlayerDropItems_Scheduled = function(event)
    ---@typelist PlayerDropInventory_ScheduledDropItemsData, LuaPlayer, Id
    local data, player, playerIndex = event.data, event.data.player, event.instanceId
    if player == nil or (not player.valid) or player.character == nil or (not player.character.valid) then
        PlayerDropInventory.StopEffectOnPlayer(playerIndex)
        return
    end

    local totalItemCount, itemsCountsInInventories, inventoriesContents = PlayerDropInventory.GetPlayersInventoryItemDetails(player, data.dropEquipment)

    -- Get the number of items to drop this event.
    local itemCountToDrop
    if data.staticItemCount ~= nil then
        itemCountToDrop = data.staticItemCount
    else
        itemCountToDrop = math.max(1, math.floor(totalItemCount / (100 / data.dynamicPercentageItemCount)))
    end

    -- Only try and drop items if there are any to drop in the player's inventories. We want the code to keep on running for future iterations until the occurence count has completed.
    if totalItemCount > 0 then
        -- Drop the number of items from across the range of inventories based on their proportional sizes.
        -- Updates the item stats as it loops.
        itemCountDropped = 0
        local surface, position = player.surface, player.position
        while itemCountDropped < itemCountToDrop do
            -- Select the random item number to be dropped from all items.
            local itemNumberToDrop = math.random(1, totalItemCount)

            -- Find the inventory with this item number in it.
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
                Logging.LogPrint(ErrorMessageStart .. "didn't find item number " .. itemNumberToDrop .. " when looking over " .. player.name .. "'s inventories.")
                return
            end

            -- Find the name of the numbered item in the specific inventory
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
                Logging.LogPrint(ErrorMessageStart .. "didn't find item name for number " .. itemNumberToDrop .. " in " .. player.name .. "'s inventory id " .. inventoryNameOfItemNumberToDrop)
                return
            end

            -- Drop the specific item
            local itemStackToDropFrom  ---@type LuaItemStack
            if inventoryNameOfItemNumberToDrop == "cursorStack" then
                -- Special case as not a real inventory.
                itemStackToDropFrom = player.cursor_stack
            else
                local inventory = player.get_inventory(inventoryNameOfItemNumberToDrop)
                itemStackToDropFrom = inventory.find_item_stack(itemNameToDrop)
            end
            local itemStackToDropFrom_count = itemStackToDropFrom.count
            if itemStackToDropFrom_count == 1 then
                -- Single item in the stack so drop it and all done. This handles any extra attributes the stack may have naturally.
                surface.spill_item_stack(position, itemStackToDropFrom, false, nil, data.dropOnBelts)
                itemStackToDropFrom.count = 0
            else
                -- Multiple items in the stack so can just drop 1 copy of the stack details and remove 1 from count.
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

            -- Count that the item was dropped.
            itemCountDropped = itemCountDropped + 1
            totalItemCount = totalItemCount - 1

            -- If no items left stop trying to drop things this event and await the next one.
            if totalItemCount == 0 then
                itemCountDropped = itemCountToDrop
            end
        end
    end

    -- Schedule the next occurence if we haven't completed them all yet.
    data.currentoccurrences = data.currentoccurrences + 1
    if data.currentoccurrences < data.totaloccurrences then
        EventScheduler.ScheduleEvent(event.tick + data.gap, "PlayerDropInventory.PlayerDropItems_Scheduled", playerIndex, data)
    else
        PlayerDropInventory.StopEffectOnPlayer(playerIndex)
        game.print({"message.muppet_streamer_player_drop_inventory_stop", player.name})
    end
end

---@param event on_pre_player_died
PlayerDropInventory.OnPrePlayerDied = function(event)
    PlayerDropInventory.StopEffectOnPlayer(event.player_index)
end

---@parm playerIndex Id
PlayerDropInventory.StopEffectOnPlayer = function(playerIndex)
    if global.playerDropInventory.affectedPlayers[playerIndex] == nil then
        return
    end

    global.playerDropInventory.affectedPlayers[playerIndex] = nil
    EventScheduler.RemoveScheduledEvents("PlayerDropInventory.PlayerDropItems_Scheduled", playerIndex)
end

---@param player LuaPlayer
---@param includeEquipment boolean
---@return uint totalItemsCount
PlayerDropInventory.GetPlayersItemCount = function(player, includeEquipment)
    local totalItemsCount = 0
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
---@return table<defines.inventory, uint> inventoryItemCounts
---@return table<defines.inventory, table<string, uint>> inventoryContents
PlayerDropInventory.GetPlayersInventoryItemDetails = function(player, includeEquipment)
    local totalItemsCount = 0
    local inventoryItemCounts = {}
    local inventoryContents = {}
    for _, inventoryName in pairs({defines.inventory.character_main, defines.inventory.character_trash}) do
        local contents = player.get_inventory(inventoryName).get_contents()
        inventoryContents[inventoryName] = contents
        local inventoryTotalCount = 0
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
            local inventoryTotalCount = 0
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
