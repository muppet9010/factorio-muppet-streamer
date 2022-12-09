Sets the ground on fire behind a player forcing them to run.

This is a Time Duration Effect and so may cut short other Time Duration Effects, for details see the [Time Duration Effects Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Time-Duration-Effects)




# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly. |
| target | STRING | Mandatory | The player name to target (case sensitive). |
| duration | DECIMAL | Mandatory | How many seconds the effect lasts on the player. |
| fireGap | INTEGER | Optional | How many ticks between each fire entity. Defaults to `6`, which gives a constant fire line. |
| fireHeadStart | INTEGER | Optional | How many fire entities does the player have a head start on. Defaults to `3`, which forces continuous running with the default value of the `fireGap` option. |
| flameCount | INTEGER | Optional | How many flames each fire entity will have, see Notes for more details. Default is `30` (intended for `fire-flame`), with the conceptual max of `250`. |
| fireType | STRING | Optional | The name of the specific `fire` type entity you want to have. This is the internal name within Factorio. Defaults to the vanilla Factorio fire entity, `fire-flame`. |
| suppressMessages | BOOLEAN | Optional | If all standard effect messages are suppressed. Defaults to `false`. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

#### Remote Interface

<details><summary>show details</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_pants_on_fire', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| continuous fire at players heels | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_pants_on_fire', {target="muppet9010", duration=30})` |
| sporadic worm acid spit (low damage type of fire entity) | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_pants_on_fire', {target="muppet9010", duration=30, fireGap=30, flameCount=3, fireHeadStart=1, fireType="acid-splash-fire-worm-behemoth"})` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



#### Factorio Command

<details><summary>show details</summary>
<p>

Command Syntax: `/muppet_streamer_pants_on_fire [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| continuous fire at players heels | `/muppet_streamer_pants_on_fire {"target":"muppet9010", "duration":30}` |
| sporadic worm acid spit (low damage type of fire entity) | `/muppet_streamer_pants_on_fire {"target":"muppet9010", "duration":30, "fireGap":30, "flameCount":3, "fireHeadStart":1, "fireType":"acid-splash-fire-worm-behemoth"}` |

</p>
</details>



# Notes

- For the duration of the effect if a player enters a vehicle they are instantly ejected. This does not use a Factorio permission group as the effect doesn't require it.
- Fire effects are on a special enemy force so that they will hurt everything on the map, `muppet_streamer_enemy`. This also means that player damage upgrades don't affect these effects.
- Generally the more flames the greater the damage, burn time and larger spread. For vanilla Factorio's `fire-flame` values above `35` have no greater effect, with it taking `20` fire count to set a tree on fire; but at this level the player will have to run right next to a tree to set it on fire. The command defaults to a value of `30` which generally sets trees very close to the player on fire without requiring the player to actually touch them. Value capped at `250`, as the Factorio's maximum of `255` is treated as a value of `0`, but this isn't `0` flames, instead its some per prototype default value. For some details on the oddity of flame counts see the following bug report: https://forums.factorio.com/viewtopic.php?f=7&t=103227
- The spitter and worm spit fire types (spit landed on ground) don't have any sound by default in Factorio. When I looked the only relevant sound is for "acid-burn" and it doesn't sound good when played continuously or en-mass. So left soundless.