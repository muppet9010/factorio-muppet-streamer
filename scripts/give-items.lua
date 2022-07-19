local GiveItems = {}
local PlayerWeapon = require("utility.functions.player-weapon")
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@class GiveItems_GiveWeaponAmmoScheduled
---@field target string @ Target player's name.
---@field ammoType? LuaItemPrototype|nil @ Nil if no ammo is being given.
---@field ammoCount? uint|nil @ Nil if no ammo is being given.
---@field weaponType? LuaItemPrototype|nil
---@field forceWeaponToSlot boolean
---@field selectWeapon boolean

GiveItems.CreateGlobals = function()
    global.giveItems = global.giveItems or {}
    global.giveItems.nextId = global.giveItems.nextId or 0 ---@type uint
end

GiveItems.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_give_player_weapon_ammo", {"api-description.muppet_streamer_give_player_weapon_ammo"}, GiveItems.GivePlayerWeaponAmmoCommand, true)
    EventScheduler.RegisterScheduledEventType("GiveItems.GiveWeaponAmmoScheduled", GiveItems.GiveWeaponAmmoScheduled)
end

---@param command CustomCommandData
GiveItems.GivePlayerWeaponAmmoCommand = function(command)
    local commandName = "muppet_streamer_give_player_weapon_ammo"

    local commandData = CommandsUtils.GetSettingsTableFromCommandParamaterString(command.parameter, true, commandName, {"delay", "target", "weaponType", "forceWeaponToSlot", "selectWeapon", "ammoType", "ammoCount"})
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

    local weaponTypeString = commandData.weaponType
    if not CommandsUtils.CheckStringArgument(weaponTypeString, false, commandName, "weaponType", nil, command.parameter) then
        return
    end
    local weaponType  ---@type LuaItemPrototype|nil
    if weaponTypeString ~= nil and weaponTypeString ~= "" then
        weaponType = game.item_prototypes[weaponTypeString]
        if weaponType == nil or weaponType.type ~= "gun" then
            CommandsUtils.LogPrintError(commandName, "weaponType", "isn't a valid weapon type: " .. tostring(weaponTypeString), command.parameter)
            return
        end
    end

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

    local ammoTypeString = commandData.ammoType
    if not CommandsUtils.CheckStringArgument(ammoTypeString, false, commandName, "ammoType", nil, command.parameter) then
        return
    end
    local ammoType  ---@type LuaItemPrototype|nil
    if ammoTypeString ~= nil and ammoTypeString ~= "" then
        ammoType = game.item_prototypes[ammoTypeString]
        if ammoType == nil or ammoType.type ~= "ammo" then
            CommandsUtils.LogPrintError(commandName, "ammoType", "isn't a valid ammo type: " .. tostring(ammoTypeString), command.parameter)
            return
        end
    end

    local ammoCount = commandData.ammoCount
    if not CommandsUtils.CheckNumberArgument(ammoCount, "int", false, commandName, "ammoCount", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast ammoCount uint|nil

    global.giveItems.nextId = global.giveItems.nextId + 1 --[[@as uint]]
    ---@type GiveItems_GiveWeaponAmmoScheduled
    local giveWeaponAmmoScheduled = {target = target, ammoType = ammoType, ammoCount = ammoCount, weaponType = weaponType, forceWeaponToSlot = forceWeaponToSlot, selectWeapon = selectWeapon}
    EventScheduler.ScheduleEventOnce(scheduleTick, "GiveItems.GiveWeaponAmmoScheduled", global.giveItems.nextId, giveWeaponAmmoScheduled)
end

---@param eventData UtilityScheduledEvent_CallbackObject
GiveItems.GiveWeaponAmmoScheduled = function(eventData)
    local data = eventData.data ---@type GiveItems_GiveWeaponAmmoScheduled

    local targetPlayer = game.get_player(data.target)
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({"message.muppet_streamer_give_player_weapon_ammo_not_character_controller", data.target})
        return
    end

    local ammoName  ---@type string|nil
    if data.ammoType ~= nil and data.ammoType.valid and data.ammoCount > 0 then
        ammoName = data.ammoType.name
    end
    if data.weaponType ~= nil and data.weaponType.valid then
        PlayerWeapon.EnsureHasWeapon(targetPlayer, data.weaponType.name, data.forceWeaponToSlot, data.selectWeapon, ammoName)
    end
    if ammoName ~= nil then
        local inserted = targetPlayer.insert({name = ammoName, count = data.ammoCount})
        if inserted < data.ammoCount then
            targetPlayer.surface.spill_item_stack(targetPlayer.position, {name = ammoName, count = data.ammoCount - inserted --[[@as uint]]}, true, nil, false)
        end
    end
end

return GiveItems
