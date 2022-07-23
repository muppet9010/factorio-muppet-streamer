--[[
    Generic EmmyLua classes. You don't need to require this file anywhere, EmyyLua will discover it within the workspace.
--]]
--
---@meta
---@diagnostic disable
---
---@alias Axis "'x'"|"'y'"
---
---@class CustomInputEvent
---@field player_index uint
---@field input_name string
---@field cursor_position Position
---@field selected_prototype SelectedPrototypeData
---
---@class Sprite
---@field direction_count uint
---@field filename string
---@field width uint
---@field height uint
---@field repeat_count uint
---
---@alias EntityActioner LuaPlayer|LuaEntity @ The placer of a built entity, either player or construction robot. A script will have a nil value.
---
---@class LuaBaseClass @ Used as a fake base class, only supports checking defined attributes.
---@field valid boolean
---
---@alias StringOrNumber string|number
---
---@diagnostic disable-line Alias for nil value. Workaround for EmmyLua not handling nil in multi type lists correctly.
---@class nil
---
---@class SurfacePositionString : string @ A surface and position as a string: "surfaceId_x,y"
---
---@class SurfacePositionObject @ A surface and position data object.
---@field surfaceId uint
---@field position MapPosition
---@field surfacePositionString SurfacePositionString
--
--
--
--
--
--
--
--
--[[




Example of defining a dictionary as containing all the same type of values en-bulk.
With just this you can't valid the dictionary level, just the selected value in it.

---@type {[string]:Color}
local Colors = {}




Often a Factorio returned type will differ from expected due to it having different types for its read and write. There are ongoing works to fix this, but for now just "@as" to fix it with a comment that its a work around and not an intentional "@as".
NOTE: in the below example the * from the end of each line needs to be removed so the comment closes. Its just in this example reference the whole block is already in a comment and so we can't let it close on each line.

local player = game.players[1] -- Is type of LuaPlayer.
local force ---@type LuaForce
force = player.force --[[@as LuaForce @Debugger Sumneko temp fix for different read/write]*]

--]]
--
