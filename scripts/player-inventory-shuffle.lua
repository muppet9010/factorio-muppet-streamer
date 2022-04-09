local PlayerInventoryShuffle = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local math_random, math_min, math_max, math_floor, math_ceil = math.random, math.min, math.max, math.floor, math.ceil

local ErrorMessageStart = "ERROR: muppet_streamer_player_inventory_shuffle command "
local ItemDestinationPlayerCountRange = 0.25

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

    global.playerInventoryShuffle.nextId = global.playerInventoryShuffle.nextId + 1
    ---@class PlayerInventoryShuffle_RequestData
    local data = {
        playerNames = playerNames,
        includeEquipment = includeEquipment
    }
    EventScheduler.ScheduleEvent(command.tick + delay, "PlayerInventoryShuffle.MixupPlayerInventories", global.playerInventoryShuffle.nextId, data)
end

PlayerInventoryShuffle.MixupPlayerInventories = function(event)
    local data = event.data ---@type PlayerInventoryShuffle_RequestData

    -- Get the active players to shuffle.
    local players  ---@type LuaPlayer[]
    if data.playerNames == nil then
        players = game.connected_players
    else
        players = {}
        local player  ---@type LuaPlayer
        for _, playerName in pairs(data.playerNames) do
            player = game.get_player(playerName)
            if player ~= nil and player.connected and player.controller_type == defines.controllers.character and player.character ~= nil then
                table.insert(players, player)
            end
        end
    end

    -- TODO: faked for testing, input items will be single copy, but output will be split across the 3 in code side.
    players = {game.players[1], game.players[1], game.players[1]}

    local playersCount = #players
    --TODO: removed for testing
    --[[if playersCount <= 1 then
        game.print({"message.muppet_streamer_player_inventory_shuffle_not_enough_players"})
        return
    end]]
    --

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
        -- Release the players cursor first so any item in it is returned to their inventory.
        player.cursor_stack.clear()

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

        -- Destination count is the number of sources clamped between 1 and number of players. It's the source player count and a random between +/- of the ItemDestinationPlayerCountRange.
        destinationCountMin = math_min(-1, -math_floor((sourcesCount * ItemDestinationPlayerCountRange)))
        destinationCountMax = math_max(1, math_ceil((sourcesCount * ItemDestinationPlayerCountRange)))
        destinationCount = math_min(math_max(sourcesCount + math_random(destinationCountMin, destinationCountMax), 1), playersCount)

        -- Work out the raw percentage of items each destination will get.
        totalAssignedPercentage, destinationPercentages = 0, {}
        for i = 1, destinationCount do
            destinationPercentage = math_random()
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
    ---@typelist LuaPlayer, LuaItemStack, uint, boolean, ItemStackDefinition, uint
    local player, itemStackToTakeFrom, itemsInserted, playersInventoryIsFull, itemToInsert, itemCountToTakeFromThisStack
    local playerIndexsWithFreeInventorySpace = Utils.DeepCopy(players)
    for i, playerItemCounts in pairs(playersItemCounts) do
        player = players[i]
        playersInventoryIsFull = false
        for itemName, itemCount in pairs(playerItemCounts) do
            -- Keep on taking items fromn the storage inventories stacks until we have moved the required number of items or filled up the players inventory.
            while itemCount > 0 do
                itemStackToTakeFrom = storageInventory.find_item_stack(itemName)
                itemStackToTakeFrom_count = itemStackToTakeFrom.count

                if itemStackToTakeFrom_count == 1 then
                    -- Single item in the stack so just transfer it and all done. This handles any extra attributes the stack may have naturally.
                    itemsInserted = player.insert(itemStackToTakeFrom)
                    if itemsInserted ~= 1 then
                        playersInventoryIsFull = true
                        break
                    end
                else
                    -- Multiple items in the stack so can just move the required numberand update the count. Have to check if we include the last item in the stack as then some extra attributes need to be handled.
                    itemCountToTakeFromThisStack = math.min(itemCount, itemStackToTakeFrom_count)
                    itemToInsert = {name = itemName, count = itemCountToTakeFromThisStack, health = itemStackToTakeFrom.health}
                    if itemStackToTakeFrom.is_item_with_tags then
                        itemToInsert.tags = itemStackToTakeFrom.tags
                    end
                    if itemCountToTakeFromThisStack == itemStackToTakeFrom_count then
                        -- We are taking the last item in the stack.
                        if itemStackToTakeFrom.type == "ammo" then
                            itemToInsert.ammo = itemStackToTakeFrom.ammo
                        end
                        itemToInsert.durability = itemStackToTakeFrom.durability
                    end

                    itemsInserted = player.insert(itemToInsert)
                    if itemsInserted ~= itemCountToTakeFromThisStack then
                        playersInventoryIsFull = true
                        break
                    end
                end

                itemStackToTakeFrom.count = itemStackToTakeFrom_count - itemsInserted
                itemCount = itemCount - itemsInserted
            end

            if playersInventoryIsFull then
                -- Players inventory is full so stop trying to add more things to do. Will catch the left over items in the storage inventory later.
                playerIndexsWithFreeInventorySpace[i] = nil
                break
            end
        end
    end

    -- Check the storage inventory is empty, distribute anything left and then remove it.
    local itemsLeftInStorage = storageInventory.get_contents()
    if next(itemsLeftInStorage) ~= nil then
        -- Stuff left in storage, this shouldn't happen, but check, warn and handle if it does.
        Logging.LogPrint(ErrorMessageStart .. "stuff left to be distributed, dumped at player " .. players[1].name .. "'s feet.")
        storageInventory.sort_and_merge()
        local storageItemStack  ---@type LuaItemStack
        local position, surface = players[1].position, players[1].surface
        -- Just drop it all on the floor at player 1's feet. No need to remove it from the inventory as we will destroy it next.
        -- TODO: shove it in some players inventories that aren't full first, then drop it on the ground. playerIndexsWithFreeInventorySpace
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

return PlayerInventoryShuffle
