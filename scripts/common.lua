local Common = {}
local MathUtils = require("utility.helper-utils.math-utils")
local Constants = require("constants")
local TableUtils = require("utility.helper-utils.table-utils")
local CommandsUtils = require("utility.helper-utils.commands-utils")

--- Takes a delay value in seconds and returns the Scheduled Event tick value.
---@param delaySeconds double|nil
---@param currentTick uint
---@param commandName string
---@param settingName string
---@return UtilityScheduledEvent_UintNegative1
Common.DelaySecondsSettingToScheduledEventTickValue = function(delaySeconds, currentTick, commandName, settingName)
    local scheduleTick  ---@type UtilityScheduledEvent_UintNegative1
    if (delaySeconds ~= nil and delaySeconds > 0) then
        local valueWasOutsideRange  ---@type boolean
        scheduleTick, valueWasOutsideRange = MathUtils.ClampToUInt(currentTick + math.floor(delaySeconds * 60))
        if valueWasOutsideRange then
            CommandsUtils.LogPrintWarning(commandName, settingName, "capped at max ticks, as excessively large number of delay seconds provided: " .. tostring(delaySeconds), nil)
        end
    else
        scheduleTick = -1 ---@type UtilityScheduledEvent_UintNegative1
    end
    return scheduleTick
end

--- A bespoke check for a player's name setting. Includes the setting as mandatory and that there's a player with this name.
---@param playerName string
---@param commandName string
---@param settingName string
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
---@return boolean isValid
Common.CheckPlayerNameSettingValue = function(playerName, commandName, settingName, commandString)
    -- Check its a valid populated string first, then that it's a player's name.
    if not CommandsUtils.CheckStringArgument(playerName, true, commandName, settingName, nil, commandString) then
        return false
    elseif game.get_player(playerName) == nil then
        CommandsUtils.LogPrintWarning(commandName, settingName, "is invalid player name", commandString)
        return false
    end
    return true
end

---@enum Common_CommandNames
Common.CommandNames = {
    muppet_streamer_aggressive_driver = "muppet_streamer_aggressive_driver",
    muppet_streamer_call_for_help = "muppet_streamer_call_for_help",
    muppet_streamer_schedule_explosive_delivery = "muppet_streamer_schedule_explosive_delivery",
    muppet_streamer_give_player_weapon_ammo = "muppet_streamer_give_player_weapon_ammo",
    muppet_streamer_leaky_flamethrower = "muppet_streamer_leaky_flamethrower",
    muppet_streamer_pants_on_fire = "muppet_streamer_pants_on_fire",
    muppet_streamer_player_drop_inventory = "muppet_streamer_player_drop_inventory",
    muppet_streamer_player_inventory_shuffle = "muppet_streamer_player_inventory_shuffle",
    muppet_streamer_spawn_around_player = "muppet_streamer_spawn_around_player",
    muppet_streamer_teleport = "muppet_streamer_teleport"
}

--- Allows calling a command via a remote interface.
---@param commandName Common_CommandNames @ The command to be run.
---@param options string|table @ The options being passed in.
Common.CallCommandFromRemote = function(commandName, options)
    -- Check the command name is valid.
    if not CommandsUtils.CheckStringArgument(commandName, true, "Remote Interface", "commandName", Common.CommandNames, commandName) then
        return
    end

    -- Check options are populated.
    if options == nil then
        CommandsUtils.LogPrintError("Remote Interface", commandName, "recieved no option data", nil)
        return
    end

    -- Get the command string equivilent for the remote call.
    local commandString
    if type(options) == "string" then
        -- Options should be a JSON string already so can just pass it through.
        commandString = options
    elseif type(options) == "table" then
        -- Options should be a table of settings, so convert it to JSOn and just pass it through.
        commandString = game.table_to_json(options)
    else
        CommandsUtils.LogPrintError("Remote Interface", commandName, "recieved unexpected option data type: " .. type(options), TableUtils.TableContentsToJSON(options, nil, true))
        return
    end

    -- Make the fake command object to pass in so the feature thinks its a command being called directly.
    ---@type CustomCommandData
    local commandData = {
        name = commandName,
        player_index = nil,
        parameter = commandString,
        tick = game.tick
    }

    -- Call the correct features command with the details.
    if commandName == Common.CommandNames.muppet_streamer_aggressive_driver then
        MOD.Interfaces.Commands.AggressiveDriver(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_call_for_help then
        MOD.Interfaces.Commands.CallForHelp(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_schedule_explosive_delivery then
        MOD.Interfaces.Commands.ExplosiveDelivery(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_give_player_weapon_ammo then
        MOD.Interfaces.Commands.GiveItems(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_leaky_flamethrower then
        MOD.Interfaces.Commands.LeakyFlamethrower(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_pants_on_fire then
        MOD.Interfaces.Commands.PantsOnFire(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_player_drop_inventory then
        MOD.Interfaces.Commands.PlayerDropInventory(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_player_inventory_shuffle then
        MOD.Interfaces.Commands.PlayerInventoryShuffle(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_spawn_around_player then
        MOD.Interfaces.Commands.SpawnAroundPlayer(commandData)
    elseif commandName == Common.CommandNames.muppet_streamer_teleport then
        MOD.Interfaces.Commands.Teleport(commandData)
    end
end

return Common
