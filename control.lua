local Freeplay = require("scripts.freeplay")
local TeamMember = require("scripts.team-member")
local ExplosiveDelivery = require("scripts.explosive-delivery")
local LeakyFlamethrower = require("scripts.leaky-flamethrower")
local EventScheduler = require("utility.managerLibraries.event-scheduler")
local GiveItems = require("scripts.give-items")
local SpawnAroundPlayer = require("scripts.spawn-around-player")
local AggressiveDriver = require("scripts.aggressive-driver")
local CallForHelp = require("scripts.call-for-help")
local Teleport = require("scripts.teleport")
local PantsOnFire = require("scripts.pants-on-fire")
local PlayerDropInventory = require("scripts.player-drop-inventory")
local PlayerInventoryShuffle = require("scripts.player-inventory-shuffle")
local BuildingGhosts = require("scripts.building-ghosts")

local function CreateGlobals()
    global.origionalPlayersPermissionGroup = global.origionalPlayersPermissionGroup or {} -- Used to track the last non-modded permission group across all the features. So we restore back to it after jumping between modded permission groups. Reset upon the last feature expiring.

    TeamMember.CreateGlobals()
    BuildingGhosts.CreateGlobals()
    ExplosiveDelivery.CreateGlobals()
    LeakyFlamethrower.CreateGlobals()
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
    BuildingGhosts.OnLoad()
    TeamMember.OnLoad()
    ExplosiveDelivery.OnLoad()
    LeakyFlamethrower.OnLoad()
    GiveItems.OnLoad()
    SpawnAroundPlayer.OnLoad()
    AggressiveDriver.OnLoad()
    CallForHelp.OnLoad()
    Teleport.OnLoad()
    PantsOnFire.OnLoad()
    PlayerDropInventory.OnLoad()
    PlayerInventoryShuffle.OnLoad()
end

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
    LeakyFlamethrower.OnStartup()
    AggressiveDriver.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_event(defines.events.on_runtime_mod_setting_changed, OnSettingChanged)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()

-- Mod wide function interface table creation. Means EmmyLua can support it and saves on UPS cost of old Interface function middelayer.
---@class InternalInterfaces
MOD.Interfaces = MOD.Interfaces or {} ---@type table<string, function>
--[[
    Populate and use from within module's OnLoad() functions with simple table reference structures, i.e:
        MOD.Interfaces.Tunnel = MOD.Interfaces.Tunnel or {}
        MOD.Interfaces.Tunnel.CompleteTunnel = Tunnel.CompleteTunnel
--]]
--
