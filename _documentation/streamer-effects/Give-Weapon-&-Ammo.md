Ensures the target player has a specific weapon and can give ammo and force their selection of the weapon.




# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds before the items are given. A `0` second delay makes it happen instantly. If not specified it defaults to happening instantly. |
| target | STRING | Mandatory | The player name to target (case sensitive). |
| weaponType | STRING | Optional | The name of a weapon to ensure the player has. Can be either in their weapon inventory or in their character inventory. If not specified then no specific weapon is given or selected. The weapon name is Factorio's internal name of the gun type and is case sensitive. |
| forceWeaponToSlot | BOOLEAN | Optional | If `true` the `weaponType` will be placed/moved to the players equipped weapon inventory. If there's no room a currently equipped weapon will be moved to the character inventory to make room. If `false` then the `weaponType` will be placed in a free weapon slot, otherwise in the character'ss inventory. Defaults to `false`. |
| selectWeapon | BOOLEAN | Optional | If `true` the player will have this `weaponType` selected as active if it's equipped in the weapon inventory. If `false` then no weapon change is done. Defaults to `false`, so not forcing the weapon to be selected. |
| ammoType | STRING | Optional | The name of the ammo type to be given to the player. The ammo name is Factorio's internal name of the ammo type and is case sensitive. If an `ammoCount` is also set greater than `0` then this `ammoType` and amount will be forced into the weapon if equipped. |
| ammoCount | INTEGER | Optional | The quantity of the named ammo to be given. If `0` or not present then no ammo is given. |
| suppressMessages | BOOLEAN | Optional | If all standard effect messages are suppressed. Defaults to `false`. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

#### Remote Interface

<details><summary>show details</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_give_player_weapon_ammo', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| shotgun and ammo | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_give_player_weapon_ammo', {target="muppet9010", weaponType="combat-shotgun", forceWeaponToSlot=true, ammoType="piercing-shotgun-shell", ammoCount=30})` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



#### Factorio Command

<details><summary>show details</summary>
<p>

Command Syntax: `/muppet_streamer_give_player_weapon_ammo [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| shotgun and ammo | `/muppet_streamer_give_player_weapon_ammo {"target":"muppet9010", "weaponType":"combat-shotgun", "forceWeaponToSlot":true, "ammoType":"piercing-shotgun-shell", "ammoCount":30}` |

</p>
</details>



# Notes

- If there isn't room in the character inventory for items they will be dropped on the ground at the players feet.