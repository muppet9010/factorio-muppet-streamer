Forces the targeted player to wield a weapon that shoots in random directions. Shoots a full ammo item, then briefly pauses before firing the next full ammo item.

This is a Time Duration Effect and so may cut short other Time Duration Effects, for details see the [Time Duration Effects Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Time-Duration-Effects)

![demo](https://github.com/muppet9010/factorio-muppet-streamer/wiki/images/malfunctioning-weapon.gif)



# Options

Details on the options syntax is available on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

| Option Name | Data Type | Required | Details |
| --- | --- | --- | --- |
| delay | DECIMAL | Optional | How many seconds the flamethrower and effects are delayed before starting. A `0` second `delay` makes it happen instantly. If not specified it defaults to happening instantly. |
| target | STRING | Mandatory | The player name to target (case sensitive). |
| ammoCount | INTEGER | Mandatory | The quantity of ammo items to be put in the weapon and shot. |
| reloadTime | DECIMAL | Optional | How many seconds to wait between each ammo magazine being fired. Defaults to `3` to give a noticeable gap. |
| weaponType | STRING | Optional | The name of the specific weapon you want to use. This is the internal name within Factorio. Defaults to the vanilla Factorio flamethrower weapon, `flamethrower`. |
| ammoType | STRING | Optional | The name of the specific ammo you want to use. This is the internal name within Factorio. Defaults to the vanilla Factorio flamethrower ammo, `flamethrower-ammo`. |
| suppressMessages | BOOLEAN | Optional | If all standard effect messages are suppressed. Defaults to `false`. |



# Syntax and Usage Examples

Note: all examples target the player named `muppet9010`, you will need to replace this with your own player's name.

#### Remote Interface

<details><summary>show details</summary>
<p>

Remote Interface Syntax: `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_malfunctioning_weapon', [OPTIONS TABLE])`

The options must be provided as a Lua table.

Examples:

| Example | Code |
| --- | --- |
| standard usage (leaky flamethrower) | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_malfunctioning_weapon', {target="muppet9010", ammoCount=5})` |
| shotgun | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_malfunctioning_weapon', {target="muppet9010", ammoCount=3, weaponType="shotgun", ammoType="shotgun-shell"})` |
| custom weapon (Cryogun from Space Exploration mod) | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_malfunctioning_weapon', {target="muppet9010", ammoCount=5, weaponType="se-cryogun", ammoType="se-cryogun-ammo"})` |
| atomic rocket launch | `/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_malfunctioning_weapon', {target="muppet9010", ammoCount=1, weaponType="rocket-launcher", ammoType="atomic-bomb"})` |


Further details and more advanced usage of using Remote Interfaces can be found here on the [Streamer Effect Options Syntax Wiki page](https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax).

</p>
</details>



#### Factorio Command

<details><summary>show details</summary>
<p>

Command Syntax: `/muppet_streamer_malfunctioning_weapon [OPTIONS TABLE AS JSON STRING]`

The effect's options must be provided as a JSON string of a table.

Examples:

| Example | Code |
| --- | --- |
| standard usage (leaky flamethrower) | `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":5}` |
| shotgun | `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":3, "weaponType":"shotgun", "ammoType":"shotgun-shell"}` |
| custom weapon (Cryogun from Space Exploration mod) | `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":5, "weaponType":"se-cryogun", "ammoType":"se-cryogun-ammo"}` |
| atomic rocket launch | `/muppet_streamer_malfunctioning_weapon {"target":"muppet9010", "ammoCount":1, "weaponType":"rocket-launcher", "ammoType":"atomic-bomb"}` |

</p>
</details>



# Notes

- This feature uses a custom Factorio permission group when active. This could conflict with other mods/scenarios that also use Factorio permission groups.
- While activated the player will be kicked out of any vehicle they are in and prevented from entering one. As no one likes to be in an enclosed space with weapons firing.
- The player will be given the weapon and ammo needed for the effect if needed. If given these will be reclaimed at the end of the effect as appropriate. The player’s original gun and weapon selection will be returned to them including any slot filters.
- While activated the player will lose control over their weapon's targeting and firing behavior.
- While activated the player can not change the active gun via the switch to the next weapon key.
- The player isn't prevented from removing the gun/ammo from their equipment slots as this isn't simple to prevent. However, this is such an active countering of the mod's behavior that if the streamer wishes to do this then that's their choice.
- The weapon is yours and so any of your force's damage upgrades will affect it.
- The weapon's `ammoType` will need to be able to either target the ground or be shot in a direction. Ammo types that need to be fired at a specific enemy target won't work.
- Stream type weapons (i.e. flamethrower) will slowly wonder around in range and direction. Projectile or beam type weapons will jump in their direction far quicker as they generally don't have the concept of target range in the same way.