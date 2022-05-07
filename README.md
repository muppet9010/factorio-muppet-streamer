# factorio-muppet-streamer

Adds actions that a streamer can let chat activate to make their games more dynamic and interactive. These features are more complicated than can be achieved via simple RCON commands and are highly customisable within the command.



Features
-----------

- Can schedule the delivery of some explosives to a player at speed via command.
- A leaky flamethrower that shoots for short bursts intermittently via command.
- Give a player a weapon and ammo, plus options to force it as an active weapon via command.
- Spawn entities around the player with various placement options via command.
- Make the player an aggressive driver via command.
- Call other players to help by teleporting them in via command.
- Teleport the player to a range of possible target types via command.
- Sets the ground on fire behind a player via command.
- Drop a player's inventory on the ground over time via command.
- Mix up players' inventories between them via command.
- Can add a team member limit GUI & research for use in Multiplayer by streamers. Supports commands.
- Mod options to disable freeplay's introduction message, rocket win condition and set the starting map reveal area.



General Usage Notes
---------------

At present a time duration event will interrupt a different type of time duration event, i.e. aggressive driver will cut short a leaky flame thrower. Multiple uses of the same time duration events will be ignored.

Argument Data Types:

- INTEGER = expects a whole number and not a fraction. So `1.5` is a bad value.
- FLOAT = can take a fraction, i.e `0.25` or `54.28437`. In some usage cases the final result will be rounded to a degree, i.e. 0.4 seconds will have to be rounded to a single tick accuracy.
- STRING = a text string wrapped in double quotes, i.e. `"some text"`
- STRING_LIST = a comma separated list of things in a single string, i.e. `"Player1,player2, Player3  "`. Any leading or trailing spaces will be removed from each entry in the list. The casing (capitalisation) of things must match the case within factorio exactly, i.e. player names must have the same case as within Factorio. This can be a single thing in a string, i.e. `"Player1"`.
- OBJECT = some features accept an object as an argument. These are detailed in the notes for those functions. i.e. a position as an object with x and y coordinates: `{"x": 5, "y":23}`

When updating the mod make sure there aren't any effects active or queued for action (in delay). As the mod is not kept backwards compatible when new features are added or changed. The chance of an effect being active when the mod is being updated seems very low given their usage, but you've been warned.



Schedule Explosive Delivery to player
-----------------

Can deliver a highly customisable explosive delivery to the player. The explosives are created off the target player's screen and so take a few seconds to fly to their destinations.

- Command syntax: `/muppet_streamer_schedule_explosive_delivery [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds the creation of the explosives will be delayed for. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay. This doesn't include the in-flight time.
    - explosiveCount: INTEGER - Mandatory: the quantity of explosives to be delivered, if 0 then the command is ignored.
    - explosiveType: STRING - Mandatory: the type of explosive, can be any one of: "grenade", "clusterGrenade", "slowdownCapsule", "poisonCapsule", "artilleryShell", "explosiveRocket", "atomicRocket", "smallSpit", "mediumSpit", "largeSpit"
    - target: STRING - Mandatory: a player name to target.
    - targetPosition: OBJECT - Optional: a position to target instead of the player's position. Will come on to the target players map (surface). See notes for syntax examples.
    - accuracyRadiusMin: FLOAT - Optional: the minimum distance from the target that can be randomly selected within. If not specified defaults to 0.
    - accuracyRadiusMax: FLOAT - Optional: the maximum distance from the target that can be randomly selected within. If not specified defaults to 0.
    - salvoSize: INTEGER - Optional: breaks the incoming explosiveCount into salvos of this size. Useful if you are using very large numbers of nukes to prevent UPS issues.
    - salvoDelay: INTEGER - Optional: use with salvoSize. Sets the delay between salvo deliveries in game ticks (60 ticks = 1 second). Each salvo will target the same player position and not re-target the player's new position.
- Example command atomic rocket: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":1, "explosiveType":"atomicRocket", "target":"muppet9010", "accuracyRadiusMax":50}`
- Example command grenades: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":7, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":10, "accuracyRadiusMax":20}`
- Example command large count of atomic rockets with salvo: `/muppet_streamer_schedule_explosive_delivery {"delay":5, "explosiveCount":150, "explosiveType":"atomicRocket", "target":"muppet9010", "accuracyRadiusMax":50, "salvoSize":10, "salvoDelay":180}`

Notes:

- Explosives will fly in from offscreen to random locations around the target player. They may take a few seconds to complete their delivery.
- Explosives flying in will use their native throwing/shooting/spitting approach and so arrival trajectories and times may vary.
- Weapons are on the "enemy" team and so don't get affected by your research.
- targetPosition expects a table of the x, y coordinates. This can be in any of the following valid JSON formats (object or array): `{"x": 10, "y": 5}` or `[10, 5]`.



Leaky Flamethrower
------------------

Forces the targeted player to wield a flamethrower that shoots in random directions for short bursts until the set ammo is used up. This is a Time Duration event.

- Command syntax: `/muppet_streamer_leaky_flamethrower [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds the flamethrower and effects are delayed before starting. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - ammoCount: INTEGER - Mandatory: the quantity of ammo to be put in the flamethrower and force fired, if 0 then the command is ignored.
    - target: STRING - Mandatory: the player name to target.
- Example command: `/muppet_streamer_leaky_flamethrower {"ammoCount":5, "target":"muppet9010"}`

Notes:

- This feature uses a custom permission group when active. This could conflict with other mods/scenarios that also use permission groups.
- While activated the player will be kicked out of any vehicle they are in and prevented from entering one.
- While activated the player will lose control over their weapons targeting and firing behaviour.
- While activated the player can not change the active gun via the switch to next weapon key.
- The player isn't prevented from removing the gun/ammo from their equipment slots as this isn't simple to prevent. However, this is such an active countering of the mod's behaviour that if the streamer wishs to do this then thats their choice.
- The flamethrower is yours and so any of your damage upgrades will affect it.



Give Weapon & Ammo
-----------------

Ensures the target player has a specific weapon and can give ammo and force their selection of the weapon.

- Command syntax: `/muppet_streamer_give_player_weapon_ammo [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the items are given. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - weaponType: STRING - Optional: the name of a weapon to ensure the player has 1 of. Can be either in their weapon inventory or in their character inventory. If not provided no weapon is given or selected.
    - forceWeaponToSlot: BOOLEAN - Optional: if True the weaponType will be placed/moved to the players weapon inventory. If there's no room a current weapon will be placed in the character inventory to make room. If False then the weapon will be placed in a free slot, otherwise the character inventory. Defaults to False
    - selectWeapon: BOOLEAN - Optional: if True the player will have this weaponType selected as active if it's equipped in the weapon inventory. If not provided or the weaponType isn't in the weapon inventory then no weapon change is done.
    - ammoType: STRING - Optional: the name of the ammo type to be given to the player.
    - ammoCount: INTEGER - Optional: the quantity of the named ammo to be given. If 0 or not present then no ammo is given.
- Example command: `/muppet_streamer_give_player_weapon_ammo {"target":"muppet9010", "weaponType":"combat-shotgun", "forceWeaponToSlot":true, "ammoType":"piercing-shotgun-shell", "ammoCount":30}`

Notes:

- If there isn't room in the character inventory for items they will be dropped on the ground at the players feet.



Spawn Around Player
------------

Spawns entities in the game around the named player on their side. Includes both helpful and damaging entities and creation process options.

- Command syntax: `/muppet_streamer_spawn_around_player [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the spawning occurs. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to center upon.
    - force: STRING - Optional: the force of the spawned entities. Value can be either the name of a force (i.e. `player` or `enemy`), or left blank for the force of the targeted player. Certain entity types are hardcoded like trees, rocks and fire to be neutral.
	- entityName: STRING - Mandatory: the type of entity to be placed: tree, rock, laserTurret, gunTurretRegularAmmo, gunTurretPiercingAmmo, gunTurretUraniumAmmo, wall, fire, defenderBot, distractorBot, destroyerBot.
	- radiusMax: FLOAT - Mandatory: the max radius of the placement area from the target player.
	- radiusMin: FLOAT - Optional: the min radius of the placement area from the target player. If set to the same value as radiusMax then a perimeter is effectively made. If not provided then 0 is used.
    - existingEntities: STRING - Mandatory: how the newly spawned entity should handle existing entities on the map. Either `overlap`, or `avoid`.
	- quantity: INTEGER - Optional: specifies the quantity of entities to place. Will not be more than this, but may be less if it struggles to find random placement spots. Placed on a truly random placement within the radius which is then searched around for a nearby valid spot. Intended for small quantities.
	- density: FLOAT - Optional: specifies the approximate density of the placed entities. 1 is fully dense, close to 0 is very sparse. Placed on a 1 tile grid with random jitter for non tile aligned entities. Due to some placement searching it won't be a perfect circle and not necessarily a regular grid. Intended for larger quantities.
    - ammoCount: INTEGER - Optional: specifies the amount of ammo in applicable entityTypes. For GunTurrets it's the ammo count and ammo over the turrets max storage is ignored. For fire it's the stacked fire count meaning longer burn time and more damage, game max is 250, but numbers above 50 seem to have no greater effect.
    - followPlayer: BOOLEAN - Optional: if true the entities that can move will follow the player. If false they will be unmanaged. Some entities like defender combat bots have a maximum follow number, the remainder will not follow the player.
- Example command tree ring: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"tree", "radiusMax":10, "radiusMin":5, "existingEntities":"avoid", "density": 0.7}`
- Example command gun turrets: `/muppet_streamer_spawn_around_player {"delay":1, "target":"muppet9010", "entityName":"gunTurretPiercingAmmo", "radiusMax":7, "radiusMin":7, "existingEntities":"avoid", "quantity":10, "ammoCount":10}`
- Example command fires: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"fire", "radiusMax":20, "radiusMin":0, "existingEntities":"overlap", "density": 0.05, "ammoCount": 100}`
- Example command combat robots: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"defenderBot", "radiusMax":10, "radiusMin":10, "existingEntities":"overlap", "quantity": 20, "followPlayer": true}`

Notes:

- For entityType of tree, if placed on a vanilla game tile or with Alien Biomes mod a biome specific tree will be selected, otherwise the tree will be random on other modded tiles. Should support and handle fully defined custom tree types, otherwise they will be ignored.



Aggressive Driver
---------------

The player is locked inside their vehicle and forced to drive forwards for the set duration. This is a Time Duration event.

- Command syntax: `/muppet_streamer_aggressive_driver [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the effect starts. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - duration: FLOAT - Mandatory: how many seconds the effect lasts on the player.
    - control: STRING - Optional: if the player has control over steering, either: `full` or `random`. Full allows control over left/right steering, random switches between left, right, straight for short periods. If not specified then full is applied.
    - teleportDistance: Number - Optional: the max distance of tiles that the player will be teleported into the nearest suitable drivable vehicle. If not supplied it is treated as 0 distance and so the player isn't teleported. Don't set a massive distance as this may cause UPS lag, i.e. 3000+.
- Example command : `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":"10", "control": "full", "teleportDistance": 100}`

Notes:

- This feature uses a custom permission group when active. This could conflict with other mods/scenarios that also use permission groups.
- If the vehicle comes to a stop during the time (due to hitting something) it will automatically start going the opposite direction.
- This feature affects all types of cars, tanks and train vehicles, but not the Spider Vehicle.



Call For Help
------------

Teleports other players on the server to near your position.

- Command syntax: `/muppet_streamer_call_for_help [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the effect starts. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - arrivalRadius - FLOAT - Mandatory: players teleported to the target player will be placed within this max distance.
    - blacklistedPlayerNames - STRING_LIST - Optional: comma separated list of player names who will never be teleported to the target player. These are removed from the available players lists and counts.
    - whitelistedPlayerNames - STRING_LIST - Optional: comma separated list of player names who will be the only ones who can be teleported to the target player. If provided these whitelisted players who are online constitute the entire available player list that any other filtering options are applied to. If not provided then all online players not blacklisted are valid players to select from based on filtering criteria.
    - callRadius - FLOAT - Optional: the max distance a player can be from the target and still be teleported to them. If not provided then a player at any distance can be teleported to the target player. If the `sameSurfaceOnly` argument is set to `false` then the `callRadius` argument is ignored entirely.
    - sameSurfaceOnly - BOOLEAN - Optional: if the players being teleported to the target have to be on the same surface as the target player or not. If `false` then the `callRadius` argument is ignored as it can't logically be applied. Defaults to `true`.
    - sameTeamOnly - BOOLEAN - Optional: if the players being teleported to the target have to be on the same team (force) as the target player or not. Defaults to `true`.
    - callSelection - STRING - Mandatory: the logic to select which available players in the callRadius are teleported, either: `random`, `nearest`.
    - number - INTEGER - Mandatory Special: how many players to call. Either `number` or `activePercentage` must be supplied.
    - activePercentage - FLOAT - Mandatory Special: the percentage of currently available players to teleport to help, i.e. 50 for 50%. Will respect blacklistedPlayerNames and whitelistedPlayerName argument values when counting the number of available players. Either `number` or `activePercentage` must be supplied.
- Example command : `/muppet_streamer_call_for_help {"target":"muppet9010", "arrivalRadius":10, "callSelection": "random", "number": 3, "activePercentage": 50}`

Notes:

- The position that each player is teleported to will be able to path to your position. So no teleporting them on to islands or middle of cliff circles, etc.
- If both `number` and `activePercentage` is supplied the greatest value at the time will be used.
- CallSelection of `nearest` will treat players on other surfaces as being maximum distance away, so they will be the lowest priority.
- A player teleported comes with their vehicle if they have one (excludes trains).



Teleport
-------------

Teleports the player to the nearest type of thing.

- Command syntax: `/muppet_streamer_teleport [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the effect starts. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - destinationType: STRING/OBJECT - Mandatory: the type of teleport to do, either the text string of `random`, `biterNest`, `enemyUnit`, `spawn` or a specific position as an object. For biterNest and enemyUnit it will be the nearest one found within range.
    - arrivalRadius - FLOAT - Optional: the max distance the player will be teleported to from the targeted destinationType. Defaults to 10.
    - minDistance: FLOAT - Optional: the minimum distance to teleport. If not provided then the value of 0 is used. Is ignored for destinationType of `spawn`, specific position or `enemyUnit`.
    - maxDistance: FLOAT - Mandatory: the maximum distance to teleport. Is ignored for destinationType of `spawn` or specific position.
    - reachableOnly: BOOLEAN - Optional: if the place you are teleported must be walkable back to where you were. Defaults to false. Only applicable for destinationType of `random` and `biterNest`.
    - backupTeleportSettings: Teleport details in JSON string - Optional: a backup complete teleport action that will be done if the main destinationType is unsuccessful. Is a complete copy of the main muppet_streamer_teleport settings as a JSON object.
- Example command biter nest: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance": 1000, "reachableOnly": true}`
- Example command random location: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"random", "minDistance": 100, "maxDistance": 500, "reachableOnly": true}`
- Example command specific position: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":[1000, 500], "maxDistance": 0}`
- Example command backup teleport: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance": 100, "reachableOnly": true, "backupTeleportSettings": {"target":"muppet9010", "destinationType":"random", "minDistance": 100, "maxDistance": 500, "reachableOnly": true} }`

Notes:

- destinationType of position expects an object of the x, y coordinates. This can be in any of the following valid JSON formats (object or array): `{"x": 10, "y": 5}` or `[10, 5]`.
- destinationType of enemyUnit and biterNests does a search for the nearest opposing force (not friend or cease-fire) unit/nest within the maxDistance. If this is a very large area (3000+) this may cause a small UPS spike.
- All teleports will try 10 random locations around their targeted position within the arrivalRadius setting to try and find a valid spot. If there is no success they will try with a different target 5 times before giving up for the `random` and `biterNest` destinationType.
- The reachableOnly option will give up on a valid random location for a target if it gets a failed pathfinder request and try another target. For biterNests this means it may not end up being the closest biter nest you are teleported to in all cases, based on walkable check. This may also lead to no valid target being found in some cases, so enable with care and expectations. The backupTeleportSettings can provide assistance here.
- The backupTeleportSettings is intended for use if you have a more risky main destinationType. For example your main destinationType may be a biter nest within 100 tiles, with a backup being a random location within 1000 tiles. All settings in the backupTeleportSettings must be provided just like the main command details. It will be queued to action at the end of the previous teleport attempt failing.
- A player teleported comes with their vehicle if they have one (excludes trains).



Pants On Fire
------------

Sets the ground on fire behind a player forcing them to run.

- Command syntax: `/muppet_streamer_pants_on_fire [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the effect starts. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - duration: FLOAT - Mandatory: how many seconds the effect lasts on the player.
    - fireGap: INTEGER - Optional: how many ticks between each fire entity. Defaults to 6, which gives a constant fire line.
    - fireHeadStart: INTEGER - Optional: how many fire entities does the player have a head start on. Defaults to 3, which forces continuous running.
    - flameCount: INTEGER - Optional: how many flames each fire entity will have. More does greater damage and burns for longer (internal Factorio logic). Defaults to 20, which is the minimum to set a tree on fire.
- Example command continuous fire at players heels: `/muppet_streamer_pants_on_fire {"target":"muppet9010", "duration": 30}`
- Example command sporadic fire long way behind player: `/muppet_streamer_pants_on_fire {"target":"muppet9010", "duration": 30, "fireGap": 30, "fireHeadStart": 6}`

Notes:

- If a player is in a vehicle while the effect is active they take increaseing damage until they get out, in addition to the ground being set on fire. If they get back in another vehicle then the damage resumes from its high point reached so far. This is to stop the player jumping in/out of armoured vehicles (tank, train, etc) and being effectively immune as those vehicles take so little fire damage.


Player Drop Inventory
---------------------

Schedules the targeted player to drop their inventory on the ground over time.

- Command syntax: `/muppet_streamer_player_drop_inventory [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the effects start. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - target: STRING - Mandatory: the player name to target.
    - quantityType: STRING - Mandatory: the way quantity value is interpreted to calculate the number of items to drop per drop event, either `constant`, `startingPercentage` or `realtimePercentage`. Constant uses quantityValue as a static number of items. StartingPercentage means a percentage of the item count at the start of the effect is dropped from the player every drop event. RealtimePercentage means that every time a drop event occurs the player's current inventory item count is used to calculate how many items to drop this event.
    - quantityValue: INTEGER - Mandatory: the number of items to drop. When quantityType is `startingPercentage`, or `realtimePercentage` this number is used as the percentage (0-100).
    - dropOnBelts: BOOLEAN - Optional: if the dropped items should be placed on belts or not. Defaults to False.
    - gap: FLOAT - Mandatory: how many seconds between each drop event.
    - occurrences: INTEGER - Mandatory: how many times the drop events are done.
    - dropEquipment: BOOLEAN - Optional: if the player's armour and weapons are dropped or not. Defaults to True.
- Example command for 50% of starting inventory items over 5 drops: `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"startingPercentage", "quantityValue":10, "gap":1, "occurrences":5}`
- Example command for 10 drops of 5 items, including on belts: `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"constant", "quantityValue":5, "gap":2, "occurrences":10, "dropOnBelts":true}`

Notes:

- Not intended to empty a player's inventory all in 1 go. A direct Lua script could be used for that.
- For percentage based quantity values it will drop a minimum of 1 item per cycle. So that very low values/inventory sizes don't drop anything.
- If the player doesn't have any items to drop for any given drop event then that occurence is marked as completed and the effect continues until all occurrences have occurred at their set gaps. The event does not not stop unless the player dies or all occurrences have been completed.



Player Inventory Shuffle
------------------------

Takes all the inventory items from the target players, shuffles them and then distributes the items back between those players. Will keep the different types of items in roughly the same number of players inventories as they started, and will spread the quantities in a random distribution between them (not evenly).

- Command syntax: `/muppet_streamer_player_inventory_shuffle [DETAILS JSON STRING]`
- Details in JSON string supports the arguments:
    - delay: FLOAT - Optional: how many seconds before the effects start. A 0 second delay makes it happen instantly. If not specified it defaults to 0 second delay.
    - targets: STRING_LIST/STRING - Mandatory: a comma separated list of the player names to target (assuming they are online at the time), or `[ALL]` to target all online players on the server. Must be 2 or more players online otherwise the command will do nothing.
    - includeEquipment: BOOLEAN - Optional: if the player's armour and weapons are included for shuffling or not. Defaults to True.
    - destinationPlayersMinimumVariance: INTEGER - Optional: The minimum number of destination player's inventories that the items should end up in above/below the number of source player inventories. Defaults to 1. See notes for logic on item distribution.
    - destinationPlayersVarianceFactor: FLOAT - Optional: The factor applied to each item type's number of source players when calculating the range of the random destination player count. Defaults to 0.25. See notes for logic on item distribution.
    - recipientItemMinToMaxRatio: INTEGER - Optional: The approximate min/max range of the number of items a destination player will receive compared to others. Defaults to 4. See notes for logic on item distribution.
- Example command for 3 players: `/muppet_streamer_player_inventory_shuffle {"targets":"muppet9010,Test_1,Test_2"}`
- Example command for all active players: `/muppet_streamer_player_inventory_shuffle {"targets":"[ALL]"}`

Notes:

- The distribution logic is a bit convoluted, but works as per:
    - All targets online have all their inventories taken. Each item type has the number of source players recorded.
    - A random number of new players to receive each item type is worked out. This is based on the number of source players for that item type, with a +/- random value based on the greatest between the destinationPlayersMinimumVariance setting and the destinationPlayersVarianceFactor setting. This allows a minimum variation to be enforced even when very small player targets are online. The final value of new players for the items to be split across will never be less than 1 or greater than all of the online target players.
    - The number of each item each selected player will receive is a random proportion of the total. This is controlled by the recipientItemMinToMaxRatio setting. This setting defines the minimum to maximum ratio between 2 players, i.e. setting of 4 means a player receiving the maximum number can receive up to 4 times as many as a player receiving the minimum. This setting's implementation isn't quite exact and should be viewed as a rough guide.
    - Any items that can't be fitted into the intended destination player will be given to another online targeted player if possible. This will affect the item quantity balance between players and the appearance of how many destination players were selected. If it isn't possible to give the items to any online targeted player then they will be dropped on the floor at the targeted players’ feet. This situation can occur as items are taken from player's extra inventories like trash, but returned to the player using Factorio default item assignment logic. Player's various inventories can also have filtering on their slots, thus further reducing the room for random items to fit in.
- Players are given items using Factorios default item assignment logic. This will mean that equipment will be loaded based on the random order it is received. Any auto trashing will happen after all the items have tried to be distributed, just like if you try to mine an auto trashed item, but your inventory is already full.



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
