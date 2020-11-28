# factorio-muppet-streamer

Adds actions that a streamer can let chat activate to make their games more dynamic and interactive. These features are more complicated than can be achived via simple RCON commands.


Features
-----------

- Mod options to disable freeplay's introduction message, rocket win condition and set the starting map reveal area.
- Can add a team member limit GUI & research for use in Multiplayer by streamers. Supports commands.
- Can schedule the delivery of some explosives to a player at speed via command.
- A leaky flamethrower that shoots for short bursts intermittently via command.
- Give a player a weapon and ammo, plus options to force it as active weapon via command.
- Spawn entities around the player with various placement options via command.
- Make the player an aggressive driver via command.
- Call other players to help by teleporting them in via command.
- Teleport the player to a range of possible target types via command.

At present a time duration event will interrupt a different type of time duration event, i.e. aggressive driver will cut short a leaky flame thrower. Multiple uses of the same time duration events will be ignored.


Team Member Limit
------------

A way to soft limit players on the map and have research to increase it.

- Includes a simple one line GUI in the top left that says the current number of team members (players - 1) and the current max team members.
- Option to have research to increase the number of team members. Cost is configurable and the research levels increase in science pack complexity. Infinite options that double in cost each time.
- Set the "Team member technology pack count" setting to 0 to hide the tech, but keep the feature active for use via mod or command.
- Set the "Team member technology pack count" setting to -1 to disable the feature entirely and remove it from the screen/shortcut bar.
- Modding interface and command to increase the max team member count by a set amount. For use with other mods/streaming integrations when the research option isn't being used.
- Command:
    - syntax: `/muppet_streamer_change_team_member_max CHANGENUMBER`
    - example to increase by 2: `/muppet_streamer_change_team_member_max 2`


Schedule Explosive Delivery to player
-----------------

Can deliver a highly customisable explosive delivery to the player.

- Command syntax: `/muppet_streamer_schedule_explosive_delivery [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds the arrival of the explosives will be delayed for. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - explosiveCount: NUMBER - Mandatory: the quantity of explosives to be delivered, if 0 then the command is ignored.
    - explosiveType: STRING - Mandatory: the type of explosive, can be any one of: "grenade", "clusterGrenade", "slowdownCapsule", "poisonCapsule", "artilleryShell", "explosiveRocket", "atomicRocket", "smallSpit", "mediumSpit", "largeSpit"
    - target: STRING - Mandatory: a player name to target.
    - targetPosition: STRING - Optional: a position as a table to target instead of the players position. Will come on to the target players map (surface).
    - accuracyRadiusMin: NUMBER - Optional: the minimum distance from the target that can be randomly selected within. If not specified defaults to 0.
    - accuracyRadiusMax: NUMBER - Optional: the maximum distance from the target that can be randomly selected within. If not specified defaults to 0.
- Example command atomic rocket: `/muppet_streamer_schedule_explosive_delivery {"delay":1, "explosiveCount":1, "explosiveType":"atomicRocket", "target":"muppet9010", "accuracyRadiusMax":50}`
- Example command grenades: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":7, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":10, "accuracyRadiusMax":20}`

Notes:

- Explosives will fly in from offscreen to random location around the target player. They may take a few seconds to complete their delivery.
- Explosives flying in will use their native throwing/shooting/spitting approach and so arrival trajectories and times may vary.
- Weapons are on the "enemy" team and so don't get affected by your research.
- targetPosition expects a table of the x, y coordinates. This can be in any of the following valid JSON formats (array or list): `{"x": 10, "y": 5}` or `[10, 5]`.

Leaky Flamethrower
------------------

Gives the targeted player a flamethrower that shoots in random directions for short bursts until the set ammo is used up. This is a Time Duration event.

- Command syntax: `/muppet_streamer_leaky_flamethrower [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds the flamethrower and effects are delayed for before starting. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - ammoCount: NUMBER - Mandatory: the quantity of ammo to be put in the flamethrower and force fired, if 0 then the command is ignored.
    - target: STRING - Mandatory: the player name to target.
- Example command: `/muppet_streamer_leaky_flamethrower {"delay":1, "ammoCount":5, "target":"muppet9010"}`

Notes:

- This feature uses a custom permission group when active.
- While activated the player will be kicked out of any vehicle they are in and prevented from entering one.
- While activated the player will loose control over their weapons targeting and firing behaviour.
- While activated the player can not change active gun via the switch to next weapon key.
- The player isn't prevented from removing the gun/ammo from their equipment slots as this isn't simple to do. However, this is such an active countering of the mods behaviour.
- The flamethrower is yours and so any of your damage upgrades will affect it.


Give Weapon & Ammo
-----------------

Ensures the target player has a specific weapon and can give ammo and force their selection of the weapon.

- Command syntax: `/muppet_streamer_give_player_weapon_ammo [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds before the items are given. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - weaponType: STRING - Optional: the name of a weapon to ensure the player has 1 of. Can be either in their weapon inventory or in their character inventory. If not provided no weapon is given or selected.
    - forceWeaponToSlot: BOOLEAN - Optional: if true the weaponType will be placed/moved to the players weapon inventory. If there's no room a current weapon will be placed in the character inventory to make room. If not provided then the weapon will be placed in a free slot, otherwise the character inventory.
    - selectWeapon: BOOLEAN - Optional: if true the player will have this weaponType selected as active if its equipped in the weapon inventory. If not provided or the weaponType isn't in the weapon inventory then no weapon change is done.
    - ammoType: STRING - Optional: the name of the ammo type to be given to the player.
    - ammoCount: NUMBER - Optional: the quantity of the named ammo to be given. If 0 or not present then no ammo is given.
- Example command: `/muppet_streamer_give_player_weapon_ammo {"delay":1, "target":"muppet9010", "weaponType":"combat-shotgun", "forceWeaponToSlot":true, "ammoType":"piercing-shotgun-shell", "ammoCount":30}`

Notes:

- If there isn't room in the character inventory for items they will be dropped on the ground at the players feet.


Spawn Around Player
------------

Spawns entities in the game around the named player on their side. Includes both helpful and damaging entities and creation process options.

- Command syntax: `/muppet_streamer_spawn_around_player [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds before the spawning occurs. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to center upon.
    - force: STRING - Optional: the force of the spawned entities. Value can be either the name of a force (i.e. `player` or `enemy`), or leave blank for the force of the targeted player. Certain entity types are hardcoded like trees, rocks and fire to be neutral.
	- entityName: STRING - Mandatory: the type of entity to be placed: tree, rock, laserTurret, gunTurretRegularAmmo, gunTurretPiercingAmmo, gunTurretUraniumAmmo, wall, fire, defenderBot, distractorBot, destroyerBot.
	- radiusMax: NUMBER - Mandatory: the max radius of the placement area from the target player.
	- radiusMin: NUMBER - Optional: the min radius of the placement area from the target player. If set to the same value as radiusMax then a perimeter is effectively made. If not provided then 0 is used.
    - existingEntities: STRING - Mandatory: how the newly spawned entity should handle existing entities on the map. Either `overlap`, or `avoid`.
	- quantity: NUMBER - Optional: specifies the quantity of entities to place. Will not be more than this, but may be less if it struggles to find random placement spots. Placed on a truly random placement within the radius which is then searched around for a near by valid spot. Intended for small quantities.
	- density: FLOAT - Optional: specifies the approximate density of the placed entities. 1 is fully dense, close to 0 is very sparse. Placed on a 1 tile grid with random jitter for non tile aligned entities. Due to some placement searching it won't be a perfect circle and not necessarily a regular grid. Intended for larger quantities.
    - ammoCount: NUMBER - Optional: specifies the amount of ammo in applicable entityTypes. For GunTurrets its the ammo count and ammo over the turrets max storage is ignored. For fire it's the stacked fire count meaning longer burn time and more damage, game max is 250, but numbers above 50 seem to have no greater effect.
    - followPlayer: BOOLEAN - Optional: if true the entities that can move will follow the player. If false they will be unmanaged. Some entities like defender combat bots have a maximum follow number, the remainder will not follow the player.
- Example command tree ring: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"tree", "radiusMax":10, "radiusMin":5, "existingEntities":"avoid", "density": 0.7}`
- Example command gun turrets: `/muppet_streamer_spawn_around_player {"delay":1, "target":"muppet9010", "entityName":"gunTurretPiercingAmmo", "radiusMax":7, "radiusMin":7, "existingEntities":"avoid", "quantity":10, "ammoCount":10}`
- Example command fires: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"fire", "radiusMax":20, "radiusMin":0, "existingEntities":"overlap", "density": 0.05, "ammoCount": 100}`
- Example command combat robots: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"defenderBot", "radiusMax":10, "radiusMin":10, "existingEntities":"overlap", "quantity": 20, "followPlayer": true}`

Notes:

- For entityType of tree placed on a vanilla game tile a biome specific tree will be selected, otherwise the tree will be random.


Aggressive Driver
---------------

The player is locked inside their vehicle and forced to drive forwards for the set duration. This is a Time Duration event.

- Command syntax: `/muppet_streamer_aggressive_driver [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds before the effect starts. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - duration: NUMBER - Mandatory: how many seconds the effect lasts on the player.
    - control: STRING - Optional: if the player has control over steering, either: `full` or `random`. Full allows control over left/right steering, random switches between left, right, straight for short periods. If not specified then full is applied.
    - teleportDistance: Number - Optional: the max distance of tiles that the player will be teleported in to the nearest suitable drivable vehicle. If not supplied is treated as 0 distance and so player isn't teleported. Don't set a massive distance as this may cause UPS lag, i.e. 3000+.
- Example command : `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":"10", "control": "full", "teleportDistance": 100}`

Notes:

- This feature uses a custom permission group when active.
- If the vehicle comes to a stop during the time it will automatically start going the opposite direction.
- This feature affects all types of cars, tanks and locomotive vehicles, but not the Spider Vehicle.


Call For Help
------------

Teleports other players on the server to near your position.

- Command syntax: `/muppet_streamer_call_for_help [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds before the effect starts. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - arrivalRadius - NUMBER - Mandatory: the max distance players will be teleported to from the target player.
    - callRadius - NUMBER - Mandatory: the max distance to call players from.
    - callSelection - STRING - Mandatory: the logic to select which players in the callRadius are teleported, either: 'random', 'nearest'.
    - number - NUMBER - Mandatory Special: how many players to call. Either `number` or `activePercentage` must be supplied.
    - activePercentage - NUMBER - Mandatory Special: the percentage of currently online players to call, i.e. 90. Either `number` or `activePercentage` must be supplied.
- Example command : `/muppet_streamer_call_for_help {"target":"muppet9010", "arrivalRadius":20, "callRadius": 1000, "callSelection": "random", "number": 3, "activePercentage": 50}`

Notes:

- The position that each player is teleported to will be able to path to your position. So no teleporting them on to islands or middle of cliff circles, etc.
- If both `number` and `activePercentage` is supplied the greatest value at the time will be used.
- A player teleported comes with their vehicle if they have one.


Teleport
-------------

Teleports the player to the nearest type of thing.

- Command syntax: `/muppet_streamer_teleport [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: NUMBER - Optional: how many seconds before the effect starts. 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - destinationType: STRING - Mandatory: the type of teleport to do, either `random`, `biterNest`, `enemyUnit`, `spawn` or a specific position as a table. For biterNest and enemyUnit it will be the nearest one found within range.
    - arrivalRadius - NUMBER - Optional: the max distance the player will be teleported to from the targeted destinationType. Defaults to 10.
    - minDistance: NUMBER - Optional: the minimum distance to teleport. If not provided then value of 0 is used. Is ignored for destinationType of `spawn`, specific position or `enemyUnit`.
    - maxDistance: NUMBER - Mandatory: the maximum distance to teleport. Is ignored for destinationType of `spawn` or specific position.
    - reachableOnly: BOOLEAN - Optional: if the place you are teleported must be walkable back to where you were. Defaults to false. Only applicable for destinationType of `random` and `biterNest`.
    - backupTeleportSettings: Teleport details in JSON string - Optional: a backup complete teleport action that will be done if the main destinationType is unsuccessful. Is a complete copy of the main muppet_streamer_teleport settings as a JSON object.
- Example command biter nest: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance": 1000, "reachableOnly": true}`
- Example command random location: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"random", "minDistance": 100, "maxDistance": 500, "reachableOnly": true}`
- Example command specific position: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":[1000, 500], "maxDistance": 0}`
- Example command backup teleport: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance": 100, "reachableOnly": true, "backupTeleportSettings": {"target":"muppet9010", "destinationType":"random", "minDistance": 100, "maxDistance": 500, "reachableOnly": true} }`

Notes:

- destinationType of position expects a table of the x, y coordinates. This can be in any of the following valid JSON formats (array or list): `{"x": 10, "y": 5}` or `[10, 5]`.
- destinationType of enemyUnit does a search for the nearest enemy unit within the maxDistance. If this is a very large area (3000+) this may be slow.
- All teleports will try 10 random locations around their targeted position within the arrivalRadius setting to try and find a valid spot. If there is no success they will repeat the whole activity up to 5 times before giving up. The destinationType target will be re-calculated for each attempt.
- The reachableOnly will give up on a target if it gets a failed pathfinder request and find a new target to repeat the process with up to the 5 times. For biterNests this means it may not end up being the closest biter nest you are teleported to in all cases. This may also lead to no valid target being found in some cases, so enable with care and expectations.
- The backupTeleportSettings is intended for use if you have a more risky main destinationType. For example your main destinationType may be biter nest within 100 tiles, with a backup being a random location within 1000 tiles. All settings in the backupTeleportSettings must be provided just like the main command details. It will be queued to action at the end of the previous teleport attempt failing.
- A player teleported comes with their vehicle if they have one.