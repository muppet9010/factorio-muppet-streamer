Schedule a highly customisable explosive delivery to the player at speed. The projectiles are created off the target player's screen and so take a few seconds to fly to their destinations.

![demo](https://github.com/muppet9010/factorio-muppet-streamer/wiki/images/schedule-explosive-delivery.gif)



# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds the effect will be delayed for before looking for the targets current position and creating the explosive. A `0` second `delay` makes it happen instantly. If not specified it defaults to happen instantly. This doesn't include the explosives in-flight time. |
| explosiveCount | INTEGER | Mandatory | The quantity of explosives to be delivered. |
| explosiveType | STRING | Mandatory | The type of explosive, can be any one of the vanilla Factorio built-in options: `grenade`, `clusterGrenade`, `slowdownCapsule`, `poisonCapsule`, `artilleryShell`, `explosiveRocket`, `atomicRocket`, `smallSpit`, `mediumSpit`, `largeSpit`, or `custom`. Is case sensitive. `custom` requires the additional options `customExplosiveType` and `customExplosiveSpeed` options to be set/considered. |
| customExplosiveType | STRING | Mandatory Special | Only required/supported if `explosiveType` is set to `custom`. Sets the name of the explosive to be used. Must be either a `projectile`, `artillery-projectile` or `stream` entity type. |
| customExplosiveSpeed | DECIMAL | Mandatory Special | Only required/supported if `explosiveType` is set to `custom`. Sets the speed of the custom explosive type in the air. Only applies to `projectile` and `artillery-projectile` entity types. Default is `0.3` if not specified. See effect Notes for the values of built-in options. |
| target | STRING | Mandatory | A player name to target the position and surface of (case sensitive). |
| targetPosition | POSITION | Optional | A specific position to target on the target player's surface, rather than the player's current position. See Argument Data Types for syntax examples of a POSITION. |
| targetOffset | POSITION | Optional | An offset position that's applied to the `target`/`targetPosition` value. By default there is no offset set. See Argument Data Types for syntax examples of a POSITION. |
| accuracyRadiusMin | DECIMAL | Optional | The minimum distance from the target that each explosive can be randomly targeted within. If not specified defaults to `0`. |
| accuracyRadiusMax | DECIMAL | Optional | The maximum distance from the target that each explosive can be randomly targeted within. If not specified defaults to `0`. |
| salvoSize | INTEGER | Optional | Breaks the incoming `explosiveCount` into salvos of this size. Useful if you are using very large numbers of nukes to prevent UPS issues. Defaults to all explosives being in a single salvo. |
| salvoDelay | INTEGER | Optional | Use when `salvoSize` is set. Sets the delay between each salvo deliveries in game ticks (60 ticks = 1 second). |
| salvoFollowPlayer | BOOLEAN | Optional | If each salvo re-targets on the player's current position and surface (`true`) or continues to target the initial position (`false`). Defaults to `false`, so any secondary salvo hits the `target` players initial position. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

#### Remote Interface

<details><summary>show details</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| grenades around player | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', {explosiveCount=20, explosiveType="grenade", target="muppet9010", accuracyRadiusMin=7, accuracyRadiusMax=10})` |
| atomic rocket | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', {explosiveCount=1, explosiveType="atomicRocket", target="muppet9010", accuracyRadiusMax=50})` |
| offset artillery | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', {explosiveCount=1, explosiveType="artilleryShell", target="muppet9010", targetOffset=[10, 10]})` |
| poison capsules in large area around spawn | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', {explosiveCount=200, explosiveType="poisonCapsule", target="muppet9010", targetPosition={"x"=0,"y"=0}, accuracyRadiusMax=200})` |
| large count of explosive rockets using salvo and delay | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', {delay=5, explosiveCount=30, explosiveType="explosiveRocket", target="muppet9010", accuracyRadiusMax=30, salvoSize=10, salvoDelay=300, salvoFollowPlayer=true})` |
| custom type | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', {explosiveCount=5, explosiveType="custom", target="muppet9010", customExplosiveType="cannon-projectile", customExplosiveSpeed=1, accuracyRadiusMax=10})` |

Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



#### Factorio Command

<details><summary>show details</summary>
<p>

Command Syntax: `/muppet_streamer_schedule_explosive_delivery [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| grenades around player | `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":20, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":7, "accuracyRadiusMax":10}` |
| atomic rocket | `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":1, "explosiveType":"atomicRocket", "target":"muppet9010", "accuracyRadiusMax":50}` |
| offset artillery | `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":1, "explosiveType":"artilleryShell", "target":"muppet9010", "targetOffset":[10, 10]}` |
| poison capsules in large area around spawn | `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":200, "explosiveType":"poisonCapsule", "target":"muppet9010", "targetPosition":{"x":0,"y":0}, "accuracyRadiusMax":200}` |
| large count of explosive rockets using salvo and delay | `/muppet_streamer_schedule_explosive_delivery {"delay":5, "explosiveCount":30, "explosiveType":"explosiveRocket", "target":"muppet9010", "accuracyRadiusMax":30, "salvoSize":10, "salvoDelay":300, "salvoFollowPlayer":true}` |
| custom type | `/muppet_streamer_schedule_explosive_delivery {"explosiveCount":5, "explosiveType":"custom", "target":"muppet9010", "customExplosiveType":"cannon-projectile", "customExplosiveSpeed":1, "accuracyRadiusMax":10}` |

</p>
</details>



# Notes

- Explosives will fly in from off screen to random locations around the target player within the accuracy options. They may take a few seconds to complete their delivery as they fly in using their native throwing/shooting/spitting speed. Any explosive that collides with things (i.e. tank cannon shells) may complete their damage before they reach the player.
- Weapons are on a special enemy force so that they will hurt everything on the map, `muppet_streamer_enemy`. This also means that player damage upgrades don't affect these effects.
- Default projectile speeds for the built-in options: the thrown grenade & capsule, plus rocket options has a value of `0.3`. The artillery shell option has a value of `1`. Projectiles can have maximum speeds defined in their game prototypes that will constrain this effects outcomes.