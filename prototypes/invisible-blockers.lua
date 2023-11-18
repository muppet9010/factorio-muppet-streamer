--[[
    Creates a series of different invisible blockers for adhoc use.
    Has types of:
        - all = same layers as a standard building, so collides with everything basically.
        - building = object layer, so blocks all buildings, but units & characters can walk on it. i.e. belts.
        - train = train layer, so only blocks trains.
    They are not selectable in-game by players and have no graphics.
    Make sure to set them as indestructible after creation as this can't be enforced from prototype.
--]]

local PrototypeUtils = require("utility.helper-utils.prototype-utils-data-stage")

---@enum InvisibleBlocker_BlockerType
local INVISIBLE_BLOCKER_BLOCKER_TYPE = {
    all = { "player-layer", "train-layer", "object-layer" } --[[@as CollisionMask]],
    building = { "object-layer" } --[[@as CollisionMask]],
    train = { "train-layer" } --[[@as CollisionMask]]
}

---@param size uint
---@param blockerType string
---@param collisionMask CollisionMask
local function CreateBlocker(size, blockerType, collisionMask)
    ---@type data.SimpleEntityPrototype
    local blockerPrototype = {
        type = "simple-entity",
        name = "muppet_streamer-invisible_blocker-" .. blockerType .. "-" .. size,
        collision_box = { { -size, -size }, { size, size } },
        collision_mask = collisionMask,
        selection_box = { { -size, -size }, { size, size } }, --Only affects editor mode.
        selectable_in_game = false,
        allow_copy_paste = false,
        flags = { "not-on-map", "not-deconstructable", "not-blueprintable", "hidden", "not-flammable" },
        remove_decoratives = "false",
    }

    data:extend({ blockerPrototype })
end

---@param size uint
local function CreateAllBlockerTypesForSize(size)
    for blockerType, collisionMask in pairs(INVISIBLE_BLOCKER_BLOCKER_TYPE) do
        CreateBlocker(size, blockerType, collisionMask)
    end
end

-- Add the required sizes (all square).
for _, size in pairs({ 1, 2, 4, 8, 16 }) do
    CreateAllBlockerTypesForSize(size)
end
