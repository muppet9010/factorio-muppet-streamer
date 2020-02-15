local TeamMember = {}
local Events = require("utility/events")
local GuiUtil = require("utility/gui-util")
local Commands = require("utility/commands")
local Logging = require("utility/logging")

TeamMember.CreateGlobals = function()
    global.teamMember = global.teamMember or {}
    global.teamMember.recruitedMaxCount = global.teamMember.recruitedMaxCount or 0
    global.teamMember.playerGuiOpened = global.teamMember.playerGuiOpened or {}
    global.teamMember.recruitTeamMemberTitle = global.teamMember.recruitTeamMemberTitle or ""
end

TeamMember.OnLoad = function()
    Events.RegisterHandler(defines.events.on_research_finished, "TeamMember", TeamMember.OnResearchFinished)
    Events.RegisterHandler(defines.events.on_lua_shortcut, "TeamMember", TeamMember.OnLuaShortcut)
    Events.RegisterHandler(defines.events.on_player_joined_game, "TeamMember", TeamMember.OnPlayerJoinedGame)
    Events.RegisterHandler(defines.events.on_player_left_game, "TeamMember", TeamMember.OnPlayerLeftGame)
    Events.RegisterHandler(defines.events.on_runtime_mod_setting_changed, "TeamMember", TeamMember.OnSettingChanged)
    remote.add_interface("muppet_streamer", {increase_team_member_level = TeamMember.RemoteIncreaseTeamMemberLevel})
    Commands.Register("muppet_streamer_change_team_member_max", {"api-description.muppet_streamer_change_team_member_max"}, TeamMember.CommandChangeTeamMemberLevel, true)
end

TeamMember.OnStartup = function()
    TeamMember.GuiRecreateAll()
end

TeamMember.OnSettingChanged = function(event)
    local settingName = event.setting
    if (settingName == nil or settingName == "muppet_streamer-recruited_team_member_gui_title") then
        global.teamMember.recruitTeamMemberTitle = settings.global["muppet_streamer-recruited_team_member_gui_title"].value
    end
end

TeamMember.OnResearchFinished = function(event)
    local technology = event.research
    if string.find(technology.name, "muppet_streamer-recruit_team_member", 0, true) then
        global.teamMember.recruitedMaxCount = technology.level
        TeamMember.GuiUpdateAll()
    end
end

TeamMember.OnLuaShortcut = function(event)
    local shortcutName = event.prototype_name
    if shortcutName == "muppet_streamer-team_member_gui_button" then
        local player = game.get_player(event.player_index)
        TeamMember.ToggleGui(player)
    end
end

TeamMember.OnPlayerJoinedGame = function(event)
    local playerIndex = event.player_index
    global.teamMember.playerGuiOpened[playerIndex] = global.teamMember.playerGuiOpened[playerIndex] or true
    local player = game.get_player(playerIndex)
    TeamMember.GuiRecreatePlayer(player)
    TeamMember.GuiUpdateAll()
end

TeamMember.OnPlayerLeftGame = function()
    TeamMember.GuiUpdateAll()
end

TeamMember.GuiRecreateAll = function()
    for _, player in ipairs(game.connected_players) do
        TeamMember.GuiRecreatePlayer(player)
    end
end

TeamMember.GuiRecreatePlayer = function(player)
    if not global.teamMember.playerGuiOpened[player.index] then
        return
    end
    TeamMember.GuiDestroy(player)
    TeamMember.GuiCreatePlayer(player)
end

TeamMember.GuiCreatePlayer = function(player)
    GuiUtil.AddElement(
        {
            parent = player.gui.left,
            type = "frame",
            name = "main",
            direction = "vertical",
            style = "muppet_frame_main_marginTL_paddingBR",
            storeName = "TeamMember",
            children = {
                {
                    type = "flow",
                    direction = "vertical",
                    style = "muppet_flow_vertical_marginTL",
                    children = {
                        {
                            type = "label",
                            name = "team_members_recruited",
                            tooltip = {"self"},
                            style = "muppet_label_text_large_bold",
                            storeName = "TeamMember"
                        }
                    }
                }
            }
        }
    )
    TeamMember.GuiUpdatePlayer(player)
end

TeamMember.GuiUpdateAll = function()
    for _, player in ipairs(game.connected_players) do
        TeamMember.GuiUpdatePlayer(player)
    end
end

TeamMember.GuiUpdatePlayer = function(player)
    if not global.teamMember.playerGuiOpened[player.index] then
        return
    end
    GuiUtil.UpdateElementFromPlayersReferenceStorage(player.index, "TeamMember", "team_members_recruited", "label", {caption = {"self", global.teamMember.recruitTeamMemberTitle, #game.connected_players - 1, global.teamMember.recruitedMaxCount}})
end

TeamMember.GuiDestroy = function(player)
    GuiUtil.DestroyPlayersReferenceStorage(player.index, "TeamMember")
end

TeamMember.ToggleGui = function(player)
    if global.teamMember.playerGuiOpened[player.index] then
        global.teamMember.playerGuiOpened[player.index] = false
        TeamMember.GuiDestroy(player)
        player.set_shortcut_toggled("muppet_streamer-team_member_gui_button", false)
    else
        global.teamMember.playerGuiOpened[player.index] = true
        TeamMember.GuiRecreatePlayer(player)
        player.set_shortcut_toggled("muppet_streamer-team_member_gui_button", true)
    end
end

TeamMember.RemoteIncreaseTeamMemberLevel = function(changeQuantity)
    global.teamMember.recruitedMaxCount = global.teamMember.recruitedMaxCount + changeQuantity
    TeamMember.GuiUpdateAll()
end

TeamMember.CommandChangeTeamMemberLevel = function(command)
    local args = Commands.GetArgumentsFromCommand(command.parameter)
    local errorMessageStartText = "ERROR: muppet_streamer_change_team_member_max command "
    if #args ~= 1 then
        Logging.LogPrint(errorMessageStartText .. "requires a value to be provided to change the level by.")
        return
    end
    local changeValueString = args[1]
    local changeValue = tonumber(changeValueString)
    if changeValue == nil then
        Logging.LogPrint(errorMessageStartText .. "requires a number value to be provided to change the level by, provided: " .. changeValueString)
        return
    end
    if tonumber(settings.startup["muppet_streamer-recruit_team_member_technology_cost"].value) ~= 0 then
        Logging.LogPrint(errorMessageStartText .. " is only suitable for use when technology researchs aren't being used.")
        return
    end

    global.teamMember.recruitedMaxCount = global.teamMember.recruitedMaxCount + changeValue
    TeamMember.GuiUpdateAll()
end

return TeamMember
