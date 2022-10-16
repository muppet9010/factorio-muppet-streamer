Teleports other players on the server to near your position. Includes options to make sure they can move to you and bringing vehicles with them.



# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly. |
| target | STRING | Mandatory | The player name to target (case sensitive). |
| arrivalRadius | DECIMAL | Optional | players teleported to the target player will be placed within this max distance. Defaults to `10`. |
| blacklistedPlayerNames | STRING_LIST | Optional | comma separated list of player names who will never be teleported to the target player. These are removed from the available players lists and counts. These names are case sensitive to the player's in-game name. |
| whitelistedPlayerNames | STRING_LIST | Optional | comma separated list of player names who will be the only ones who can be teleported to the target player. If provided these whitelisted players who are online constitute the entire available player list that any other filtering options are applied to. If not provided then all online players not blacklisted are valid players to select from based on filtering criteria. These names are case sensitive to the player's in-game name. |
| callRadius | DECIMAL | Optional | The max distance a player can be from the target and still be teleported to them. If not provided then a player at any distance can be teleported to the target player. If the `sameSurfaceOnly` argument is set to `false` (non default) then the `callRadius` argument is ignored entirely. |
| sameSurfaceOnly | BOOLEAN | Optional | If the players being teleported to the target have to be on the same surface as the target player or not. If `false` then the `callRadius` argument is ignored as it can't logically be applied. Defaults to `true`. |
| sameTeamOnly | BOOLEAN | Optional | If the players being teleported to the target have to be on the same team (force) as the target player or not. Defaults to `true`. |
| callSelection | STRING | Mandatory | The logic to select which available players in the callRadius are teleported, either: `random`, `nearest`. |
| number | INTEGER | Mandatory Special | How many players to call. Either one or both of `number` or `activePercentage` must be supplied. |
| activePercentage | DECIMAL | Mandatory Special | The percentage of currently available players to teleport to help, i.e. `50` for 50%. Will respect blacklistedPlayerNames and whitelistedPlayerName argument values when counting the number of available players. Either one or both of `number` or `activePercentage` must be supplied. |
| suppressMessages | BOOLEAN | Optional | If all standard effect messages are suppressed. Defaults to `false`. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

<details><summary>Remote Interface</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_call_for_help', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| call in the greater of either 3 or 50% of valid players | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_call_for_help', {target="muppet9010", callSelection="random", number=3, activePercentage=50})` |
| call in all the players nearby | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_call_for_help', {target="muppet9010", callRadius=200, callSelection="random", activePercentage=100})` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



<details><summary>Factorio Command</summary>
<p>

Command Syntax: `/muppet_streamer_call_for_help [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| call in the greater of either 3 or 50% of valid players | `/muppet_streamer_call_for_help {"target":"muppet9010", "callSelection":"random", "number":3, "activePercentage":50}` |
| call in all the players nearby | `/muppet_streamer_call_for_help {"target":"muppet9010", "callRadius":200, "callSelection":"random", "activePercentage":100}` |

</p>
</details>



# Notes

- The position that each player is teleported to will be able to path to your position. So no teleporting them on to islands or middle of cliff circles, etc.
- If both `number` and `activePercentage` is supplied the greatest value at the time will be used.
- CallSelection of `nearest` will treat players on other surfaces as being maximum distance away, so they will be the lowest priority. If these players on other surfaces are included or not is controlled by the `sameSurfaceOnly` option.
- A teleported player comes with their vehicle where appropriate (excludes trains). Anyone else in the vehicle will stay in the vehicle and thus be teleported as well. The vehicle will be partially re-angled unless/until a Factorio modding API request is done.
- If the player requesting help is in a vehicle then any teleported players who can will be added in to that vehicle/train before the default of being placed on foot within the arrival radius as normal. Any teleported player that has their own teleportable vehicle (all but trains) will remain with that vehicle post its teleporting.