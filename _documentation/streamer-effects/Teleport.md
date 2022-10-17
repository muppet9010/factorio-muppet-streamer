Teleports the player to the nearest type of thing. Includes a wide range of target options and backup targets.





# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly. |
| target | STRING | Mandatory | The player name to target (case sensitive). |
| destinationType | STRING/POSITION | Mandatory | The type of teleport to do, either the text string of `random`, `biterNest`, `enemyUnit`, `spawn` or a specific position in the map as a POSITION. For `biterNest` and `enemyUnit` it will be the nearest one found within range. See Argument Data Types for syntax examples of a POSITION. |
| arrivalRadius | DECIMAL | Optional | The max distance the player will be teleported to from the targeted `destinationType`. Defaults to `10`. |
| minDistance | DECIMAL | Optional | The minimum distance to teleport. If not provided then the value of `0` is used. Is ignored for `destinationType` of `spawn`, specific position or `enemyUnit`. |
| maxDistance | DECIMAL | Mandatory Special | The maximum distance to teleport. Is not mandatory and ignored for `destinationType` of `spawn` or a specific position. |
| reachableOnly | BOOLEAN | Optional | If the place you are teleported must be walkable back to where you were. Defaults to `false`. Only applicable for `destinationType` of `random` and `biterNest`. |
| suppressMessages | BOOLEAN | Optional | If all standard effect messages are suppressed. Can be specified within nested `backupTeleportSettings` options, otherwise will be inherited from the parent command. Defaults to `false`. |
| backupTeleportSettings | Teleport details in JSON string | Optional | a backup complete teleport action that will be done if the main/parent command is unsuccessful. Is a complete copy of the main muppet_streamer_teleport options as a JSON object. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

#### Remote Interface

<details><summary>show details</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_teleport', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| nearest walkable biter nest | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_teleport', {target="muppet9010", destinationType="biterNest", maxDistance=1000, reachableOnly=true})` |
| random location | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_teleport', {target="muppet9010", destinationType="random", minDistance=100, maxDistance=500, reachableOnly=true})` |
| specific position | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_teleport', {target="muppet9010", destinationType=[200, 100]})` |
| usage of a backup teleport | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_teleport', {target="muppet9010", destinationType="biterNest", maxDistance=100, reachableOnly=true, backupTeleportSettings= {target="muppet9010", destinationType="random", minDistance=100, maxDistance=500, reachableOnly=true} })` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



#### Factorio Command

<details><summary>show details</summary>
<p>

Command Syntax: `/muppet_streamer_teleport [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| nearest walkable biter nest | `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance":1000, "reachableOnly":true}` |
| random location | `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"random", "minDistance":100, "maxDistance":500, "reachableOnly":true}` |
| specific position | `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":[200, 100]}` |
| usage of a backup teleport | `/muppet_streamer_teleport {"target":"muppet9010", "destinationType":"biterNest", "maxDistance":100, "reachableOnly":true, "backupTeleportSettings": {"target":"muppet9010", "destinationType":"random", "minDistance":100, "maxDistance":500, "reachableOnly":true} }` |

</p>
</details>



# Notes

- `destinationType` of `enemyUnit` and `biterNests` does a search for the nearest opposing force (not friend or cease-fire) unit/nest within the `maxDistance`. If this is a very large area (3000+) this may cause a small UPS spike.
- All teleports will try 10 random locations around their targeted position within the `arrivalRadius` option to try and find a valid spot. If there is no success they will try with a different target 5 times before giving up for the `random` and `biterNest` `destinationType`.
- The `reachableOnly` option will give up on a valid random location for a target if it gets a failed pathfinder request and try another target. For `biterNests` this means it may not end up being the closest biter nest you are teleported to in all cases, based on walkable checks. This may also lead to no valid target being found in some cases, so enable with care and expectations. The `backupTeleportSettings` can provide assistance here.
- The `backupTeleportSettings` is intended for use if you have a more risky main `destinationType`. For example your main `destinationType` may be a biter nest within 100 tiles, with a backup being a random location within 1000 tiles. All options in the `backupTeleportSettings` must be provided just like the main command details. It will be queued to action at the end of the previous teleport attempt failing. You can nest these as many times as required.
- A teleported player comes with their vehicle where appropriate (excludes trains). Anyone else in the vehicle will stay in the vehicle and thus be teleported as well. The vehicle will be partially re-angled unless/until a Factorio modding API request is done.