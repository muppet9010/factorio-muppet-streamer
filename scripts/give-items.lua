local GiveItems = {}
local PlayerWeapon = require("utility.functions.player-weapon")
local CommandsUtils = require("utility.helper-utils.commands-utils")
local LoggingUtils = require("utility.helper-utils.logging-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local BooleanUtils = require("utility.helper-utils.boolean-utils")
local Common = require("scripts.common")

---@class GiveItems_GiveWeaponAmmoScheduled
---@field target string @ Target player's name.
---@field ammoType? LuaItemPrototype|nil @ Nil if no ammo is being given.
---@field ammoCount? uint|nil @ Nil if no ammo is being given.
---@field weaponType? LuaItemPrototype|nil
---@field forceWeaponToSlot boolean
---@field selectWeapon boolean

GiveItems.CreateGlobals = function()
    global.giveItems = global.giveItems or {}
    global.giveItems.nextId = global.giveItems.nextId or 0
end

GiveItems.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_give_player_weapon_ammo", {"api-description.muppet_streamer_give_player_weapon_ammo"}, GiveItems.GivePlayerWeaponAmmoCommand, true)
    EventScheduler.RegisterScheduledEventType("GiveItems.GiveWeaponAmmoScheduled", GiveItems.GiveWeaponAmmoScheduled)
end

---@param command CustomCommandData
GiveItems.GivePlayerWeaponAmmoCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_give_player_weapon_ammo command "
    local commandName = "muppet_streamer_give_player_weapon_ammo"
    local commandData
    if command.parameter ~= nil then
        commandData = game.json_to_table(command.parameter)
    end
    if commandData == nil or type(commandData) ~= "table" then
        LoggingUtils.LogPrintError(errorMessageStart .. "requires details in JSON format.")
        LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
        return
    end ---@cast commandData table<string, any>

    local delaySeconds = tonumber(commandData.delay)
    if not CommandsUtils.ParseNumberArgument(delaySeconds, "double", false, commandName, "delay", 0, nil, command.parameter) then
        return
    end ---@cast delaySeconds double|nil
    local scheduleTick = Common.DelaySecondsSettingToScheduledEventTickValue(delaySeconds, command.tick, commandName, "delay")

    local target = commandData.target
    if not Common.CheckPlayerNameSettingValue(target, commandName, "target", command.parameter) then
        return
    end ---@cast target string

    local weaponTypeString, weaponType = commandData.weaponType, nil
    if weaponTypeString ~= nil and weaponTypeString ~= "" then
        weaponType = game.item_prototypes[weaponTypeString]
        if weaponType == nil or weaponType.type ~= "gun" then
            LoggingUtils.LogPrintError(errorMessageStart .. "optional weaponType provide, but isn't a valid type")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    ---@type boolean|nil
    local forceWeaponToSlot = false
    if commandData.forceWeaponToSlot ~= nil then
        forceWeaponToSlot = BooleanUtils.ToBoolean(commandData.forceWeaponToSlot)
        if forceWeaponToSlot == nil then
            LoggingUtils.LogPrintError(errorMessageStart .. "optional forceWeaponToSlot provided, but isn't a boolean true/false")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end ---@cast forceWeaponToSlot -nil

    ---@type boolean|nil
    local selectWeapon = false
    if commandData.selectWeapon ~= nil then
        selectWeapon = BooleanUtils.ToBoolean(commandData.selectWeapon)
        if selectWeapon == nil then
            LoggingUtils.LogPrintError(errorMessageStart .. "optional selectWeapon provided, but isn't a boolean true/false")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end ---@cast selectWeapon -nil

    ---@typelist string|nil, LuaItemPrototype|nil
    local ammoTypeString, ammoType = commandData.ammoType, nil
    if ammoTypeString ~= nil and ammoTypeString ~= "" then
        ammoType = game.item_prototypes[ammoTypeString]
        if ammoType == nil or ammoType.type ~= "ammo" then
            LoggingUtils.LogPrintError(errorMessageStart .. "optional ammoType provide, but isn't a valid type")
            LoggingUtils.LogPrintError(errorMessageStart .. "recieved text: " .. command.parameter)
            return
        end
    end

    ---@type uint|nil
    local ammoCount = tonumber(commandData.ammoCount) --[[@as uint]]
    if ammoCount == nil or ammoCount <= 0 then
        ammoType = nil
    end

    global.giveItems.nextId = global.giveItems.nextId + 1
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

    if data.weaponType ~= nil and data.weaponType.valid then
        PlayerWeapon.EnsureHasWeapon(targetPlayer, data.weaponType.name, data.forceWeaponToSlot, data.selectWeapon)
    end
    if data.ammoType ~= nil and data.ammoType.valid and data.ammoCount > 0 then
        local inserted = targetPlayer.insert({name = data.ammoType.name, count = data.ammoCount})
        if inserted < data.ammoCount then
            targetPlayer.surface.spill_item_stack(targetPlayer.position, {name = data.ammoType.name, count = data.ammoCount - inserted --[[@as uint]]}, true, nil, false)
        end
    end
end

return GiveItems
