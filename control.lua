local Freeplay = require("scripts.freeplay")
local TeamMember = require("scripts.team-member")
local ExplosiveDelivery = require("scripts.explosive-delivery")
local MalfunctioningWeapon = require("scripts.malfunctioning-weapon")
local EventScheduler = require("utility.manager-libraries.event-scheduler")
local GiveItems = require("scripts.give-items")
local SpawnAroundPlayer = require("scripts.spawn-around-player")
local AggressiveDriver = require("scripts.aggressive-driver")
local CallForHelp = require("scripts.call-for-help")
local Teleport = require("scripts.teleport")
local PantsOnFire = require("scripts.pants-on-fire")
local PlayerDropInventory = require("scripts.player-drop-inventory")
local PlayerInventoryShuffle = require("scripts.player-inventory-shuffle")
local BuildingGhosts = require("scripts.building-ghosts")
local Common = require("scripts.common")

local function CreateGlobals()
    global.originalPlayersPermissionGroup = global.originalPlayersPermissionGroup or {} ---@type table<uint, LuaPermissionGroup> @ Used to track the last non-modded permission group across all the features. So we restore back to it after jumping between modded permission groups. Reset upon the last feature expiring.

    TeamMember.CreateGlobals()
    BuildingGhosts.CreateGlobals()
    ExplosiveDelivery.CreateGlobals()
    MalfunctioningWeapon.CreateGlobals()
    GiveItems.CreateGlobals()
    SpawnAroundPlayer.CreateGlobals()
    AggressiveDriver.CreateGlobals()
    CallForHelp.CreateGlobals()
    Teleport.CreateGlobals()
    PantsOnFire.CreateGlobals()
    PlayerDropInventory.CreateGlobals()
    PlayerInventoryShuffle.CreateGlobals()
    PlayerInventoryShuffle.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    remote.remove_interface("muppet_streamer")
    remote.add_interface(
        "muppet_streamer",
        {
            run_command = Common.CallCommandFromRemote,
            increase_team_member_level = TeamMember.RemoteIncreaseTeamMemberLevel
        }
    )

    BuildingGhosts.OnLoad()
    TeamMember.OnLoad()
    ExplosiveDelivery.OnLoad()
    MalfunctioningWeapon.OnLoad()
    GiveItems.OnLoad()
    SpawnAroundPlayer.OnLoad()
    AggressiveDriver.OnLoad()
    CallForHelp.OnLoad()
    Teleport.OnLoad()
    PantsOnFire.OnLoad()
    PlayerDropInventory.OnLoad()
    PlayerInventoryShuffle.OnLoad()
end

---@param event on_runtime_mod_setting_changed
local function OnSettingChanged(event)
    TeamMember.OnSettingChanged(event)
    SpawnAroundPlayer.OnStartup()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    OnSettingChanged(nil)

    Freeplay.OnStartup()
    BuildingGhosts.OnStartup()
    TeamMember.OnStartup()
    MalfunctioningWeapon.OnStartup()
    AggressiveDriver.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()

-- Mod wide function interface table creation. Means EmmyLua can support it.
MOD = MOD or {} ---@class MOD
MOD.Interfaces = MOD.Interfaces or {} ---@class MOD_InternalInterfaces
MOD.Interfaces.Commands = MOD.Interfaces.Commands or {} ---@class MOD_InternalInterfaces_Commands
--[[
    Populate and use from within module's OnLoad() functions with simple table reference structures, i.e:
        MOD.Interfaces.Tunnel = MOD.Interfaces.Tunnel or {} ---@class InternalInterfaces_XXXXXX
        MOD.Interfaces.Tunnel.CompleteTunnel = Tunnel.CompleteTunnel
--]]
--
