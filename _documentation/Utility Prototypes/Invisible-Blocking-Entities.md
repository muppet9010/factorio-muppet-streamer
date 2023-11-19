Invisible blocking entities that can be used to block different entity types.

Useful for blocking a special area from being built on, or units being able to be created/moving there for example.

Default features:
- Not selectable in-game by players. In Editor mode (Entities tab) you can then select them for removing them. Enable show the collision boxes (Factorio debug menu) to see where the have been placed.
- Have no visual graphics or map icon.
- Not blueprintable, deconstructable, or minable.
- Can't have stickers or flames attach to them.



# Variations

- Sizes: They come as a square shape in tile sizes: 1, 2, 4, 8 & 16.
- Blocking Types: There are different variations allowing selective blocking:
    - all = same layers as a standard building, so collides with everything basically.
    - building = object layer, so blocks all buildings, but units & characters can walk on it. i.e. like belts.
    - train = train layer, so only blocks train carriages, not rail.



# Usage

Create via Lua script as a named prototype.
- Prototype name format: `muppet_streamer-invisible_blocker-[BLOCKING_TYPE]-[SIZE]`.
- e.g. `muppet_streamer-invisible_blocker-all-4`

Must be made indestructible (`destructible = false`) after creation via a Lua script, as this can't be set in the prototype definition unfortunately.

Example script to create a 4x4 Blocking All at a given location:
```
/sc
local placementPosition = {x=10, y=12};
local blockerEntity = game.surfaces["nauvis"].create_entity({name="muppet_streamer-invisible_blocker-all-4", position=placementPosition, force = game.forces["player"]});
blockerEntity.destructible = false;
```



# Notes

- They are designed around and use vanilla Factorio collision layers. So they should be compatible with most mods as almost all mods respect the vanilla Factorio collision layers.