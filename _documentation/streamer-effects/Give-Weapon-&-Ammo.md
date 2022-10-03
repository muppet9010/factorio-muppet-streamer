Ensures the target player has a specific weapon and can give ammo and force their selection of the weapon.



#### Command syntax

`/muppet_streamer_give_player_weapon_ammo [OPTIONS TABLE AS JSON STRING]`



#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the items are given. A `0` second delay makes it happen instantly. If not specified it defaults to happening instantly.
- target: STRING - Mandatory: the player name to target (case sensitive).
- weaponType: STRING - Optional: the name of a weapon to ensure the player has. Can be either in their weapon inventory or in their character inventory. If not specified then no specific weapon is given or selected. The weapon name is Factorio's internal name of the gun type and is case sensitive.
- forceWeaponToSlot: BOOLEAN - Optional: if `true` the `weaponType` will be placed/moved to the players equipped weapon inventory. If there's no room a currently equipped weapon will be moved to the character inventory to make room. If `false` then the `weaponType` will be placed in a free weapon slot, otherwise in the character'ss inventory. Defaults to `false`.
- selectWeapon: BOOLEAN - Optional: if `true` the player will have this `weaponType` selected as active if it's equipped in the weapon inventory. If `false` then no weapon change is done. Defaults to `false`, so not forcing the weapon to be selected.
- ammoType: STRING - Optional: the name of the ammo type to be given to the player. The ammo name is Factorio's internal name of the ammo type and is case sensitive. If an `ammoCount` is also set greater than `0` then this `ammoType` and amount will be forced into the weapon if equipped.
- ammoCount: INTEGER - Optional: the quantity of the named ammo to be given. If `0` or not present then no ammo is given.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.



#### Examples

- shotgun and ammo: `/muppet_streamer_give_player_weapon_ammo {"target":"muppet9010", "weaponType":"combat-shotgun", "forceWeaponToSlot":true, "ammoType":"piercing-shotgun-shell", "ammoCount":30}`



#### Notes

- If there isn't room in the character inventory for items they will be dropped on the ground at the players feet.