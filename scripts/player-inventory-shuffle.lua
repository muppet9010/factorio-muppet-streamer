local PlayerInventoryShuffle = {} ---@class PlayerInventoryShuffle
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Colors = require("utility.lists.colors")
local StringUtils = require("utility.helper-utils.string-utils")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

local math_random, math_min, math_max, math_floor = math.random, math.min, math.max, math.floor

local StorageInventorySizeIncrements = 1000 ---@type uint16 @ The starting size of the shared storage inventory and how much it grows each time. Vanilla players only have 160~ max inventory space across all their inventories.
local StorageInventoryMaxGrowthSize = (65535) --[[@as uint16]] - StorageInventorySizeIncrements ---@type uint16 @ Max size when the inventory can still grow by another increment.

--[[----------------------------------------------------------------------------------------
                                        CODE DEV NOTES

    Inventory manipulation:
        There are 2 ways to access an inventory, one is to iterate each inventory slot and the other is to get a list of its contents and then search for a stack of that type.
            - get_contents() = Is suitable for tiny up to potentially maximum sized inventories as we iterate the number of item types and not the inventory size. Is more UPS cost per stack moved than inventory iteration, but cheaper when there are lots (hundreds+) of empty slots. The surprisingly high cost is partly as we have to insert and remove each item stack, whereas inventory iteration can just insert each item stack and then clear the whole inventory at the end. Making this especially suitable for any massively grown or script inventory.
            - Inventory iteration = iterating over every inventory slot is better for small to medium (up to a few hundred slots) inventories that are generally full or have lots of different item types, compared to get_contents().
        In all player inventory manipulations we have to expect filtered slots and some players choose not to sort (auto) their inventories, meaning there can be empty gaps. This prevents viewing an inventory as fully moved on the first empty slot unfortunately.

--]]
------------------------------------------------------------------------------------------

------------------------        DEBUG OPTIONS - MAKE SURE ARE FALSE ON RELEASE       ------------------------
local DebugStatusMessages = false
local SinglePlayerTesting = false -- Set to TRUE to force the mod to work for one player with false copies of the one player.
local SinglePlayerTesting_DuplicateInputItems = false -- Set to TRUE to force the mod to work for one player with false copies of the one player. It will duplicate the input items as if each fake player had a complete set. Has to discard excess items as otherwise profile is distorted. Intended for profiling more than bug fixing.

---@alias PlayerInventoryShuffle_PlayersItemCounts table<uint, PlayerInventoryShuffle_OrderedItemCounts>

---@alias PlayerInventoryShuffle_OrderedItemCounts table<uint, PlayerInventoryShuffle_ItemCounts>

---@class PlayerInventoryShuffle_ItemCounts
---@field name string
---@field count uint

---@class PlayerInventoryShuffle_RequestData
---@field includedPlayerNames string[]
---@field includedForces LuaForce[]
---@field includeAllPlayersOnServer boolean
---@field includeEquipment boolean
---@field includeHandCrafting boolean
---@field destinationPlayersMinimumVariance uint
---@field destinationPlayersVarianceFactor double
---@field recipientItemMinToMaxRatio uint

local commandName = "muppet_streamer_player_inventory_shuffle"

PlayerInventoryShuffle.CreateGlobals = function()
    global.playerInventoryShuffle = global.playerInventoryShuffle or {}
    global.playerInventoryShuffle.nextId = global.playerInventoryShuffle.nextId or 0 ---@type uint
end

PlayerInventoryShuffle.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_player_inventory_shuffle", {"api-description.muppet_streamer_player_inventory_shuffle"}, PlayerInventoryShuffle.PlayerInventoryShuffleCommand, true)
    EventScheduler.RegisterScheduledEventType("PlayerInventoryShuffle.MixUpPlayerInventories", PlayerInventoryShuffle.MixUpPlayerInventories)
    MOD.Interfaces.Commands.PlayerInventoryShuffle = PlayerInventoryShuffle.PlayerInventoryShuffleCommand
end

---@param command CustomCommandData
PlayerInventoryShuffle.PlayerInventoryShuffleCommand = function(command)
    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, {"delay", "includedPlayers", "includedForces", "includeEquipment", "includeHandCrafting", "destinationPlayersMinimumVariance", "destinationPlayersVarianceFactor", "recipientItemMinToMaxRatio"})
    if commandData == nil then
        return
    end

    local delaySeconds = commandData.delay
    if not CommandsUtils.CheckNumberArgument(delaySeconds, "double", false, commandName, "delay", 0, nil, command.parameter) then
        return
    end ---@cast delaySeconds double|nil
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySeconds, command.tick, commandName, "delay")

    -- Just get the Included Players with minimal checking as we do the checks once all the include settings are obtained.
    local includedPlayersString = commandData.includedPlayers
    if not CommandsUtils.CheckStringArgument(includedPlayersString, false, commandName, "includedPlayers", nil, command.parameter) then
        return
    end ---@cast includedPlayersString string|nil
    local includedPlayerNames = {} ---@type string[]
    local includeAllPlayersOnServer = false ---@type boolean
    if includedPlayersString ~= nil and includedPlayersString ~= "" then
        -- Can't check if the names are valid players right now, as they may just not have joined the server yet, but may in the future.
        includedPlayerNames = StringUtils.SplitStringOnCharactersToList(includedPlayersString, ",")
        if #includedPlayerNames == 1 then
            -- If it's only one name then check if its the special ALL value.
            if includedPlayerNames[1] == "[ALL]" then
                includedPlayerNames = {}
                includeAllPlayersOnServer = true
            end
        end
    end

    -- Get the Included Forces and just check anything provided is valid.
    local includedForcesString = commandData.includedForces
    if not CommandsUtils.CheckStringArgument(includedForcesString, false, commandName, "includedForces", nil, command.parameter) then
        return
    end ---@cast includedForcesString string|nil
    local includedForces = {} ---@type LuaForce[]
    if includedForcesString ~= nil and includedForcesString ~= "" then
        if includeAllPlayersOnServer then
            CommandsUtils.LogPrintError(commandName, "includedForces", "is invalid option as all players on the server are already being included", command.parameter)
            return
        end
        local includedForceNames = StringUtils.SplitStringOnCharactersToList(includedForcesString, ",")
        for _, includedForceName in pairs(includedForceNames) do
            local force = game.forces[includedForceName]
            if force ~= nil then
                table.insert(includedForces, force)
            else
                CommandsUtils.LogPrintError(commandName, "includedForces", "has an invalid force name: " .. tostring(includedForceName), command.parameter)
                return
            end
        end
    end

    -- Check the Include settings in combination.
    if not includeAllPlayersOnServer and #includedForces == 0 then
        -- As not all players and no forces fully included, we actually have to check the player list.
        if includedPlayerNames == nil or #includedPlayerNames < 2 then
            CommandsUtils.LogPrintError(commandName, nil, "at least 2 player's names must be included in the `includedPlayers` option if no force is included in the 'includedForces' option.", command.parameter)
            return
        end
    end

    local includeEquipment = commandData.includeEquipment
    if not CommandsUtils.CheckBooleanArgument(includeEquipment, false, commandName, "includeEquipment", command.parameter) then
        return
    end ---@cast includeEquipment boolean|nil
    if includeEquipment == nil then
        includeEquipment = true
    end

    local includeHandCrafting = commandData.includeHandCrafting
    if not CommandsUtils.CheckBooleanArgument(includeHandCrafting, false, commandName, "includeHandCrafting", command.parameter) then
        return
    end ---@cast includeHandCrafting boolean|nil
    if includeHandCrafting == nil then
        includeHandCrafting = true
    end

    local destinationPlayersMinimumVariance = commandData.destinationPlayersMinimumVariance
    if not CommandsUtils.CheckNumberArgument(destinationPlayersMinimumVariance, "int", false, commandName, "destinationPlayersMinimumVariance", 0, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast destinationPlayersMinimumVariance uint|nil
    if destinationPlayersMinimumVariance == nil then
        destinationPlayersMinimumVariance = 1
    end

    local destinationPlayersVarianceFactor = commandData.destinationPlayersVarianceFactor
    if not CommandsUtils.CheckNumberArgument(destinationPlayersVarianceFactor, "double", false, commandName, "destinationPlayersVarianceFactor", 0, nil, command.parameter) then
        return
    end ---@cast destinationPlayersVarianceFactor double|nil
    if destinationPlayersVarianceFactor == nil then
        destinationPlayersVarianceFactor = 0.25
    end

    local recipientItemMinToMaxRatio = commandData.recipientItemMinToMaxRatio
    if not CommandsUtils.CheckNumberArgument(recipientItemMinToMaxRatio, "int", false, commandName, "recipientItemMinToMaxRatio", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast recipientItemMinToMaxRatio uint|nil
    if recipientItemMinToMaxRatio == nil then
        recipientItemMinToMaxRatio = 5
    end

    global.playerInventoryShuffle.nextId = global.playerInventoryShuffle.nextId + 1
    ---@type PlayerInventoryShuffle_RequestData
    local requestData = {
        includedPlayerNames = includedPlayerNames,
        includedForces = includedForces,
        includeAllPlayersOnServer = includeAllPlayersOnServer,
        includeEquipment = includeEquipment,
        includeHandCrafting = includeHandCrafting,
        destinationPlayersMinimumVariance = destinationPlayersMinimumVariance,
        destinationPlayersVarianceFactor = destinationPlayersVarianceFactor,
        recipientItemMinToMaxRatio = recipientItemMinToMaxRatio
    }
    EventScheduler.ScheduleEventOnce(scheduleTick, "PlayerInventoryShuffle.MixUpPlayerInventories", global.playerInventoryShuffle.nextId, requestData)
end

---@param event UtilityScheduledEvent_CallbackObject
PlayerInventoryShuffle.MixUpPlayerInventories = function(event)
    local requestData = event.data ---@type PlayerInventoryShuffle_RequestData

    -- Get the active players to shuffle.
    local players = {} ---@type LuaPlayer[]
    local playerNamesAddedByForce = {} ---@type table<string, string> @ Key and value both player name.
    local playerNamesAddedByName = {} ---@type table<string, string> @ Key and value both player name.
    if requestData.includeAllPlayersOnServer == true then
        -- Just include everyone.
        for _, player in pairs(game.connected_players) do
            if player.controller_type == defines.controllers.character and player.character ~= nil and player.character.valid then
                table.insert(players, player)
            end
        end
    else
        -- Include the named players and force's players. Does forces first and then any non included listed players.
        for _, force in pairs(requestData.includedForces) do
            if force.valid then
                for _, player in pairs(force.connected_players) do
                    if player.controller_type == defines.controllers.character and player.character ~= nil and player.character.valid then
                        table.insert(players, player)
                        local player_name = player.name
                        playerNamesAddedByForce[player_name] = player_name
                    end
                end
            end
        end
        for _, playerName in pairs(requestData.includedPlayerNames) do
            local player = game.get_player(playerName)
            if player ~= nil and player.connected and player.controller_type == defines.controllers.character and player.character ~= nil and player.character.valid then
                local player_name = player.name
                -- Only include the player if they aren't already included by their force.
                if playerNamesAddedByForce[player_name] == nil then
                    table.insert(players, player)
                    playerNamesAddedByName[player_name] = player_name
                end
            end
        end
    end

    if SinglePlayerTesting or SinglePlayerTesting_DuplicateInputItems then
        -- Fakes the only player as multiple players so that the 1 players inventory is spread across these multiple fake players, but still all ends up inside the single real player's inventory.
        players = {game.players[1], game.players[1], game.players[1], game.players[1], game.players[1], game.players[1], game.players[1], game.players[1], game.players[1], game.players[1]}
    end

    -- Check that there are the minimum of 2 players to shuffle.
    if #players <= 1 then
        game.print({"message.muppet_streamer_player_inventory_shuffle_not_enough_players"})
        return
    end

    -- Announce that the shuffle is being done and to which active players.
    local playerNamePrettyList
    if requestData.includeAllPlayersOnServer == true then
        -- Is all active players.
        playerNamePrettyList = {"message.muppet_streamer_player_inventory_shuffle_all_players"}
    else
        playerNamePrettyList = ""
        for _, force in pairs(requestData.includedForces) do
            playerNamePrettyList = playerNamePrettyList .. ", force '" .. force.name .. "'"
        end
        for _, playerName in pairs(playerNamesAddedByName) do
            playerNamePrettyList = playerNamePrettyList .. ", " .. playerName
        end
        -- Remove leading comma and space
        playerNamePrettyList = string.sub(playerNamePrettyList, 3)
    end
    game.print({"message.muppet_streamer_player_inventory_shuffle_start", playerNamePrettyList})

    -- Do the collection and distribution.
    local storageInventory, itemSources = PlayerInventoryShuffle.CollectPlayerItems(players, requestData)
    local playersItemCounts = PlayerInventoryShuffle.CalculateItemDistribution(storageInventory, itemSources, requestData, #players --[[@as uint]])
    local playerIndexesWithFreeInventorySpace_table = PlayerInventoryShuffle.DistributePlannedItemsToPlayers(storageInventory, players, playersItemCounts)
    PlayerInventoryShuffle.DistributeRemainingItemsAnywhere(storageInventory, players, playerIndexesWithFreeInventorySpace_table)

    -- Remove the now empty storage inventory
    storageInventory.destroy()
end

--- Collect all the items from the players in to the storage inventory.
---@param players LuaPlayer[]
---@param requestData PlayerInventoryShuffle_RequestData
---@return LuaInventory storageInventory
---@return table<string, uint> itemSources @ A table of item name to source player count.
PlayerInventoryShuffle.CollectPlayerItems = function(players, requestData)
    -- Work out what inventories we will be emptying based on settings.
    -- CODE NOTE: Empty main inventory before armor so no oddness with main inventory size changes.
    local inventoryNamesToCheck  ---@type defines.inventory[]
    if requestData.includeEquipment then
        inventoryNamesToCheck = {defines.inventory.character_main, defines.inventory.character_trash, defines.inventory.character_armor, defines.inventory.character_guns, defines.inventory.character_ammo}
    else
        inventoryNamesToCheck = {defines.inventory.character_main, defines.inventory.character_trash}
    end

    -- We will track the number of player sources for each item type when moving the items in to the shared inventory.
    local itemSources = {} ---@type table<string, uint> @ Item name to count of players who had the item.

    -- Create a single storage inventory (limited size). Track the maximum number of stacks that have gone in to it in a very simple way i.e. it doesn't account for stacks that merge together. It's used just to give a warning at present if the shared storageInventory may have filled up.
    local storageInventorySize = StorageInventorySizeIncrements ---@type uint16 -- Starting storage inventory size is 1 increment.
    local storageInventory = game.create_inventory(storageInventorySize)
    local storageInventoryStackCount, storageInventoryFull = 0, false

    -- Loop over each player and handle their inventories.
    ---@type LuaItemStack|nil, LuaInventory|nil, string, uint, table<string, true>
    local playerInventoryStack, playersInventory, stackItemName, playersInitialInventorySlotBonus, playersItemSources
    for _, player in pairs(players) do
        -- Return the players cursor stack to their inventory before handling.
        player.clear_cursor()

        -- A list of the item names (key) this player has already been found to have. To avoid double counting the same player for an item across different inventories.
        playersItemSources = {} ---@type table<string, true> @ Item name this player has already been found to have.

        -- Move each inventory for this player.
        for _, inventoryName in pairs(inventoryNamesToCheck) do
            playersInventory = player.get_inventory(inventoryName)

            if playersInventory ~= nil and not playersInventory.is_empty() then
                -- Move each item stack in the inventory. See code notes at top of file for iterating inventory slots vs get_contents().
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
                        -- DEV NOTE: doing an inventory stack swap or set rather than insert only saves a fraction (10%) at best of the functions overall UPS. This test wasn't fully tested and may have required additional UPS code to completely manage it.

                        -- Track the inventory fullness very crudely. Grow it when its possibly close to full.
                        storageInventoryStackCount = storageInventoryStackCount + 1
                        if storageInventoryStackCount == storageInventorySize then
                            if storageInventorySize <= StorageInventoryMaxGrowthSize then
                                -- Can just grow it.
                                storageInventorySize = storageInventorySize + StorageInventorySizeIncrements -- This is safe to blindly do as we already avoid exceeding the smaller size of uint 16 in the previous logic.
                                storageInventory.resize(storageInventorySize)
                            else
                                -- This is very simplistic and just used to avoid losing items, it will actually duplicate some of the last players items.
                                game.print({"message.muppet_streamer_player_inventory_shuffle_item_limit_reached"}, Colors.lightRed)
                                storageInventoryFull = true
                                break
                            end
                        end
                    end
                end

                if storageInventoryFull then
                    break
                end

                if not SinglePlayerTesting_DuplicateInputItems then
                    -- If testing with one real player don't remove all the items as we want to add them for the next "fake" player referencing this same real character.
                    playersInventory.clear()
                end
            end
        end

        if storageInventoryFull then
            break
        end

        --- Cancel any crafting queue if the player has one and this feature is enabled.
        if requestData.includeHandCrafting and player.crafting_queue_size > 0 then
            playersInventory = player.get_inventory(defines.inventory.character_main)
            if playersInventory ~= nil then
                -- Grow the player's inventory to maximum size so that all cancelled craft ingredients are bound to fit in it.
                playersInitialInventorySlotBonus = player.character_inventory_slots_bonus
                player.character_inventory_slots_bonus = MathUtils.ClampToUInt(playersInitialInventorySlotBonus * 4, nil, 1000) -- This is an arbitrary limit to try and balance between a player having many full inventories of items being crafted, vs the UPS cost that setting to a larger inventory causes. 1000 slots increase is twice the UPS of no increase to the cancel_crafting commands, but orders of magnitude larger take progressively longer.

                -- Have to cancel each item one at a time while there still are some. As if you cancel a pre-requisite or final item then the other related items are auto cancelled and any attempt to iterate a cached list errors.
                while player.crafting_queue_size > 0 do
                    player.cancel_crafting {index = 1, count = 99999999} -- Just a number to get all.

                    -- Move each item type in the player's inventory to the storage inventory until we have got them all. See code notes at top of file for iterating inventory slots vs get_contents().
                    -- CODE NOTE: All items will end up in players main inventory as their other inventories have already been emptied. No trashing or other actions will occur mid tick.
                    -- CODE NOTE: Empty the players inventory after each crafting cancel as this minimises risks of overflowing to the floor, as we only grow the players inventory to a limited size. It does mean more runs of the inventory empty loop if lots of small craft jobs are cancelled, but the UPS savings from the game handling a smaller grown inventory size is well worth it.
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

                        -- Keep on moving each item stack until all are done. Some items can have multiple stacks of pre-requisite items in their recipes.
                        playerInventoryStack = playersInventory.find_item_stack(name)
                        while playerInventoryStack ~= nil do
                            -- Move the item stack to the storage inventory.
                            storageInventory.insert(playerInventoryStack) -- This effectively sorts and merges the inventory as its made.
                            playersInventory.remove(playerInventoryStack) -- Remove from the player as we go as otherwise we can't iterate our item count correctly.

                            -- Track the inventory fullness very crudely. Grow it when its possibly close to full.
                            storageInventoryStackCount = storageInventoryStackCount + 1
                            if storageInventoryStackCount == storageInventorySize then
                                if storageInventorySize < StorageInventoryMaxGrowthSize then
                                    -- Can just grow it.
                                    storageInventorySize = storageInventorySize + StorageInventorySizeIncrements -- This is safe to blindly do as we already avoid exceeding the smaller size of uint 16 in the previous logic.
                                    storageInventory.resize(storageInventorySize)
                                else
                                    -- This is very simplistic and just used to avoid losing items, it will actually duplicate some of the last players items.
                                    game.print({"message.muppet_streamer_player_inventory_shuffle_item_limit_reached"}, Colors.lightRed)
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

                -- Return the players inventory back to its original size.
                player.character_inventory_slots_bonus = playersInitialInventorySlotBonus
            end
        end

        if storageInventoryFull then
            break
        end
    end

    -- If testing with one real player now empty the players inventories. In real code this was done during the loop.
    if SinglePlayerTesting_DuplicateInputItems then
        for _, inventoryName in pairs(inventoryNamesToCheck) do
            playersInventory = players[1].get_inventory(inventoryName)
            if playersInventory ~= nil then
                playersInventory.clear()
            end
        end
    end

    return storageInventory, itemSources
end

--- Called to work out how to distribute the items across the target player list index (not LuaPlayer.index).
---@param storageInventory LuaInventory
---@param itemSources table<string, uint>
---@param requestData PlayerInventoryShuffle_RequestData
---@param playersCount uint
---@return PlayerInventoryShuffle_PlayersItemCounts playersItemCounts
PlayerInventoryShuffle.CalculateItemDistribution = function(storageInventory, itemSources, requestData, playersCount)
    -- Set up the main player variable arrays, these are references to the players variable index and not the actual LuaPlayer index value.
    local itemsToDistribute = storageInventory.get_contents()
    local playersItemCounts = {} ---@type PlayerInventoryShuffle_PlayersItemCounts
    for i = 1, playersCount do ---@type uint
        playersItemCounts[i] = {}
    end

    -- Work out the distribution of items to players.
    ---@type uint, uint, double, uint[], double, uint, uint, uint[], uint, uint, uint, uint, uint
    local sourcesCount, destinationCount, totalAssignedRatio, destinationRatios, standardisedPercentageModifier, itemsLeftToAssign, destinationRatio, playersAvailableToReceiveThisItem, playerIndex, playerIndexListIndex, itemCountForPlayerIndex, destinationCountVariance
    for itemName, itemCount in pairs(itemsToDistribute) do
        sourcesCount = itemSources[itemName]

        -- Destination count is the number of sources clamped between 1 and number of players. It's the source player count and a random +/- of the greatest between the ItemDestinationPlayerCountRange and destinationPlayersMinimumVariance.
        destinationCountVariance = math_max(requestData.destinationPlayersMinimumVariance, math_floor((sourcesCount * requestData.destinationPlayersVarianceFactor)))
        destinationCount = math_min(math_max(sourcesCount + math_random(-destinationCountVariance --[[@as integer @ needed due to expected type in math.random().]], destinationCountVariance), 1), playersCount) --[[@as uint @ The min and max values are uints.]]

        -- Work out the raw ratios of items each destination will get.
        totalAssignedRatio, destinationRatios = 0, {}
        for i = 1, destinationCount do
            destinationRatio = math_random(1, requestData.recipientItemMinToMaxRatio) --[[@as uint]]
            destinationRatios[i] = destinationRatio
            totalAssignedRatio = totalAssignedRatio + destinationRatio
        end
        standardisedPercentageModifier = 1 / totalAssignedRatio

        -- Work out how many items each destination will get and assign them to a specific players list index.
        itemsLeftToAssign = itemCount
        playersAvailableToReceiveThisItem = {} ---@type table<uint, uint> @ A list of the players list indexes that is trimmed once assigned this item.
        for i = 1, playersCount do ---@type uint
            playersAvailableToReceiveThisItem[i] = i
        end

        for i = 1, destinationCount do
            -- Select a random players list index from those not yet assigned this item and then remove it from the available list.
            playerIndexListIndex = math_random(1, #playersAvailableToReceiveThisItem) --[[@as uint]]
            playerIndex = playersAvailableToReceiveThisItem[playerIndexListIndex]
            table.remove(playersAvailableToReceiveThisItem, playerIndexListIndex)

            -- Record how many actual items this player index will get.
            if i == destinationCount then
                -- Is last slot so just add all that are remaining.
                itemCountForPlayerIndex = itemsLeftToAssign
            else
                -- Round down the initial number and then keep it below the number of items left. Never try to use more than are left to assign.
                itemCountForPlayerIndex = math_min(math_max(math_floor(destinationRatios[i] * standardisedPercentageModifier * itemsLeftToAssign), 1), itemsLeftToAssign) --[[@as uint @ The min and max values are uints.]]
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
    ---@type uint, PlayerInventoryShuffle_OrderedItemCounts
    local randomOrderPosition, randomItemCountsList
    for itemCountsPlayerIndex, itemCountsList in pairs(playersItemCounts) do
        randomItemCountsList = {}
        for _, itemCounts in ipairs(itemCountsList) do
            randomOrderPosition = math.random(1, #randomItemCountsList + 1) --[[@as uint]]
            table.insert(randomItemCountsList, randomOrderPosition, itemCounts)
        end
        playersItemCounts[itemCountsPlayerIndex] = randomItemCountsList
    end

    return playersItemCounts
end

--- Try to distribute the items to the players they were planned for. Anything that won't fit in their inventories will remain in the storage inventory.
---@param storageInventory LuaInventory
---@param players LuaPlayer[]
---@param playersItemCounts PlayerInventoryShuffle_PlayersItemCounts
---@return table<uint, LuaPlayer> playerIndexesWithFreeInventorySpace_table
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
    local playerIndexesWithFreeInventorySpace_table = {} ---@type table<uint, LuaPlayer> -- Becomes a gappy table as we remove keys without re-ordering.
    for i, player in pairs(players) do ---@cast i uint
        playerIndexesWithFreeInventorySpace_table[i] = player
    end

    ---@type boolean, LuaPlayer
    local playersInventoryIsFull, player
    for playerIndex, orderedPlayerItemCountList in pairs(playersItemCounts) do
        player = players[playerIndex]
        for _, itemCounts in pairs(orderedPlayerItemCountList) do
            -- DEV NOTE: this list of items to be assigned is never used again, so no need to updated how many items were successfully removed from it.
            playersInventoryIsFull = PlayerInventoryShuffle.InsertItemsInToPlayer(storageInventory, itemCounts.name, itemCounts.count, player)
            if playersInventoryIsFull then
                -- Player's inventory is full so stop trying to add more things to do. Will catch the left over items in the storage inventory later.
                playerIndexesWithFreeInventorySpace_table[playerIndex] = nil -- This will make it a gappy array, but we will squash it down later.
                if DebugStatusMessages then
                    CommandsUtils.LogPrintWarning(commandName, nil, "Player list index " .. playerIndex .. "'s inventory is full during initial item distribution")
                end
                break
            end
        end
    end

    return playerIndexesWithFreeInventorySpace_table
end

--- Distribute any items left in the storage inventory across the players and then on the floor.
---@param storageInventory LuaInventory
---@param players LuaPlayer[]
---@param playerIndexesWithFreeInventorySpace_table table<uint, LuaPlayer>
PlayerInventoryShuffle.DistributeRemainingItemsAnywhere = function(storageInventory, players, playerIndexesWithFreeInventorySpace_table)
    -- Check the storage inventory is empty, distribute anything left or just dump it on the ground.
    local itemsLeftInStorage = storageInventory.get_contents()
    if next(itemsLeftInStorage) ~= nil then
        if DebugStatusMessages then
            CommandsUtils.LogPrintWarning(commandName, nil, "storage inventory not all distributed to players initially")
        end
        -- playerIndexesWithFreeInventorySpace_table is a gappy array so have to make it consistent to allow easier usage in this phase.
        local playerIndexesWithFreeInventorySpace_array = {} ---@type LuaPlayer[]
        for _, player in pairs(playerIndexesWithFreeInventorySpace_table) do
            table.insert(playerIndexesWithFreeInventorySpace_array, player)
        end

        -- Try and shove the items in players inventories that aren't full first
        ---@type uint, LuaPlayer, boolean
        local playerListIndex, player, playersInventoryIsFull
        for itemName, itemCount in pairs(itemsLeftInStorage) do
            -- Keep on trying to insert these items across all available players until its all inserted or no players have any room left.
            while itemCount > 0 do
                if #playerIndexesWithFreeInventorySpace_array == 0 then
                    -- No more players with free inventory space so stop this item.
                    break
                end
                playerListIndex = math_random(1, #playerIndexesWithFreeInventorySpace_array) --[[@as uint]]
                player = playerIndexesWithFreeInventorySpace_array[playerListIndex]
                playersInventoryIsFull, itemCount = PlayerInventoryShuffle.InsertItemsInToPlayer(storageInventory, itemName, itemCount, player)
                if playersInventoryIsFull then
                    -- Player's inventory is full so prevent trying to add anything else to this player in the future.
                    table.remove(playerIndexesWithFreeInventorySpace_array, playerListIndex)
                    if DebugStatusMessages then
                        CommandsUtils.LogPrintWarning(commandName, nil, "A player's inventory is full during secondary item dump to players") -- This doesn't know the original position of the player in the list as the list is being trimmed and squashed as it goes.
                    end
                end
            end

            if #playerIndexesWithFreeInventorySpace_array == 0 then
                -- No more players with free inventory space so stop all items.
                break
            end
        end

        -- If testing with one real player just leave the excess duplicated stuff in the storage as otherwise we will pollute the profile with a massive item drop on floor.
        if SinglePlayerTesting_DuplicateInputItems then
            return
        end

        -- Check if anything is still left, if it is just dump it on the ground so its not lost.
        itemsLeftInStorage = storageInventory.get_contents()
        if next(itemsLeftInStorage) ~= nil then
            -- Just drop it all on the floor at the players feet. No need to remove it from the inventory as we will destroy it next.
            -- CODE NOTE: the spilling on the ground is very UPS costly, especially the further away from each player. So Distributing semi equally across all players should help reduce this impact. Ideally this state won't be reached.
            game.print({"message.muppet_streamer_player_inventory_shuffle_not_enough_room_for_items"})
            storageInventory.sort_and_merge()
            ---@type LuaItemStack, LuaPlayer
            local storageItemStack, randomPlayer
            ---@type uint
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
    ---@type LuaItemStack|nil, uint, ItemStackDefinition, uint, uint
    local itemStackToTakeFrom, itemsInserted, itemToInsert, itemStackToTakeFrom_count, itemCountToTakeFromThisStack
    local playersInventoryIsFull = false

    -- Keep on taking items from the storage inventories stacks until we have moved the required number of items or filled up the player's inventory.
    while itemCount > 0 do
        itemStackToTakeFrom = storageInventory.find_item_stack(itemName)
        if itemStackToTakeFrom == nil then
            CommandsUtils.LogPrintError(commandName, nil, "When inserting items in to player item was missing in shared storage")
            return true, itemCount -- This aborts the code loop, but may give weird later error messages. Unexpected route so shouldn't matter.
        end
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
