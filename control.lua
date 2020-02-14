local Events = require("utility/events")
local TeamMember = require("scripts/team-member")
local Utils = require("utility/utils")

local function CreateGlobals()
    TeamMember.CreateGlobals()
end

local function OnLoad()
    --Any Remote Interface registration calls can go in here or in root of control.lua
    remote.remove_interface("muppet_streamer")
    TeamMember.OnLoad()

    if settings.startup["muppet_streamer-disable_silo_counter"].value then
        Utils.DisableSiloScript()
    end
end

local function OnStartup()
    CreateGlobals()
    OnLoad()
    Events.RaiseRuntimeModSettingChangedEventFromStartup()

    if settings.startup["muppet_streamer-disable_intro_message"].value then
        Utils.DisableIntroMessage()
    end
    if settings.startup["muppet_streamer-disable_rocket_win"].value then
        Utils.DisableWinOnRocket()
    end
    TeamMember.OnStartup()
end

script.on_init(OnStartup)
script.on_configuration_changed(OnStartup)
Events.RegisterEvent(defines.events.on_runtime_mod_setting_changed)
script.on_load(OnLoad)

Events.RegisterEvent(defines.events.on_research_finished)
Events.RegisterEvent(defines.events.on_lua_shortcut)
Events.RegisterEvent(defines.events.on_player_joined_game)
Events.RegisterEvent(defines.events.on_player_left_game)
