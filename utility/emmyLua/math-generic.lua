---@meta
-- cSpell:disable # Just ignore whole file while is conceptual.

-- Experimental. not used at present.
-- Allows for better (not perfect) math_generic.random() input to output typing via generics.
-- Also allows for @as typed to work, but these don't do it natively as the defines objects have no actual values in VSCode in the current API emyLua files: math_generic.random((0) --[[@as defines.riding.direction]], (2) --[[@as defines.riding.direction]])

-- Taken from Sumneko 3.5.0 - tree/master/meta/template/math_generic.lua



---#DES 'math'
---@class mathlib_generic
math_generic = math --[[@as mathlib_generic]]

---#DES 'math_generic.abs'
---@param x number
---@return number
---@nodiscard
function math_generic.abs(x)
end

---#DES 'math_generic.acos'
---@param x number
---@return number
---@nodiscard
function math_generic.acos(x)
end

---#DES 'math_generic.asin'
---@param x number
---@return number
---@nodiscard
function math_generic.asin(x)
end

---#if VERSION <= 5.2 then
---#DES 'math_generic.atan<5.2'
---@param y number
---@return number
---@nodiscard
function math_generic.atan(y)
end

---#else
---#DES 'math_generic.atan>5.3'
---@param y  number
---@param x? number
---@return number
---@nodiscard
function math_generic.atan(y, x)
end

---#end

---@version <5.2
---#DES 'math_generic.atan2'
---@param y number
---@param x number
---@return number
---@nodiscard
function math_generic.atan2(y, x)
end

---#DES 'math_generic.ceil'
---@param x number
---@return integer
---@nodiscard
function math_generic.ceil(x)
end

---#DES 'math_generic.cos'
---@param x number
---@return number
---@nodiscard
function math_generic.cos(x)
end

---@version <5.2
---#DES 'math_generic.cosh'
---@param x number
---@return number
---@nodiscard
function math_generic.cosh(x)
end

---#DES 'math_generic.deg'
---@param x number
---@return number
---@nodiscard
function math_generic.deg(x)
end

---#DES 'math_generic.exp'
---@param x number
---@return number
---@nodiscard
function math_generic.exp(x)
end

---#DES 'math_generic.floor'
---@param x number
---@return integer
---@nodiscard
function math_generic.floor(x)
end

---#DES 'math_generic.fmod'
---@param x number
---@param y number
---@return number
---@nodiscard
function math_generic.fmod(x, y)
end

---@version <5.2
---#DES 'math_generic.frexp'
---@param x number
---@return number m
---@return number e
---@nodiscard
function math_generic.frexp(x)
end

---@version <5.2
---#DES 'math_generic.ldexp'
---@param m number
---@param e number
---@return number
---@nodiscard
function math_generic.ldexp(m, e)
end

---#if VERSION <= 5.1 and not JIT then
---#DES 'math_generic.log<5.1'
---@param x     number
---@return number
---@nodiscard
function math_generic.log(x)
end

---#else
---#DES 'math_generic.log>5.2'
---@param x     number
---@param base? integer
---@return number
---@nodiscard
function math_generic.log(x, base)
end

---#end

---@version <5.1
---#DES 'math_generic.log10'
---@param x number
---@return number
---@nodiscard
function math_generic.log10(x)
end

---#DES 'math_generic.max'
---@generic Number: number
---@param x Number
---@param ... Number
---@return Number
---@nodiscard
function math_generic.max(x, ...)
end

---#DES 'math_generic.min'
---@generic Number: number
---@param x Number
---@param ... Number
---@return Number
---@nodiscard
function math_generic.min(x, ...)
end

---#DES 'math_generic.modf'
---@param x number
---@return integer
---@return number
---@nodiscard
function math_generic.modf(x)
end

---@version <5.2
---#DES 'math_generic.pow'
---@param x number
---@param y number
---@return number
---@nodiscard
function math_generic.pow(x, y)
end

---#DES 'math_generic.rad'
---@param x number
---@return number
---@nodiscard
function math_generic.rad(x)
end

---#DES 'math_generic.random' - Modified from Sumneko default
---
--- WARNING: Does not warn on invalid types and allow anything to be passed in, i.e. boolean types.
---@generic Number: number
---@param m Number
---@return Number
---@nodiscard
function math_generic.random(m)
end

--- #DES 'math_generic.random' - Modified from Sumneko default.
---
--- WARNING: Does not warn on invalid types and allow anything to be passed in, i.e. boolean types.
---@generic Number: number
---@param m Number
---@param n Number
---@return Number
---@nodiscard
function math_generic.random(m, n)
end

---#if VERSION >= 5.4 then
---#DES 'math_generic.randomseed>5.4'
---@param x? integer
---@param y? integer
function math_generic.randomseed(x, y)
end

---#else
---#DES 'math_generic.randomseed<5.3'
---@param x integer
function math_generic.randomseed(x)
end

---#end

---#DES 'math_generic.sin'
---@param x number
---@return number
---@nodiscard
function math_generic.sin(x)
end

---@version <5.2
---#DES 'math_generic.sinh'
---@param x number
---@return number
---@nodiscard
function math_generic.sinh(x)
end

---#DES 'math_generic.sqrt'
---@param x number
---@return number
---@nodiscard
function math_generic.sqrt(x)
end

---#DES 'math_generic.tan'
---@param x number
---@return number
---@nodiscard
function math_generic.tan(x)
end

---@version <5.2
---#DES 'math_generic.tanh'
---@param x number
---@return number
---@nodiscard
function math_generic.tanh(x)
end

---@version >5.3
---#DES 'math_generic.tointeger'
---@param x any
---@return integer?
---@nodiscard
function math_generic.tointeger(x)
end

---#DES 'math_generic.type'
---@param x any
---@return
---| '"integer"'
---| '"float"'
---| 'nil'
---@nodiscard
function math_generic.type(x)
end

---#DES 'math_generic.ult'
---@param m integer
---@param n integer
---@return boolean
---@nodiscard
function math_generic.ult(m, n)
end

return math
