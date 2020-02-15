# factorio-streamer-support-team
Mod for streamers to disable some default Factorio things and earn/research extra team members (players) to help them in Multiplayer.


Features
-----------
- Disable freeplay's rocket counter GUI
- Disable freeplay's introduction message
- Disable freeplay's rocket win
- Add a team member limit feature for use in Multiplayer by streamers.


Team Member Limit (other players than 1 streamer)
------------
- Includes a simple one line GUI in the top left that says the current number of team members (players - 1) and the current max team members.
- Option to have research to increase the number of team members. Cost is configurable and the research levels increase in science pack complexity. Infinite options that double in cost each time.
- Modding interface and command to increase the max team member count by a set amount. For use with other mods/streaming integrations when the research option isn't being used.
- Command:
    - syntax: `/muppet_streamer_change_team_member_max CHANGENUMBER`
    - example to increase by 2: `/muppet_streamer_change_team_member_max 2`