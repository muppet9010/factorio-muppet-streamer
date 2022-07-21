local PlayerDropInventory = {}
local CommandsUtils = require("utility.helper-utils.commands-utils")
local LoggingUtils = require("utility.helper-utils.logging-utils")
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
---@field totaloccurrences uint
---@field dropOnBelts boolean
---@field dropEquipment boolean
---@field staticItemCount uint|nil
---@field dynamicPercentageItemCount uint|nil
---@field currentoccurrences uint

---@alias PlayerDropInventory_InventoryItemCounts table<defines.inventory|'cursorStack', uint> @ Dictionary of each inventory to a cached total count across all items (count of each item all added togeather) were in that inventory.
---@alias PlayerDropInventory_InventoryContents table<defines.inventory|'cursorStack', table<string, uint>> @ Dictionary of each inventory to a cached list of item name and counts in that inventory.

local ErrorMessageStart = "ERROR: muppet_streamer_player_drop_inventory command " --TODO: replace me

PlayerDropInventory.CreateGlobals = function()
    global.playerDropInventory = global.playerDropInventory or {}
    global.playerDropInventory.affectedPlayers = global.playerDropInventory.affectedPlayers or {} ---@type table<uint, true> @ A dictionary of player indexs that have the effect active on them currently.
    global.playerDropInventory.nextId = global.playerDropInventory.nextId or 0 ---@type uint
end

PlayerDropInventory.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_player_drop_inventory", {"api-description.muppet_streamer_player_drop_inventory"}, PlayerDropInventory.PlayerDropInventoryCommand, true)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.PlayerDropItems_Scheduled", PlayerDropInventory.PlayerDropItems_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "PlayerDropInventory.OnPrePlayerDied", PlayerDropInventory.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.ApplyToPlayer", PlayerDropInventory.ApplyToPlayer)
end

---@param command CustomCommandData
PlayerDropInventory.PlayerDropInventoryCommand = function(command)
    local commandName = "muppet_streamer_player_drop_inventory"

    local commandData = CommandsUtils.GetSettingsTableFromCommandParamaterString(command.parameter, true, commandName, {"delay", "target", "quantityType", "quantityValue", "dropOnBelts", "gap", "occurrences", "dropEquipment"})
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
    if not CommandsUtils.CheckNumberArgument(gapSeconds, "double", true, commandName, "gap", 1, math.floor(MathUtils.uintMax / 60), command.parameter) then
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
        staticItemCount = math.max(1, math.floor(totalItemCount / (100 / data.quantityValue))) -- Output will always be a uint based on the input values prior valdiation.
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
        totaloccurrences = data.occurrences,
        dropOnBelts = data.dropOnBelts,
        dropEquipment = data.dropEquipment,
        staticItemCount = staticItemCount,
        dynamicPercentageItemCount = dynamicPercentageItemCount,
        currentoccurrences = 0
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

    --TODO: I don't understand what itemsCountsInInventories does. Work out and either remove or comment. The type def is based off code and may be wrong intentions.
    local totalItemCount, itemsCountsInInventories, inventoriesContents = PlayerDropInventory.GetPlayersInventoryItemDetails(player, data.dropEquipment)

    -- Get the number of items to drop this event.
    local itemCountToDrop
    if data.staticItemCount ~= nil then
        itemCountToDrop = data.staticItemCount
    else
        itemCountToDrop = math.max(1, math.floor(totalItemCount / (100 / data.dynamicPercentageItemCount))) --[[@as uint @ End value will always end up as a uint from the validated input values.]]
    end ---@cast itemCountToDrop - nil

    -- Only try and drop items if there are any to drop in the player's inventories. We want the code to keep on running for future iterations until the occurence count has completed.
    if totalItemCount > 0 then
        -- Drop the number of items from across the range of inventories based on their proportional sizes.
        -- Updates the item stats as it loops.
        local itemCountDropped = 0
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
                LoggingUtils.LogPrintError(ErrorMessageStart .. "didn't find item number " .. itemNumberToDrop .. " when looking over " .. player.name .. "'s inventories.")
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
                LoggingUtils.LogPrintError(ErrorMessageStart .. "didn't find item name for number " .. itemNumberToDrop .. " in " .. player.name .. "'s inventory id " .. inventoryNameOfItemNumberToDrop)
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
    EventScheduler.RemoveScheduledEvents("PlayerDropInventory.PlayerDropItems_Scheduled", playerIndex)
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
