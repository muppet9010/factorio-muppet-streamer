You can trigger all of the features via a remote interface call as well as the standard commands detailed above. This is useful for triggering the features from other mods, from viewer integrations when you need to use a Lua script for some maths, or if you want multiple features to be applied simultaneously.

All features are called with the `muppet_streamer` interface and the `run_command` function name. They each then take 2 arguments:

- CommandName - This is the feature's command name you want to trigger. It's identical to the command name detailed in each feature.
- Options - These are the options you want to pass to the feature. These are identical to the command for the feature. It accepts either a JSON string or a Lua table of the options.

#### Calling the Aggressive Driver feature with options as a JSON string

This option string is identical to the command's, with the string defined by single quotes to avoid needing to escape the double quotes within the JSON text.
If you want to dynamically insert values in to this options JSON string you will have to ensure the correct JSON syntax is maintained. Often this is when using a Lua object (detailed below) is easier.
```/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', '{"target":"muppet9010", "duration":30, "control":"random", "teleportDistance":100}')```

#### Calling the Aggressive Driver feature with options as a Lua object

This option object has the same options as the command, with the syntax being for a Lua object. This makes adding dynamic content in much more natural.
```/sc remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=30, control="random", teleportDistance=100})```

#### Lua script value manipulation

Using remote interface calls instead of RCON commands also allows for any required value manipulation from whichever viewer integration you are using, for example the below is assuming your integration tool is replacing VALUE with a scalable number from your viewer integration and want to limit the result to no greater than 30.
```
/sc local drivingTime = math.min(VALUE, 30)
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_aggressive_driver', {target="muppet9010", duration=drivingTime, control="random", teleportDistance=100})
```

You can also use this to affect multiple players with the same effect at once. You are responsible for ensuring the options you apply to the effect are suitable for this. In the below example we create 3 hostile worms near every player. Note that if multiple players are together then many more worms will appear around them collectively.
```
/sc for _, player in pairs(game.connected_players) do
	remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', {target=player.name, entityName="custom", customEntityName="big-worm-turret", force="muppet_streamer_enemy", radiusMax=15, radiusMin=10, existingEntities="avoid", quantity=3})
end
```

#### Multiple simultaneous feature calling

Running features via remote interface calls within a Lua script and not as a command allows you to trigger multiple features simultaneously. Whereas doing them via RCON command requires them to be done sequentially and thus have a slight delay between them. This can be particularly useful when you want multiple effects to be centered on the same position and the target player may be moving fast (i.e. a train).

An example of this is below, with making a ring of turrets around the player, with a short barrage of grenades outside this. If done via command and the player was moving fast the grenades would likely hit the turrets, with a single Lua script calling both features via remote interface this friendly fire won't occur.
```
/sc
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_spawn_around_player', '{"target":"muppet9010", "entityName":"gunTurretPiercingAmmo", "radiusMax":3, "radiusMin":3, "existingEntities":"avoid", "quantity":5, "ammoCount":10}')
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', '{"explosiveCount":60, "explosiveType":"grenade", "target":"muppet9010", "accuracyRadiusMin":15, "accuracyRadiusMax":15, "salvoSize":20, "salvoDelay":120}')
```
