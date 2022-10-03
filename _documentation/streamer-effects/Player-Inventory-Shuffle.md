Takes all the inventory items from the targeted players, shuffles them and then distributes the items back between those players. Will keep the different types of items in roughly the same number of players inventories as they started, and will spread the quantities each player receives in a random distribution between them (not evenly).



#### Command syntax

`/muppet_streamer_player_inventory_shuffle [OPTIONS TABLE AS JSON STRING]`



#### OPTIONS TABLE AS JSON STRING supports the arguments

- delay: DECIMAL - Optional: how many seconds before the effects start. A `0` second delay makes it happen instantly. If not specified it defaults to happen instantly.
- includedPlayers: STRING_LIST/STRING -  Mandatory Special: Can be one of a few setting values; Either blank(`""`) or not specified for no specific named players. A comma separated list of the player names to include (assuming they are online at the time). Or `[ALL]` to target all online players on the server. Any player names listed are case sensitive to the player's in-game name. Either or both of `includedPlayers` or `includedForces` options must be provided.
- includedForces: STRING_LIST -  Mandatory Special: Can be one of a few setting values; Either blank(`""`) or not specified for no specific force's players. A comma separated list of the force names to include all players from (assuming they are online at the time). Any force names listed are case sensitive to the forces's in-game name. Either or both of `includedPlayers` or `includedForces` options must be provided.
- includeArmor: BOOLEAN - Optional: if the player's equipped (worn) armor is included for shuffling or not. Defaults to `true`.
- extractArmorEquipment: BOOLEAN - Optional: if the player's armor (equipped and in inventory) should have its equipment removed from it and included in the shuffled items. Defaults to `false`.
- includeWeapons: BOOLEAN - Optional: if the player's equipped weapons and ammo are included for shuffling or not. Defaults to `true`.
- includeHandCrafting: BOOLEAN - Optional: if the player's hand crafting should be cancelled and the ingredients shuffled. Defaults to `true`.
- destinationPlayersMinimumVariance: INTEGER - Optional: Set the minimum player count variance to receive an item type compared to the number of source inventories. A value of `0` will allow the same number of players to receive an item as lost it, greater than 0 ensures a wider distribution away from the source number of inventories. Defaults to `1` to ensure some uneven spreading of items. See Notes for logic on item distribution and how this option interacts with other options.
- destinationPlayersVarianceFactor: DECIMAL - Optional: The multiplying factor applied to each item type's number of source players when calculating the number of inventories to receive the item. Used to allow scaling of item recipients for large player counts. A value of `0` will mean there is no scaling of source to destination inventories. Defaults to `0.25`. See Notes for logic on item distribution and how this option interacts with other options.
- recipientItemMinToMaxRatio: INTEGER - Optional: The approximate min/max ratio range of the number of items a destination player will receive compared to others. Defaults to `4`. See Notes for logic on item distribution.
- suppressMessages: BOOLEAN - Optional: if all standard effect messages are suppressed. Defaults to `false`.



#### Examples

- 3 named players: `/muppet_streamer_player_inventory_shuffle {"includedPlayers":"muppet9010,Test_1,Test_2"}`
- all active players: `/muppet_streamer_player_inventory_shuffle {"includedPlayers":"[ALL]"}`
- 2 named players and all players on a specific force: `/muppet_streamer_player_inventory_shuffle {"includedPlayers":"Test_1,Test_2", "includedForces":"player"}`



#### Notes

- There must be 2 or more included players online otherwise the command will do nothing (prints notification message). The players from both include options will be pooled for this.
- Players are given items using Factorio's default item assignment logic. This will mean that equipment will be loaded based on the random order it is received. Any auto trashing will happen after all the items have tried to be distributed, just like if you try to mine an auto trashed item, but your inventory is already full.
- If includeHandCrafting is `true`; Any hand crafting by players will be cancelled and the ingredients added into the shared items. To limit the UPS impact from this, each item stack (icon in crafting queue) that is cancelled will have any ingredients greater than 4 full player inventories worth dropped on the ground rather than included into the shared items. Multiple separate crafts will be individually handled and so have their own limits. This will come into play in the example of a player filling up their inventory with stone and starts crafting stone furnaces, then refills with stone and does this again 4 times sequentially, thus having a huge number of queued crafting items. As these crafts would all go into 1 craft item (icon in the queue).
- All attempts are made to give the items to players, but as a last resort they will be dropped on the ground. In large quantities this can cause a UPS stutter as the core Factorio game engine handles it. This will arise if players have all their different inventories full and have long crafting queues with extra items already used in these crafts.
- This command can be UPS intensive for large player numbers (10/20+), if players have very large modded inventories, or if lots of players are hand crafting lots of things. In these cases the server may pause for a moment or two until the effect completes. This feature has been refactored multiple times for UPS improvements, but ultimately does a lot of API commands and inventory manipulation which is UPS intensive.
- When the option `extractArmorEquipment` is enabled any items extracted from armor equipment grids will lose their electric charge. This is default Factorio behavior during the process of removing equipment from the equipment grid.



#### Distribution Logic

The distribution logic is a bit convoluted, but works as per:

- All targets online have all their inventories taken. Each item type has the number of source players recorded.
- A random number of new players to receive each item type is worked out. This is based on the number of source players for that item type, with a +/- random value applied based on the greatest between; the `destinationPlayersMinimumVariance` option, and the `destinationPlayersVarianceFactor` option multiplied by the number of source inventories to give a scaling player effect. Use of the `destinationPlayersMinimumVariance` option allows a minimum variation of receiving players compared to source inventories to be enforced even when very small player targets are online. The final value of new players for the items to be split across will never be less than 1 or greater than all of the online target players.
- The number of each item each selected player will receive is a random proportion of the total. This is controlled by the `recipientItemMinToMaxRatio` option. This option defines the minimum to maximum ratio between 2 players, i.e. option of `4` means a player receiving the maximum number can receive up to 4 times as many as a player receiving the minimum. This option's implementation isn't quite exact and should be viewed as a rough guide.
- Any items that can't be fitted into the intended destination player will be given to another online targeted player if possible. This will affect the item quantity balance between players and the appearance of how many destination players were selected. If it isn't possible to give the items to any online targeted player then they will be dropped on the floor at the targeted players’ feet. This situation can occur as items are taken from the player's extra inventories like trash, but returned to the player using Factorio default item assignment logic. Player's various inventories can also have filtering on their slots, thus further reducing the room for random items to fit in.