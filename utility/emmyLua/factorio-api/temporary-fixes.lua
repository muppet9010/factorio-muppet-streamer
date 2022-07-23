---@meta

---@class LuaSurface
local LuaSurface = {
    ---Get the tile at a given position.
    ---
    ---**Note:** The input position params can also be a single tile position.
    ---
    ---[View documentation](https://lua-api.factorio.com/latest/LuaSurface.html#LuaSurface.get_tile)
    ---@param x int
    ---@param y int
    ---@return LuaTile
    ---@overload fun(position: TilePosition): LuaTile
    get_tile = function(x, y)
    end
}

---@class Vector.1
---@field [1] double
---@field [2] double

-----@class uint
-----@operator unm:uint
-----@operator mod:uint
-----@operator add(float):float
-----@operator add(uint): uint
-----@operator div(integer):uint
-----@operator sub:uint
-----@operator mul:uint

-----@class float
-----@operator unm:float
-----@operator mod:float
-----@operator add(float):float
-----@operator add(number):float
-----@operator add(uint):float
-----@operator div:float
-----@operator sub:float
-----@operator mul:float

-----@class integer
-----@operator add(integer):integer
-----@operator add(float):float
-----@operator add(number):number
-----@operator add(uint):uint

-----@class number
-----@operator add(integer):number
-----@operator add(float):number
-----@operator add(number):number
-----@operator add(uint):number

---@class RealOrientation
---@operator unm:RealOrientation
---@operator mod:RealOrientation
---@operator add:RealOrientation
---@operator div:RealOrientation
---@operator sub:RealOrientation
---@operator mul:RealOrientation

---@class defines.direction
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.north
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.northeast
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.east
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.southeast
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.south
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.southwest
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.west
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction

---@class defines.direction.northwest
---@operator unm:defines.direction
---@operator mod:defines.direction
---@operator add:defines.direction
---@operator div:defines.direction
---@operator sub:defines.direction
---@operator mul:defines.direction
