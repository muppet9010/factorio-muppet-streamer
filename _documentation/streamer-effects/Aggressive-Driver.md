The player is locked inside their vehicle and forced to drive forwards for the set duration, they may have control over the steering based on settings. If they don't have a vehicle they can aggressively walk in stead.

This is a Time Duration Effect and so may cut short other Time Duration Effects, for details see the [Time Duration Effects Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Time-Duration-Effects)

![demo](https://github.com/muppet9010/factorio-muppet-streamer/wiki/images/aggressive-driver.gif)



# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds before the effect starts. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly. |
| target | STRING | Mandatory | The player name to target (case sensitive). |
| duration | DECIMAL | Mandatory | How many seconds the effect lasts on the player. |
| control | STRING | Optional | If the driver of the vehicle has control over steering, either: `full` or `random`. `full` allows control over left/right steering, with `random` switching between left, right and straight for short periods. Both option settings include continuous accelerating. Defaults to `random`. |
| commandeerVehicle | BOOLEAN | Optional | When `true` (default) the target player asserts control over vehicles dislodging other players if required, otherwise the target player won't dislodge other players in trying to ge a vehicle to drive. See Notes for more details on the option's settings. Defaults to `true`. |
| teleportDistance | DECIMAL | Optional | The max distance of tiles that the player will be teleported into the nearest suitable vehicle. If not supplied it is treated as `0` distance and so the player isn't teleported. Don't set a massive distance as this may cause UPS lag, i.e. 3000+. See Notes for more details on how options interact. |
| teleportWhitelistTypes | STRING_LIST | Optional | Comma separated list of vehicle entity types that the player will only be teleported too. See Notes for more details on how options interact. These types are case sensitive to the Factorio's in-game vehicle types. Defaults to blank, which is all vehicle types. |
| teleportWhitelistNames | STRING_LIST | Optional | Comma separated list of vehicle entity names that the player will only be teleported too. See Notes for more details on how options interact. These names are case sensitive to the specific Factorio vehicle in-game names. Defaults to blank, which is all specific vehicle names. |
| aggressiveWalking | STRING | Optional | When the player should aggressively walk: `never`, `noVehicle`, `vehicleLost`, `both`. `noVehicle` is when no suitable vehicle is found you will instead walk aggressively. `vehicleLost` is when the aggressive driver effect has started on a vehicle you're in and the vehicle is then destroyed or becomes unsuitable, you then continue the effect when walking. `both` is both `noVehicle` and `vehicleLost`. `never` means aggressive walking never occurs. Defaults to `both` so that the effect is maximised. |
| suppressMessages | BOOLEAN | Optional | If all standard effect messages are suppressed. Defaults to `false`. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

#### Remote Interface

<details><summary>show details</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| standard usage with teleport to a near vehicle | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=30, teleportDistance=100})` |
| only be aggressive if currently driving a vehicle | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=30, commandeerVehicle=false})` |
| only teleport in to a train type | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=30, teleportDistance=100, teleportWhitelistTypes="locomotive,cargo-wagon,fluid-wagon,artillery-wagon"})` |
| don't aggressively walk if no vehicle is found | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=30, teleportDistance=100, aggressiveWalking="never"})` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



#### Factorio Command

<details><summary>show details</summary>
<p>

Command Syntax: `/muppet_streamer_aggressive_driver [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| standard usage with teleport to a near vehicle | `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":30, "teleportDistance":100}` |
| only be aggressive if currently driving a vehicle | `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":30, "commandeerVehicle":false}` |
| only teleport in to a train type | `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":30, "teleportDistance":100, "teleportWhitelistTypes":"locomotive,cargo-wagon,fluid-wagon,artillery-wagon"}` |
| don't aggressively walk if no vehicle is found | `/muppet_streamer_aggressive_driver {"target":"muppet9010", "duration":30, "teleportDistance":100, "aggressiveWalking":"never"}` |

</p>
</details>



# Notes

- This feature uses a custom Factorio permission group when active. This could conflict with other mods/scenarios that also use Factorio permission groups.
- This feature affects all types of cars, tanks, spider vehicles and train carriages. Plus it affects the player's walking by default.
- When in `control` option of `full` you may have to hold a direction key to get it to be applied, rather than just pushing it briefly. It may also take a moment for the key press to be detected. This is due to how the code has to interlaced the player's key presses and force inputs to keep the vehicle moving.
- If the vehicle (non spider-vehicle) comes to a stop during the effect due to hitting something it will automatically start moving in the opposite direction.
- Spider vehicles and aggressive player walking will not reverse if they get stuck on something. They just keep on moving in the direction of travel. This direction may be dictated by the players with `control` option of `full`, or randomly changing with the `control` option of `random`.
- Any vehicle that is lacking fuel is treated as not suitable for the effect. This correctly handles vehicles that don't require fuel. If the `aggressiveWalking` option is set to either `noVehicle` or `both` then the player will be ejected so they can walk. `vehicleLost` if you become in an unsuitable vehicle you will be ejected.
- Any vehicle that is viewed as unusable based on its settings is treated as not suitable. This can be when the vehicle is marked as script-disabled (`active == false`), however, train carriages don't support this. Also if a vehicle is both non operable and not destructible its viewed as being non suitable. This is to provide compatibility with Stasis Weapons mod and that no normal vehicle would ever meet these conditions.
- The `commandeerVehicle` option when enabled (`true`) will always aim to put the player in the driving seat of a vehicle so they have all of the control over the vehicle. If the target player is already in a suitable vehicle they will be swapped to the drivers seat. If they aren't in a suitable vehicle and the `teleportDistance` option is greater than 0, then if there's no driverless suitable vehicles the target player will be moved in to any suitable vehicle's driver seat. Any other players dislodged will be moved to a passenger seat if possible, otherwise ejected from the vehicle. The vehicle selection logic for teleport targets will aim to minimise dislocations of other player, choosing greater teleportation distance first.
- The `commandeerVehicle` option when disabled (`false`) will try to get the player a vehicle to drive, but won't dislodge any other players to achieve it. If the player is already in a suitable vehicle in the passengers seat then the current vehicle will be deemed unsuitable as they aren't driving it. When the `teleportDistance` option is greater than 0, suitable vehicles must have a vacant drivers seat.
- The `teleportDistance` option will de-prioritise non-locomotive train carriages. So it will pick a further away locomotive or car type, rather than a near by cargo-wagon type. It will still aim to minimise player dislocations over target vehicle type priority.
- If either the `teleportWhitelistTypes` or `teleportWhitelistNames` options are populated then vehicle whitelisting as a whole is enabled. In this case the vehicle types and names listed are merged together to make the largest inclusion list possible. If neither are populated then there is no vehicle whitelisting and so all are included. A usage example is to set `teleportWhitelistTypes` to `spider-vehicle` and `teleportWhitelistNames` to `car-mk2`. This would mean the player can be teleported in to either specifically a car-mk2, or any spider-vehicle type vehicle, i.e. a spidertron.
- Trains are a special case in Factorio as every player in the train can have input to drive it. The mod will control the target players inputs and generally these seem to supersede any other train riding player's inputs, however, this isn't guaranteed.
- The player isn't prevented from removing the fuel from their vehicle as this isn't simple to prevent. However, this is such an active countering of the mod's behavior that if the streamer wishes to do this then that's their choice.
- If the vehicle runs out of fuel during the effect it will continue, but just have no impact other than locking the player in the vehicle. This is a very unlikely edge case and the player can obviously add fuel to the vehicle if they have any.
- In an MP server there can be some visual oddities in player character movement if the player tries to move via their input keys. This is due to how Factorio anti-lag works and shows the player's character walking in their input direction before the server/mod over rules the movement direction. In a single player game or when no player input is used everything is perfectly smooth.



# Complicated Usage Examples

#### Just walk aggressively.

You can make yourself just walk aggressively by having the game eject you from any vehicle first. Then have it do no vehicle teleport search so you are guaranteed to be on foot, and just let it walk as the default fall-back.

```
/sc playerName = "muppet9010";
local player = game.get_player(playerName);
if player ~= nil then;
    player.driving = false;
    remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target=playerName, duration=30});
end;
```