Forces the targeted player to wield a weapon that shoots in random directions. Shoots a full ammo item, then briefly pauses before firing the next full ammo item.

This is a Time Duration Effect and so may cut short other Time Duration Effects, see General Notes for details.



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