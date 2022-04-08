local Freeplay = require("scripts/freeplay")
local TeamMember = require("scripts/team-member")
local ExplosiveDelivery = require("scripts/explosive-delivery")
local LeakyFlamethrower = require("scripts/leaky-flamethrower")
local EventScheduler = require("utility/event-scheduler")
local GiveItems = require("scripts/give-items")
local SpawnAroundPlayer = require("scripts/spawn-around-player")
local AggressiveDriver = require("scripts/aggressive-driver")
local CallForHelp = require("scripts/call-for-help")
local Teleport = require("scripts/teleport")
local PantsOnFire = require("scripts/pants-on-fire")
local PlayerDropInventory = require("scripts.player-drop-inventory")

local function CreateGlobals()
    global.origionalPlayersPermissionGroup = global.origionalPlayersPermissionGroup or {} -- Used to track the last non-modded permission group across all the features. So we restore back to it after jumping between modded permission groups. Reset upon the last feature expiring.

    TeamMember.CreateGlobals()
    ExplosiveDelivery.CreateGlobals()
    LeakyFlamethrower.CreateGlobals()
    GiveItems.CreateGlobals()
    SpawnAroundPlayer.CreateGlobals()
    AggressiveDriver.CreateGlobals()
    CallForHelp.CreateGlobals()
    Teleport.CreateGlobals()
    PantsOnFire.CreateGlobals()
    PlayerDropInventory.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    remote.remove_interface("muppet_streamer")
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
end

local function OnSettingChanged(event)
    TeamMember.OnSettingChanged()
    SpawnAroundPlayer.OnStartup()
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    OnSettingChanged(nil)

    Freeplay.OnStartup()
    TeamMember.OnStartup()
    LeakyFlamethrower.OnStartup()
    AggressiveDriver.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
script.on_load(OnLoad)
EventScheduler.RegisterScheduler()
