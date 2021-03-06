data:extend(
    {
        {
            name = "muppet_streamer-disable_intro_message",
            type = "bool-setting",
            default_value = false,
            setting_type = "startup",
            order = "1002"
        },
        {
            name = "muppet_streamer-disable_rocket_win",
            type = "bool-setting",
            default_value = false,
            setting_type = "startup",
            order = "1003"
        },
        {
            name = "muppet_streamer-starting_reveal",
            type = "int-setting",
            default_value = -1,
            minimum_value = -1,
            setting_type = "startup",
            order = "1004"
        },
        {
            name = "muppet_streamer-recruit_team_member_technology_cost",
            type = "int-setting",
            default_value = -1,
            min_value = -1,
            setting_type = "startup",
            order = "2001"
        },
        {
            name = "muppet_streamer-recruit_team_member_technology_title",
            type = "string-setting",
            default_value = "Recruit Team Member",
            allow_blank = true,
            setting_type = "startup",
            order = "2002"
        },
        {
            name = "muppet_streamer-recruit_team_member_technology_description",
            type = "string-setting",
            default_value = "Recruit another team member to increase your maximum concurrent team size",
            allow_blank = true,
            setting_type = "startup",
            order = "2003"
        }
    }
)

data:extend(
    {
        {
            name = "muppet_streamer-recruited_team_member_gui_title",
            type = "string-setting",
            default_value = "Active team members",
            allow_blank = true,
            setting_type = "runtime-global",
            order = "2001"
        }
    }
)
