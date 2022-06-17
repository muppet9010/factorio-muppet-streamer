local PlayerInventoryShuffle = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Colors = require("utility.colors")
local math_random, math_min, math_max, math_floor, math_ceil = math.random, math.min, math.max, math.floor, math.ceil

local ErrorMessageStart = "ERROR: muppet_streamer_player_inventory_shuffle command "
local StorageInventorySizeIncrements = 1000 -- The starting size of the shared storage invnetory and how much it grows each time. Vanilla players only have 160~ max inventory space across all their inventories.
local StorageInventoryMaxGrowthSize = 65535 - StorageInventorySizeIncrements

------------------------        DEBUG OPTIONS - MAKE SURE ARE FALE ON RELEASE       ------------------------
local debugStatusMessages = false
local singlePlayerTesting = false -- Set to TRUE to force the mod to work for one player with false copies of the one player.

---@alias PlayerInventoryShuffle_playersItemCounts table<uint, PlayerInventoryShuffle_orderedItemCounts>

---@alias PlayerInventoryShuffle_orderedItemCounts table<uint, PlayerInventoryShuffle_itemCounts>

---@class PlayerInventoryShuffle_itemCounts
---@field name string
---@field count uint

---@class PlayerInventoryShuffle_RequestData
---@field playerNames string[]
---@field includeEquipment boolean
---@field destinationPlayersMinimumVariance uint
---@field destinationPlayersVarianceFactor double
---@field recipientItemMinToMaxRatio uint

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
        Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
        return
    end

    local delay = 0
    if commandData.delay ~= nil then
        delay = tonumber(commandData.delay)
        if delay == nil then
            Logging.LogPrint(ErrorMessageStart .. "delay is Optional, but must be a non-negative number if supplied")
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
        delay = math_max(delay * 60, 0)
    end

    local targets = commandData.targets ---@type string
    if targets == nil then
        Logging.LogPrint(ErrorMessageStart .. "targets is mandatory")
        Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
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
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
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
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
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
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
        destinationPlayersMinimumVariance = math_floor(destinationPlayersMinimumVariance)
        if destinationPlayersMinimumVariance < 0 then
            Logging.LogPrint(ErrorMessageStart .. "destinationPlayersMinimumVariance must be a number >= 0.")
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
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
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
        if destinationPlayersVarianceFactor < 0 then
            Logging.LogPrint(ErrorMessageStart .. "destinationPlayersVarianceFactor must be a number >= 0.")
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
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
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
        recipientItemMinToMaxRatio = math_floor(recipientItemMinToMaxRatio)
        if recipientItemMinToMaxRatio < 1 then
            Logging.LogPrint(ErrorMessageStart .. "recipientItemMinToMaxRatio must be a number >= 1.")
            Logging.LogPrint(ErrorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    global.playerInventoryShuffle.nextId = global.playerInventoryShuffle.nextId + 1
    EventScheduler.ScheduleEvent(
        command.tick + delay,
        "PlayerInventoryShuffle.MixupPlayerInventories",
        global.playerInventoryShuffle.nextId,
        {
            playerNames = playerNames,
            includeEquipment = includeEquipment,
            destinationPlayersMinimumVariance = destinationPlayersMinimumVariance,
            destinationPlayersVarianceFactor = destinationPlayersVarianceFactor,
            recipientItemMinToMaxRatio = recipientItemMinToMaxRatio
        }
    )
end

PlayerInventoryShuffle.MixupPlayerInventories = function(event)
    local requestData = event.data ---@type PlayerInventoryShuffle_RequestData

    -- Get the active players to shuffle.
    local players = {} ---@type LuaPlayer[]
    if requestData.playerNames == nil then
        for _, player in pairs(game.connected_players) do
            if player.controller_type == defines.controllers.character and player.character ~= nil and player.character.valid then
                table.insert(players, player)
            end
        end
    else
        local player  ---@type LuaPlayer
        for _, playerName in pairs(requestData.playerNames) do
            player = game.get_player(playerName)
            if player ~= nil and player.connected and player.controller_type == defines.controllers.character and player.character ~= nil and player.character.valid then
                table.insert(players, player)
            end
        end
    end

    if singlePlayerTesting then
        -- Fakes the only player as multiple players so that the 1 players invnetory is spread across these multiple fake players, but still all ends up inside the single real player's inventory.
        players = {game.players[1], game.players[1], game.players[1]}
    end

    -- Check that there are the minimum of 2 players to shuffle.
    if #players <= 1 then
        game.print({"message.muppet_streamer_player_inventory_shuffle_not_enough_players"})
        return
    end

    -- Announce that the shuffle is being done and to which active players.
    local playerNamePrettyList
    if requestData.playerNames == nil then
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

    -- Do the collection and distribution.
    local storageInventory, itemSources = PlayerInventoryShuffle.CollectPlayerItems(players, requestData)
    local playersItemCounts = PlayerInventoryShuffle.CalculateItemDistribution(storageInventory, itemSources, requestData, #players)
    local playerIndexsWithFreeInventorySpace_table = PlayerInventoryShuffle.DistributePlannedItemsToPlayers(storageInventory, players, playersItemCounts)
    PlayerInventoryShuffle.DistributeRemainingItemsAnywhere(storageInventory, players, playerIndexsWithFreeInventorySpace_table)

    -- Remove the now empty storage inventory
    storageInventory.destroy()
end

--- Collect all the items from the players in to the storage inventory.
---@param players LuaPlayer[]
---@param requestData PlayerInventoryShuffle_RequestData
---@return LuaInventory storageInventory
---@return table<string, uint> itemSources @ A table of item name to soure player count.
PlayerInventoryShuffle.CollectPlayerItems = function(players, requestData)
    -- Work out what inventories we will be emptying based on settings.
    -- CODE NOTE: Empty main inventory before armour so no oddness with main inventory size changes.
    local inventoryNamesToCheck  ---@type defines.inventory[]
    if requestData.includeEquipment then
        inventoryNamesToCheck = {defines.inventory.character_main, defines.inventory.character_trash, defines.inventory.character_armor, defines.inventory.character_guns, defines.inventory.character_ammo}
    else
        inventoryNamesToCheck = {defines.inventory.character_main, defines.inventory.character_trash}
    end

    -- We will track the number of player sources for each item type when moving the items in to the shared inventory.
    local itemSources = {} ---@type table<string, uint> @ Item name to count of players who had the item.

    -- Create a single storage invnetory (limited size). Track the maximum number of stacks that have gone in to it in a very simple way i.e. it doesn't account for stacks that merge togeather. It's used just to give a warning at present if the shared storageInventory may have filled up.
    local storageInventorySize = StorageInventorySizeIncrements -- Starting storage inventory size is 1 increment.
    local storageInventory = game.create_inventory(storageInventorySize)
    local storageInventoryStackCount, storageInventoryFull = 0, false

    -- Loop over each player and handle their inventories.
    ---@typelist LuaItemStack, LuaInventory, string
    local playerInventoryStack, playersInventory, stackItemName, playersInitialInventorySlotBonus, playersItemSources
    for _, player in pairs(players) do
        -- Return the players cursor stack to their inventory before handling.
        player.clear_cursor()

        -- A list of the item names (key) this player has already been found to have. To avoid double counting the same player for an item across different inventories.
        playersItemSources = {} ---@type table<string, True>

        -- Move each inventory for this player.
        for _, inventoryName in pairs(inventoryNamesToCheck) do
            playersInventory = player.get_inventory(inventoryName)
            -- Move each item stack in the inventory. As this is a players inventory there could be filtered item stacks at the end.
            -- CODE NOTE: this is suitable for regular sized inventories as there shouldn't be too many stacks and we expect lots of random item types.
            for i = 1, #playersInventory do
                playerInventoryStack = playersInventory[i] ---@type LuaItemStack
                if playerInventoryStack.valid_for_read then
                    -- Record this player as an item source if they haven't already been counted for this item in another inventory.
                    stackItemName = playerInventoryStack.name
                    if playersItemSources[stackItemName] == nil then
                        playersItemSources[stackItemName] = true
                        if itemSources[stackItemName] == nil then
                            itemSources[stackItemName] = 1
                        else
                            itemSources[stackItemName] = itemSources[stackItemName] + 1
                        end
                    end

                    -- Move the item stack to the storage inventory.
                    storageInventory.insert(playerInventoryStack) -- This effectively sorts and merges the inventory as its made.

                    -- Track the inventory fullness very crudely. Grow it when its possibly close to full.
                    storageInventoryStackCount = storageInventoryStackCount + 1
                    if storageInventoryStackCount == storageInventorySize then
                        if storageInventorySize <= StorageInventoryMaxGrowthSize then
                            -- Can just grow it. Assumes 1,000 increments.
                            storageInventorySize = storageInventorySize + StorageInventorySizeIncrements
                            storageInventory.resize(storageInventorySize)
                        else
                            -- This is very simplistic and just used to avoid lossing items, it will actually duplicate some of the last players items.
                            game.print({"message.muppet_streamer_player_inventory_shuffle_item_limit_reached"}, Colors.lightred)
                            storageInventoryFull = true
                            break
                        end
                    end
                end
            end

            if storageInventoryFull then
                break
            end

            playersInventory.clear()
        end

        if storageInventoryFull then
            break
        end

        --- Cancel any crafting queue if the player has one.
        if player.crafting_queue_size > 0 then
            playersInventory = player.get_inventory(defines.inventory.character_main)

            -- Grow the player's inventory to maximum size so that all cancelled craft ingredients are bound to fit in it.
            playersInitialInventorySlotBonus = player.character_inventory_slots_bonus
            player.character_inventory_slots_bonus = 1000 -- This is an arbitary limit to try and balance between a player having many full inventories of items being crafted, vs the UPS cost that setting to a larger inventory causes. 160 slots is the vanilla max total player inventories slots (120 for just character inventory), so 1,000 is over 8 full player inventories.

            -- Have to cancel each item one at a time while there still are some. As if you cancel a pre-requisite or final item then the other related items are auto cancelled and any attempt to iterate a cached list errors.
            while player.crafting_queue_size > 0 do
                player.cancel_crafting {index = 1, count = 99999999} -- Just a number to get all.

                -- Move each item type in the player's inventory to the storage inventory until we have got them all. We expect only a few item types/stacks from the craft cancel, but due to filtered inventory slots we can't be sure they will be at the start of the inventory.
                -- CODE NOTE: All items will end up in players main inventory as their other inventories have already been emptied.
                -- CODE NOTE: Empty the players inventory after each craftng cancel as this minimises risks from having grown the players inventory to a limited size. It does mean more runs of the inventory empty loop if lots of small craft jobs are cancelled, but the savings from handling a smaller overall inventory is well worth it.
                -- CODE NOTE: This is suitable for tiny up to potentially maximum sized inventories as we iterate the number of item types and not the inventory size. Is more UPS per item type, but cheaper with thousands of empty slots.
                for name in pairs(playersInventory.get_contents()) do
                    -- Record this player as an item source if they haven't already been counted for this item in another inventory.
                    if playersItemSources[name] == nil then
                        playersItemSources[name] = true
                        if itemSources[name] == nil then
                            itemSources[name] = 1
                        else
                            itemSources[name] = itemSources[name] + 1
                        end
                    end

                    -- Keep on moving each item stack until all are done. Some items can have mutliple stacks of pre-requisite items in their recipes.
                    playerInventoryStack = playersInventory.find_item_stack(name)
                    while playerInventoryStack ~= nil do
                        -- Move the item stack to the storage inventory.
                        storageInventory.insert(playerInventoryStack) -- This effectively sorts and merges the inventory as its made.
                        playersInventory.remove(playerInventoryStack) -- Remove from the player as we go as otherwise we can't iterate our item count correctly.

                        -- Track the inventory fullness very crudely. Grow it when its possibly close to full.
                        storageInventoryStackCount = storageInventoryStackCount + 1
                        if storageInventoryStackCount == storageInventorySize then
                            if storageInventorySize < StorageInventoryMaxGrowthSize then
                                -- Can just grow it. Assumes 1,000 increments.
                                storageInventorySize = storageInventorySize + StorageInventorySizeIncrements
                                storageInventory.resize(storageInventorySize)
                            else
                                -- This is very simplistic and just used to avoid lossing items, it will actually duplicate some of the last players items.
                                game.print({"message.muppet_streamer_player_inventory_shuffle_item_limit_reached"}, Colors.lightred)
                                storageInventoryFull = true
                                break
                            end
                        end

                        -- Update ready for next loop.
                        playerInventoryStack = playersInventory.find_item_stack(name)
                    end

                    if storageInventoryFull then
                        break
                    end
                end

                if storageInventoryFull then
                    break
                end
            end

            -- Return the players inventory back to its origional size.
            player.character_inventory_slots_bonus = playersInitialInventorySlotBonus
        end

        if storageInventoryFull then
            break
        end
    end

    return storageInventory, itemSources
end

--- Called to work out how to distribute the items across the target player list index (not LuaPlayer.index).
---@param storageInventory LuaInventory
---@param itemSources table<string, uint>
---@param requestData PlayerInventoryShuffle_RequestData
---@param playersCount uint
---@return PlayerInventoryShuffle_playersItemCounts playersItemCounts
PlayerInventoryShuffle.CalculateItemDistribution = function(storageInventory, itemSources, requestData, playersCount)
    -- Set up the main player variable arrays, these are references to the players variable index and not the actual LuaPlayer index value.
    local itemsToDistribute = storageInventory.get_contents()
    local playersItemCounts = {} ---@type PlayerInventoryShuffle_playersItemCounts
    local playersIndexsList = {} ---@type uint[] @ A list of the players list index. Copies of this are taken per item and those copies are trimmed.
    for i = 1, playersCount do
        playersItemCounts[i] = {}
        playersIndexsList[i] = i
    end

    -- Work out the distribution of items to players.
    ---@typelist uint, uint, double, double[], double, uint, double, uint[], uint, uint, uint, uint, uint
    local sourcesCount, destinationCount, totalAssignedPercentage, destinationPercentages, standardisedPercentageModifier, itemsLeftToAssign, destinationPercentage, playersAvailableToRecieveThisItem, playerIndex, playerIndexListIndex, itemCountForPlayerIndex, destinationCountMin, destinationCountMax
    for itemName, itemCount in pairs(itemsToDistribute) do
        sourcesCount = itemSources[itemName]

        -- Destination count is the number of sources clamped between 1 and number of players. It's the source player count and a random +/- of the greatest between the ItemDestinationPlayerCountRange and destinationPlayersMinimumVariance.
        destinationCountMin = math_min(-requestData.destinationPlayersMinimumVariance, -math_floor((sourcesCount * requestData.destinationPlayersVarianceFactor)))
        destinationCountMax = math_max(requestData.destinationPlayersMinimumVariance, math_ceil((sourcesCount * requestData.destinationPlayersVarianceFactor)))
        destinationCount = math_min(math_max(sourcesCount + math_random(destinationCountMin, destinationCountMax), 1), playersCount)

        -- Work out the raw percentage of items each destination will get.
        totalAssignedPercentage, destinationPercentages = 0, {}
        for i = 1, destinationCount do
            destinationPercentage = math_random(1, requestData.recipientItemMinToMaxRatio)
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
            table.insert(playersItemCounts[playerIndex], {name = itemName, count = itemCountForPlayerIndex})

            if itemsLeftToAssign == 0 then
                -- All of this item type assigned so stop.
                break
            end
        end
    end

    -- Randomly order the items we will be distributing as otherwise the same type of things are those forced in to inventories out of ratio or dropped on the ground. WIthout this also the worst armor was always assigned as well (lowest order).
    ---@typelist uint, PlayerInventoryShuffle_orderedItemCounts
    local randomOrderPosition, randomItemCountsList
    for itemCountsPlayerIndex, itemCountsList in pairs(playersItemCounts) do
        randomItemCountsList = {}
        for _, itemCounts in ipairs(itemCountsList) do
            randomOrderPosition = math.random(1, #randomItemCountsList + 1)
            table.insert(randomItemCountsList, randomOrderPosition, itemCounts)
        end
        playersItemCounts[itemCountsPlayerIndex] = randomItemCountsList
    end

    return playersItemCounts
end

--- Try to distribute the items to the players they were planned for. Anything that won't fit in their inventories will remain in the storage inventory.
---@param storageInventory LuaInventory
---@param players LuaPlayer[]
---@param playersItemCounts PlayerInventoryShuffle_playersItemCounts
---@return table<uint, LuaPlayer> playerIndexsWithFreeInventorySpace_table
PlayerInventoryShuffle.DistributePlannedItemsToPlayers = function(storageInventory, players, playersItemCounts)
    -- Distribute any armors and guns first to the players as these will affect players inventory sizes and usage of ammo slots for the rest of the items.
    local armorItemNames = game.get_filtered_item_prototypes({{filter = "type", type = "armor"}})
    local gunItemNames = game.get_filtered_item_prototypes({{filter = "type", type = "gun"}})
    for playerIndex, orderedPlayerItemCountList in pairs(playersItemCounts) do
        local player = players[playerIndex]
        for order, itemCounts in pairs(orderedPlayerItemCountList) do
            if armorItemNames[itemCounts.name] ~= nil or gunItemNames[itemCounts.name] ~= nil then
                PlayerInventoryShuffle.InsertItemsInToPlayer(storageInventory, itemCounts.name, itemCounts.count, player)
                orderedPlayerItemCountList[order] = nil
            end
        end
    end

    -- Distribute the items to the actual players.
    local playerIndexsWithFreeInventorySpace_table = Utils.DeepCopy(players) ---@type table<uint, LuaPlayer> -- Becomes a table as we remove keys without re-ordering.
    ---@typelist boolean, LuaPlayer
    local playersInventoryIsFull, player
    for playerIndex, orderedPlayerItemCountList in pairs(playersItemCounts) do
        player = players[playerIndex]
        for _, itemCounts in pairs(orderedPlayerItemCountList) do
            -- DEV NOTE: this list of items to be assigned is never used again, so no need to updated how many items were successfuly removed from it.
            playersInventoryIsFull = PlayerInventoryShuffle.InsertItemsInToPlayer(storageInventory, itemCounts.name, itemCounts.count, player)
            if playersInventoryIsFull then
                -- Player's inventory is full so stop trying to add more things to do. Will catch the left over items in the storage inventory later.
                playerIndexsWithFreeInventorySpace_table[playerIndex] = nil -- This will make it a gappy array, but we will squash it down later.
                Logging.LogPrint("Player list index " .. playerIndex .. "'s inventory is full during initial item distribution", debugStatusMessages)
                break
            end
        end
    end

    return playerIndexsWithFreeInventorySpace_table
end

--- Distribute any items left in the storage inventory across the players and then on the floor.
---@param storageInventory LuaInventory
---@param players LuaPlayer[]
---@param playerIndexsWithFreeInventorySpace_table table<uint, LuaPlayer>
PlayerInventoryShuffle.DistributeRemainingItemsAnywhere = function(storageInventory, players, playerIndexsWithFreeInventorySpace_table)
    -- Check the storage inventory is empty, distribute anything left or just dump it on the ground.
    local itemsLeftInStorage = storageInventory.get_contents()
    if next(itemsLeftInStorage) ~= nil then
        Logging.LogPrint("storage inventory not all distributed to players initially", debugStatusMessages)
        -- playerIndexsWithFreeInventorySpace_table is a gappy array so have to make it consistent to allow easier usage in this phase.
        local playerIndexsWithFreeInventorySpace_array = {} ---@type LuaPlayer[]
        for _, player in pairs(playerIndexsWithFreeInventorySpace_table) do
            table.insert(playerIndexsWithFreeInventorySpace_array, player)
        end

        -- Try and shove the items in players inventories that aren't full first
        ---@typelist uint, LuaPlayer, boolean
        local playerListIndex, player, playersInventoryIsFull
        for itemName, itemCount in pairs(itemsLeftInStorage) do
            -- Keep on trying to insert these items across all available players until its all inserted or no players have any room left.
            while itemCount > 0 do
                if #playerIndexsWithFreeInventorySpace_array == 0 then
                    -- No more players with free inventory space so stop this item.
                    break
                end
                playerListIndex = math_random(1, #playerIndexsWithFreeInventorySpace_array)
                player = playerIndexsWithFreeInventorySpace_array[playerListIndex]
                playersInventoryIsFull, itemCount = PlayerInventoryShuffle.InsertItemsInToPlayer(storageInventory, itemName, itemCount, player)
                if playersInventoryIsFull then
                    -- Player's inventory is full so prevent trying to add anything else to this player in the future.
                    table.remove(playerIndexsWithFreeInventorySpace_array, playerListIndex)
                    Logging.LogPrint("A player's inventory is full during secondary item dump to players", debugStatusMessages) -- This doesn't know the origional position of the player in the list as the list is being trimmed and squashed as it goes.
                end
            end

            if #playerIndexsWithFreeInventorySpace_array == 0 then
                -- No more players with free inventory space so stop all items.
                break
            end
        end

        -- Check if anything is still left, if it is just dump it on the ground so its not lost.
        itemsLeftInStorage = storageInventory.get_contents()
        if next(itemsLeftInStorage) ~= nil then
            -- Just drop it all on the floor at the players feet. No need to remove it from the inventory as we will destroy it next.
            -- CODE NOTE: the spilling on the ground is very UPS costly, espically the further away from each player. So Distributing semi equally across all players should help reduce this impact. Ideally this state won't be reached.
            game.print({"message.muppet_streamer_player_inventory_shuffle_not_enough_room_for_items"})
            storageInventory.sort_and_merge()
            ---@typelist LuaItemStack, LuaPlayer
            local storageItemStack, randomPlayer
            for i = 1, #storageInventory do
                storageItemStack = storageInventory[i]
                if storageItemStack.valid_for_read then
                    randomPlayer = players[math_random(1, #players)]
                    randomPlayer.surface.spill_item_stack(randomPlayer.position, storageItemStack, false, nil, false)
                else
                    -- As we sorted and merged all the items are at the start and all the free space at the end. So no need to check each free slot.
                    break
                end
            end
        end
    end
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
    local itemStackToTakeFrom, itemsInserted, itemToInsert, itemStackToTakeFrom_count, itemCountToTakeFromThisStack
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
