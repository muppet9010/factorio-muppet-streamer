Features that a streamer can let chat activate to make their games more dynamic and interactive. These features are more complicated than can be achieved via simple Lua scripting and are highly customisable within the command/remote interface calls.

Mod Portal Entry: https://mods.factorio.com/mod/muppet_streamer

Github Wiki: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Home



Streamer Effects
================

All are done via highly configurable RCON commands as detailed for each feature. Each can also be triggered via a remote interface call from a Lua script, details on this are at the end of this document.



### Schedule Explosive Delivery

Schedule a highly customisable explosive delivery to the player at speed.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Schedule-Explosive-Delivery

![demo](https://github.com/muppet9010/factorio-muppet-streamer/wiki/images/schedule-explosive-delivery.gif)



### Malfunctioning Weapon

A malfunctioning weapon that shoots wildly for short bursts intermittently.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Malfunctioning-Weapon



### Give Weapon & Ammo

Give the player a weapon and ammo, plus options to force it as an active weapon.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Give-Weapon-&-Ammo



### Spawn Around Player

Spawn things around the player with various placement options.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Spawn-Around-Player



### Aggressive Driver

Make the player an aggressive driver who has no or limited control of their vehicle.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Aggressive-Driver



### Call For Help

Call other players for help by teleporting them in near you.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Call-For-Help



### Teleport

Teleport the player to a range of possible target types.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Teleport



### Pants On Fire

Sets the ground on fire behind a player.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Pants-On-Fire



### Player Drop Inventory

Drop a player's inventory on the ground over time.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Player-Drop-Inventory



### Player Inventory Shuffle

Mix up multiple players' inventories between them.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Player-Inventory-Shuffle





Multiplayer Features
==============

Persistent features that can be controlled via mod settings and commands. All default to off.



### Team Member Limit

Can add a team member limit GUI & research for use in Multiplayer by streamers.

Configuration details and examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Team-Member-Limit



Map Helper Features
==============

### Dead Building Ghosts

Start the game with ghosts appearing when buildings die, rather than having to wait for a technology to unlock it (construction robotics).

A mod setting that can make all forces start with ghosts being placed upon entity deaths. Ideal if your chat blows up your base often early game and you freehand build, so don't have a blueprint to just paste down again.

This is the same as if the force had researched the vanilla Factorio construction robot technology to unlock it, by giving entity ghosts a long life time. The mod setting can be safely disabled post technology research if desired without it undoing any researched ghost life timer.



### Game Starting Settings

Game settings that the mod provides an easy way to manage via mod settings.

- Disable introduction message in freeplay.
- Disable rocket win condition in freeplay.
- Set a custom area of the map revealed at game start.



General Usage Notes
================

- Streamer Effect options syntax: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Streamer-Effect-Options-Syntax
- Time Duration Effect explanation: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Time-Duration-Effects
- Remote Interface Usage and Examples: https://github.com/muppet9010/factorio-muppet-streamer/wiki/Remote-Interface



Updating the mod
===============

When updating the mod make sure there aren't any effects active or queued for action (in delay). As the mod is not kept backwards compatible when new features are added or changed. The chance of an effect being active when the mod is being updated seems very low given their usage, but you've been warned.