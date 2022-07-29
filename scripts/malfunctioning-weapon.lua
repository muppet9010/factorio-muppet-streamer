local MalfunctioningWeapon = {} ---@class MalfunctioningWeapon
local CommandsUtils = require("utility.helper-utils.commands-utils")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local Events = require("utility.manager-libraries.events")
local PlayerWeapon = require("utility.functions.player-weapon")
local PositionUtils = require("utility.helper-utils.position-utils")
local Common = require("scripts.common")
local MathUtils = require("utility.helper-utils.math-utils")

---@enum MalfunctioningWeapon_EffectEndStatus
local EffectEndStatus = {
    completed = "completed",
    died = "died",
    invalid = "invalid"
}

---@class MalfunctioningWeapon_ScheduledEventDetails
---@field target string @ Target player's name.
---@field ammoCount uint
---@field reloadTicks uint @ >=1
---@field weaponPrototype LuaItemPrototype
---@field ammoPrototype LuaItemPrototype

---@class MalfunctioningWeapon_ShootFlamethrowerDetails
---@field player LuaPlayer
---@field player_index uint
---@field angle double
---@field distance double
---@field currentBurstTicks uint
---@field burstsDone uint
---@field maxBursts uint
---@field usedSomeAmmo boolean @ If the player has actually used some of their ammo, otherwise the player's weapons are still on cooldown.
---@field startingAmmoItemStacksCount uint @ How many item stacks of ammo the player had when we start trying to fire the weapon.
---@field startingAmmoItemStackAmmo uint @ The "ammo" property of the ammo item stack the player had when we start trying to fire the weapon.
---@field weaponPrototype LuaItemPrototype
---@field ammoPrototype LuaItemPrototype
---@field minRange float
---@field maxRange float
---@field cooldownTicks uint @ >= 1
---@field reloadTicks uint @ >=1

---@class MalfunctioningWeapon_AffectedPlayersDetails
---@field flamethrowerGiven boolean @ If a flamethrower weapon had to be given to the player or if they already had one.
---@field burstsLeft uint
---@field removedWeaponDetails UtilityPlayerWeapon_RemovedWeaponToEnsureWeapon
---@field weaponPrototype LuaItemPrototype
---@field ammoPrototype LuaItemPrototype

local commandName = "muppet_streamer_malfunctioning_weapon"

MalfunctioningWeapon.CreateGlobals = function()
    global.leakyFlamethrower = global.leakyFlamethrower or {}
    global.leakyFlamethrower.affectedPlayers = global.leakyFlamethrower.affectedPlayers or {} ---@type table<uint, MalfunctioningWeapon_AffectedPlayersDetails> @ Key'd by player_index.
    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId or 0 ---@type uint
end

MalfunctioningWeapon.OnLoad = function()
    CommandsUtils.Register("muppet_streamer_malfunctioning_weapon", { "api-description.muppet_streamer_malfunctioning_weapon" }, MalfunctioningWeapon.MalfunctioningWeaponCommand, true)
    EventScheduler.RegisterScheduledEventType("MalfunctioningWeapon.ShootFlamethrower", MalfunctioningWeapon.ShootFlamethrower)
    Events.RegisterHandlerEvent(defines.events.on_pre_player_died, "MalfunctioningWeapon.OnPrePlayerDied", MalfunctioningWeapon.OnPrePlayerDied)
    EventScheduler.RegisterScheduledEventType("MalfunctioningWeapon.ApplyToPlayer", MalfunctioningWeapon.ApplyToPlayer)
    MOD.Interfaces.Commands.MalfunctioningWeapon = MalfunctioningWeapon.MalfunctioningWeaponCommand
    EventScheduler.RegisterScheduledEventType("MalfunctioningWeapon.StopEffectOnPlayer_Schedule", MalfunctioningWeapon.StopEffectOnPlayer_Schedule)
end

MalfunctioningWeapon.OnStartup = function()
    MalfunctioningWeapon.GetOrCreatePermissionGroup()
end

---@param command CustomCommandData
MalfunctioningWeapon.MalfunctioningWeaponCommand = function(command)
    local commandData = CommandsUtils.GetSettingsTableFromCommandParameterString(command.parameter, true, commandName, { "delay", "target", "ammoCount", "reloadTime", "weaponType", "ammoType" })
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

    local ammoCount = commandData.ammoCount
    if not CommandsUtils.CheckNumberArgument(ammoCount, "int", true, commandName, "ammoCount", 1, MathUtils.uintMax, command.parameter) then
        return
    end ---@cast ammoCount uint

    local reloadSeconds = commandData.reloadTime
    if not CommandsUtils.CheckNumberArgument(reloadSeconds, "double", false, commandName, "reloadTime", 1, math.floor(MathUtils.uintMax / 60), command.parameter) then
        return
    end ---@cast reloadSeconds double|nil
    local reloadTicks = math.max(math.floor((reloadSeconds or 3) * 60), 1) --[[@as uint @ Reload was validated as not exceeding a uint during input validation.]]

    local weaponPrototype, valid = Common.GetItemPrototypeFromCommandArgument(commandData.weaponType, "gun", false, commandName, "weaponType", command.parameter)
    if not valid then return end
    if weaponPrototype == nil then
        -- No custom weapon set, so use the base game weapon and confirm its valid.
        weaponPrototype = game.item_prototypes["flamethrower"]
        if weaponPrototype == nil or weaponPrototype.type ~= "gun" then
            CommandsUtils.LogPrintError(commandName, nil, "tried to use base game 'flamethrower' weapon, but it doesn't exist in this save.", command.parameter)
            return
        end
    end

    local ammoPrototype, valid = Common.GetItemPrototypeFromCommandArgument(commandData.ammoType, "ammo", false, commandName, "ammoType", command.parameter)
    if not valid then return end
    if ammoPrototype == nil then
        -- No custom ammo set, so use the base game ammo and confirm its valid.
        ammoPrototype = game.item_prototypes["flamethrower-ammo"]
        if ammoPrototype == nil or ammoPrototype.type ~= "ammo" then
            CommandsUtils.LogPrintError(commandName, nil, "tried to use base game 'flamethrower-ammo' ammo, but it doesn't exist in this save.", command.parameter)
            return
        end
    end

    --Check that the ammo is suitable for our needs.
    local ammoType = ammoPrototype.get_ammo_type("player") --[[@as AmmoType @ We've already validated this is of type ammo.]]
    if not PlayerWeapon.IsAmmoCompatibleWithWeapon(ammoType, weaponPrototype) then
        CommandsUtils.LogPrintError(commandName, nil, "ammo isn't compatible with the weapon.", command.parameter)
        return
    end
    local ammoType_targetType = ammoType.target_type
    if ammoType_targetType ~= "position" and ammoType_targetType ~= "direction" then
        CommandsUtils.LogPrintError(commandName, nil, "ammo can't be shot at the ground and so can't be used.", command.parameter)
        return
    end

    -- Some modded weapons may have a reload time greater than the delay setting and so we must wait for this otherwise we can't start shooting when we expect.
    reloadTicks = math.max(reloadTicks, ammoPrototype.reload_time)

    global.leakyFlamethrower.nextId = global.leakyFlamethrower.nextId + 1 ---@type uint @ Needed for weird bug reason, maybe in Sumneko or maybe the plugin with its fake global.
    ---@type MalfunctioningWeapon_ScheduledEventDetails
    local scheduledEventDetails = { target = target, ammoCount = ammoCount, reloadTicks = reloadTicks, weaponPrototype = weaponPrototype, ammoPrototype = ammoPrototype }
    EventScheduler.ScheduleEventOnce(scheduleTick, "MalfunctioningWeapon.ApplyToPlayer", global.leakyFlamethrower.nextId, scheduledEventDetails)
end

---@param eventData UtilityScheduledEvent_CallbackObject
MalfunctioningWeapon.ApplyToPlayer = function(eventData)
    local data = eventData.data ---@type MalfunctioningWeapon_ScheduledEventDetails

    local targetPlayer = game.get_player(data.target)
    if targetPlayer == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted since the command was run.", nil)
        return
    end
    if targetPlayer.controller_type ~= defines.controllers.character or targetPlayer.character == nil then
        game.print({ "message.muppet_streamer_malfunctioning_weapon_not_character_controller", data.target })
        return
    end
    local targetPlayer_index = targetPlayer.index

    -- Check the weapon and ammo are still valid (unchanged).
    if not data.weaponPrototype.valid then
        CommandsUtils.LogPrintWarning(commandName, nil, "The in-game weapon prototype has been changed/removed since the command was run.", nil)
        return
    end
    if not data.ammoPrototype.valid then
        CommandsUtils.LogPrintWarning(commandName, nil, "The in-game ammo prototype has been changed/removed since the command was run.", nil)
        return
    end

    -- If this player already has the effect active then terminate this new instance.
    if global.leakyFlamethrower.affectedPlayers[targetPlayer_index] ~= nil then
        return
    end

    targetPlayer.driving = false
    local flamethrowerGiven, removedWeaponDetails = PlayerWeapon.EnsureHasWeapon(targetPlayer, data.weaponPrototype.name, true, true, data.ammoPrototype.name) ---@cast removedWeaponDetails - nil @ removedWeaponDetails is always populated in our use case as we are forcing the weapon to be equipped (not allowing it to go in to the player's inventory).

    if flamethrowerGiven == nil then
        CommandsUtils.LogPrintError(commandName, nil, "target player can't be given a flamethrower for some odd reason: " .. data.target, nil)
        return
    end

    -- Put the required ammo in the guns related ammo slot.
    local selectedAmmoItemStack = targetPlayer.get_inventory(defines.inventory.character_ammo)[removedWeaponDetails.gunInventoryIndex]
    if selectedAmmoItemStack.valid_for_read then
        -- There's a stack there and it will be flamethrower ammo from when we forced the weapon to the player.
        -- Just give the ammo to the player and it will auto assign it correctly.
        local inserted = targetPlayer.insert({ name = data.ammoPrototype.name, count = data.ammoCount })
        if inserted < data.ammoCount then
            targetPlayer.surface.spill_item_stack(targetPlayer.position, { name = data.ammoPrototype.name, count = data.ammoCount - inserted }, true, nil, false)
        end
    else
        -- No current ammo in the slot. So just set our required one.
        selectedAmmoItemStack.set_stack({ name = data.ammoPrototype.name, count = data.ammoCount })
    end

    -- Check the player has the weapon equipped as expected. (same as checking logic as when it tries to fire the weapon).
    local selectedGunIndex = targetPlayer.character.selected_gun_index
    local selectedGunInventory = targetPlayer.get_inventory(defines.inventory.character_guns)[selectedGunIndex]
    if selectedGunInventory == nil or (not selectedGunInventory.valid_for_read) or selectedGunInventory.name ~= data.weaponPrototype.name then
        -- Flamethrower has been removed as active weapon by some script.
        CommandsUtils.LogPrintError(commandName, nil, "target player weapon state isn't right for some odd reason: " .. data.target, nil)
        return
    end
    -- Check the player has the weapon's ammo equipped as expected. (same as checking logic as when it tries to fire the weapon).
    local selectedAmmoInventory = targetPlayer.get_inventory(defines.inventory.character_ammo)[selectedGunIndex]
    if selectedAmmoInventory == nil or (not selectedAmmoInventory.valid_for_read) or selectedAmmoInventory.name ~= data.ammoPrototype.name then
        -- Ammo has been removed by some script. As we wouldn't have reached this point in a managed loop as its beyond the last burst.
        CommandsUtils.LogPrintError(commandName, nil, "target player ammo state isn't right for some odd reason: " .. data.target, nil)
        return
    end

    -- Get the starting ammo item and ammo counts. As they may already have had flamer ammo and we've added to it.
    local startingAmmoItemStacksCount, startingAmmoItemStackAmmo = selectedAmmoItemStack.count, selectedAmmoItemStack.ammo

    -- Store the players current permission group. Left as the previously stored group if an effect was already being applied to the player, or captured if no present effect affects them.
    global.originalPlayersPermissionGroup[targetPlayer_index] = global.originalPlayersPermissionGroup[targetPlayer_index] or targetPlayer.permission_group

    targetPlayer.permission_group = MalfunctioningWeapon.GetOrCreatePermissionGroup()
    global.leakyFlamethrower.affectedPlayers[targetPlayer_index] = { flamethrowerGiven = flamethrowerGiven, burstsLeft = data.ammoCount, removedWeaponDetails = removedWeaponDetails, weaponPrototype = data.weaponPrototype, ammoPrototype = data.ammoPrototype }

    local startingAngle = math.random(0, 360)

    local ammoType = data.ammoPrototype.get_ammo_type("player") --[[@as AmmoType @ We've already validated this is of type ammo.]]
    local minRange, maxRange, cooldown = PlayerWeapon.GetWeaponAmmoDetails(ammoType, data.weaponPrototype)
    local startingDistance = MathUtils.GetRandomDoubleInRange(minRange, maxRange)
    local cooldownTicks = math.max(MathUtils.RoundNumberToDecimalPlaces(cooldown, 0), 1) --[[@as uint]]
    -- One or more ticks (rounded). Anything that fires quicker than once per tick will be slowed down as other code can't handle it.

    game.print({ "message.muppet_streamer_malfunctioning_weapon_start", targetPlayer.name, data.weaponPrototype.localised_name })

    ---@type MalfunctioningWeapon_ShootFlamethrowerDetails
    local shootFlamethrowerDetails = { player = targetPlayer, angle = startingAngle, distance = startingDistance, currentBurstTicks = 0, burstsDone = 0, maxBursts = data.ammoCount, player_index = targetPlayer_index, usedSomeAmmo = false, startingAmmoItemStacksCount = startingAmmoItemStacksCount, startingAmmoItemStackAmmo = startingAmmoItemStackAmmo, weaponPrototype = data.weaponPrototype, ammoPrototype = data.ammoPrototype, minRange = minRange, maxRange = maxRange, cooldownTicks = cooldownTicks, reloadTicks = data.reloadTicks }
    ---@type UtilityScheduledEvent_CallbackObject
    local shootFlamethrowerCallbackObject = { tick = eventData.tick, instanceId = targetPlayer_index, data = shootFlamethrowerDetails }
    MalfunctioningWeapon.ShootFlamethrower(shootFlamethrowerCallbackObject)
end

---@param eventData UtilityScheduledEvent_CallbackObject
MalfunctioningWeapon.ShootFlamethrower = function(eventData)
    local data = eventData.data ---@type MalfunctioningWeapon_ShootFlamethrowerDetails
    local player, playerIndex = data.player, data.player_index
    if (not player.valid) or player.character == nil or (not player.character.valid) or player.vehicle ~= nil then
        MalfunctioningWeapon.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
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

    -- Check the player has the weapon equipped as expected.
    local selectedGunIndex = player.character.selected_gun_index
    local selectedGunInventory = player.get_inventory(defines.inventory.character_guns)[selectedGunIndex]
    if selectedGunInventory == nil or (not selectedGunInventory.valid_for_read) or selectedGunInventory.name ~= data.weaponPrototype.name then
        -- Flamethrower has been removed as active weapon by some script.
        MalfunctioningWeapon.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- Check the player has the weapon's ammo equipped as expected.
    local selectedAmmoInventory = player.get_inventory(defines.inventory.character_ammo)[selectedGunIndex]
    if selectedAmmoInventory == nil or (not selectedAmmoInventory.valid_for_read) or selectedAmmoInventory.name ~= data.ammoPrototype.name then
        -- Ammo has been removed by some script. As we wouldn't have reached this point in a managed loop as its beyond the last burst.
        MalfunctioningWeapon.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    -- When first trying to fire the weapon detect when we successfully expend some ammo. As an existing weapon cooldown at effect start will delay us starting to shoot the flamethrower. Leading to the player being left with a tiny bit of ammo at the end.
    -- This will accept a scripted removal of ammo as being equivalent to the ammo started being fired, but this should be fine and we can't tell the difference, so meh.
    -- CODE NOTE: No way to read or set a player's gun cooldown, so this monitoring is the best option I can think of.
    if not data.usedSomeAmmo then
        local currentAmmoItemStacksCount, currentAmmoItemStackAmmo = selectedAmmoInventory.count, selectedAmmoInventory.ammo
        if currentAmmoItemStacksCount < data.startingAmmoItemStacksCount then
            -- Players shot some ammo and its finished an item off, so ignore the ammo property and assume all is good.
            data.usedSomeAmmo = true
        elseif currentAmmoItemStacksCount == data.startingAmmoItemStacksCount then
            if currentAmmoItemStackAmmo < data.startingAmmoItemStackAmmo then
                -- Players shot some of the ammo property on the current item stack count, so assume all is good.
                data.usedSomeAmmo = true
            elseif currentAmmoItemStackAmmo == data.startingAmmoItemStackAmmo then
                -- Nothings changed so continue to monitor. Will run on at least the initial tick the effect is active as that tick we set the player to shoot, but they don't do it until the end of the tick.
                data.currentBurstTicks = 0
            else
                -- Ammo prototype has increased, so players picked up ammo. So update counts and we will continue monitoring next tick from these new values.
                data.startingAmmoItemStacksCount = currentAmmoItemStacksCount
                data.startingAmmoItemStackAmmo = currentAmmoItemStackAmmo
            end
        else
            -- Ammo stacks has increased, son players picked up ammo. So update counts and we will continue monitoring next tick from these new values.
            data.startingAmmoItemStacksCount = currentAmmoItemStacksCount
            data.startingAmmoItemStackAmmo = currentAmmoItemStackAmmo
        end
    end

    local nextShootDelayTicks ---@type uint
    data.currentBurstTicks = data.currentBurstTicks + 1
    -- Do the action for this tick.
    if data.currentBurstTicks > data.ammoPrototype.magazine_size then
        -- End of shooting ticks. Ready for next shooting and take break.
        data.currentBurstTicks = 0
        data.burstsDone = data.burstsDone + 1
        global.leakyFlamethrower.affectedPlayers[playerIndex].burstsLeft = global.leakyFlamethrower.affectedPlayers[playerIndex].burstsLeft - 1
        player.shooting_state = { state = defines.shooting.not_shooting }

        if data.burstsDone == data.maxBursts then
            MalfunctioningWeapon.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
            return
        end

        -- Prepare for the next shooting period.
        data.angle = math.random(0, 360)
        data.distance = MathUtils.GetRandomDoubleInRange(data.minRange, data.maxRange)
        nextShootDelayTicks = data.reloadTicks
    else
        -- Shoot this tick as a small random wonder from last ticks target.
        data.distance = math.min(math.max(data.distance + ((math.random() * 2) - 1), data.minRange), data.maxRange)
        if data.weaponPrototype.attack_parameters.type == "stream" then
            -- A stream weapon waves around on both distance and angle, so do less in each.
            data.angle = data.angle + (math.random(-10, 10))
        else
            -- A projectile and beam weapon shoots for its distance so the angle needs to change much faster.
            data.angle = data.angle + (math.random(-50, 50))
        end
        local targetPos = PositionUtils.GetPositionForAngledDistance(player.position, data.distance, data.angle)
        player.shooting_state = { state = defines.shooting.shooting_selected, position = targetPos }
        nextShootDelayTicks = data.cooldownTicks
    end

    EventScheduler.ScheduleEventOnce(eventData.tick + nextShootDelayTicks, "MalfunctioningWeapon.ShootFlamethrower", playerIndex, data)
end

--- Called when a player has died, but before their character is turned in to a corpse.
---@param event on_pre_player_died
MalfunctioningWeapon.OnPrePlayerDied = function(event)
    MalfunctioningWeapon.StopEffectOnPlayer(event.player_index, nil, EffectEndStatus.died)
end

---@param eventData UtilityScheduledEvent_CallbackObject
MalfunctioningWeapon.StopEffectOnPlayer_Schedule = function(eventData)
    local data = eventData.data ---@type MalfunctioningWeapon_ShootFlamethrowerDetails
    local player, playerIndex = data.player, data.player_index
    if (not player.valid) or player.character == nil or (not player.character.valid) or player.vehicle ~= nil then
        MalfunctioningWeapon.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.invalid)
        return
    end

    MalfunctioningWeapon.StopEffectOnPlayer(playerIndex, player, EffectEndStatus.completed)
end

--- Called when the effect has been stopped and the effects state and weapon changes should be undone.
--- Called when the player is alive or if they have died before their character has been affected.
---@param playerIndex uint
---@param player LuaPlayer|nil @ Obtained if needed and not provided.
---@param status MalfunctioningWeapon_EffectEndStatus
MalfunctioningWeapon.StopEffectOnPlayer = function(playerIndex, player, status)
    local affectedPlayer = global.leakyFlamethrower.affectedPlayers[playerIndex]
    if affectedPlayer == nil then
        return
    end

    -- Remove the flag against this player as being currently affected by the leaky flamethrower.
    global.leakyFlamethrower.affectedPlayers[playerIndex] = nil

    player = player or game.get_player(playerIndex)
    if player == nil then
        CommandsUtils.LogPrintWarning(commandName, nil, "Target player has been deleted while the effect was running.", nil)
        return
    end
    local playerHasCharacter = player ~= nil and player.character ~= nil

    -- Take back any weapon and ammo from a player with a character (alive or just dead).
    if playerHasCharacter then
        -- Confirm the prototypes are still valid, if they aren't then the player will have lost those items anyway.
        if affectedPlayer.flamethrowerGiven and affectedPlayer.weaponPrototype.valid then
            PlayerWeapon.TakeItemFromPlayerOrGround(player, affectedPlayer.weaponPrototype.name, 1)
        end
        if affectedPlayer.burstsLeft > 0 and affectedPlayer.ammoPrototype.valid then
            PlayerWeapon.TakeItemFromPlayerOrGround(player, affectedPlayer.ammoPrototype.name, affectedPlayer.burstsLeft)
        end
    end

    -- Return the player's weapon and ammo filters (alive or just dead) if there were any.
    PlayerWeapon.ReturnRemovedWeapon(player, affectedPlayer.removedWeaponDetails)

    -- Return the player to their initial permission group.
    if player.permission_group.name == "MalfunctioningWeapon" then
        -- If the permission group has been changed by something else don't set it back to the last non modded one.
        player.permission_group = global.originalPlayersPermissionGroup[playerIndex]
        global.originalPlayersPermissionGroup[playerIndex] = nil
    end

    -- Remove any shooting state set and maintained from previous ticks.
    player.shooting_state = { state = defines.shooting.not_shooting }

    -- Print a message based on ending status.
    if status == EffectEndStatus.completed then
        game.print({ "message.muppet_streamer_malfunctioning_weapon_stop", player.name })
    end
end

--- Gets the permission group for this feature. Will create it if needed.
---@return LuaPermissionGroup
MalfunctioningWeapon.GetOrCreatePermissionGroup = function()
    local group = game.permissions.get_group("MalfunctioningWeapon") or game.permissions.create_group("MalfunctioningWeapon") ---@cast group - nil @ Script always has permission to create groups.
    group.set_allows_action(defines.input_action.select_next_valid_gun, false)
    group.set_allows_action(defines.input_action.toggle_driving, false)
    group.set_allows_action(defines.input_action.change_shooting_state, false)
    return group
end

return MalfunctioningWeapon
