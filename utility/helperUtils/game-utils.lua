--[[
    Game utility functions that don't fit in to any other category.
]]
--

local GameUtils = {}

--- Called from OnInit
GameUtils.DisableWinOnRocket = function()
    if remote.interfaces["silo_script"] == nil then
        return
    end
    remote.call("silo_script", "set_no_victory", true)
end

--- Called from OnInit
GameUtils.ClearSpawnRespawnItems = function()
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_created_items", {})
    remote.call("freeplay", "set_respawn_items", {})
end

--- Called from OnInit
---@param distanceTiles uint
GameUtils.SetStartingMapReveal = function(distanceTiles)
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_chart_distance", distanceTiles)
end

-- called from OnInit
GameUtils.DisableIntroMessage = function()
    if remote.interfaces["freeplay"] == nil then
        return
    end
    remote.call("freeplay", "set_skip_intro", true)
end

return GameUtils
