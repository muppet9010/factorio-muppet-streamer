--[[
    All boolean type related utils functions.
]]
--

local BooleanUtils = {}
local string_lower = string.lower

--- Tries to converts a non boolean to a boolean value.
---@param text string|int|boolean @ The input to check.
---@return boolean|nil @ If successful converted then the boolean of the value, or nil if not a convertable input.
BooleanUtils.ToBoolean = function(text)
    if text == nil then
        return nil
    end
    local textType = type(text)
    if textType == "string" then
        text = string_lower(text)
        if text == "true" then
            return true
        elseif text == "false" then
            return false
        else
            return nil
        end
    elseif textType == "number" then
        if text == 0 then
            return false
        elseif text == 1 then
            return true
        else
            return nil
        end
    elseif textType == "boolean" then
        return text
    else
        return nil
    end
end

return BooleanUtils
