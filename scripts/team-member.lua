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
    if tonumber(settings.startup["muppet_streamer-recruit_team_member_technology_cost"].value) < 0 then
        return
    end

    Events.RegisterHandlerEvent(defines.events.on_research_finished, "TeamMember", TeamMember.OnResearchFinished)
    Events.RegisterHandlerEvent(defines.events.on_lua_shortcut, "TeamMember", TeamMember.OnLuaShortcut)
    Events.RegisterHandlerEvent(defines.events.on_player_joined_game, "TeamMember", TeamMember.OnPlayerJoinedGame)
    Events.RegisterHandlerEvent(defines.events.on_player_left_game, "TeamMember", TeamMember.OnPlayerLeftGame)
    remote.add_interface("muppet_streamer", {increase_team_member_level = TeamMember.RemoteIncreaseTeamMemberLevel})
    Commands.Register("muppet_streamer_change_team_member_max", {"api-description.muppet_streamer_change_team_member_max"}, TeamMember.CommandChangeTeamMemberLevel, true)
end

TeamMember.OnStartup = function()
    if tonumber(settings.startup["muppet_streamer-recruit_team_member_technology_cost"].value) < 0 then
        return
    end

    TeamMember.GuiRecreateForAll()
end

TeamMember.OnSettingChanged = function(event)
    local settingName
    if event ~= nil then
        settingName = event.setting
    end
    if (settingName == nil or settingName == "muppet_streamer-recruited_team_member_gui_title") then
        global.teamMember.recruitTeamMemberTitle = settings.global["muppet_streamer-recruited_team_member_gui_title"].value
    end
end

TeamMember.OnResearchFinished = function(event)
    local technology = event.research
    if string.find(technology.name, "muppet_streamer-recruit_team_member", 0, true) then
        global.teamMember.recruitedMaxCount = technology.level
        TeamMember.GuiUpdateForAll()
    end
end

TeamMember.OnLuaShortcut = function(event)
    local shortcutName = event.prototype_name
    if shortcutName == "muppet_streamer-team_member_gui_button" then
        local player = game.get_player(event.player_index)
        if global.teamMember.playerGuiOpened[player.index] then
            TeamMember.GuiCloseForPlayer(player)
        else
            TeamMember.GuiOpenForPlayer(player)
        end
    end
end

TeamMember.OnPlayerJoinedGame = function(event)
    local playerIndex = event.player_index
    global.teamMember.playerGuiOpened[playerIndex] = global.teamMember.playerGuiOpened[playerIndex] or true
    local player = game.get_player(playerIndex)
    TeamMember.GuiRecreateForPlayer(player)
    TeamMember.GuiUpdateForAll()
end

TeamMember.OnPlayerLeftGame = function()
    TeamMember.GuiUpdateForAll()
end

TeamMember.GuiRecreateForAll = function()
    for _, player in ipairs(game.connected_players) do
        TeamMember.GuiRecreateForPlayer(player)
    end
end

TeamMember.GuiRecreateForPlayer = function(player)
    GuiUtil.DestroyPlayersReferenceStorage(player.index, "TeamMember")
    if not global.teamMember.playerGuiOpened[player.index] then
        return
    end
    TeamMember.GuiOpenForPlayer(player)
end

TeamMember.GuiOpenForPlayer = function(player)
    global.teamMember.playerGuiOpened[player.index] = true
    player.set_shortcut_toggled("muppet_streamer-team_member_gui_button", true)
    TeamMember.GuiCreateForPlayer(player)
end

TeamMember.GuiCloseForPlayer = function(player)
    global.teamMember.playerGuiOpened[player.index] = false
    player.set_shortcut_toggled("muppet_streamer-team_member_gui_button", false)
    GuiUtil.DestroyPlayersReferenceStorage(player.index, "TeamMember")
end

TeamMember.GuiCreateForPlayer = function(player)
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
    TeamMember.GuiUpdateForPlayer(player)
end

TeamMember.GuiUpdateForAll = function()
    for _, player in ipairs(game.connected_players) do
        TeamMember.GuiUpdateForPlayer(player)
    end
end

TeamMember.GuiUpdateForPlayer = function(player)
    if not global.teamMember.playerGuiOpened[player.index] then
        return
    end
    GuiUtil.UpdateElementFromPlayersReferenceStorage(player.index, "TeamMember", "team_members_recruited", "label", {caption = {"self", global.teamMember.recruitTeamMemberTitle, #game.connected_players - 1, global.teamMember.recruitedMaxCount}})
end

TeamMember.RemoteIncreaseTeamMemberLevel = function(changeQuantity)
    local errorMessageStartText = "ERROR: muppet_streamer_change_team_member_max remote interface "
    if tonumber(settings.startup["muppet_streamer-recruit_team_member_technology_cost"].value) ~= 0 then
        Logging.LogPrint(errorMessageStartText .. " is only suitable for use when technology researchs aren't being used.")
        return
    end
    global.teamMember.recruitedMaxCount = global.teamMember.recruitedMaxCount + changeQuantity
    TeamMember.GuiUpdateForAll()
end

TeamMember.CommandChangeTeamMemberLevel = function(command)
    local args = Commands.GetArgumentsFromCommand(command.parameter)
    local errorMessageStartText = "ERROR: muppet_streamer_change_team_member_max command "
    if #args ~= 1 then
        Logging.LogPrint(errorMessageStartText .. "requires a value to be provided to change the level by.")
        Logging.LogPrint(errorMessageStartText .. "recieved text: " .. command.parameter)
        return
    end
    local changeValueString = args[1]
    local changeValue = tonumber(changeValueString)
    if changeValue == nil then
        Logging.LogPrint(errorMessageStartText .. "requires a number value to be provided to change the level by, provided: " .. changeValueString)
        Logging.LogPrint(errorMessageStartText .. "recieved text: " .. command.parameter)
        return
    end
    if tonumber(settings.startup["muppet_streamer-recruit_team_member_technology_cost"].value) ~= 0 then
        Logging.LogPrint(errorMessageStartText .. " is only suitable for use when technology researchs aren't being used.")
        Logging.LogPrint(errorMessageStartText .. "recieved text: " .. command.parameter)
        return
    end

    global.teamMember.recruitedMaxCount = global.teamMember.recruitedMaxCount + changeValue
    TeamMember.GuiUpdateForAll()
end

return TeamMember
