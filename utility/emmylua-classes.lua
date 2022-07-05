--[[
    Generic EmmyLua classes. You don't need to require this file anywhere, EmyyLua will discover it within the workspace.
--]]
---@meta
---@diagnostic disable
---
---
---
---@class Id : uint @ id attribute of this thing.
---
---@class UnitNumber : uint @ unit_number of the related entity.
---
---@alias Axis "'x'"|"'y'"
---
---@class PlayerIndex : uint @ Player index attribute.
---
---@class Tick : uint
---
---@class Second : int
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
---@class SurfacePositionString @ A surface and position as a string: "surfaceId_x,y"
---
---@class SurfacePositionObject @ A surface and position data object.
---@field surfaceId uint
---@field position MapPosition
---@field surfacePositionString SurfacePositionString
---
---@alias True boolean
---@alias False boolean
--
--
--
--
--
--[[
Example of doing table string enums.
Declare the main class type and then its options as sub classes of it. Then make the variable as an empty table of the class type, and add its options in to it as their string values.
NOTE: this doesn't protect against nesting the class within itself, but this is an edge case and until EmmyLua supports table enums fully this is unavoidable.

---@class AggressiveDriver_EffectEndStatus
---@class AggressiveDriver_EffectEndStatus.completed : AggressiveDriver_EffectEndStatus
---@class AggressiveDriver_EffectEndStatus.died : AggressiveDriver_EffectEndStatus
---@class AggressiveDriver_EffectEndStatus.invalid : AggressiveDriver_EffectEndStatus
---@type AggressiveDriver_EffectEndStatus
local EffectEndStatus = {}
EffectEndStatus.completed = "completed"
EffectEndStatus.died = "died"
EffectEndStatus.invalid = "invalid"

--]]
--
