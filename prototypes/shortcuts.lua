local Constants = require("constants")

if tonumber(settings.startup["muppet_streamer-recruit_team_member_technology_cost"].value) >= 0 then
    data:extend(
        {
            {
                type = "shortcut",
                name = "muppet_streamer-team_member_gui_button",
                action = "lua",
                toggleable = true,
                icon = {
                    filename = Constants.AssetModName .. "/graphics/shortcuts/team_member32.png",
                    width = 32,
                    height = 32
                },
                small_icon = {
                    filename = Constants.AssetModName .. "/graphics/shortcuts/team_member24.png",
                    width = 24,
                    height = 24
                },
                disabled_small_icon = {
                    filename = Constants.AssetModName .. "/graphics/shortcuts/team_member24-disabled.png",
                    width = 24,
                    height = 24
                }
            }
        }
    )
end
