-- Just re-scan for all spawners and replace the old data. Any delayed or mid attempts loop of Teleport to biterNest will fail (note added to changelog).

local Teleport = {}

--- Copy of the function used for new maps started with the mod.
--- Find all existing spawners on all surfaces and record them. For use at mods initial load to handle being added to a map mid game.
---@return surfaceForceBiterNests surfacesSpawners
Teleport.FindExistingSpawnersOnAllSurfaces = function()
    local surfacesSpawners = {} ---@type surfaceForceBiterNests
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index
        surfacesSpawners[surface_index] = {}
        local spawners = surface.find_entities_filtered { type = "unit-spawner" }
        for _, spawner in pairs(spawners) do
            local spawner_unitNumber, spawner_force_name = spawner.unit_number, spawner.force.name ---@cast spawner_unitNumber -nil # Spawners always have unit numbers.
            surfacesSpawners[surface_index][spawner_force_name] = surfacesSpawners[surface_index][spawner_force_name] or {}
            surfacesSpawners[surface_index][spawner_force_name][spawner_unitNumber] = { unitNumber = spawner_unitNumber, entity = spawner, forceName = spawner_force_name, position = spawner.position }
        end
    end
    return surfacesSpawners
end

global.teleport.surfaceBiterNests = Teleport.FindExistingSpawnersOnAllSurfaces()
