--[[
    Event related utility functions. Seperate to the Events library for registering event handlers.
]]
--

local EventUtils = {}

EventUtils.WasCreativeModeInstantDeconstructionUsed = function(event)
    if event.instant_deconstruction ~= nil and event.instant_deconstruction == true then
        return true
    else
        return false
    end
end

--- Get the thing that did the building/mining from an event.
---@param event on_built_entity|on_robot_built_entity|script_raised_built|script_raised_revive|on_pre_player_mined_item|on_robot_pre_mined
---@return EntityActioner|nil placer @ Player, construction robot or nil if script done.
EventUtils.GetActionerFromEvent = function(event)
    if event.robot ~= nil then
        -- Construction robots
        return event.robot
    elseif event.player_index ~= nil then
        -- Player
        return game.get_player(event.player_index)
    else
        -- Script placed
        return nil
    end
end

--- Returns either tha player or force for robots from the EntityActioner.
---
--- Useful for passing in to rendering player/force filters or for returning items to them.
---@param actioner EntityActioner
---@return LuaPlayer|nil
---@return LuaForce|nil
EventUtils.GetPlayerOrForceFromEventActioner = function(actioner)
    if actioner.is_player() then
        -- Is a player.
        return actioner, nil
    else
        -- Is construction bot.
        return nil, actioner.force
    end
end

return EventUtils
