local BuildingGhosts = {}
local Events = require("utility.manager-libraries.events")
local MathUtil = require("utility.helper-utils.math-utils")

local customGhostLife = 40000000 ---@type uint @ Different to the vanilla value so it can be distinguished. Vanilla adds 36288000 (36mil vs 40mil).

BuildingGhosts.CreateGlobals = function()
    global.buildingGhosts = global.buildingGhosts or {}
    global.buildingGhosts.enabled = global.buildingGhosts.enabled or false ---@type boolean
end

BuildingGhosts.OnStartup = function()
    -- Track changes in setting from last known and apply changes as required.
    if not global.buildingGhosts.enabled and settings.startup["muppet_streamer-enable_building_ghosts"].value then
        global.buildingGhosts.enabled = true
        for _, force in pairs(game.forces) do
            BuildingGhosts.EnableForForce(force)
        end
    elseif global.buildingGhosts.enabled and not settings.startup["muppet_streamer-enable_building_ghosts"].value then
        global.buildingGhosts.enabled = false
        for _, force in pairs(game.forces) do
            BuildingGhosts.DisableForForce(force)
        end
    end
end

BuildingGhosts.OnLoad = function()
    Events.RegisterHandlerEvent(defines.events.on_force_reset, "BuildingGhosts.OnForceChanged", BuildingGhosts.OnForceChanged)
    Events.RegisterHandlerEvent(defines.events.on_force_created, "BuildingGhosts.OnForceChanged", BuildingGhosts.OnForceChanged)
end

--- Called when a force is reset or created by a mod/editor and we need to re-apply the ghost setting if enabled.
---@param event on_force_reset|on_force_created
BuildingGhosts.OnForceChanged = function(event)
    if settings.startup["muppet_streamer-enable_building_ghosts"].value then
        BuildingGhosts.EnableForForce(event.force)
    end
end

--- For specific force enable building ghosts on death. This will preserve any vanilla researched state as our value is greater than vanilla's value.
---@param force LuaForce
BuildingGhosts.EnableForForce = function(force)
    if force.ghost_time_to_live < customGhostLife then
        force.ghost_time_to_live = math.min(force.ghost_time_to_live + customGhostLife, MathUtil.UintMax) --[[@as uint]] -- Safe as any sensible values added togetaher will be millions of the 2 billion max.
    end
end

--- For specific force disable building ghosts on death. This will preserve any vanilla researched state as our value is greater than vanilla's value.
---@param force LuaForce
BuildingGhosts.DisableForForce = function(force)
    if force.ghost_time_to_live >= customGhostLife then
        force.ghost_time_to_live = math.max(force.ghost_time_to_live - customGhostLife, 0) --[[@as uint]] -- Safe to assume the number hadn't maxed out as any sensible values added togeather will be millions of the 2 billion max.
    end
end

return BuildingGhosts
