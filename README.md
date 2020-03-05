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


Schedule Explosive Delivery to player
-----------------

Can deliver a highly customisable explosive delivery via command. A number of the chosen explosive type after a delay will fly from offscreen to randomly around the target player. The perfect gift for any streamer. Note, that it takes them a second or two to fly in from offscreen.

- Command syntax: `/muppet_streamer_schedule_explosive_delivery [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds the arrival of the explosives will be delayed for. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - explosiveCount: NUMBER - Mandatory: the quantity of explosives to be delivered, if 0 then the command is ignored.
    - explosiveType: STRING - Mandatory: the type of explosive, can be any one of: "grenade", "clusterGrenade", "slowdownCapsule", "poisonCapsule", "artilleryShell", "explosiveRocket", "atomicRocket", "smallSpit", "mediumSpit", "largeSpit"
    - target: STRING - Mandatory: the player name to target.
    - accuracyRadiusMin: NUMBER - Optional: the minimum distance from the target that can be randomly selected within. If not specified defaults to 0.
    - accuracyRadiusMax: NUMBER - Optional: the maximum distance from the target that can be randomly selected within. If not specified defaults to 0.
- Example command 1: `/muppet_streamer_schedule_explosive_delivery {"delay":5, "explosiveCount":1, "explosiveType":"atomicRocket", "target":"muppet9010", "accuracyRadiusMax":50}`
- Example command 2: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":7, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":10, "accuracyRadiusMax":20}`
- Explosives flying in will use their native throwing/shooting/spitting approach and so arrival trajectories may vary.


Leaky Flamethrower
------------------

Gives the targeted player a flamethrower that shoots in random dirctions for short bursts until the set ammo is used up. During this time the player can't do anything to prevent this from happening.

- Command syntax: `/muppet_streamer_leaky_flamethrower [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds the flamethrower and effects are delayed for before starting. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - ammoCount: NUMBER - Mandatory: the quantity of ammo to be put in the flamethrower and force fired, if 0 then the command is ignored.
    - target: STRING - Mandatory: the player name to target.
- Example command 1: `/muppet_streamer_leaky_flamethrower {"delay":5, "ammoCount":5, "target":"muppet9010"}`
- While activated the player will be kicked out of any vehicle they are in and prevented from entering one.
- While activated the player will loose control over their weapons targetign and firing behaviour.
- While activated the player can not change active gun via the switch to next weapon key.
- The player isn't prevented from removing the gun/ammo from their equipment slots as this isn't simple to do. However, this is such an active countering of the mods behaviour.


Give Weapon & Ammo
-----------------

Gives the target player a named weapon and/or named ammo.

- Command syntax: `/muppet_streamer_give_player_weapon_ammo [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds before the items are given. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - weaponType: STRING - Optional: the name of a weapon to ensure the player has 1 of. Can be either in their weapon inventory or in their character inventory. If not provided no weapon is given or selected.
    - forceWeaponToSlot: BOOLEAN - Optional: if true the weaponType will be placed/moved to the players weapon inventory. If theres no room a current weapon will be placed in the character inventory to make room. If not provided then the weapon will be placed in a free slot, otherwise the character inventory.
    - selectWeapon: BOOLEAN - Optional: if true the player will have this weaponType selected as active if its equiped in the weapon inventory. If not provided or the weaponType isn't in the weapon inventory then no weapon change is done.
    - ammoType: STRING - Optional: the name of the ammo type to be given to the player.
    - ammoCount: NUMBER - Optional: the quantity of the named ammo to be given. If 0 or not present then no ammo is given.
- Example command 1: `/muppet_streamer_give_player_weapon_ammo {"delay":5, "target":"muppet9010", "weaponType":"combat-shotgun", "forceWeaponToSlot":true, "ammoType":"piercing-shotgun-shell", "ammoCount":30}`
- If there isn't room in the character inventory for items they will eb dropped on the ground at the players feeet.