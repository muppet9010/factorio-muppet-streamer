# factorio-streamer-support-team
Mod for streamers to customise and add flavour to their play throughs.


Features
-----------

- Option to disable freeplay's rocket counter GUI
- Option to disable freeplay's introduction message
- Option to disable freeplay's rocket win
- Can add a team member limit GUI & research for use in Multiplayer by streamers. Supports commands.
- Can schedule the delivery of some explosives to a player via command.


Team Member Limit (other players than 1 streamer)
------------

- Includes a simple one line GUI in the top left that says the current number of team members (players - 1) and the current max team members.
- Option to have research to increase the number of team members. Cost is configurable and the research levels increase in science pack complexity. Infinite options that double in cost each time.
- Set the "Team member technology pack count" setting to 0 to hide the tech, but keep the feature active for use via mod or command.
- Set the "Team member technology pack count" setting to -1 to disable the feature entirely and rmeove it from the screen/shortcut bar.
- Modding interface and command to increase the max team member count by a set amount. For use with other mods/streaming integrations when the research option isn't being used.
- Command:
    - syntax: `/muppet_streamer_change_team_member_max CHANGENUMBER`
    - example to increase by 2: `/muppet_streamer_change_team_member_max 2`


Schedule Explosive Delivery
-----------------

- Can deliver a highly customisable explosive delivery via command. A number of the chosen explosive type after a delay will fly from offscreen to randomly around the target player. The perfect gift for any streamer.
- Command syntax: `/muppet_streamer_schedule_explosive_delivery [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds the arrival of the explosives will be delayed for. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - explosiveCount: NUMBER - Mandatory: the quantity of explosives to be delivered, if 0 then the command is ignored.
    - explosiveType: STRING - Mandatory: the type of explosive, can be any one of: "grenade", "clusterGrenade", "artilleryShell", "atomicRocket"
    - target: STRING - Mandatory: the player name to target.
    - accuracyRadiusMin: NUMBER - Optional: the minimum distance from the target that can be randomly selected within. If not specified defaults to 0.
    - accuracyRadiusMax: NUMBER - Optional: the maximum distance from the target that can be randomly selected within. If not specified defaults to 0.
- Example command 1: `/muppet_streamer_schedule_explosive_delivery {"delay":5, "explosiveCount":1, "explosiveType":"atomicRocket", "target":"muppet9010", "accuracyRadiusMax":50}`
- Example command 2: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":7, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":10, "accuracyRadiusMax":20}`
- At present is hard coded to the "nauvis" (default) surface.