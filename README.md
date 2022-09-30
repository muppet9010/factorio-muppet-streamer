# factorio-muppet-streamer

Features that a streamer can let chat activate to make their games more dynamic and interactive. These features are more complicated than can be achieved via simple Lua scripting and are highly customisable within the command/remote interface calls.



Features
-----------

#### Streamer Effects

- Schedule the delivery of some hostile explosives to the player at speed. = `Schedule Explosive Delivery`
- A malfunctioning weapon (leaky flamethrower) that shoots wildly for short bursts intermittently. = `Malfunctioning Weapon`
- Give the player a weapon and ammo, plus options to force it as an active weapon. = `Give Weapon & Ammo`
- Spawn entities around the player with various placement options. = `Spawn Around Player`
- Make the player an aggressive driver who has no or limited control of their vehicle. = `Aggressive Driver`
- Call other players to help by teleporting them in. = `Call For Help`
- Teleport the player to a range of possible target types. = `Teleport`
- Sets the ground on fire behind a player. = `Pants On Fire`
- Drop a player's inventory on the ground over time. = `Player Drop Inventory`
- Mix up multiple players' inventories between them. = `Player Inventory Shuffle`

All are done via highly configurable RCON commands as detailed below for each feature. Each can also be triggered via a remote interface call from a Lua script, details on this are at the end of this document.

Examples of some of the single player features can be seen here in a YouTube video:
[![single player features](https://i.ytimg.com/vi/_X8gfOKxSJI/hqdefault.jpg)](https://youtu.be/_X8gfOKxSJI)

#### Multiplayer Features

- Can add a team member limit GUI & research for use in Multiplayer by streamers. Supports commands. = `Team Member Limit`

#### Map Helper Features (mod options)

- Start the game with ghosts appearing when buildings die, rather than having to wait for a technology to unlock it (construction robotics). = `Dead Building Ghosts`
- Disable introduction message in freeplay.
- Disable rocket win condition in freeplay.
- Set a custom area of the map revealed at game start.

#### General Usage Notes

See the end of the file for descriptions of the data types and other wordings used in this explanation document. Also includes details on the Remote Interface of the mod, and mod upgrading advice.

#### Updating the mod

When updating the mod make sure there aren't any effects active or queued for action (in delay). As the mod is not kept backwards compatible when new features are added or changed. The chance of an effect being active when the mod is being updated seems very low given their usage, but you've been warned.



---------------------------------------

Schedule Explosive Delivery
============

Can deliver a highly customisable explosive delivery to the player. The explosives are created off the target player's screen and so take a few seconds to fly to their destinations.

#### Command syntax

`/muppet_streamer_schedule_explosive_delivery [OPTIONS TABLE AS JSON STRING]`

#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds the effect will be delayed for before looking for the targets current position and creating the explosive. A `0` second `delay` makes it happen instantly. If not specified it defaults to happen instantly. This doesn't include the explosives in-flight time.
- explosiveCount: INTEGER - Mandatory: the quantity of explosives to be delivered.
- explosiveType: STRING - Mandatory: the type of explosive, can be any one of the vanilla Factorio built-in options: `grenade`, `clusterGrenade`, `slowdownCapsule`, `poisonCapsule`, `artilleryShell`, `explosiveRocket`, `atomicRocket`, `smallSpit`, `mediumSpit`, `largeSpit`, or `custom`. Is case sensitive. `custom` requires the additional options `customExplosiveType` and `customExplosiveSpeed` options to be set/considered.
- customExplosiveType: STRING - Mandatory Special: only required/supported if `explosiveType` is set to `custom`. Sets the name of the explosive to be used. Must be either a `projectile`, `artillery-projectile` or `stream` entity type.
- customExplosiveSpeed: DECIMAL - Mandatory Special: only required/supported if `explosiveType` is set to `custom`. Sets the speed of the custom explosive type in the air. Only applies to `projectile` and `artillery-projectile` entity types. Default is `0.3` if not specified. See effect Notes for the values of built-in options.
- target: STRING - Mandatory: a player name to target the position and surface of (case sensitive).
- targetPosition: POSITION_OBJECT - Optional: a specific position to target on the target player's surface. See Argument Data Types for syntax examples of a POSITION_OBJECT.
- targetOffset: POSITION_OBJECT - Optional: an offset position that's applied to the `target`/`targetPosition` value. This allows for explosives to be targeted at a static offset from the target player's current position for example. By default there is no offset set. See Argument Data Types for syntax examples of a POSITION_OBJECT. As this is an offset, a value of `0` for "x" and/or "y" is valid as specifying no offset on that axis.
- accuracyRadiusMin: DECIMAL - Optional: the minimum distance from the target that each explosive can be randomly targeted within. If not specified defaults to `0`.
- accuracyRadiusMax: DECIMAL - Optional: the maximum distance from the target that each explosive can be randomly targeted within. If not specified defaults to `0`.
- salvoSize: INTEGER - Optional: breaks the incoming `explosiveCount` into salvos of this size. Useful if you are using very large numbers of nukes to prevent UPS issues. Defaults to all explosives being in a single salvo.
- salvoDelay: INTEGER - Optional: use when `salvoSize` is set. Sets the delay between each salvo deliveries in game ticks (60 ticks = 1 second).
- salvoFollowPlayer: BOOLEAN - Optional: if each salvo re-targets on the player's current position and surface (`true`) or continues to target the initial position (`false`). Defaults to `false`, so any secondary salvo hits the `target` players initial position.

#### Examples

- atomic rocket: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":1, "explosiveType":"atomicRocket", "target":"muppet9010", "accuracyRadiusMax":50}`
- grenades around player: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":7, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":10, "accuracyRadiusMax":20}`
- offset artillery: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":1, "explosiveType":"artilleryShell", "target":"muppet9010", "targetOffset":[10, 10]}`
- poison capsules in large area around spawn: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":200, "explosiveType":"poisonCapsule", "target":"muppet9010", "targetPosition":{"x":0,"y":0}, "accuracyRadiusMax":200}`
- large count of explosive rockets using salvo and delay: `/muppet_streamer_schedule_explosive_delivery {"delay":5, "explosiveCount":30, "explosiveType":"explosiveRocket", "target":"muppet9010", "accuracyRadiusMax":30, "salvoSize":10, "salvoDelay":300, "salvoFollowPlayer": true}`
- custom type: `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":5, "explosiveType":"custom", "target":"muppet9010", "customExplosiveType":"cannon-projectile", "customExplosiveSpeed":1, "accuracyRadiusMax":10}`

#### Notes

- Explosives will fly in from off screen to random locations around the target player within the accuracy options. They may take a few seconds to complete their delivery as they fly in using their native throwing/shooting/spitting speed. Any explosive that collides with things (i.e. tank cannon shells) may complete their damage before they reach the player.
- Weapons are on a special enemy force so that they will hurt everything on the map, `muppet_streamer_enemy`. This also means that player damage upgrades don't affect these effects.
- Default projectile speeds for the built-in options: the thrown grenade & capsule, plus rocket options has a value of `0.3`. The artillery shell option has a value of `1`. Projectiles can have maximum speeds defined in their game prototypes that will constrain this effects outcomes.



---------------------------------------

Malfunctioning Weapon (Leaky Flamethrower)
============

Forces the targeted player to wield a weapon that shoots in random directions. Shoots a full ammo item, then briefly pauses before firing the next full ammo item. This is a Time Duration Effect and so may cut short other Time Duration Effects, see General Notes for details.

#### Command syntax

`/muppet_streamer_malfunctioning_weapon [OPTIONS TABLE AS JSON STRING]`

#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds the flamethrower and effects are delayed before starting. A `0` second `delay` makes it happen instantly. If not specified it defaults to happening instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- ammoCount: INTEGER - Mandatory: the quantity of ammo items to be put in the weapon and shot.
- reloadTime: DECIMAL - Optional: how many seconds to wait between each ammo magazine being fired. Defaults to `3` to give a noticeable gap.
- weaponType: STRING - Optional: the name of the specific weapon you want to use. This is the internal name within Factorio. Defaults to the vanilla Factorio flamethrower weapon, `flamethrower`.
- ammoType: STRING - Optional: the name of the specific ammo you want to use. This is the internal name within Factorio. Defaults to the vanilla Factorio flamethrower ammo, `flamethrower-ammo`.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.

#### Examples

- standard usage (leaky flamethrower): `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":5}`
- shotgun: `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":3, "weaponType":"shotgun", "ammoType":"shotgun-shell"}`
- custom weapon (Cryogun from Space Exploration mod): `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":5, "weaponType":"se-cryogun", "ammoType":"se-cryogun-ammo"}`
- atomic rocket launch: `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":1, "weaponType":"rocket-launcher", "ammoType":"atomic-bomb"}`

#### Notes

- This feature uses a custom Factorio permission group when active. This could conflict with other mods/scenarios that also use Factorio permission groups.
- While activated the player will be kicked out of any vehicle they are in and prevented from entering one. As no one likes to be in an enclosed space with weapons firing.
- The player will be given the weapon and ammo needed for the effect if needed. If given these will be reclaimed at the end of the effect as appropriate. The player’s original gun and weapon selection will be returned to them including any slot filters.
- While activated the player will lose control over their weapon's targeting and firing behavior.
- While activated the player can not change the active gun via the switch to the next weapon key.
- The player isn't prevented from removing the gun/ammo from their equipment slots as this isn't simple to prevent. However, this is such an active countering of the mod's behavior that if the streamer wishes to do this then that's their choice.
- The weapon is yours and so any of your force's damage upgrades will affect it.
- The weapon's `ammoType` will need to be able to either target the ground or be shot in a direction. Ammo types that need to be fired at a specific enemy target won't work.
- Stream type weapons (i.e. flamethrower) will slowly wonder around in range and direction. Projectile or beam type weapons will jump in their direction far quicker as they generally don't have the concept of target range in the same way.



---------------------------------------

Give Weapon & Ammo
============

Ensures the target player has a specific weapon and can give ammo and force their selection of the weapon.

#### Command syntax

`/muppet_streamer_give_player_weapon_ammo [OPTIONS TABLE AS JSON STRING]`

#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the items are given. A `0` second delay makes it happen instantly. If not specified it defaults to happening instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- weaponType: STRING - Optional: the name of a weapon to ensure the player has. Can be either in their weapon inventory or in their character inventory. If not specified then no specific weapon is given or selected. The weapon name is Factorio's internal name of the gun type and is case sensitive.
- forceWeaponToSlot: BOOLEAN - Optional: if `true` the `weaponType` will be placed/moved to the players equipped weapon inventory. If there's no room a currently equipped weapon will be moved to the character inventory to make room. If `false` then the `weaponType` will be placed in a free weapon slot, otherwise in the character'ss inventory. Defaults to `false`.
- selectWeapon: BOOLEAN - Optional: if `true` the player will have this `weaponType` selected as active if it's equipped in the weapon inventory. If `false` then no weapon change is done. Defaults to `false`, so not forcing the weapon to be selected.
- ammoType: STRING - Optional: the name of the ammo type to be given to the player. The ammo name is Factorio's internal name of the ammo type and is case sensitive. If an `ammoCount` is also set greater than `0` then this `ammoType` and amount will be forced into the weapon if equipped.
- ammoCount: INTEGER - Optional: the quantity of the named ammo to be given. If `0` or not present then no ammo is given.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.

#### Examples

- shotgun and ammo: `/muppet_streamer_give_player_weapon_ammo {"target":"muppet9010", "weaponType":"combat-shotgun", "forceWeaponToSlot":true, "ammoType":"piercing-shotgun-shell", "ammoCount":30}`

#### Notes

- If there isn't room in the character inventory for items they will be dropped on the ground at the players feet.



---------------------------------------

Spawn Around Player
============

Spawns entities in the game around the named player on their side. Includes both helpful and damaging entities and creation process options.

#### Command syntax

`/muppet_streamer_spawn_around_player [OPTIONS TABLE AS JSON STRING]`

#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the spawning occurs. A `0` second delay makes it happen instantly. If not specified it defaults to 0 happen instantly.
- target: STRING - Mandatory: the player name to center upon (case sensitive).
- force: STRING - Optional: the force of the spawned entities. Value can be either the name of a force (i.e. `player`), or left blank for the default for the entity type. See Notes for this list. Value is case sensitive to Factorio's internal force name.
- entityName: STRING - Mandatory: the type of entity to be placed: `tree`, `rock`, `laserTurret`, `gunTurretRegularAmmo`, `gunTurretPiercingAmmo`, `gunTurretUraniumAmmo`, `wall`, `landmine`, `fire`, `defenderBot`, `distractorBot`, `destroyerBot`, or `custom`. Is case sensitive. Custom requires the additional options `customEntityName` and `customSecondaryDetail` options to be set/considered.
- customEntityName: STRING - Mandatory Special: only required/supported if `entityName` is set to `custom`. Sets the name of the entity to be used. Supports any entity type, with the behaviours matching the included entityTypes.
- customSecondaryDetail: STRING - Optional Special: only required/supported if `entityName` is set to `custom`. Sets the name of any secondary item/entity used with the main `customEntityName`. See Notes for a list of supported `customEntityName` types.
- ammoCount: INTEGER - Optional: specifies the amount of "ammo" in applicable entityTypes. For turrets it's the ammo count and ammo over the turrets max storage is ignored. For fire types it's the flame count, see Notes for more details. This option applies to both `entityName` options and `customEntityName` entity types of turrets (all types) and fire.
- radiusMax: INTEGER - Mandatory: the max radius of the placement area from the target player.
- radiusMin: INTEGER - Optional: the min radius of the placement area from the target player. If set to the same value as radiusMax then a perimeter is effectively made. If not provided then `0` is used.
- existingEntities: STRING - Mandatory: how the newly spawned entity should handle existing entities on the map. Either `overlap`, or `avoid`.
- quantity: INTEGER - Mandatory Special: specifies the quantity of entities to place. Will not be more than this, but may be less if it struggles to find random placement spots. Placed on a truly random placement within the radius which is then searched around for a nearby valid spot. Intended for small quantities. Either `quantity` or `density` must be supplied.
- density: DECIMAL - Mandatory Special: specifies the approximate density of the placed entities. `1` is fully dense, close to `0` is very sparse. Placed on a 1 tile grid with random jitter for non tile aligned entities. Due to some placement searching it won't be a perfect circle and not necessarily a regular grid. Intended for larger quantities. Either `quantity` or `density` must be supplied.
- followPlayer: BOOLEAN - Optional: if `true` the combat robot types that are able to follow the player will do. If `false` they will be unmanaged. Some entities like defender combat bots have a maximum follower number, and so those beyond this limit will just be placed in the desired area.
- removalTimeMin: DECIMAL - Optional: the minimum number of seconds before the created entity will be automatically removed. Removal time is randomly between `removalTimeMin` and `removalTimeMax`. If neither `removalTimeMin` and `removalTimeMax` are specified it defaults to never removing the created entity.
- removalTimeMax: DECIMAL - Optional: the maximum number of seconds before the created entity will be automatically removed. Removal time is randomly between `removalTimeMin` and `removalTimeMax`. If neither `removalTimeMin` and `removalTimeMax` are specified it defaults to never removing the created entity.

#### Examples

- tree ring: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"tree", "radiusMax":10, "radiusMin":5, "existingEntities":"avoid", "density": 0.5}`
- gun turrets with small delay: `/muppet_streamer_spawn_around_player {"delay":3, "target":"muppet9010", "entityName":"gunTurretPiercingAmmo", "ammoCount":10, "radiusMax":7, "radiusMin":7, "existingEntities":"avoid", "quantity":10}`
- spread out fires: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"fire", "ammoCount": 100, "radiusMax":20, "radiusMin":0, "existingEntities":"overlap", "density": 0.05}`
- combat robots: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"defenderBot", "radiusMax":10, "radiusMin":10, "existingEntities":"overlap", "quantity": 20, "followPlayer": true}`
- named ammo in a named turret: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"custom", "customEntityName":"artillery-turret", "customSecondaryDetail":"artillery-shell", "ammoCount": 5, "radiusMax":7, "radiusMin":3, "existingEntities":"avoid", "quantity":1}`
- enemy worms that disappear after around 15 seconds: `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"custom", "customEntityName":"big-worm-turret", "radiusMax":20, "radiusMin":10, "existingEntities":"avoid", "quantity":5, "removalTimeMin":12, "removalTimeMax":18}`

#### Notes

- For `entityType` of `tree` or a `customEntityName` of an entity with a type of `tree`: if placed on a vanilla Factorio tile or with Alien Biomes mod a biome specific tree will be selected, otherwise the tree will be random on other modded tiles. Should support and handle fully defined custom tree types, otherwise they will be ignored.
- For `entityType` of `rock` or a `customEntityName` of an entity with a type of `rock`: a random selection between the larger 3 minable vanilla Factorio rocks will be used.
- There is a special force included in the mod that is hostile to every other force which can be used if desired for the `forceString` option: `muppet_streamer_enemy`. The `enemy` force is the one the default biters are on, with players by default on the `player` force.
- For `entityType` of `fire` or a `customEntityName` of an entity with a type of `fire`: Suggested is `30`, with the max of `250`. Generally the more flames the greater the damage, burn time and larger spread. For vanilla Factorio's `fire-flame` values above `35` have no greater effect, with it taking `20` fire count to set a tree on fire; but at this level the player will have to run right next to a tree to set it on fire. The suggested value of `30` generally sets trees very close to the player on fire without requiring the player to actually touch them. Value capped at `250`, as the Factorio's maximum of `255` is treated as a value of `0`, but this isn't 0 flames, instead its some per prototype default value. For some details on the oddity of flame counts see the following bug report: https://forums.factorio.com/viewtopic.php?f=7&t=103227
- For `customEntityName` of an entity with a type of `fluid-turret`: use the `customSecondaryDetail` to specify the fluid type to load the turret with. When using the `ammoCount` option be aware that the amount must be greater than the turret's minimum fluid to activate (a prototype field); for vanilla Factorio Flamethrower turrets this is greater than `25`.
- The `customSecondaryDetail` option is used when the `customEntityName` is one of these entity types: `ammo-turret` it stores the ammo name. `artillery-turret` it stores the ammo name. `fluid-turret` it stores the fluid name.
- The default `force` used is based on the entity type if not specified as part of the command. The default is for the force of the targeted player, with the following exceptions: Tree and rock types will be the `neutral` force. Fire types will be the `muppet_streamer_enemy` force which will hurt everything on the map.
- Most entity types will be placed no closer than 1 per tile. With the exception of the pre-defined `entityType` of `tree` and `rock`, plus any `entityType` and `customEntityName` that is a `combat-robot` or `fire` entity type. These exceptions are allowed to be placed much closer together.
- `Density` is done based on each tile having a random chance of getting an entity added. This means very low density values can be supported. However, it also means that in unlikely random outcomes quite a few of something could be created even with low values.
- The `radiusMin` and `radiusMax` options aren't truly precise. While the placement target is controlled by them, the entities are placed "near" to this if a valid position can be found for them. For a `quantity` number this is anywhere within a few tiles. For a `density` this is within half a tile. The aim is to create approximately the desired number of things in approximately the specified area.



---------------------------------------

Aggressive Driver
============

The player is locked inside their vehicle and forced to drive forwards for the set duration, they may have control over the steering based on settings. This is a Time Duration Effect and so may cut short other Time Duration Effects, see General Notes for details.

#### Command syntax

`/muppet_streamer_aggressive_driver [OPTIONS TABLE AS JSON STRING]`

#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- duration: DECIMAL - Mandatory: how many seconds the effect lasts on the player.
- control: STRING - Optional: if the driver of the vehicle has control over steering, either: `full` or `random`. `full` allows control over left/right steering, with `random` switching between left, right and straight for short periods. Both option settings include continuous accelerating. Defaults to `random`.
- commandeerVehicle: BOOLEAN - Optional: when `true` (default) the target player asserts control over vehicles dislodging other players if required, otherwise the target player won't dislodge other players in trying to ge a vehicle to drive. See Notes for more details on the option's settings. Defaults to `true`.
- teleportDistance: DECIMAL - Optional: the max distance of tiles that the player will be teleported into the nearest suitable vehicle. If not supplied it is treated as `0` distance and so the player isn't teleported. Don't set a massive distance as this may cause UPS lag, i.e. 3000+. See Notes for more details on how options interact.
- teleportWhitelistTypes: STRING_LIST - Optional: comma separated list of vehicle entity types that the player will only be teleported too. See Notes for more details on how options interact. These types are case sensitive to the Factorio's in-game vehicle types. Defaults to blank, which is all vehicle types.
- teleportWhitelistNames: STRING_LIST - Optional: comma separated list of vehicle entity names that the player will only be teleported too. See Notes for more details on how options interact. These names are case sensitive to the specific Factorio vehicle in-game names. Defaults to blank, which is all specific vehicle names.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.

#### Examples

- standard usage with teleport to a near vehicle: `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":30, "teleportDistance": 100}`
- only be aggressive if currently driving a vehicle: `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":30, "commandeerVehicle": false}`
- only teleport in to a train type: `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":30, "teleportDistance": 100, "teleportWhitelistTypes":"locomotive,cargo-wagon,fluid-wagon,artillery-wagon"}`

#### Notes

- This feature uses a custom Factorio permission group when active. This could conflict with other mods/scenarios that also use Factorio permission groups.
- If the vehicle comes to a stop during the effect due to hitting something it will automatically start moving in the opposite direction.
- This feature affects all types of cars, tanks, spider vehicles and train carriages.
- Any vehicle that is lacking fuel is treated as not suitable for the effect.
- The `commandeerVehicle` option when enabled (`true`) will always aim to put the player in the driving seat of a vehicle so they have all of the control over the vehicle. If the target player is already in a suitable vehicle they will be swapped to the drivers seat. If they aren't in a suitable vehicle and the `teleportDistance` option is greater than 0, then if there's no driverless suitable vehicles the target player will be moved in to any suitable vehicle's driver seat. Any other players dislodged will be moved to a passenger seat if possible, otherwise ejected from the vehicle. The vehicle selection logic for teleport targets will aim to minimise dislocations of other player, choosing greater teleportation distance first.
- The `commandeerVehicle` option when disabled (`false`) will try to get the player a vehicle to drive, but won't dislodge any other players to achieve it. If the player is already in a suitable vehicle in the passengers seat then the current vehicle will be deemed unsuitable as they aren't driving it. When the `teleportDistance` option is greater than 0, suitable vehicles must have a vacant drivers seat.
- The `teleportDistance` option will de-prioritise non-locomotive train carriages. So it will pick a further away locomotive or car type, rather than a near by cargo-wagon type. It will still aim to minimise player dislocations over target vehicle type priority.
- If either the `teleportWhitelistTypes` or `teleportWhitelistNames` options are populated then vehicle whitelisting as a whole is enabled. In this case the vehicle types and names listed are merged together to make the largest inclusion list possible. If neither are populated then there is no vehicle whitelisting and so all are included. A usage example is to set `teleportWhitelistTypes` to `spider-vehicle` and `teleportWhitelistNames` to `car-mk2`. This would mean the player can be teleported in to either specifically a car-mk2, or any spider-vehicle type vehicle, i.e. a spidertron.
- Trains are a special case in Factorio as every player in the train can have input to drive it. The mod will control the target players inputs and generally these seem to supersede any other train riding player's inputs, however, this isn't guaranteed.
- The player isn't prevented from removing the fuel from their vehicle as this isn't simple to prevent. However, this is such an active countering of the mod's behavior that if the streamer wishes to do this then that's their choice.
- If the vehicle runs out of fuel during the effect it will continue, but just have no impact other than locking the player in the vehicle. This is a very unlikely edge case and the player can obviously add fuel to the vehicle if they have any.



---------------------------------------

Call For Help
============

Teleports other players on the server to near your position.

#### Command syntax

`/muppet_streamer_call_for_help [OPTIONS TABLE AS JSON STRING]`
#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- arrivalRadius - DECIMAL - Optional: players teleported to the target player will be placed within this max distance. Defaults to `10`.
- blacklistedPlayerNames - STRING_LIST - Optional: comma separated list of player names who will never be teleported to the target player. These are removed from the available players lists and counts. These names are case sensitive to the player's in-game name.
- whitelistedPlayerNames - STRING_LIST - Optional: comma separated list of player names who will be the only ones who can be teleported to the target player. If provided these whitelisted players who are online constitute the entire available player list that any other filtering options are applied to. If not provided then all online players not blacklisted are valid players to select from based on filtering criteria. These names are case sensitive to the player's in-game name.
- callRadius - DECIMAL - Optional: the max distance a player can be from the target and still be teleported to them. If not provided then a player at any distance can be teleported to the target player. If the `sameSurfaceOnly` argument is set to `false` (non default) then the `callRadius` argument is ignored entirely.
- sameSurfaceOnly - BOOLEAN - Optional: if the players being teleported to the target have to be on the same surface as the target player or not. If `false` then the `callRadius` argument is ignored as it can't logically be applied. Defaults to `true`.
- sameTeamOnly - BOOLEAN - Optional: if the players being teleported to the target have to be on the same team (force) as the target player or not. Defaults to `true`.
- callSelection - STRING - Mandatory: the logic to select which available players in the callRadius are teleported, either: `random`, `nearest`.
- number - INTEGER - Mandatory Special: how many players to call. Either one or both of `number` or `activePercentage` must be supplied.
- activePercentage - DECIMAL - Mandatory Special: the percentage of currently available players to teleport to help, i.e. `50` for 50%. Will respect blacklistedPlayerNames and whitelistedPlayerName argument values when counting the number of available players. Either one or both of `number` or `activePercentage` must be supplied.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.

#### Examples

- call in the greater of either 3 or 50% of valid players : `/muppet_streamer_call_for_help {"target":"muppet9010", "callSelection": "random", "number": 3, "activePercentage": 50}`
- call in all the players nearby : `/muppet_streamer_call_for_help {"target":"muppet9010", "callRadius": 200, "callSelection": "random", "activePercentage": 100}`

#### Notes

- The position that each player is teleported to will be able to path to your position. So no teleporting them on to islands or middle of cliff circles, etc.
- If both `number` and `activePercentage` is supplied the greatest value at the time will be used.
- CallSelection of `nearest` will treat players on other surfaces as being maximum distance away, so they will be the lowest priority. If these players on other surfaces are included or not is controlled by the `sameSurfaceOnly` option.
- A teleported player comes with their vehicle where appropriate (excludes trains). Anyone else in the vehicle will stay in the vehicle and thus be teleported as well. The vehicle will be partially re-angled unless/until a Factorio modding API request is done.



---------------------------------------

Teleport
============

Teleports the player to the nearest type of thing.

#### Command syntax

`/muppet_streamer_teleport [OPTIONS TABLE AS JSON STRING]`
#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- destinationType: STRING/POSITION_OBJECT - Mandatory: the type of teleport to do, either the text string of `random`, `biterNest`, `enemyUnit`, `spawn` or a specific position in the map as a POSITION_OBJECT. For `biterNest` and `enemyUnit` it will be the nearest one found within range. See Argument Data Types for syntax examples of a POSITION_OBJECT.
- arrivalRadius - DECIMAL - Optional: the max distance the player will be teleported to from the targeted `destinationType`. Defaults to `10`.
- minDistance: DECIMAL - Optional: the minimum distance to teleport. If not provided then the value of `0` is used. Is ignored for `destinationType` of `spawn`, specific position or `enemyUnit`.
- maxDistance: DECIMAL - Mandatory Special: the maximum distance to teleport. Is not mandatory and ignored for `destinationType` of `spawn` or a specific position.
- reachableOnly: BOOLEAN - Optional: if the place you are teleported must be walkable back to where you were. Defaults to `false`. Only applicable for `destinationType` of `random` and `biterNest`.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Can be specified within nested `backupTeleportSettings` options, otherwise will be inherited from the parent command. Defaults to `false`.
- backupTeleportSettings: Teleport details in JSON string - Optional: a backup complete teleport action that will be done if the main/parent command is unsuccessful. Is a complete copy of the main muppet_streamer_teleport options as a JSON object.

#### Examples

- nearest walkable biter nest: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance": 1000, "reachableOnly": true}`
- random location: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"random", "minDistance": 100, "maxDistance": 500, "reachableOnly": true}`
- specific position: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":[200, 100]}`
- usage of a backup teleport: `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance": 100, "reachableOnly": true, "backupTeleportSettings": {"target":"muppet9010", "destinationType":"random", "minDistance": 100, "maxDistance": 500, "reachableOnly": true} }`

#### Notes

- `destinationType` of `enemyUnit` and `biterNests` does a search for the nearest opposing force (not friend or cease-fire) unit/nest within the `maxDistance`. If this is a very large area (3000+) this may cause a small UPS spike.
- All teleports will try 10 random locations around their targeted position within the `arrivalRadius` option to try and find a valid spot. If there is no success they will try with a different target 5 times before giving up for the `random` and `biterNest` `destinationType`.
- The `reachableOnly` option will give up on a valid random location for a target if it gets a failed pathfinder request and try another target. For `biterNests` this means it may not end up being the closest biter nest you are teleported to in all cases, based on walkable checks. This may also lead to no valid target being found in some cases, so enable with care and expectations. The `backupTeleportSettings` can provide assistance here.
- The `backupTeleportSettings` is intended for use if you have a more risky main `destinationType`. For example your main `destinationType` may be a biter nest within 100 tiles, with a backup being a random location within 1000 tiles. All options in the `backupTeleportSettings` must be provided just like the main command details. It will be queued to action at the end of the previous teleport attempt failing. You can nest these as many times as required.
- A teleported player comes with their vehicle where appropriate (excludes trains). Anyone else in the vehicle will stay in the vehicle and thus be teleported as well. The vehicle will be partially re-angled unless/until a Factorio modding API request is done.



---------------------------------------

Pants On Fire
============

Sets the ground on fire behind a player forcing them to run. This is a Time Duration Effect and so may cut short other Time Duration Effects, see General Notes for details.

#### Command syntax

`/muppet_streamer_pants_on_fire [OPTIONS TABLE AS JSON STRING]`
#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- duration: DECIMAL - Mandatory: how many seconds the effect lasts on the player.
- fireGap: INTEGER - Optional: how many ticks between each fire entity. Defaults to `6`, which gives a constant fire line.
- fireHeadStart: INTEGER - Optional: how many fire entities does the player have a head start on. Defaults to `3`, which forces continuous running with the default value of the `fireGap` option.
- flameCount: INTEGER - Optional: how many flames each fire entity will have, see Notes for more details. Default is `30` (intended for `fire-flame`), with the conceptual max of `250`.
- fireType: STRING - Optional: the name of the specific `fire` type entity you want to have. This is the internal name within Factorio. Defaults to the vanilla Factorio fire entity, `fire-flame`.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.

#### Examples

- continuous fire at players heels: `/muppet_streamer_pants_on_fire {"target":"muppet9010", "duration": 30}`
- sporadic worm acid spit (low damage type of fire entity): `/muppet_streamer_pants_on_fire {"target":"muppet9010", "duration": 30, "fireGap": 30, "flameCount": 3, "fireHeadStart": 1, "fireType":"acid-splash-fire-worm-behemoth"}`

#### Notes

- For the duration of the effect if a player enters a vehicle they are instantly ejected. This does not use a Factorio permission group as the effect doesn't require it.
- Fire effects are on a special enemy force so that they will hurt everything on the map, `muppet_streamer_enemy`. This also means that player damage upgrades don't affect these effects.
- Generally the more flames the greater the damage, burn time and larger spread. For vanilla Factorio's `fire-flame` values above `35` have no greater effect, with it taking `20` fire count to set a tree on fire; but at this level the player will have to run right next to a tree to set it on fire. The command defaults to a value of `30` which generally sets trees very close to the player on fire without requiring the player to actually touch them. Value capped at `250`, as the Factorio's maximum of `255` is treated as a value of `0`, but this isn't `0` flames, instead its some per prototype default value. For some details on the oddity of flame counts see the following bug report: https://forums.factorio.com/viewtopic.php?f=7&t=103227



---------------------------------------

Player Drop Inventory
============

Schedules the targeted player to drop their inventory on the ground over time. This is a Time Duration Effect and so may cut short other Time Duration Effects, see General Notes for details.

#### Command syntax

`/muppet_streamer_player_drop_inventory [OPTIONS TABLE AS JSON STRING]`
#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the effects start. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- quantityType: STRING - Mandatory: the way quantity value is interpreted to calculate the number of items to drop per drop action, either `constant`, `startingPercentage` or `realtimePercentage`. The `constant` setting uses the `quantityValue` option as a static number of items. The `startingPercentage` setting means a percentage of the item count at the start of the effect is dropped from the player every drop action. The `realtimePercentage` setting means that every time a drop action occurs the player's current inventory item count is used to calculate how many items to drop this action.
- quantityValue: INTEGER - Mandatory: the number of items to drop. When quantityType is `startingPercentage`, or `realtimePercentage` this number is used as the percentage (0-100).
- dropOnBelts: BOOLEAN - Optional: if the dropped items should be placed on belts or not. Defaults to `false`.
- markForDeconstruction: BOOLEAN - Optional: if the dropped items are marked for deconstruction by the owning player's force. Defaults to `false`.
- dropAsLoot: BOOLEAN - Optional: if the dropped items are marked as loot and thus any player who goes near them automatically picks them up. Defaults to `false`.
- gap: DECIMAL - Mandatory: how many seconds between each drop action. If `occurrences` is set to `1` then this `gap` option has no impact, but still must be set to `1` or greater.
- occurrences: INTEGER - Mandatory: how many times the drop actions are done. Must be a value of `1` or greater.
- includeArmor: BOOLEAN - Optional: if the player's equipped (worn) armor is included for dropping or not. Defaults to `true`.
- includeWeapons: BOOLEAN - Optional: if the player's equipped weapons and ammo are included for dropping or not. Defaults to `true`.
- density: DECIMAL - Optional: specifies the approximate density of the dropped items at the center of their spill area. Value in range of `10` (dense) to `0` (extremely spread out), see Notes for full details. Defaults to `10`.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.

#### Examples

- dropping 10% of starting inventory items 5 times: `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"startingPercentage", "quantityValue":10, "gap":2, "occurrences":5}`
- 10 drops of 5 items a time, allows dropping items on belts: `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"constant", "quantityValue":5, "gap":2, "occurrences":10, "dropOnBelts":true}`
- dropping all of inventory in 1 go: `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"startingPercentage", "quantityValue":100, "gap":1, "occurrences":1}`

#### Notes

- Will drop individually randomised items across all of the included inventories and item stack types the player has. It will drop items of the same type from the first stack in the inventory, rather than from across multiple item stacks of the same type; this should almost never have any impact on the outcome.
- Dropping very large quantities of items in crowded areas at one time may cause Factorio to use increased UPS as it tries to find placement locations for all the items.
- For percentage based quantity values it will drop a minimum of 1 item per cycle. So that very low values/inventory sizes avoid not dropping anything.
- If the player doesn't have any items to drop for any given drop action then while that drop occurrence is complete, the effect continues until all occurrences have occurred at their set gaps. The effect does not not stop unless the player dies or all occurrences have been completed.
- The items are dropped around the player approximately 2 tiles away from them in a circle. With the density decreasing as the items move away from the player. The spread is ideal in open areas, with tight areas seeming more densely placed due to the limited placement options. The items placement density won't be exactly the same between very low and high item drop quantities, but should be approximately similar considering the randomisation in the placement logic. Any square edges to dense areas of items on the ground is caused by entities blocking their placement.
- The `density` option will define how dense the items will be at their center. The rate the density of items decreases at is related to the starting density, with higher central `density` values getting sparser quicker (mountain shape), and lower starting `density` values becoming sparse over a larger distance (frisbee shape). All items are placed in the same total area regardless of `density` option, but the number of items towards the edge of this area will vary significantly. Changes to the `density` value around the max density (`10`) will appear to have a greater impact on distribution than changes at the sparse (`0`) end of the range. This may be real from the Gaussian algorithm or just human perception.
- Maximum `density` is configured to avoid excessive overlapping of the items when randomly placed on the ground. This is why it doesn't place the full 9 items per tile. Overlapping items cause the Factorio game engine to work harder to find a placement location and thus can have higher UPS usage.
- Armor is dropped last if it's included. When the armor is dropped this may reduce players inventory size, and thus may spill items on the ground using default Factorio logic. The armor is dropped last to try and avoid/reduce this risk, but it is unavoidable.



---------------------------------------

Player Inventory Shuffle
============

Takes all the inventory items from the targeted players, shuffles them and then distributes the items back between those players. Will keep the different types of items in roughly the same number of players inventories as they started, and will spread the quantities each player receives in a random distribution between them (not evenly).

#### Command syntax

`/muppet_streamer_player_inventory_shuffle [OPTIONS TABLE AS JSON STRING]`
#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the effects start. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly.
- includedPlayers: STRING_LIST/STRING -  Mandatory Special: Can be one of a few setting values; Either blank(`""`) or not specified for no specific named players. A comma separated list of the player names to include (assuming they are online at the time). Or `[ALL]` to target all online players on the server. Any player names listed are case sensitive to the player's in-game name. Either or both of `includedPlayers` or `includedForces` options must be provided.
- includedForces: STRING_LIST -  Mandatory Special: Can be one of a few setting values; Either blank(`""`) or not specified for no specific force's players. A comma separated list of the force names to include all players from (assuming they are online at the time). Any force names listed are case sensitive to the forces's in-game name. Either or both of `includedPlayers` or `includedForces` options must be provided.
- includeArmor: BOOLEAN - Optional: if the player's equipped (worn) armor is included for shuffling or not. Defaults to `true`.
- extractArmorEquipment: BOOLEAN - Optional: if the player's armor (equipped and in inventory) should have its equipment removed from it and included in the shuffled items. Defaults to `false`.
- includeWeapons: BOOLEAN - Optional: if the player's equipped weapons and ammo are included for shuffling or not. Defaults to `true`.
- includeHandCrafting: BOOLEAN - Optional: if the player's hand crafting should be cancelled and the ingredients shuffled. Defaults to `true`.
- destinationPlayersMinimumVariance: INTEGER - Optional: Set the minimum player count variance to receive an item type compared to the number of source inventories. A value of `0` will allow the same number of players to receive an item as lost it, greater than 0 ensures a wider distribution away from the source number of inventories. Defaults to `1` to ensure some uneven spreading of items. See Notes for logic on item distribution and how this option interacts with other options.
- destinationPlayersVarianceFactor: DECIMAL - Optional: The multiplying factor applied to each item type's number of source players when calculating the number of inventories to receive the item. Used to allow scaling of item recipients for large player counts. A value of `0` will mean there is no scaling of source to destination inventories. Defaults to `0.25`. See Notes for logic on item distribution and how this option interacts with other options.
- recipientItemMinToMaxRatio: INTEGER - Optional: The approximate min/max ratio range of the number of items a destination player will receive compared to others. Defaults to `4`. See Notes for logic on item distribution.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.

#### Examples

- 3 named players: `/muppet_streamer_player_inventory_shuffle {"includedPlayers":"muppet9010,Test_1,Test_2"}`
- all active players: `/muppet_streamer_player_inventory_shuffle {"includedPlayers":"[ALL]"}`
- 2 named players and all players on a specific force: `/muppet_streamer_player_inventory_shuffle {"includedPlayers":"Test_1,Test_2", "includedForces":"player"}`

#### Notes

- There must be 2 or more included players online otherwise the command will do nothing (prints notification message). The players from both include options will be pooled for this.
- Players are given items using Factorio's default item assignment logic. This will mean that equipment will be loaded based on the random order it is received. Any auto trashing will happen after all the items have tried to be distributed, just like if you try to mine an auto trashed item, but your inventory is already full.
- If includeHandCrafting is `true`; Any hand crafting by players will be cancelled and the ingredients added into the shared items. To limit the UPS impact from this, each item stack (icon in crafting queue) that is cancelled will have any ingredients greater than 4 full player inventories worth dropped on the ground rather than included into the shared items. Multiple separate crafts will be individually handled and so have their own limits. This will come into play in the example of a player filling up their inventory with stone and starts crafting stone furnaces, then refills with stone and does this again 4 times sequentially, thus having a huge number of queued crafting items. As these crafts would all go into 1 craft item (icon in the queue).
- All attempts are made to give the items to players, but as a last resort they will be dropped on the ground. In large quantities this can cause a UPS stutter as the core Factorio game engine handles it. This will arise if players have all their different inventories full and have long crafting queues with extra items already used in these crafts.
- This command can be UPS intensive for large player numbers (10/20+), if players have very large modded inventories, or if lots of players are hand crafting lots of things. In these cases the server may pause for a moment or two until the effect completes. This feature has been refactored multiple times for UPS improvements, but ultimately does a lot of API commands and inventory manipulation which is UPS intensive.
- When the option `extractArmorEquipment` is enabled any items extracted from armor equipment grids will lose their electric charge. This is default Factorio behavior during the process of removing equipment from the equipment grid.

#### Distribution Logic

The distribution logic is a bit convoluted, but works as per:

- All targets online have all their inventories taken. Each item type has the number of source players recorded.
- A random number of new players to receive each item type is worked out. This is based on the number of source players for that item type, with a +/- random value applied based on the greatest between; the `destinationPlayersMinimumVariance` option, and the `destinationPlayersVarianceFactor` option multiplied by the number of source inventories to give a scaling player effect. Use of the `destinationPlayersMinimumVariance` option allows a minimum variation of receiving players compared to source inventories to be enforced even when very small player targets are online. The final value of new players for the items to be split across will never be less than 1 or greater than all of the online target players.
- The number of each item each selected player will receive is a random proportion of the total. This is controlled by the `recipientItemMinToMaxRatio` option. This option defines the minimum to maximum ratio between 2 players, i.e. option of `4` means a player receiving the maximum number can receive up to 4 times as many as a player receiving the minimum. This option's implementation isn't quite exact and should be viewed as a rough guide.
- Any items that can't be fitted into the intended destination player will be given to another online targeted player if possible. This will affect the item quantity balance between players and the appearance of how many destination players were selected. If it isn't possible to give the items to any online targeted player then they will be dropped on the floor at the targeted players’ feet. This situation can occur as items are taken from the player's extra inventories like trash, but returned to the player using Factorio default item assignment logic. Player's various inventories can also have filtering on their slots, thus further reducing the room for random items to fit in.



---------------------------------------

Team Member Limit
============

A way to soft limit the number of players on the map and options to use either Factorio research or RCON commands to increase it.

Intended for use by a single streamer and so the simple one line GUI in the top left reports the current number of team members to the streamer (players on the server - 1).

#### Features Usage

The Team Member Limit feature's usage is controlled via the startup setting `Team member technology pack count`. It defaults to `-1` for disabled. When being used the limit on players can be increased either by technology research or from Command/Remote Interface, but not both.

- A value of `-1` disables the entire feature. This is needed as the feature adds GUIs and shortcuts, thus if you aren't using it you don't want these present.
- A value of `0` hides the technology from the research screen and enables the Command and Remote Interface to be used to change the max player limit.
- A value of greater than `0` shows the technology in the research screen and prevents the Command and Remote Interface from being used.

#### Technology Research

Research to increase the number of team members. Requires vanilla Factorio science packs to exist. Cost is configurable and the research levels increase in science pack complexity. Includes infinite options that double in cost each time.

#### Command and Remote Interface

Command and Remote interface to increase the max team member count by a set amount.

Command:

- syntax: `/muppet_streamer_change_team_member_max NUMBER`
- example to increase by 2: `/muppet_streamer_change_team_member_max 2`

Remote Interface:

- syntax: muppet_streamer , increase_team_member_level , NUMBER
- example to increase by 2: `remote.call('muppet_streamer', 'increase_team_member_level', 2)`



---------------------------------------

Dead Building Ghosts
============

A mod setting that can make all forces start with ghosts being placed upon entity deaths. Ideal if your chat blows up your base often early game and you freehand build, so don't have a blueprint to just paste down again.

This is the same as if the force had researched the vanilla Factorio construction robot technology to unlock it, by giving entity ghosts a long life time. The mod setting can be safely disabled post technology research if desired without it undoing any researched ghost life timer.



---------------------------------------

Command Syntax
============

All of the commands take a table of options as a JSON string when they are called to provide the configuration of the command. All of the command examples include this format and so can be copy/pasted straight into the game.

#### Argument Data Types

- INTEGER = expects a whole number and not a fraction. So `1.5` is a bad value. Integers are not wrapped in double quotes.
- DECIMAL = can take a fraction, i.e `0.25` or `54.28437`. In some usage cases the final result will be rounded to a degree when processed, i.e. `0.4` seconds will have to be rounded to a single tick accuracy to be timed within the game. Decimals are not wrapped in double quotes.
- BOOLEAN = expects either `true` or `false`. Booleans are not wrapped in double quotes.
- STRING = a text string wrapped in double quotes, i.e. `"some text"`
- STRING_LIST = a comma separated list of things in a single string, i.e. `"Player1,player2, Player3  "`. Any leading or trailing spaces will be removed from each entry in the list. The casing (capitalisation) of things must match the case within factorio exactly, i.e. player names must have the same case as within Factorio. This can be a single thing in a string, i.e. `"Player1"`.
- POSITION_OBJECT = Arguments that accept a position will accept either a table or an array for the positional data. Both formats are recording 2 coordinates, an `x` and `y` value. They can be provided as either a table JSON string `{"x": 10, "y": 5}` or as a shorter array JSON string `[10, 5]`.
- OBJECT = some features accept an object as an argument. These are detailed in the Notes for those functions. This is a dictionary of keys and values in JSON format (a table). The arguments each command accepts is an example of this.

#### Argument Requirements

- Mandatory = the option must be provided.
- Mandatory Special = the option is/can be mandatory, see the details on the option for specifics.
- Optional = you are free to include or exclude the option. The default value will be listed and used when the option isn't included or is a nil value. As well as not including optional options you can also pass in `null` to JSON strings or `nil` to Lua objects, if you wish to have the option name included to improve readability between different commands. While `null` isn't part of the JSON specification, the Factorio JSON string to Lua Object does handle it.

#### Number ranges

- Many options will have non-documented common sense minimum number requirements. i.e. you can't have a malfunctioning flamethrower activated for 0 or less bursts. These will raise a warning on screen and the command won't run.
- Many options will have non-documented maximum values at extremes. The known ones will be capped to the maximum allowed, i.e. number of seconds to delay an event for. However, so will be unknown about and are generally Factorio internal limits, so will not be prevented and may cause crashes. For this reason experimenting with ridiculously large numbers isn't advised.



---------------------------------------

General Usage Notes
============

#### Time Duration Effect

At present a Time Duration Effect may interrupt a different type of Time Duration Effect, depending upon each effects behaviours and player state requirements. i.e. Aggressive Driver and Malfunctioning Weapon will interrupt each other, but a Player Drop Inventory will not affect an Aggressive Driver.

Any repeated running of the same effect will have the subsequent effect requests ignored, with the first effect continuing until its original completion.



---------------------------------------

Remote Interface - Calling from Lua script
============

You can trigger all of the features via a remote interface call as well as the standard commands detailed above. This is useful for triggering the features from other mods, from viewer integrations when you need to use a Lua script for some maths, or if you want multiple features to be applied simultaneously.

All features are called with the `muppet_streamer` interface and the `run_command` function name. They each then take 2 arguments:

- CommandName - This is the feature's command name you want to trigger. It's identical to the command name detailed in each feature.
- Options - These are the options you want to pass to the feature. These are identical to the command for the feature. It accepts either a JSON string or a Lua table of the options.

#### Calling the Aggressive Driver feature with options as a JSON string

This option string is identical to the command's, with the string defined by single quotes to avoid needing to escape the double quotes within the JSON text.
If you want to dynamically insert values in to this options JSON string you will have to ensure the correct JSON syntax is maintained. Often this is when using a Lua object (detailed below) is easier.
```/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', '{"target":"muppet9010", "duration":30, "control": "random", "teleportDistance": 100}')```

#### Calling the Aggressive Driver feature with options as a Lua object

This option object has the same options as the command, with the syntax being for a Lua object. This makes adding dynamic content in much more natural.
```/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=30, control="random", teleportDistance=100})```

#### Lua script value manipulation

Using remote interface calls instead of RCON commands also allows for any required value manipulation from whichever viewer integration you are using, for example the below is assuming your integration tool is replacing VALUE with a scalable number from your viewer integration and want to limit the result to no greater than 30.
```
/sc local drivingTime = math.min(VALUE, 30)
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=drivingTime, control="random", teleportDistance=100})
```

You can also use this to affect multiple players with the same effect at once. You are responsible for ensuring the options you apply to the effect are suitable for this. In the below example we create 3 hostile worms near every player. Note that if multiple players are together then many more worms will appear around them collectively.
```
/sc for _, player in pairs(game.connected_players) do
	remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=player.name, entityName="custom", customEntityName="big-worm-turret", force="muppet_streamer_enemy", radiusMax=15, radiusMin=10, existingEntities="avoid", quantity=3})
end
```

#### Multiple simultaneous feature calling

Running features via remote interface calls within a Lua script and not as a command allows you to trigger multiple features simultaneously. Whereas doing them via RCON command requires them to be done sequentially and thus have a slight delay between them. This can be particularly useful when you want multiple effects to be centered on the same position and the target player may be moving fast (i.e. a train).

An example of this is below, with making a ring of turrets around the player, with a short barrage of grenades outside this. If done via command and the player was moving fast the grenades would likely hit the turrets, with a single Lua script calling both features via remote interface this friendly fire won't occur.
```
/sc
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', '{"target":"muppet9010", "entityName":"gunTurretPiercingAmmo", "radiusMax":3, "radiusMin":3, "existingEntities":"avoid", "quantity":5, "ammoCount":10}')
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', '{"explosiveCount":60, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":15, "accuracyRadiusMax":15, "salvoSize": 20, "salvoDelay": 120}')
```
