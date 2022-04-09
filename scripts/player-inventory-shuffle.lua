local PlayerInventoryShuffle = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local math_random, math_min, math_max, math_floor, math_ceil = math.random, math.min, math.max, math.floor, math.ceil

local ErrorMessageStart = "ERROR: muppet_streamer_player_inventory_shuffle command "
local debugStatusMessages = true

PlayerInventoryShuffle.CreateGlobals = function()
    global.playerInventoryShuffle = global.playerInventoryShuffle or {}
    global.playerInventoryShuffle.nextId = global.playerInventoryShuffle.nextId or 0
end

PlayerInventoryShuffle.OnLoad = function()
    Commands.Register("muppet_streamer_player_inventory_shuffle", {"api-description.muppet_streamer_player_inventory_shuffle"}, PlayerInventoryShuffle.PlayerInventoryShuffleCommand, true)
    EventScheduler.RegisterScheduledEventType("PlayerInventoryShuffle.MixupPlayerInventories", PlayerInventoryShuffle.MixupPlayerInventories)
end

---@param command CustomCommandData
PlayerInventoryShuffle.PlayerInventoryShuffleCommand = function(command)
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
        delay = math_max(delay * 60, 0)
    end

    local targets = commandData.targets ---@type string
    if targets == nil then
        Logging.LogPrint(ErrorMessageStart .. "targets is mandatory")
        return
    end
    -- Can't check if the names are valid players as they may just not have joined the server yet, but may in the future.
    local playerNames = Utils.SplitStringOnCharacters(targets, ",", false) ---@type string[]
    if #playerNames == 1 then
        -- If it's only one name then it must be ALL, otherwise its a bad argument as will do nothing.
        if playerNames[1] == "[ALL]" then
            playerNames = nil
        else
            Logging.LogPrint(ErrorMessageStart .. "targets was supplied with only 1 name, but it wasn't the special ALL. It was: " .. targets)
            return
        end
    end

    local includeEquipmentString = commandData.includeEquipment
    local includeEquipment  ---@type boolean
    if includeEquipmentString == nil then
        includeEquipment = true
    else
        includeEquipment = Utils.ToBoolean(includeEquipmentString)
        if includeEquipment == nil then
            Logging.LogPrint(ErrorMessageStart .. "if includeEquipment is supplied it must be a boolean.")
            return
        end
    end

    local destinationPlayersMinimumVarianceString = commandData.destinationPlayersMinimumVariance
    local destinationPlayersMinimumVariance  ---@type uint
    if destinationPlayersMinimumVarianceString == nil then
        destinationPlayersMinimumVariance = 1
    else
        destinationPlayersMinimumVariance = Utils.ToNumber(destinationPlayersMinimumVarianceString)
        if destinationPlayersMinimumVariance == nil then
            Logging.LogPrint(ErrorMessageStart .. "if destinationPlayersMinimumVariance is supplied it must be a number.")
            return
        end
        destinationPlayersMinimumVariance = math_floor(destinationPlayersMinimumVariance)
        if destinationPlayersMinimumVariance < 0 then
            Logging.LogPrint(ErrorMessageStart .. "destinationPlayersMinimumVariance must be a number >= 0.")
            return
        end
    end

    local destinationPlayersVarianceFactorString = commandData.destinationPlayersVarianceFactor
    local destinationPlayersVarianceFactor  ---@type uint
    if destinationPlayersVarianceFactorString == nil then
        destinationPlayersVarianceFactor = 0.25
    else
        destinationPlayersVarianceFactor = Utils.ToNumber(destinationPlayersVarianceFactorString)
        if destinationPlayersVarianceFactor == nil then
            Logging.LogPrint(ErrorMessageStart .. "if destinationPlayersVarianceFactor is supplied it must be a number.")
            return
        end
        if destinationPlayersVarianceFactor < 0 then
            Logging.LogPrint(ErrorMessageStart .. "destinationPlayersVarianceFactor must be a number >= 0.")
            return
        end
    end

    local recipientItemMinToMaxRatioString = commandData.recipientItemMinToMaxRatio
    local recipientItemMinToMaxRatio  ---@type uint
    if recipientItemMinToMaxRatioString == nil then
        recipientItemMinToMaxRatio = 4
    else
        recipientItemMinToMaxRatio = Utils.ToNumber(recipientItemMinToMaxRatioString)
        if recipientItemMinToMaxRatio == nil then
            Logging.LogPrint(ErrorMessageStart .. "if recipientItemMinToMaxRatio is supplied it must be a number.")
            return
        end
        recipientItemMinToMaxRatio = math_floor(recipientItemMinToMaxRatio)
        if recipientItemMinToMaxRatio < 1 then
            Logging.LogPrint(ErrorMessageStart .. "recipientItemMinToMaxRatio must be a number >= 1.")
            return
        end
    end

    global.playerInventoryShuffle.nextId = global.playerInventoryShuffle.nextId + 1
    ---@class PlayerInventoryShuffle_RequestData
    local data = {
        playerNames = playerNames,
        includeEquipment = includeEquipment,
        destinationPlayersMinimumVariance = destinationPlayersMinimumVariance,
        destinationPlayersVarianceFactor = destinationPlayersVarianceFactor,
        recipientItemMinToMaxRatio = recipientItemMinToMaxRatio
    }
    EventScheduler.ScheduleEvent(command.tick + delay, "PlayerInventoryShuffle.MixupPlayerInventories", global.playerInventoryShuffle.nextId, data)
end

PlayerInventoryShuffle.MixupPlayerInventories = function(event)
    local data = event.data ---@type PlayerInventoryShuffle_RequestData

    -- Get the active players to shuffle.
    local players  ---@type LuaPlayer[]
    if data.playerNames == nil then
        for _, player in pairs(game.connected_players) do
            if player.controller_type == defines.controllers.character and player.character ~= nil and player.character.valid then
                table.insert(players, player)
            end
        end
    else
        players = {}
        local player  ---@type LuaPlayer
        for _, playerName in pairs(data.playerNames) do
            player = game.get_player(playerName)
            if player ~= nil and player.connected and player.controller_type == defines.controllers.character and player.character ~= nil and player.character.valid then
                table.insert(players, player)
            end
        end
    end

    -- TODO: faked for testing, input items will be single copy, but output will be split across the 3 in code side.
    players = {game.players[1], game.players[1], game.players[1]}

    local playersCount = #players
    if playersCount <= 1 then
        game.print({"message.muppet_streamer_player_inventory_shuffle_not_enough_players"})
        return
    end

    -- Track the number of player sources for each item type when moving the items in to the shared inventory.
    local storageInventory = game.create_inventory(65535)
    local itemSources = {} ---@type table<string, int>, uint
    local inventoryNamesToCheck  ---@typelist defines.inventory[], LuaItemStack
    if data.includeEquipment then
        inventoryNamesToCheck = {defines.inventory.character_main, defines.inventory.character_trash, defines.inventory.character_armor, defines.inventory.character_guns, defines.inventory.character_ammo}
    else
        inventoryNamesToCheck = {defines.inventory.character_main, defines.inventory.character_trash}
    end
    ---@typelist LuaItemStack, LuaInventory, string
    local playerInventoryStack, playersInventory, stackItemName
    -- Loop over each player.
    for _, player in pairs(players) do
        -- Return the players cursor stack to their inventory before handling.
        player.clear_cursor()

        -- Move each inventory for this player.
        for _, inventoryName in pairs(inventoryNamesToCheck) do
            playersInventory = player.get_inventory(inventoryName)
            -- Move each item stack in the inventory. As this is a players inventory there could be filtered item stacks at the end.
            for i = 1, #playersInventory do
                playerInventoryStack = playersInventory[i] ---@type LuaItemStack
                if playerInventoryStack.valid_for_read then
                    stackItemName = playerInventoryStack.name
                    if itemSources[stackItemName] == nil then
                        itemSources[stackItemName] = 1
                    else
                        itemSources[stackItemName] = itemSources[stackItemName] + 1
                    end
                    storageInventory.insert(playerInventoryStack) -- This effectively sorts and merges the inventory as its made.
                end
            end
            playersInventory.clear()
        end
    end

    -- Set up the main player variable arrays, these are references to the players variable index and not the actual LuaPlayer index value.
    local itemsToDistribute = storageInventory.get_contents()
    local playersItemCounts = {} ---@type table<uint, table<string, uint>> @ A list of the players list index to the item names and counts. Not related to actual LuaPlayers indexs, but instead the position the LuaPlayer has in the players variable list.
    local playersIndexsList = {} ---@type uint[] @ A list of the players list index. Copies of this are taken per item and those copies are trimmed.
    for i = 1, playersCount do
        playersItemCounts[i] = {}
        playersIndexsList[i] = i
    end

    -- Work out the distribution of items to players.
    ---@typelist uint, uint, double, double[], double, uint, double, uint[], uint, uint, uint, uint, uint
    local sourcesCount, destinationCount, totalAssignedPercentage, destinationPercentages, standardisedPercentageModifier, itemsLeftToAssign, destinationPercentage, playersAvailableToRecieveThisItem, playerIndex, playerIndexListIndex, itemCountForPlayerIndex, destinationCountMin, destinationCountMax
    for itemName, itemCount in pairs(itemsToDistribute) do
        sourcesCount = itemSources[stackItemName]

        -- Destination count is the number of sources clamped between 1 and number of players. It's the source player count and a random +/- of the greatest between the ItemDestinationPlayerCountRange and destinationPlayersMinimumVariance.
        destinationCountMin = math_min(-data.destinationPlayersMinimumVariance, -math_floor((sourcesCount * data.destinationPlayersVarianceFactor)))
        destinationCountMax = math_max(data.destinationPlayersMinimumVariance, math_ceil((sourcesCount * data.destinationPlayersVarianceFactor)))
        destinationCount = math_min(math_max(sourcesCount + math_random(destinationCountMin, destinationCountMax), 1), playersCount)

        -- Work out the raw percentage of items each destination will get.
        totalAssignedPercentage, destinationPercentages = 0, {}
        for i = 1, destinationCount do
            destinationPercentage = math_random(1, data.recipientItemMinToMaxRatio)
            destinationPercentages[i] = destinationPercentage
            totalAssignedPercentage = totalAssignedPercentage + destinationPercentage
        end
        standardisedPercentageModifier = 1 / totalAssignedPercentage

        -- Work out how many items each destination will get and assign them to a specific players list index.
        itemsLeftToAssign = itemCount
        playersAvailableToRecieveThisItem = Utils.DeepCopy(playersIndexsList)
        for i = 1, destinationCount do
            -- Select a random players list index from those not yet assigned this item and then remove it from the avialable list.
            playerIndexListIndex = math_random(1, #playersAvailableToRecieveThisItem)
            playerIndex = playersAvailableToRecieveThisItem[playerIndexListIndex]
            table.remove(playersAvailableToRecieveThisItem, playerIndexListIndex)

            -- Record how many actual items this player index will get.
            if i == destinationCount then
                -- Is last slot so just add all that are remaning.
                itemCountForPlayerIndex = itemsLeftToAssign
            else
                -- Round down the initial number and then keep it below the number of items left. Never try to use more than are left to assign.
                itemCountForPlayerIndex = math_min(math_max(math_floor(destinationPercentages[i] * standardisedPercentageModifier * itemsLeftToAssign), 1), itemsLeftToAssign)
            end
            itemsLeftToAssign = itemsLeftToAssign - itemCountForPlayerIndex
            playersItemCounts[playerIndex][itemName] = itemCountForPlayerIndex

            if itemsLeftToAssign == 0 then
                -- All of this item type assigned so stop.
                break
            end
        end
    end

    -- Distribute the items to the actual players.
    local playerIndexsWithFreeInventorySpace = Utils.DeepCopy(players) ---@type table<uint, LuaPlayer>|LuaPlayer[] -- Starts as a table as we remove keys without re-ordering. Later on it is rebuilt as an array and then managed as such (remove() not =nil).
    for i, playerItemCounts in pairs(playersItemCounts) do
        local player = players[i]
        for itemName, itemCount in pairs(playerItemCounts) do
            local playersInventoryIsFull = PlayerInventoryShuffle.InsertItemsInToPlayer(storageInventory, itemName, itemCount, player)
            if playersInventoryIsFull then
                -- Player's inventory is full so stop trying to add more things to do. Will catch the left over items in the storage inventory later.
                playerIndexsWithFreeInventorySpace[i] = nil -- This will make it a gappy array, but we will squash it down later.
                Logging.LogPrint("Player list index " .. i .. "'s inventory is full", debugStatusMessages)
                break
            end
        end
    end

    -- Check the storage inventory is empty, distribute anything left or just dump it on the ground.
    local itemsLeftInStorage = storageInventory.get_contents()
    if next(itemsLeftInStorage) ~= nil then
        -- playerIndexsWithFreeInventorySpace is a gappy array so have to make it consistent to allow easier usage in this phase.
        local gappyPlayerIndexsWithFreeInventorySpace = playerIndexsWithFreeInventorySpace
        playerIndexsWithFreeInventorySpace = {}
        for _, player in pairs(gappyPlayerIndexsWithFreeInventorySpace) do
            table.insert(playerIndexsWithFreeInventorySpace, player)
        end

        -- Try and shove the items in players inventories that aren't full first
        local playersInventoryIsFull
        for itemName, itemCount in pairs(itemsLeftInStorage) do
            -- Keep on trying to insert these items across all available players until its all inserted or no players have any room left.
            while itemCount > 0 do
                if #playerIndexsWithFreeInventorySpace == 0 then
                    -- No more players with free inventory space so stop this item.
                    break
                end
                local playerListIndex = math_random(1, #playerIndexsWithFreeInventorySpace)
                local player = playerIndexsWithFreeInventorySpace[playerListIndex]
                playersInventoryIsFull, itemCount = PlayerInventoryShuffle.InsertItemsInToPlayer(storageInventory, itemName, itemCount, player)
                if playersInventoryIsFull then
                    -- Player's inventory is full so prevent trying to add anything else to this player in the future.
                    table.remove(playerIndexsWithFreeInventorySpace, playerListIndex)
                end
            end

            if #playerIndexsWithFreeInventorySpace == 0 then
                -- No more players with free inventory space so stop all items.
                break
            end
        end

        -- Check if anything is still left, if it is just dump it on the ground so its not lost.
        itemsLeftInStorage = storageInventory.get_contents()
        if next(itemsLeftInStorage) ~= nil then
            -- Just drop it all on the floor at player 1's feet. No need to remove it from the inventory as we will destroy it next.
            Logging.LogPrint(ErrorMessageStart .. "stuff left to be distributed, dumped at player " .. players[1].name .. "'s feet.")
            storageInventory.sort_and_merge()
            local storageItemStack  ---@type LuaItemStack
            local position, surface = players[1].position, players[1].surface
            for i = 1, #storageInventory do
                storageItemStack = storageInventory[i]
                if storageItemStack.valid_for_read then
                    surface.spill_item_stack(position, storageItemStack, false, nil, false)
                else
                    -- As we sorted and merged all the items are at the start and all the free space at the end. So no need to check each free slot.
                    break
                end
            end
        end
    end

    -- Remove the now empty storage inventory
    storageInventory.destroy()

    -- Announce that the shuffle has been done and to which active players.
    local playerNamePrettyList
    if data.playerNames == nil then
        -- Is all active players.
        playerNamePrettyList = {"message.muppet_streamer_player_inventory_shuffle_all_players"}
    else
        playerNamePrettyList = ""
        for _, player in pairs(players) do
            playerNamePrettyList = playerNamePrettyList .. ", " .. player.name
        end
        -- Remove leading comma and space
        playerNamePrettyList = string.sub(playerNamePrettyList, 3)
    end
    game.print({"message.muppet_streamer_player_inventory_shuffle_start", playerNamePrettyList})
end

--- Try and insert the item count in to the player from the storage inventory.
---@param storageInventory LuaInventory
---@param itemName string
---@param itemCount uint
---@param player LuaPlayer
---@return boolean playersInventoryIsFull
---@return uint itemCountNotInserted
PlayerInventoryShuffle.InsertItemsInToPlayer = function(storageInventory, itemName, itemCount, player)
    ---@typelist LuaItemStack, uint, boolean, ItemStackDefinition, uint
    local itemStackToTakeFrom, itemsInserted, itemToInsert, itemCountToTakeFromThisStack
    local playersInventoryIsFull = false

    -- Keep on taking items from the storage inventories stacks until we have moved the required number of items or filled up the player's inventory.
    while itemCount > 0 do
        itemStackToTakeFrom = storageInventory.find_item_stack(itemName)
        itemStackToTakeFrom_count = itemStackToTakeFrom.count
        itemCountToTakeFromThisStack = math_min(itemCount, itemStackToTakeFrom_count)

        if itemCountToTakeFromThisStack == itemStackToTakeFrom_count then
            -- We want the whole stack so just transfer it and all done. This handles any extra attributes the stack may have naturally.
            itemsInserted = player.insert(itemStackToTakeFrom)
            if itemsInserted ~= itemCountToTakeFromThisStack then
                playersInventoryIsFull = true
            end
        else
            -- We want some of the items from the stack, so add the required number with attributes to the player.
            itemToInsert = {name = itemName, count = itemCountToTakeFromThisStack, health = itemStackToTakeFrom.health, durability = itemStackToTakeFrom.durability}
            if itemStackToTakeFrom.type == "ammo" then
                itemToInsert.ammo = itemStackToTakeFrom.ammo
            end
            if itemStackToTakeFrom.is_item_with_tags then
                itemToInsert.tags = itemStackToTakeFrom.tags
            end
            itemsInserted = player.insert(itemToInsert)
            if itemsInserted ~= itemCountToTakeFromThisStack then
                playersInventoryIsFull = true
            end
        end

        -- Update the old storage stack count for how many we removed.
        itemStackToTakeFrom.count = itemStackToTakeFrom_count - itemsInserted

        -- Update the count remaining to be moved based on how many were actually moved.
        itemCount = itemCount - itemsInserted

        if playersInventoryIsFull then
            break
        end
    end

    return playersInventoryIsFull, itemCount
end

return PlayerInventoryShuffle
