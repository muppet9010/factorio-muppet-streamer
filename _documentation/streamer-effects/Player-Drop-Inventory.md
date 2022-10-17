Make the player drop their inventory on the ground over time. Includes many options to control types of items dropped and very flexible drop rate options.

This is a Time Duration Effect and so may cut short other Time Duration Effects, for details see the [Time Duration Effects Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Time-Duration-Effects)






# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds before the effects start. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly. |
| target | STRING | Mandatory | The player name to target (case sensitive). |
| quantityType | STRING | Mandatory | The way quantity value is interpreted to calculate the number of items to drop per drop action, either `constant`, `startingPercentage` or `realtimePercentage`. The `constant` setting uses the `quantityValue` option as a static number of items. The `startingPercentage` setting means a percentage of the item count at the start of the effect is dropped from the player every drop action. The `realtimePercentage` setting means that every time a drop action occurs the player's current inventory item count is used to calculate how many items to drop this action. |
| quantityValue | INTEGER | Mandatory | The number of items to drop. When quantityType is `startingPercentage`, or `realtimePercentage` this number is used as the percentage (0-100). |
| dropOnBelts | BOOLEAN | Optional | If the dropped items should be placed on belts or not. Defaults to `false`. |
| markForDeconstruction | BOOLEAN | Optional | If the dropped items are marked for deconstruction by the owning player's force. Defaults to `false`. |
| dropAsLoot | BOOLEAN | Optional | If the dropped items are marked as loot and thus any player who goes near them automatically picks them up. Defaults to `false`. |
| gap | DECIMAL | Mandatory | How many seconds between each drop action. If `occurrences` is set to `1` then this `gap` option has no impact, but still must be set to `1` or greater. |
| occurrences | INTEGER | Mandatory | How many times the drop actions are done. Must be a value of `1` or greater. |
| includeArmor | BOOLEAN | Optional | If the player's equipped (worn) armor is included for dropping or not. Defaults to `true`. |
| includeWeapons | BOOLEAN | Optional | If the player's equipped weapons and ammo are included for dropping or not. Defaults to `true`. |
| density | DECIMAL | Optional | Specifies the approximate density of the dropped items at the center of their spill area. Value in range of `10` (dense) to `0` (extremely spread out), see Notes for full details. Defaults to `10`. |
| suppressMessages | BOOLEAN | Optional | If all standard effect messages are suppressed. Defaults to `false`. |




# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

#### Remote Interface

<details><summary>show details</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_player_drop_inventory', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| dropping 10% of starting inventory items 5 times | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_player_drop_inventory', {target="muppet9010", quantityType="startingPercentage", quantityValue=10, gap=2, occurrences=5})` |
| 10 drops of 5 items a time, allows dropping items on belts | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_player_drop_inventory', {target="muppet9010", quantityType="constant", quantityValue=5, gap=2, occurrences=10, dropOnBelts=true})` |
| dropping all of inventory in 1 go | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_player_drop_inventory', {target="muppet9010", quantityType="startingPercentage", quantityValue=100, gap=1, occurrences=1})` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



#### Factorio Command

<details><summary>show details</summary>
<p>

Command Syntax: `/muppet_streamer_player_drop_inventory [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| dropping 10% of starting inventory items 5 times | `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"startingPercentage", "quantityValue":10, "gap":2, "occurrences":5}` |
| 10 drops of 5 items a time, allows dropping items on belts | `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"constant", "quantityValue":5, "gap":2, "occurrences":10, "dropOnBelts":true}` |
| dropping all of inventory in 1 go | `/muppet_streamer_player_drop_inventory {"target":"muppet9010", "quantityType":"startingPercentage", "quantityValue":100, "gap":1, "occurrences":1}` |

</p>
</details>



# Notes

- Will drop individually randomised items across all of the included inventories and item stack types the player has. It will drop items of the same type from the first stack in the inventory, rather than from across multiple item stacks of the same type; this should almost never have any impact on the outcome.
- Dropping very large quantities of items in crowded areas at one time may cause Factorio to use increased UPS as it tries to find placement locations for all the items.
- For percentage based quantity values it will drop a minimum of 1 item per cycle. So that very low values/inventory sizes avoid not dropping anything.
- If the player doesn't have any items to drop for any given drop action then while that drop occurrence is complete, the effect continues until all occurrences have occurred at their set gaps. The effect does not not stop unless the player dies or all occurrences have been completed.
- The items are dropped around the player approximately 2 tiles away from them in a circle. With the density decreasing as the items move away from the player. The spread is ideal in open areas, with tight areas seeming more densely placed due to the limited placement options. The items placement density won't be exactly the same between very low and high item drop quantities, but should be approximately similar considering the randomisation in the placement logic. Any square edges to dense areas of items on the ground is caused by entities blocking their placement.
- The `density` option will define how dense the items will be at their center. The rate the density of items decreases at is related to the starting density, with higher central `density` values getting sparser quicker (mountain shape), and lower starting `density` values becoming sparse over a larger distance (frisbee shape). All items are placed in the same total area regardless of `density` option, but the number of items towards the edge of this area will vary significantly. Changes to the `density` value around the max density (`10`) will appear to have a greater impact on distribution than changes at the sparse (`0`) end of the range. This may be real from the Gaussian algorithm or just human perception.
- Maximum `density` is configured to avoid excessive overlapping of the items when randomly placed on the ground. This is why it doesn't place the full 9 items per tile. Overlapping items cause the Factorio game engine to work harder to find a placement location and thus can have higher UPS usage.
- Armor is dropped last if it's included. When the armor is dropped this may reduce players inventory size, and thus may spill items on the ground using default Factorio logic. The armor is dropped last to try and avoid/reduce this risk, but it is unavoidable.