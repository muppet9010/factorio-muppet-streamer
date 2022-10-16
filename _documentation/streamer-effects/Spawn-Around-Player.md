Spawns entities in the game around the player. Can includes both helpful and damaging entities and creation process options.

![demo](https://github.com/muppet9010/factorio-muppet-streamer/wiki/images/spawn-around-player.gif)



# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds before the spawning occurs. A `0` second delay makes it happen instantly. If not specified it defaults to 0 happen instantly. |
| target | STRING | Mandatory | The player name to center upon (case sensitive). |
| targetPosition | POSITION | Optional | A specific position to center at on the target player's surface, rather than the player's current position. See Argument Data Types for syntax examples of a POSITION. |
| targetOffset | POSITION | Optional | An offset that's applied to the `target`/`targetPosition` value. By default there is no offset set. See Argument Data Types for syntax examples of a POSITION. |
| force | STRING | Optional | The force of the spawned entities. Value can be either the name of a force (i.e. `player`), or left blank for the default for the entity type. See Notes for this list. Value is case sensitive to Factorio's internal force name. |
| entityName | STRING | Mandatory | The type of entity to be placed: `tree`, `rock`, `laserTurret`, `gunTurretRegularAmmo`, `gunTurretPiercingAmmo`, `gunTurretUraniumAmmo`, `wall`, `landmine`, `fire`, `defenderBot`, `distractorBot`, `destroyerBot`, or `custom`. Is case sensitive. Custom requires the additional options `customEntityName` and `customSecondaryDetail` options to be set/considered. |
| customEntityName | STRING | Mandatory Special | Only required/supported if `entityName` is set to `custom`. Sets the name of the entity to be used. Supports any entity type, with the behaviours matching the included entityTypes. |
| customSecondaryDetail | STRING | Optional Special | Only required/supported if `entityName` is set to `custom`. Sets the name of any secondary item/entity used with the main `customEntityName`. See Notes for a list of supported `customEntityName` types. |
| ammoCount | INTEGER | Optional | Specifies the amount of "ammo" in applicable entityTypes. For turrets it's the ammo count and ammo over the turrets max storage is ignored. For fire types it's the flame count, see Notes for more details. This option applies to both `entityName` options and `customEntityName` entity types of turrets (all types) and fire. |
| radiusMax | INTEGER | Mandatory | The max radius of the placement area from the target position. |
| radiusMin | INTEGER | Optional | The min radius of the placement area from the target position. If set to the same value as radiusMax then a perimeter is effectively made. If not provided then `0` is used. |
| existingEntities | STRING | Mandatory | How the newly spawned entity should handle existing entities on the map. Either `overlap`, or `avoid`. |
| quantity | INTEGER | Mandatory Special | Specifies the quantity of entities to place. Will not be more than this, but may be less if it struggles to find random placement spots. Placed on a truly random placement within the radius which is then searched around for a nearby valid spot. Intended for small quantities. Either `quantity` or `density` must be supplied. |
| density | DECIMAL | Mandatory Special | Specifies the approximate density of the placed entities. `1` is fully dense, close to `0` is very sparse. Placed on a 1 tile grid with random jitter for non tile aligned entities. Due to some placement searching it won't be a perfect circle and not necessarily a regular grid. Intended for larger quantities. Either `quantity` or `density` must be supplied. |
| followPlayer | BOOLEAN | Optional | If `true` the combat robot types that are able to follow the player will do. If `false` they will be unmanaged. Some entities like defender combat bots have a maximum follower number, and so those beyond this limit will just be placed in the desired area. |
| removalTimeMin | DECIMAL | Optional | The minimum number of seconds before the created entity will be automatically removed. Removal time is randomly between `removalTimeMin` and `removalTimeMax`. If neither `removalTimeMin` and `removalTimeMax` are specified it defaults to never removing the created entity. |
| removalTimeMax | DECIMAL | Optional | The maximum number of seconds before the created entity will be automatically removed. Removal time is randomly between `removalTimeMin` and `removalTimeMax`. If neither `removalTimeMin` and `removalTimeMax` are specified it defaults to never removing the created entity. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

<details><summary>Remote Interface</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| tree ring | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target="muppet9010", entityName="tree", radiusMax=10, radiusMin=5, existingEntities="avoid", density=0.5})` |
| gun turrets with small delay | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {delay=3, target="muppet9010", entityName="gunTurretPiercingAmmo", ammoCount=10, radiusMax=7, radiusMin=7, existingEntities="avoid", quantity=10})` |
| spread out fires | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target="muppet9010", entityName="fire", ammoCount=100, radiusMax=20, radiusMin=0, existingEntities="overlap", density=0.05})` |
| combat robots | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target="muppet9010", entityName="defenderBot", radiusMax=10, radiusMin=10, existingEntities="overlap", quantity=20, followPlayer=true})` |
| named ammo in a named turret | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target="muppet9010", entityName="custom", customEntityName="artillery-turret", customSecondaryDetail="artillery-shell", ammoCount=5, radiusMax=7, radiusMin=3, existingEntities="avoid", quantity=1})` |
| enemy worms that disappear after around 15 seconds | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target="muppet9010", entityName="custom", customEntityName="big-worm-turret", radiusMax=20, radiusMin=10, existingEntities="avoid", quantity=5, removalTimeMin=12, removalTimeMax=18})` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



<details><summary>Factorio Command</summary>
<p>

Command Syntax: `/muppet_streamer_spawn_around_player [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| tree ring | `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"tree", "radiusMax":10, "radiusMin":5, "existingEntities":"avoid", "density":0.5}` |
| gun turrets with small delay | `/muppet_streamer_spawn_around_player {"delay":3, "target":"muppet9010", "entityName":"gunTurretPiercingAmmo", "ammoCount":10, "radiusMax":7, "radiusMin":7, "existingEntities":"avoid", "quantity":10}` |
| spread out fires | `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"fire", "ammoCount":100, "radiusMax":20, "radiusMin":0, "existingEntities":"overlap", "density":0.05}` |
| combat robots | `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"defenderBot", "radiusMax":10, "radiusMin":10, "existingEntities":"overlap", "quantity":20, "followPlayer":true}` |
| named ammo in a named turret | `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"custom", "customEntityName":"artillery-turret", "customSecondaryDetail":"artillery-shell", "ammoCount":5, "radiusMax":7, "radiusMin":3, "existingEntities":"avoid", "quantity":1}` |
| enemy worms that disappear after around 15 seconds | `/muppet_streamer_spawn_around_player {"target":"muppet9010", "entityName":"custom", "customEntityName":"big-worm-turret", "radiusMax":20, "radiusMin":10, "existingEntities":"avoid", "quantity":5, "removalTimeMin":12, "removalTimeMax":18}` |

</p>
</details>



# Notes

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



# Complicated usage examples

<details><summary>Build castle around player</summary>
<p>

This makes a small castle like thing around the player with walls, turrets and landmines. As it's all random and it will avoid placing these new things over existing things its not guaranteed in busy areas and may be a a bit wonky. But still a fun example of stacking multiple commands together to give a dynamic and flexible outcome.

![example](https://github.com/muppet9010/factorio-muppet-streamer/wiki/images/spawn_around_player-castle.png)

```
/sc
local targetPlayer = game.get_player("muppet9010")
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="gunTurretPiercingAmmo", ammoCount=20, existingEntities="avoid", quantity=1, targetOffset={x=-8,y=-8}, radiusMax=0})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="wall", existingEntities="avoid", density=1, targetOffset={x=-8,y=-8}, radiusMin=3, radiusMax=4})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="gunTurretPiercingAmmo", ammoCount=20, existingEntities="avoid", quantity=1, targetOffset={x=8,y=-8}, radiusMax=0})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="wall", existingEntities="avoid", density=1, targetOffset={x=8,y=-8}, radiusMin=3, radiusMax=4})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="gunTurretPiercingAmmo", ammoCount=20, existingEntities="avoid", quantity=1, targetOffset={x=8,y=8}, radiusMax=0})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="wall", existingEntities="avoid", density=1, targetOffset={x=8,y=8}, radiusMin=3, radiusMax=4})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="gunTurretPiercingAmmo", ammoCount=20, existingEntities="avoid", quantity=1, targetOffset={x=-8,y=8}, radiusMax=0})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="wall", existingEntities="avoid", density=1, targetOffset={x=-8,y=8}, radiusMin=3, radiusMax=4})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="wall", existingEntities="avoid", density=1, radiusMin=7, radiusMax=7})
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=targetPlayer.name, entityName="landmine", existingEntities="avoid", density=0.2, radiusMin=18, radiusMax=18})
```

</p>
</details>