local PlayerDropInventory = {} ---@class PlayerDropInventory
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Events = require("utility.manager-libraries.events")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")
local math_sin, math_cos, math_pi, math_random, math_sqrt, math_log, math_max = math.sin, math.cos, math.pi, math.random, math.sqrt, math.log, math.max

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
---@field gap uint # Must be > 0.
---@field occurrences uint
---@field dropEquipment boolean
---@field density double
---@field suppressMessages boolean

---@class PlayerDropInventory_ScheduledDropItemsData
---@field player_index uint
---@field player LuaPlayer
---@field gap uint # Must be > 0.
---@field totalOccurrences uint
---@field dropOnBelts boolean
---@field dropEquipment boolean
---@field staticItemCount uint|nil
---@field dynamicPercentageItemCount uint|nil
---@field currentOccurrences uint
---@field density double
---@field suppressMessages boolean

---@alias PlayerDropInventory_InventoryItemCounts table<defines.inventory|"cursorStack", uint> # Dictionary of each inventory to a cached total count across all items (count of each item all added together) were in that inventory.
---@alias PlayerDropInventory_InventoryContents table<defines.inventory|"cursorStack", table<string, uint>> # Dictionary of each inventory to a cached list of item name and counts in that inventory.

local commandName = "muppet_streamer_player_drop_inventory"

PlayerDropInventory.CreateGlobals = function()
    global.playerDropInventory = global.playerDropInventory or {}
    global.playerDropInventory.affectedPlayers = global.playerDropInventory.affectedPlayers or {} ---@type table<uint, true> # A dictionary of player indexes that have the effect active on them currently.
    global.playerDropInventory.nextId = global.playerDropInventory.nextId or 0 ---@type uint
end

PlayerDropInventory.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_player_drop_inventory", { "api-description.muppet_streamer_player_drop_inventory" }, PlayerDropInventory.PlayerDropInventoryCommand, true)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.PlayerDropItems_Scheduled", PlayerDropInventory.PlayerDropItems_Scheduled)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "PlayerDropInventory.OnPrePlayerDied", PlayerDropInventory.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("PlayerDropInventory.ApplyToPlayer", PlayerDropInventory.ApplyToPlayer)
    MOD.Interfaces.Commands.PlayerDropInventory = PlayerDropInventory.PlayerDropInventoryCommand
end

---@param command CustomCommandData
PlayerDropInventory.PlayerDropInventoryCommand = function(command)
    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "quantityType", "quantityValue", "dropOnBelts", "gap", "occurrences", "dropEquipment", "density", "suppressMessages" })
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
    local gap = math.floor(gapSeconds * 60) --[[@as uint # gapSeconds was validated as not exceeding a uint during input validation.]]

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

    local density = commandData.density
    if not CommandsUtils.CheckNumberArgument(density, "double", false, commandName, "density", 0, 10, command.parameter) then
        return
    end ---@cast density double
    if density == nil then
        density = 10
    end

    local distributionOuterDensity = commandData.distributionOuterDensity
    if not CommandsUtils.CheckNumberArgument(distributionOuterDensity, "double", false, commandName, "distributionOuterDensity", 0, 1, command.parameter) then
        return
    end ---@cast distributionOuterDensity double
    if distributionOuterDensity == nil then
        distributionOuterDensity = 0
    end

    local suppressMessages = commandData.suppressMessages
    if not CommandsUtils.CheckBooleanArgument(suppressMessages, false, commandName, "suppressMessages", command.parameter) then
        return
    end ---@cast suppressMessages boolean|nil
    if suppressMessages == nil then
        suppressMessages = false
    end

    global.playerDropInventory.nextId = global.playerDropInventory.nextId + 1
    ---@type PlayerDropInventory_ApplyDropItemsData
    local applyDropItemsData = { target = target, quantityType = quantityType, quantityValue = quantityValue, dropOnBelts = dropOnBelts, gap = gap, occurrences = occurrences, dropEquipment = dropEquipment, density = density, distributionOuterDensity = distributionOuterDensity, suppressMessages = suppressMessages }
    EventScheduler.ScheduleEventOnce(scheduleTick, "PlayerDropInventory.ApplyToPlayer", global.playerDropInventory.nextId, applyDropItemsData)
end

--- Prepare to apply the effect to the player.
PlayerDropInventory.ApplyToPlayer = function(event)
    local data = event.data ---@type PlayerDropInventory_ApplyDropItemsData

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    local targetPlayer_index = targetPlayer.index
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        -- Player not alive or in non playing mode.
        if not data.suppressMessages then game.print({ "message.muppet_streamer_player_drop_inventory_not_character_controller", data.target }) end
        return
    end

    -- If the effect is always set on this player don't start a new one.
    if global.playerDropInventory.affectedPlayers[targetPlayer_index] ~= nil then
        if not data.suppressMessages then game.print({ "message.muppet_streamer_duplicate_command_ignored", "Player Drop Inventory", data.target }) end
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
    if not data.suppressMessages then game.print({ "message.muppet_streamer_player_drop_inventory_start", targetPlayer.name }) end
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
        currentOccurrences = 0,
        density = data.density,
        suppressMessages = data.suppressMessages
    }
    PlayerDropInventory.PlayerDropItems_Scheduled({ tick = event.tick, instanceId = scheduledDropItemsData.player_index, data = scheduledDropItemsData })
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

        -- Cap the itemCountToDrop at the totalItemCount if it's lower. Makes later logic simpler.
        itemCountToDrop = math.min(itemCountToDrop, totalItemCount)
    else
        itemCountToDrop = math.max(1, math.floor(totalItemCount / (100 / data.dynamicPercentageItemCount))) --[[@as uint # End value will always end up as a uint from the validated input values.]]
    end ---@cast itemCountToDrop -nil

    -- Only try and drop items if there are any to drop in the player's inventories. We want the code to keep on running for future iterations until the occurrence count has completed.
    if totalItemCount > 0 and itemCountToDrop > 0 then
        local surface = player.surface
        local player_position = player.position
        local centerPosition_x, centerPosition_y = player_position.x, player_position.y
        local maxRadius = math.sqrt(itemCountToDrop) * 0.7 -- The larger this multiplier is the more spread out items are. However too small a value leads to them being bunched up around the center when very large numbers of items are dropped.

        -- We have to invert the number as in code lower is more dense, but that doesn't make sense in a command configuration situation.
        -- Max non overlapping density is 0.075 at max radius increase and result radius offset.
        local density = (10 - data.density) + 0.075

        -- Standard position and drop on ground tables that I just update rather than create. Should save UPS and LuaGarbage collection.
        local position, itemToDrop = {}, { count = 1 }
        -- Standard variables used in the loop per item being dropped.
        local itemStackToDropFrom, itemStackToDropFrom_count, itemToPlaceOnGround, angle, radius
        local math_pi_x2 = math_pi * 2

        -- Get a sorted list of the random item numbers across all inventories we are going to drop. Duplicates can be supported as we will reduce the item count from cache and local variables when we drop each item. These numbers are all manipulated post selection to account for the reduced items in inventories as previous items are dropped.
        -- CODE NOTE: this logic isn't quite right, but it does handle duplicate random numbers by just selecting the next one. Also handles the fact we select all of the items from a full list, but we iterate through the items from low to high and thus the selected item numbers to be dropped have to be kept within the remaining total as we work through the items. Its likely not perfectly random, but in testing it looks pretty even across the many item stacks.
        local itemNumbersToBeDropped = {} ---@type table<int, int>
        for i = 1, itemCountToDrop do
            itemNumbersToBeDropped[i] = math_random(1, totalItemCount)
        end
        table.sort(itemNumbersToBeDropped)
        local newNumber
        local lastItemNumber = 1
        for i, number in pairs(itemNumbersToBeDropped) do
            newNumber = math_max(number - (i - 1), lastItemNumber) ---@type int
            lastItemNumber = newNumber
            itemNumbersToBeDropped[i] = newNumber
        end

        -- Set up the initial values before starting to hunt for the item numbers.
        local inventoryNameOfItemNumberToDrop = next(itemsCountsInInventories)
        local countInInventory = itemsCountsInInventories[inventoryNameOfItemNumberToDrop]
        local itemCountedUpTo, inventoryTotalCountedUpTo = 0, 0
        local inventoryContents = inventoriesContents[inventoryNameOfItemNumberToDrop]
        local itemNameToDrop = next(inventoryContents)
        local itemCount = inventoryContents[itemNameToDrop]

        -- Set initial cached LuaObjects used when placing entities on the ground. "cursorStack" is a special case and we don't use the inventory variable there, so just don't update it.
        -- CODE NOTE: this is technically wasteful as its likely the first item to be dropped won't be from the first item in the first inventory, but its only 1 or 2 API calls and makes the looping code simpler.
        local inventory
        if inventoryNameOfItemNumberToDrop ~= "cursorStack" then
            ---@cast inventoryNameOfItemNumberToDrop defines.inventory # "cursorStack" has separate if/else leg.
            inventory = player.get_inventory(inventoryNameOfItemNumberToDrop)
            if inventory == nil then
                CommandsUtils.LogPrintError(commandName, nil, "didn't find inventory id " .. inventoryNameOfItemNumberToDrop .. "' for " .. player.name, nil)
                return
            end
        end

        -- Work over the items numbers to be dropped. Increment the inventories as required and drop the item when found. As we drop in a random location from player the order dropped doesn't matter.
        for _, itemNumberToDrop in pairs(itemNumbersToBeDropped) do
            -- Check if the current inventory has the item number we want within it, otherwise cycle to the correct one.
            if inventoryTotalCountedUpTo + countInInventory < itemNumberToDrop then
                -- Item not in this inventory so cycle to the correct inventory.
                while inventoryTotalCountedUpTo + countInInventory < itemNumberToDrop do
                    inventoryTotalCountedUpTo = inventoryTotalCountedUpTo + countInInventory
                    inventoryNameOfItemNumberToDrop = next(itemsCountsInInventories, inventoryNameOfItemNumberToDrop)

                    if inventoryNameOfItemNumberToDrop == nil then
                        -- Run out of inventories to iterate through, ERROR.
                        CommandsUtils.LogPrintError(commandName, nil, "run out of inventories to search before finding item number " .. itemNumberToDrop .. " for " .. player.name, nil)
                        return
                    end
                    countInInventory = itemsCountsInInventories[inventoryNameOfItemNumberToDrop]
                end

                -- Correct inventory found, so update our starting positions to the start of this inventory.
                inventoryContents = inventoriesContents[inventoryNameOfItemNumberToDrop]
                itemNameToDrop = next(inventoryContents)
                itemCount = inventoryContents[itemNameToDrop]
                itemCountedUpTo = inventoryTotalCountedUpTo

                -- Update cached LuaObjects used when placing entities on the ground.
                if inventoryNameOfItemNumberToDrop ~= "cursorStack" then
                    -- Standard case for all real inventories.
                    ---@cast inventoryNameOfItemNumberToDrop defines.inventory # "cursorStack" has separate if/else leg.
                    inventory = player.get_inventory(inventoryNameOfItemNumberToDrop)
                    if inventory == nil then
                        CommandsUtils.LogPrintError(commandName, nil, "didn't find inventory id " .. inventoryNameOfItemNumberToDrop .. "' for " .. player.name, nil)
                        return
                    end
                end
                itemStackToDropFrom = nil
            end

            -- Decrease this inventories cached total count by 1 as we will be removing an item from it.
            countInInventory = countInInventory - 1
            itemsCountsInInventories[inventoryNameOfItemNumberToDrop] = countInInventory

            -- Check if the current item is the item type we want, otherwise cycle to the correct one.
            if itemCountedUpTo + itemCount < itemNumberToDrop then
                -- Find the specific item in this inventory details if the current item doesn't include the required count.
                while itemCountedUpTo + itemCount < itemNumberToDrop do
                    itemCountedUpTo = itemCountedUpTo + itemCount
                    itemNameToDrop = next(inventoryContents, itemNameToDrop)
                    if itemNameToDrop == nil then
                        -- Run out of items in this this inventory to iterate through, ERROR.
                        CommandsUtils.LogPrintError(commandName, nil, "didn't find item number " .. itemNumberToDrop .. " in " .. player.name .. "'s inventory id " .. inventoryNameOfItemNumberToDrop, nil)
                        return
                    end
                    itemCount = inventoryContents[itemNameToDrop]
                end

                -- Update cached LuaObjects used when placing entities on the ground.
                itemStackToDropFrom = nil
            end

            -- Decrease the cached item count by 1 as we will be removing an item from it.
            itemCount = itemCount - 1
            inventoryContents[itemNameToDrop] = itemCount

            -- Obtain the specific LuaItemStack having an item being dropped from it if we don't already have it.
            if itemStackToDropFrom == nil then
                if inventoryNameOfItemNumberToDrop == "cursorStack" then
                    -- Special case as not a real inventory.
                    itemStackToDropFrom = player.cursor_stack ---@cast itemStackToDropFrom -nil # We know the cursor_stack is populated if its gone down this logic path.
                else
                    -- Standard case for all other inventories.
                    itemStackToDropFrom = inventory.find_item_stack(itemNameToDrop)
                    if itemStackToDropFrom == nil then
                        CommandsUtils.LogPrintError(commandName, nil, "didn't find item stack for item '" .. itemNameToDrop .. "' in " .. player.name .. "'s inventory id " .. inventoryNameOfItemNumberToDrop, nil)
                        return
                    end
                end
            end

            -- Create the details of the item to be dropped.
            itemStackToDropFrom_count = itemStackToDropFrom.count
            if itemStackToDropFrom_count == 1 then
                -- Single item in the itemStack so drop it and all done. This handles any extra attributes the itemStack may have naturally.
                itemToPlaceOnGround = itemStackToDropFrom
            else
                -- Multiple items in the itemStack so can just drop 1 copy of the itemStack details and remove 1 from count.
                -- CODE NOTE: ItemStacks are grouped by Factorio in to full health or damaged (health averaged across all items in itemStack).
                -- CODE NOTE: ItemStacks have a single durability and ammo stat which effectively is for the first item in the itemStack, with the other items in the itemStack all being full.
                -- CODE NOTE: when the itemStack's count is reduced by 1 the itemStacks durability and ammo fields are reset to full. As the first item is considered to be the partially used items.
                itemToDrop.name = itemStackToDropFrom.name
                itemToDrop.health = itemStackToDropFrom.health
                itemToDrop.durability = itemStackToDropFrom.durability
                if itemStackToDropFrom.type == "ammo" then
                    itemToDrop.ammo = itemStackToDropFrom.ammo
                else
                    itemToDrop.ammo = nil
                end
                if itemStackToDropFrom.is_item_with_tags then
                    itemToDrop.tags = itemStackToDropFrom.tags
                else
                    itemToDrop.ammo = nil
                end
                itemToPlaceOnGround = itemToDrop
            end

            -- Work out where to put the item on the ground.
            angle = math_pi_x2 * math_random()
            radius = (maxRadius * math_sqrt(-density * math_log(math_random()))) + 2
            position.x = centerPosition_x + radius * math_cos(angle)
            position.y = centerPosition_y + radius * math_sin(angle)
            surface.spill_item_stack(position, itemToPlaceOnGround, false, nil, data.dropOnBelts)

            -- Remove 1 from the source item stack. This may make it 0, so have to this after placing it on the ground as in some cases we reference it.
            itemStackToDropFrom.count = itemStackToDropFrom_count - 1
            if itemStackToDropFrom_count - 1 == 0 then
                itemStackToDropFrom = nil
            end
        end
    end

    -- Schedule the next occurrence if we haven't completed them all yet.
    data.currentOccurrences = data.currentOccurrences + 1
    if data.currentOccurrences < data.totalOccurrences then
        EventScheduler.ScheduleEventOnce(event.tick + data.gap, "PlayerDropInventory.PlayerDropItems_Scheduled", playerIndex, data)
    else
        PlayerDropInventory.StopEffectOnPlayer(playerIndex)
        if not data.suppressMessages then game.print({ "message.muppet_streamer_player_drop_inventory_stop", player.name }) end
    end
end

---@param event on_pre_player_died
PlayerDropInventory.OnPrePlayerDied = function(event)
    PlayerDropInventory.StopEffectOnPlayer(event.player_index)
end

---@param playerIndex uint
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
    for _, inventoryName in pairs({ defines.inventory.character_main, defines.inventory.character_trash }) do
        for _, count in pairs(player.get_inventory(inventoryName).get_contents()) do
            totalItemsCount = totalItemsCount + count
        end
    end
    local cursorStack = player.cursor_stack
    if cursorStack ~= nil and cursorStack.valid_for_read then
        totalItemsCount = totalItemsCount + cursorStack.count
    end

    if includeEquipment then
        for _, inventoryName in pairs({ defines.inventory.character_armor, defines.inventory.character_guns, defines.inventory.character_ammo }) do
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
    for _, inventoryName in pairs({ defines.inventory.character_main, defines.inventory.character_trash }) do
        local inventory = player.get_inventory(inventoryName) ---@cast inventory - nil
        inventoryContents[inventoryName] = inventory.get_contents()
        local inventoryTotalCount = inventory.get_item_count()
        totalItemsCount = totalItemsCount + inventoryTotalCount
        inventoryItemCounts[inventoryName] = inventoryTotalCount
    end
    local cursorStack = player.cursor_stack
    if cursorStack ~= nil and cursorStack.valid_for_read then
        local count = cursorStack.count
        totalItemsCount = totalItemsCount + count
        inventoryItemCounts["cursorStack"] = count
        inventoryContents["cursorStack"] = { [cursorStack.name] = count }
    end

    if includeEquipment then
        for _, inventoryName in pairs({ defines.inventory.character_armor, defines.inventory.character_guns, defines.inventory.character_ammo }) do
            local inventory = player.get_inventory(inventoryName) ---@cast inventory - nil
            inventoryContents[inventoryName] = inventory.get_contents()
            local inventoryTotalCount = inventory.get_item_count()
            totalItemsCount = totalItemsCount + inventoryTotalCount
            inventoryItemCounts[inventoryName] = inventoryTotalCount
        end
    end

    return totalItemsCount, inventoryItemCounts, inventoryContents
end

return PlayerDropInventory
