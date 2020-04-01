# factorio-streamer-support-team
Mod for streamers to customise and add flavour to their play throughs.


Features
-----------

- Mod options to disable freeplay's rocket counter GUI, introduction message, rocket win conditon and set starting map reveal area.
- Can add a team member limit GUI & research for use in Multiplayer by streamers. Supports commands.
- Can schedule the delivery of some explosives to a player via command.
- A leaky flamethrower that shoots for short bursts intermittently via command.
- Give a player a weapon and ammo, plus options to force it as active weapon via command.
- Spawn "friendly" entities around the player with various placement options via command.


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

Ensures the target player has a specific weapon and can give ammo and force their selection of the weapon.

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
- If there isn't room in the character inventory for items they will eb dropped on the ground at the players feet.


Spawn Around Player
------------

Spawns entities in the game around the named player on their side. Incldues both helpful and damaging entities and creation process options.

- Command syntax: `/muppet_streamer_spawn_around_player [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds before the spawning occurs. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to center upon.
	- entityName: STRING - Mandatory: the type of entity to be placed: tree, rock, laserTurret, gunTurretRegularAmmo, gunTurretPiercingAmmo, gunTurretUraniumAmmo, wall, fire, defenderCapsule, distractorCapsule, destroyedCapsule.
	- radiusMax: NUMBER - Mandatory: the max radius of the placement area from the target player.
	- radiusMin: NUMBER - Optional: the min radius of the placement area from the target player. If set to the same value as radiusMax then a peremiter is effectively made. If not provided then 0 is used.
    - existingEntities: STRING - Mandatory: how the newly spawned entity should handle existing entities on the map. Either `overlap`, or `avoid`.
	- quantity: NUMBER - Optional: specifies the quantity of entities to place. Will not be more than this, but may be less if it struggles to find random placement spots. Placed on a truely random placement within the radius which is then searched around for a near by valid spot. Intended for small quantities.
	- density: FLOAT - Optional: specifies the approximate density of the placed entities. 1 is fully dense, close to 0 is very sparse. Placed on a 1 tile grid with random jitter for non tile aligned entities. Due to some placement searching it won't be a perfect circle and not necessarily a regular grid. Intended for larger quantities.
    - ammoCount: NUMBER - Optional: specifies the amount of ammo in applicable entityTypes. For GunTurrets its the ammo count and ammo over the turrets max storage is ignored. For fire it's the stacked fire count meaning longer burn time and more damage, game max is 255.
- Example command 1: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"tree", "radiusMax":10, "radiusMin":5, "existingEntities":"avoid", "density": 0.7}`
- Example command 2: `/muppet_streamer_spawn_around_player {"delay":5, "target":"muppet9010", "entityName":"gunTurretPiercingAmmo", "radiusMax":7, "radiusMin":7, "existingEntities":"avoid", "quantity":10, "ammoCount":10}`
- Example command 3: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"fire", "radiusMax":20, "radiusMin":0, "existingEntities":"overlap", "density": 0.05, "ammoCount": 100}`
- For entityType of tree placed on a vanilla game tile a biome specific tree will be selected, otherwise the tree will be random.