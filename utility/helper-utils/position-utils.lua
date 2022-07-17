--[[
    All position concept related utils functions, including bounding boxes.
]]
--

local PositionUtils = {}
local MathUtils = require("utility.helper-utils.math-utils")
local math_rad, math_cos, math_sin, math_floor, math_sqrt, math_abs, math_random = math.rad, math.cos, math.sin, math.floor, math.sqrt, math.abs, math.random

---@param pos1 MapPosition
---@param pos2 MapPosition
---@return boolean
PositionUtils.ArePositionsTheSame = function(pos1, pos2)
    if (pos1.x or pos1[1]) == (pos2.x or pos2[1]) and (pos1.y or pos1[2]) == (pos2.y or pos2[2]) then
        return true
    else
        return false
    end
end

---@param thing table
---@return boolean
PositionUtils.IsTableValidPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return true
    else
        return false
    end
end

-- Returns the table as an x|y table rather than an [1]|[2] table.
---@param thing table
---@return MapPosition|nil position? @ x,y key'd table or nil if not a valid MapPosition.
PositionUtils.TableToProperPosition = function(thing)
    if thing.x ~= nil and thing.y ~= nil then
        if type(thing.x) == "number" and type(thing.y) == "number" then
            return thing
        else
            return nil
        end
    end
    if #thing ~= 2 then
        return nil
    end
    if type(thing[1]) == "number" and type(thing[2]) == "number" then
        return {x = thing[1], y = thing[2]}
    else
        return nil
    end
end

---@param thing table
---@return boolean
PositionUtils.IsTableValidBoundingBox = function(thing)
    if thing.left_top ~= nil and thing.right_bottom ~= nil then
        if PositionUtils.IsTableValidPosition(thing.left_top) and PositionUtils.IsTableValidPosition(thing.right_bottom) then
            return true
        else
            return false
        end
    end
    if #thing ~= 2 then
        return false
    end
    if PositionUtils.IsTableValidPosition(thing[1]) and PositionUtils.IsTableValidPosition(thing[2]) then
        return true
    else
        return false
    end
end

-- Returns a clean bounding box object or nil if invalid.
---@param thing table
---@return BoundingBox|nil
PositionUtils.TableToProperBoundingBox = function(thing)
    if not PositionUtils.IsTableValidBoundingBox(thing) then
        return nil
    elseif thing.left_top ~= nil and thing.right_bottom ~= nil then
        return {left_top = PositionUtils.TableToProperPosition(thing.left_top), right_bottom = PositionUtils.TableToProperPosition(thing.right_bottom)}
    else
        return {left_top = PositionUtils.TableToProperPosition(thing[1]), right_bottom = PositionUtils.TableToProperPosition(thing[2])}
    end
end

--- Return the positioned bounding box (collision box) of a bounding box applied to a position. Or nil if invalid data.
---@param centrePos MapPosition
---@param boundingBox BoundingBox
---@param orientation RealOrientation
---@return BoundingBox|nil
PositionUtils.ApplyBoundingBoxToPosition = function(centrePos, boundingBox, orientation)
    local checked_centrePos = PositionUtils.TableToProperPosition(centrePos)
    if checked_centrePos == nil then
        return nil
    end
    local checked_boundingBox = PositionUtils.TableToProperBoundingBox(boundingBox)
    if checked_boundingBox == nil then
        return nil
    end
    if orientation == nil or orientation == 0 or orientation == 1 then
        return {
            left_top = {
                x = checked_centrePos.x + checked_boundingBox.left_top.x,
                y = checked_centrePos.y + checked_boundingBox.left_top.y
            },
            right_bottom = {
                x = checked_centrePos.x + checked_boundingBox.right_bottom.x,
                y = checked_centrePos.y + checked_boundingBox.right_bottom.y
            }
        }
    elseif orientation == 0.25 or orientation == 0.5 or orientation == 0.75 then
        local rotatedPoint1 = PositionUtils.RotatePositionAround0(orientation, checked_boundingBox.left_top)
        local rotatedPoint2 = PositionUtils.RotatePositionAround0(orientation, checked_boundingBox.right_bottom)
        local rotatedBoundingBox = PositionUtils.CalculateBoundingBoxFrom2Points(rotatedPoint1, rotatedPoint2)
        return {
            left_top = {
                x = checked_centrePos.x + rotatedBoundingBox.left_top.x,
                y = checked_centrePos.y + rotatedBoundingBox.left_top.y
            },
            right_bottom = {
                x = checked_centrePos.x + rotatedBoundingBox.right_bottom.x,
                y = checked_centrePos.y + rotatedBoundingBox.right_bottom.y
            }
        }
    end
end

---@param pos MapPosition
---@param numDecimalPlaces uint
---@return MapPosition
PositionUtils.RoundPosition = function(pos, numDecimalPlaces)
    return {x = MathUtils.RoundNumberToDecimalPlaces(pos.x, numDecimalPlaces), y = MathUtils.RoundNumberToDecimalPlaces(pos.y, numDecimalPlaces)}
end

---@param pos MapPosition
---@return ChunkPosition
PositionUtils.GetChunkPositionForTilePosition = function(pos)
    return {x = math_floor(pos.x / 32), y = math_floor(pos.y / 32)}
end

---@param chunkPos ChunkPosition
---@return MapPosition
PositionUtils.GetLeftTopTilePositionForChunkPosition = function(chunkPos)
    return {x = chunkPos.x * 32, y = chunkPos.y * 32}
end

--- Rotates an offset around position of {0,0}.
---@param orientation RealOrientation
---@param position MapPosition
---@return MapPosition
PositionUtils.RotatePositionAround0 = function(orientation, position)
    -- Handle simple cardinal direction rotations.
    if orientation == 0 then
        return position
    elseif orientation == 0.25 then
        return {
            x = -position.y,
            y = position.x
        }
    elseif orientation == 0.5 then
        return {
            x = -position.x,
            y = -position.y
        }
    elseif orientation == 0.75 then
        return {
            x = position.y,
            y = -position.x
        }
    end

    -- Handle any non cardinal direction orientation.
    local rad = math_rad(orientation * 360)
    local cosValue = math_cos(rad)
    local sinValue = math_sin(rad)
    local rotatedX = (position.x * cosValue) - (position.y * sinValue)
    local rotatedY = (position.x * sinValue) + (position.y * cosValue)
    return {x = rotatedX, y = rotatedY}
end

--- Rotates an offset around a position. Combines PositionUtils.RotatePositionAround0() and PositionUtils.ApplyOffsetToPosition() to save UPS.
---@param orientation RealOrientation
---@param offset MapPosition @ the position to be rotated by the orientation.
---@param position MapPosition @ the position the rotated offset is applied to.
---@return MapPosition
PositionUtils.RotateOffsetAroundPosition = function(orientation, offset, position)
    -- Handle simple cardinal direction rotations.
    if orientation == 0 then
        return {
            x = position.x + offset.x,
            y = position.y + offset.y
        }
    elseif orientation == 0.25 then
        return {
            x = position.x - offset.y,
            y = position.y + offset.x
        }
    elseif orientation == 0.5 then
        return {
            x = position.x - offset.x,
            y = position.y - offset.y
        }
    elseif orientation == 0.75 then
        return {
            x = position.x + offset.y,
            y = position.y - offset.x
        }
    end

    -- Handle any non cardinal direction orientation.
    local rad = math_rad(orientation * 360)
    local cosValue = math_cos(rad)
    local sinValue = math_sin(rad)
    local rotatedX = (position.x * cosValue) - (position.y * sinValue)
    local rotatedY = (position.x * sinValue) + (position.y * cosValue)
    return {x = position.x + rotatedX, y = position.y + rotatedY}
end

---@param point1 MapPosition
---@param point2 MapPosition
---@return BoundingBox
PositionUtils.CalculateBoundingBoxFrom2Points = function(point1, point2)
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    if minX == nil or point1.x < minX then
        minX = point1.x
    end
    if maxX == nil or point1.x > maxX then
        maxX = point1.x
    end
    if minY == nil or point1.y < minY then
        minY = point1.y
    end
    if maxY == nil or point1.y > maxY then
        maxY = point1.y
    end
    if minX == nil or point2.x < minX then
        minX = point2.x
    end
    if maxX == nil or point2.x > maxX then
        maxX = point2.x
    end
    if minY == nil or point2.y < minY then
        minY = point2.y
    end
    if maxY == nil or point2.y > maxY then
        maxY = point2.y
    end
    return {left_top = {x = minX, y = minY}, right_bottom = {x = maxX, y = maxY}}
end

---@param listOfBoundingBoxs BoundingBox[]
---@return BoundingBox
PositionUtils.CalculateBoundingBoxToIncludeAllBoundingBoxs = function(listOfBoundingBoxs)
    local minX, maxX, minY, maxY = nil, nil, nil, nil
    for _, boundingBox in pairs(listOfBoundingBoxs) do
        for _, point in pairs({boundingBox.left_top, boundingBox.right_bottom}) do
            if minX == nil or point.x < minX then
                minX = point.x
            end
            if maxX == nil or point.x > maxX then
                maxX = point.x
            end
            if minY == nil or point.y < minY then
                minY = point.y
            end
            if maxY == nil or point.y > maxY then
                maxY = point.y
            end
        end
    end
    return {left_top = {x = minX, y = minY}, right_bottom = {x = maxX, y = maxY}}
end

-- Applies an offset to a position. If you are rotating the offset first consider using PositionUtils.RotateOffsetAroundPosition() as lower UPS than the 2 seperate function calls.
---@param position MapPosition
---@param offset MapPosition
---@return MapPosition
PositionUtils.ApplyOffsetToPosition = function(position, offset)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y
    }
end

--- Return a copy of the BoundingBox with the growth values added to both sides.
---@param boundingBox BoundingBox
---@param growthX double
---@param growthY double
---@return BoundingBox
PositionUtils.GrowBoundingBox = function(boundingBox, growthX, growthY)
    return {
        left_top = {
            x = boundingBox.left_top.x - growthX,
            y = boundingBox.left_top.y - growthY
        },
        right_bottom = {
            x = boundingBox.right_bottom.x + growthX,
            y = boundingBox.right_bottom.y + growthY
        }
    }
end

--- Checks if a collision box is populated with valid data.
---@param boundingBox BoundingBox
---@return boolean
PositionUtils.IsBoundingBoxPopulated = function(boundingBox)
    if boundingBox == nil then
        return false
    end
    if boundingBox.left_top.x ~= 0 and boundingBox.left_top.y ~= 0 and boundingBox.right_bottom.x ~= 0 and boundingBox.right_bottom.y ~= 0 then
        return true
    else
        return false
    end
end

--- Generate a positioned bounding box (collision box) for a position and an equal distance on each side.
---@param position MapPosition
---@param range double
---@return BoundingBox
PositionUtils.CalculateBoundingBoxFromPositionAndRange = function(position, range)
    return {
        left_top = {
            x = position.x - range,
            y = position.y - range
        },
        right_bottom = {
            x = position.x + range,
            y = position.y + range
        }
    }
end

--- Calculate a list of tile positions that are within a bounding box.
---@param positionedBoundingBox BoundingBox
---@return MapPosition[]
PositionUtils.CalculateTilesUnderPositionedBoundingBox = function(positionedBoundingBox)
    local tiles = {}
    for x = positionedBoundingBox.left_top.x, positionedBoundingBox.right_bottom.x do
        for y = positionedBoundingBox.left_top.y, positionedBoundingBox.right_bottom.y do
            table.insert(tiles, {x = math_floor(x), y = math_floor(y)})
        end
    end
    return tiles
end

-- Gets the distance between the 2 positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number @ is inheriently a positive number.
PositionUtils.GetDistance = function(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math_sqrt(dx * dx + dy * dy)
end

-- Gets the distance between a single axis of 2 positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@param axis Axis
---@return number @ is inheriently a positive number.
PositionUtils.GetDistanceSingleAxis = function(pos1, pos2, axis)
    return math_abs(pos1[axis] - pos2[axis])
end

-- Returns the offset for the first position in relation to the second position.
---@param newPosition MapPosition
---@param basePosition MapPosition
---@return MapPosition
PositionUtils.GetOffsetForPositionFromPosition = function(newPosition, basePosition)
    return {x = newPosition.x - basePosition.x, y = newPosition.y - basePosition.y}
end

---@param position MapPosition
---@param boundingBox BoundingBox
---@param safeTiling? boolean|nil @ If enabled the boundingbox can be tiled without risk of an entity on the border being in 2 result sets, i.e. for use on each chunk.
---@return boolean
PositionUtils.IsPositionInBoundingBox = function(position, boundingBox, safeTiling)
    if safeTiling == nil or not safeTiling then
        if position.x >= boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y >= boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    else
        if position.x > boundingBox.left_top.x and position.x <= boundingBox.right_bottom.x and position.y > boundingBox.left_top.y and position.y <= boundingBox.right_bottom.y then
            return true
        else
            return false
        end
    end
end

--- Get a random location within a radius (circle) of a target.
---@param centrePos MapPosition
---@param maxRadius double
---@param minRadius? double|nil @ Defaults to 0.
---@return MapPosition
PositionUtils.RandomLocationInRadius = function(centrePos, maxRadius, minRadius)
    local angle = math_random(0, 360)
    minRadius = minRadius or 0
    local radiusMultiplier = maxRadius - minRadius
    local distance = minRadius + (math_random() * radiusMultiplier)
    return PositionUtils.GetPositionForAngledDistance(centrePos, distance, angle)
end

--- Gets a map position for an angled distance from a position.
---@param startingPos MapPosition
---@param distance double
---@param angle double
---@return MapPosition
PositionUtils.GetPositionForAngledDistance = function(startingPos, distance, angle)
    if angle < 0 then
        angle = 360 + angle
    end
    local angleRad = math_rad(angle)
    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

---@param startingPos MapPosition
---@param distance number
---@param orientation RealOrientation
---@return MapPosition
PositionUtils.GetPositionForOrientationDistance = function(startingPos, distance, orientation)
    local angle = orientation * 360
    if angle < 0 then
        angle = 360 + angle
    end
    local angleRad = math_rad(angle)
    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

--- Gets the position for a distance along a line from a starting positon towards a target position.
---@param startingPos MapPosition
---@param targetPos MapPosition
---@param distance number
---@return MapPosition
PositionUtils.GetPositionForDistanceBetween2Points = function(startingPos, targetPos, distance)
    local angleRad = -math.atan2(startingPos.y - targetPos.y, targetPos.x - startingPos.x) + 1.5707963267949 -- Static value is to re-align it from east to north as 0 value.
    -- equivilent to: math.rad(math.deg(-math.atan2(startingPos.y - targetPos.y, targetPos.x - startingPos.x)) + 90)

    local newPos = {
        x = (distance * math_sin(angleRad)) + startingPos.x,
        y = (distance * -math_cos(angleRad)) + startingPos.y
    }
    return newPos
end

--- Find where a line cross a circle at a set radius from a 0 position.
---@param radius double
---@param slope double @ the x value per 1 Y. so 1 is a 45 degree SW to NE line. 2 is a steeper line. -1 would be a 45 degree line SE to NW line. -- I THINK...
---@param yIntercept double @ Where on the Y axis the line crosses.
---@return MapPosition|nil firstCrossingPosition @ Position if the line crossed or touched the edge of the circle. Nil if the line never crosses the circle.
---@return MapPosition|nil secondCrossingPosition @ Only a position if the line crossed the circle in 2 places. Nil if the line just touched the edge of the circle or never crossed it.
PositionUtils.FindWhereLineCrossesCircle = function(radius, slope, yIntercept)
    local centerPos = {x = 0, y = 0}
    local A = 1 + slope * slope
    local B = -2 * centerPos.x + 2 * slope * yIntercept - 2 * centerPos.y * slope
    local C = centerPos.x * centerPos.x + yIntercept * yIntercept + centerPos.y * centerPos.y - 2 * centerPos.y * yIntercept - radius * radius
    local delta = B * B - 4 * A * C

    if delta < 0 then
        return nil, nil
    else
        local x1 = (-B + math_sqrt(delta)) / (2 * A)
        local x2 = (-B - math_sqrt(delta)) / (2 * A)
        local y1 = slope * x1 + yIntercept
        local y2 = slope * x2 + yIntercept

        local pos1 = {x = x1, y = y1}
        local pos2 = {x = x2, y = y2}
        if pos1 == pos2 then
            return pos1, nil
        else
            return pos1, pos2
        end
    end
end

--- Check if a position is within a circles area.
---@param circleCenter MapPosition
---@param radius double
---@param position MapPosition
---@return boolean
PositionUtils.IsPositionWithinCircled = function(circleCenter, radius, position)
    local deltaX = math_abs(position.x - circleCenter.x)
    local deltaY = math_abs(position.y - circleCenter.y)
    if deltaX + deltaY <= radius then
        return true
    elseif deltaX > radius then
        return false
    elseif deltaY > radius then
        return false
    elseif deltaX ^ 2 + deltaY ^ 2 <= radius ^ 2 then
        return true
    else
        return false
    end
end

--- The valid key names in a table that can be converted in to a MapPosition with PositionUtils.TableToProperPosition(). Useful when you want to just check that no unexpected keys are present, i.e. command argument checking.
---@type table<string|uint, string|uint>
PositionUtils.MapPositionConvertableTableValidKeysList = {
    [1] = 1,
    [2] = 2,
    x = "x",
    y = "y"
}

return PositionUtils
