local GiveItems = {} ---@class GiveItems
local PlayerWeapon = require("utility.functions.player-weapon")
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@class GiveItems_GiveWeaponAmmoScheduled
---@field target string # Target player's name.
---@field ammoPrototype? LuaItemPrototype|nil # Nil if no ammo is being given.
---@field ammoCount? uint|nil # Nil if no ammo is being given.
---@field weaponPrototype? LuaItemPrototype|nil
---@field forceWeaponToSlot boolean
---@field selectWeapon boolean

local commandName = "muppet_streamer_give_player_weapon_ammo"

GiveItems.CreateGlobals = function()
    global.giveItems = global.giveItems or {}
    global.giveItems.nextId = global.giveItems.nextId or 0 ---@type uint
end

GiveItems.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_give_player_weapon_ammo", { "api-description.muppet_streamer_give_player_weapon_ammo" }, GiveItems.GivePlayerWeaponAmmoCommand, true)
    EventScheduler.RegisterScheduledEventType("GiveItems.GiveWeaponAmmoScheduled", GiveItems.GiveWeaponAmmoScheduled)
    MOD.Interfaces.Commands.GiveItems = GiveItems.GivePlayerWeaponAmmoCommand
end

---@param command CustomCommandData
GiveItems.GivePlayerWeaponAmmoCommand = function(command)

    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "weaponType", "forceWeaponToSlot", "selectWeapon", "ammoType", "ammoCount" })
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

    local weaponPrototype, valid = Common.GetItemPrototypeFromCommandArgument(commandData.weaponType, "gun", false, commandName, "weaponType", command.parameter)
    if not valid then return end

    local forceWeaponToSlot = commandData.forceWeaponToSlot
    if not CommandsUtils.CheckBooleanArgument(forceWeaponToSlot, false, commandName, "forceWeaponToSlot", command.parameter) then
        return
    end ---@cast forceWeaponToSlot boolean|nil
    if forceWeaponToSlot == nil then
        forceWeaponToSlot = false
    end

    local selectWeapon = commandData.selectWeapon
    if not CommandsUtils.CheckBooleanArgument(selectWeapon, false, commandName, "selectWeapon", command.parameter) then
        return
    end ---@cast selectWeapon boolean|nil
    if selectWeapon == nil then
        selectWeapon = false
    end

    local ammoPrototype, valid = Common.GetItemPrototypeFromCommandArgument(commandData.ammoType, "ammo", false, commandName, "ammoType", command.parameter)
    if not valid then return end

    local ammoCount = commandData.ammoCount
    if not CommandsUtils.CheckNumberArgument(ammoCount, "int", false, commandName, "ammoCount", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast ammoCount uint|nil

    global.giveItems.nextId = global.giveItems.nextId + 1
    ---@type GiveItems_GiveWeaponAmmoScheduled
    local giveWeaponAmmoScheduled = { target = target, ammoPrototype = ammoPrototype, ammoCount = ammoCount, weaponPrototype = weaponPrototype, forceWeaponToSlot = forceWeaponToSlot, selectWeapon = selectWeapon }
    EventScheduler.ScheduleEventOnce(scheduleTick, "GiveItems.GiveWeaponAmmoScheduled", global.giveItems.nextId, giveWeaponAmmoScheduled)
end

---@param eventData UtilityScheduledEvent_CallbackObject
GiveItems.GiveWeaponAmmoScheduled = function(eventData)
    local data = eventData.data ---@type GiveItems_GiveWeaponAmmoScheduled

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({ "message.muppet_streamer_give_player_weapon_ammo_not_character_controller", data.target })
        return
    end


    -- Check the weapon and ammo are still valid (unchanged).
    if not data.weaponPrototype.valid then
        CommandsUtils.LogPrintWarning(commandName, nil, "The in-game weapon prototype has been changed/removed since the command was run.", nil)
        return
    end
    if not data.ammoPrototype.valid then
        CommandsUtils.LogPrintWarning(commandName, nil, "The in-game ammo prototype has been changed/removed since the command was run.", nil)
        return
    end

    local ammoName ---@type string|nil
    if data.ammoPrototype ~= nil and data.ammoPrototype.valid and data.ammoCount > 0 then
        ammoName = data.ammoPrototype.name
    end
    if data.weaponPrototype ~= nil and data.weaponPrototype.valid then
        PlayerWeapon.EnsureHasWeapon(targetPlayer, data.weaponPrototype.name, data.forceWeaponToSlot, data.selectWeapon, ammoName)
    end
    if ammoName ~= nil then
        local inserted = targetPlayer.insert({ name = ammoName, count = data.ammoCount })
        if inserted < data.ammoCount then
            targetPlayer.surface.spill_item_stack(targetPlayer.position, { name = ammoName, count = data.ammoCount - inserted }, true, nil, false)
        end
    end
end

return GiveItems
