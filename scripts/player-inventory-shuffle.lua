local PlayerInventoryShuffle = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local Utils = require("utility/utils")
local EventScheduler = require("utility/event-scheduler")
local Events = require("utility/events")

local ErrorMessageStart = "ERROR: muppet_streamer_player_inventory_shuffle command "

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
        delay = math.max(delay * 60, 0)
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
    --TODO: removed for testing
    --[[if #players <= 1 then
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
    -- Loop over each player.
    for _, player in pairs(players) do
        -- Release the players cursor first so any item in it is returned to their inventory.
        player.cursor_stack.clear()

        -- Move each inventory for this player.
        for _, inventoryName in pairs(inventoryNamesToCheck) do
            local playersInventory = player.get_inventory(inventoryName)
            for i = 1, #playersInventory do
                local playerInventoryStack = playersInventory[i] ---@type LuaItemStack
                if playerInventoryStack.valid_for_read then
                    local stackItemName = playerInventoryStack.name
                    if itemSources[stackItemName] == nil then
                        itemSources[stackItemName] = 1
                    else
                        itemSources[stackItemName] = itemSources[stackItemName] + 1
                    end
                    storageInventory.insert(playerInventoryStack)
                end
            end
            playersInventory.clear()
        end
    end

    -- Work out the distribution of items to players and pass out the items.
    local itemsToDistribute = storageInventory.get_contents()
    -- TODO: do the actual shuffle. Anything that can't fit in to the target player just drop on the ground at the feet of the target player. As filtered inventories and the fact we are takign from lots of inventoies back in to 1 may lead to this.

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
