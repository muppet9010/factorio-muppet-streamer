--[[
    Random utility functions that don't fit in to any other category.
]]
--

local MiscUtils = {}

---@class LuaBaseClass @ Used as a fake base class, only supports checking defined attributes.
---@field valid boolean

--- Returns a luaObject if its valid, else nil. Convientent for inline usage when rarely called.
---
--- Should be done locally if called frequently.
---@param luaObject LuaBaseClass
---@return LuaBaseClass|nil
MiscUtils.ReturnValidLuaObjectOrNil = function(luaObject)
    if luaObject == nil or not luaObject.valid then
        return nil
    else
        return luaObject
    end
end

return MiscUtils
