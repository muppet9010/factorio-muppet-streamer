--[[
    All direction and orientation concept related utils functions.
]]
--

local DirectionUtils = {}
local MathUtils = require("utility.helper-utils.math-utils")

--- Rotates the directionToRotate by a direction difference from the referenceDirection to the appliedDirection. Useful for rotating entities direction in proportion to a parent's direction change from known direction.
---
--- Should be done locally if called frequently.
---@param directionToRotate defines.direction
---@param referenceDirection defines.direction
---@param appliedDirection defines.direction
DirectionUtils.RotateDirectionByDirection = function(directionToRotate, referenceDirection, appliedDirection)
    local directionDif = appliedDirection - referenceDirection
    local directionValue = directionToRotate + directionDif
    -- Hard coded copy of MathUtils.LoopIntValueWithinRange().
    if directionValue > 7 then
        return -7 + directionValue - 1
    elseif directionValue < 0 then
        return 7 + directionValue + 1
    else
        return directionValue
    end
end

--- Takes an orientation (0-1) and returns the nerest direction (int 0-7).
---
--- Should be done locally if called frequently.
---@param orientation RealOrientation
---@return defines.direction
DirectionUtils.OrientationToNearestDirection = function(orientation)
    local directionValue = MathUtils.RoundNumberToDecimalPlaces(orientation * 8, 0) --[[@as defines.direction]]
    -- Hard coded copy of MathUtils.LoopIntValueWithinRange().
    if directionValue > 7 then
        return -7 + directionValue - 1 --[[@as defines.direction]]
    elseif directionValue < 0 then
        return 7 + directionValue + 1 --[[@as defines.direction]]
    else
        return directionValue
    end
end

--- Takes an orientation (0-1) and returns the nerest cardinal direction (int 0,2,4,6).
---
--- Should be done locally if called frequently.
---@param orientation RealOrientation
---@return defines.direction
DirectionUtils.OrientationToNearestCardinalDirection = function(orientation)
    local directionValue = MathUtils.RoundNumberToDecimalPlaces(orientation * 4, 0) * 2 --[[@as defines.direction]]
    -- Hard coded copy of MathUtils.LoopIntValueWithinRange().
    if directionValue > 6 then
        return -6 + directionValue - 2 --[[@as defines.direction]]
    elseif directionValue < 0 then
        return 6 + directionValue + 2 --[[@as defines.direction]]
    else
        return directionValue
    end
end

--- Takes a direction (int 0-7) and returns an orientation (0-1).
---
--- Should be done locally if called frequently.
---@param directionValue defines.direction
---@return RealOrientation
DirectionUtils.DirectionToOrientation = function(directionValue)
    return directionValue / 8
end

--- A dictionary of directionValue key's (0-7) to their direction name (label's of defines.direction).
DirectionUtils.DirectionValueToName = {
    [0] = "north",
    [1] = "northeast",
    [2] = "east",
    [3] = "southeast",
    [4] = "south",
    [5] = "southwest",
    [6] = "west",
    [7] = "northwest"
}

--- Takes a direction input value and if it's greater/less than the allowed orientation range it loops it back within the range.
---@param directionValue defines.direction @ A number from 0-7.
---@return defines.direction
DirectionUtils.LoopDirectionValue = function(directionValue)
    -- Hard coded copy of MathUtils.LoopIntValueWithinRange().
    if directionValue > 7 then
        return -7 + directionValue - 1 --[[@as defines.direction]]
    elseif directionValue < 0 then
        return 7 + directionValue + 1 --[[@as defines.direction]]
    else
        return directionValue
    end
end

--- Takes an orientation input value and if it's greater/less than the allowed orientation range it loops it back within the range.
---
--- Should be done locally if called frequently.
---@param orientationValue RealOrientation
---@return RealOrientation
DirectionUtils.LoopOrientationValue = function(orientationValue)
    -- Hard coded copy of MathUtils.LoopFloatValueWithinRangeMaxExclusive().
    if orientationValue >= 1 then
        return -1 + orientationValue
    elseif orientationValue < 0 then
        return 1 + orientationValue
    else
        return orientationValue
    end
end

--- Get a direction heading from a start point to an end point that is a on an exact cardinal direction.
---@param startPos MapPosition
---@param endPos MapPosition
---@return defines.direction|-1|-2 @ Returns -1 if the startPos and endPos are the same. Returns -2 if the positions not on a cardinal direction difference.
DirectionUtils.GetCardinalDirectionHeadingToPosition = function(startPos, endPos)
    if startPos.x == endPos.x then
        if startPos.y > endPos.y then
            return defines.direction.north
        elseif startPos.y < endPos.y then
            return defines.direction.south
        else
            return -1
        end
    elseif startPos.y == endPos.y then
        if startPos.x > endPos.x then
            return defines.direction.west
        elseif startPos.x < endPos.x then
            return defines.direction.east
        else
            return -1
        end
    else
        return -2
    end
end

return DirectionUtils
