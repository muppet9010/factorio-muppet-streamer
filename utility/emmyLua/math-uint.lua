---@meta
-- cSpell:disable # Just ignore whole file while is conceptual.

-- Experimental. not used at present and is an extra to the standard mathlib.

-- Taken from Sumneko 3.5.0 - tree/master/meta/template/math_generic.lua

---#DES 'math'
---@class mathlib_uint
math_uint = math --[[@as mathlib_uint]]

---#DES 'math.abs'
---@param x uint
---@return uint
---@nodiscard
function math_uint.abs(x)
end

---#DES 'math.acos'
---@param x number
---@return number
---@nodiscard
function math_uint.acos(x)
end

---#DES 'math.asin'
---@param x number
---@return number
---@nodiscard
function math_uint.asin(x)
end

---#if VERSION <= 5.2 then
---#DES 'math.atan<5.2'
---@param y number
---@return number
---@nodiscard
function math_uint.atan(y)
end

---#else
---#DES 'math.atan>5.3'
---@param y  number
---@param x? number
---@return number
---@nodiscard
function math_uint.atan(y, x)
end

---#end

---@version <5.2
---#DES 'math.atan2'
---@param y number
---@param x number
---@return number
---@nodiscard
function math_uint.atan2(y, x)
end

---#DES 'math.ceil'
---@param x number
---@return integer
---@nodiscard
function math_uint.ceil(x)
end

---#DES 'math.cos'
---@param x number
---@return number
---@nodiscard
function math_uint.cos(x)
end

---@version <5.2
---#DES 'math.cosh'
---@param x number
---@return number
---@nodiscard
function math_uint.cosh(x)
end

---#DES 'math.deg'
---@param x number
---@return number
---@nodiscard
function math_uint.deg(x)
end

---#DES 'math.exp'
---@param x number
---@return number
---@nodiscard
function math_uint.exp(x)
end

---#DES 'math.floor'
---@param x number
---@return integer
---@nodiscard
function math_uint.floor(x)
end

---#DES 'math.fmod'
---@param x number
---@param y number
---@return number
---@nodiscard
function math_uint.fmod(x, y)
end

---@version <5.2
---#DES 'math.frexp'
---@param x number
---@return number m
---@return number e
---@nodiscard
function math_uint.frexp(x)
end

---@version <5.2
---#DES 'math.ldexp'
---@param m number
---@param e number
---@return number
---@nodiscard
function math_uint.ldexp(m, e)
end

---#if VERSION <= 5.1 and not JIT then
---#DES 'math.log<5.1'
---@param x     number
---@return number
---@nodiscard
function math_uint.log(x)
end

---#else
---#DES 'math.log>5.2'
---@param x     number
---@param base? integer
---@return number
---@nodiscard
function math_uint.log(x, base)
end

---#end

---@version <5.1
---#DES 'math.log10'
---@param x number
---@return number
---@nodiscard
function math_uint.log10(x)
end

---#DES 'math.max'
---@param x uint
---@param ... uint
---@return uint
---@nodiscard
function math_uint.max(x, ...)
end

---#DES 'math.min'
---@generic Number: number
---@param x Number
---@param ... Number
---@return Number
---@nodiscard
function math_uint.min(x, ...)
end

---#DES 'math.modf'
---@param x number
---@return integer
---@return number
---@nodiscard
function math_uint.modf(x)
end

---@version <5.2
---#DES 'math.pow'
---@param x number
---@param y number
---@return number
---@nodiscard
function math_uint.pow(x, y)
end

---#DES 'math.rad'
---@param x number
---@return number
---@nodiscard
function math_uint.rad(x)
end

---#DES 'math.random'
---@overload fun(m: uint):uint
---@param m uint
---@param n uint
---@return uint
---@nodiscard
function math_uint.random(m, n)
end

---#if VERSION >= 5.4 then
---#DES 'math.randomseed>5.4'
---@param x? integer
---@param y? integer
function math_uint.randomseed(x, y)
end

---#else
---#DES 'math.randomseed<5.3'
---@param x integer
function math_uint.randomseed(x)
end

---#end

---#DES 'math.sin'
---@param x number
---@return number
---@nodiscard
function math_uint.sin(x)
end

---@version <5.2
---#DES 'math.sinh'
---@param x number
---@return number
---@nodiscard
function math_uint.sinh(x)
end

---#DES 'math.sqrt'
---@param x number
---@return number
---@nodiscard
function math_uint.sqrt(x)
end

---#DES 'math.tan'
---@param x number
---@return number
---@nodiscard
function math_uint.tan(x)
end

---@version <5.2
---#DES 'math.tanh'
---@param x number
---@return number
---@nodiscard
function math_uint.tanh(x)
end

---@version >5.3
---#DES 'math.tointeger'
---@param x any
---@return integer?
---@nodiscard
function math_uint.tointeger(x)
end

---#DES 'math.type'
---@param x any
---@return
---| '"integer"'
---| '"float"'
---| 'nil'
---@nodiscard
function math_uint.type(x)
end

---#DES 'math.ult'
---@param m integer
---@param n integer
---@return boolean
---@nodiscard
function math_uint.ult(m, n)
end

return math
