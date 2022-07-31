--[[
    Can get random biter types and worm type for specified evolution level.
]]
--

local MathUtils = require("utility.helper-utils.math-utils")
local RandomChance = require("utility.functions.random-chance")

local BiterSelection = {} ---@class Utility_BiterSelection

---@alias UtilityBiterSelection_SpawnerTypes 'biter-spawner'|'spitter-spawner'|string # Biter and spitter are the base game unit spawners, but mods can add new named ones, so any string is accepted.

---@alias UtilityBiterSelection_BiterSpawnerTypeCaches table<string, UtilityBiterSelection_BiterCacheEntry> # Key'd by the spawner type.
---@class UtilityBiterSelection_BiterCacheEntry
---@field calculatedEvolution double
---@field probabilities UtilityBiterSelection_UnitChanceEntry[]

---@class UtilityBiterSelection_WormCacheEntry
---@field calculatedEvolution double
---@field name string|nil

---@class UtilityBiterSelection_UnitChanceEntry
---@field chance double
---@field unitName string

----------------------------------------------------------------------------------
--                          PUBLIC FUNCTIONS
----------------------------------------------------------------------------------

--- Get the biters's xxx for the current evolution. Will cache the last result to avoid frequent lookups based on the probabilityGlobalName. Use different probabilityGlobalName's if different evolution values are going to be checked and so should be cached in parallel.
---@param probabilityGlobalName string
---@param spawnerType UtilityBiterSelection_SpawnerTypes # Biter and spitter are the base game unit spawners, but mods can add new named ones, so any string is accepted.
---@param evolution double
---@return string
BiterSelection.GetBiterType = function(probabilityGlobalName, spawnerType, evolution)
    -- probabilityGlobalName option is a name for tracking this biter evolution probability line. Use unique names if different evolutions are being tracked.
    global.UTILITYBITERSELECTION = global.UTILITYBITERSELECTION or {}
    global.UTILITYBITERSELECTION.BiterCacheName = global.UTILITYBITERSELECTION.BiterCacheName or {} ---@type table<string, UtilityBiterSelection_BiterSpawnerTypeCaches> # Key'd by the biter cache name.
    global.UTILITYBITERSELECTION.BiterCacheName[probabilityGlobalName] = global.UTILITYBITERSELECTION.BiterCacheName[probabilityGlobalName] or {} ---@type UtilityBiterSelection_BiterSpawnerTypeCaches
    local modEnemyProbabilities = global.UTILITYBITERSELECTION.BiterCacheName[probabilityGlobalName]
    if modEnemyProbabilities[spawnerType] == nil then
        modEnemyProbabilities[spawnerType] = {}
    end
    evolution = MathUtils.RoundNumberToDecimalPlaces(evolution, 2)
    local x = modEnemyProbabilities[spawnerType]
    if modEnemyProbabilities[spawnerType].calculatedEvolution == nil or modEnemyProbabilities[spawnerType].calculatedEvolution ~= evolution then
        modEnemyProbabilities[spawnerType].calculatedEvolution = evolution
        modEnemyProbabilities[spawnerType].probabilities = BiterSelection._CalculateSpecificBiterSelectionProbabilities(spawnerType, evolution)
    end
    return RandomChance.GetRandomEntryFromNormalisedDataSet(modEnemyProbabilities[spawnerType].probabilities, "chance").unitName
end

--- Get the best (highest evolution) worm's entity name for the current evolution. Will cache the last result to avoid frequent lookups based on the wormEvoGlobalName. Use different wormEvoGlobalName's if different evolution values are going to be checked and so should be cached in parallel.
---@param wormEvoGlobalName string
---@param evolution double
---@return string wormEntityName
BiterSelection.GetWormType = function(wormEvoGlobalName, evolution)
    global.UTILITYBITERSELECTION = global.UTILITYBITERSELECTION or {}
    global.UTILITYBITERSELECTION.WormCacheName = global.UTILITYBITERSELECTION.WormCacheName or {} ---@type table<string, UtilityBiterSelection_WormCacheEntry> # Key'd by the worm cache name.
    global.UTILITYBITERSELECTION.WormCacheName[wormEvoGlobalName] = global.UTILITYBITERSELECTION.WormCacheName[wormEvoGlobalName] or {} ---@type UtilityBiterSelection_WormCacheEntry
    local wormEvoType = global.UTILITYBITERSELECTION.WormCacheName[wormEvoGlobalName]
    evolution = MathUtils.RoundNumberToDecimalPlaces(evolution, 2)
    if wormEvoType.calculatedEvolution == nil or wormEvoType.calculatedEvolution ~= evolution then
        wormEvoType.calculatedEvolution = evolution
        wormEvoType.name = BiterSelection._CalculateSpecificWormForEvolution(evolution)
    end
    return wormEvoType.name
end

----------------------------------------------------------------------------------
--                          PRIVATE FUNCTIONS
----------------------------------------------------------------------------------

--- Returns an array of UnitChanceEntries for the biters of the specified spawnerType and evolution.
---@param spawnerType UtilityBiterSelection_SpawnerTypes
---@param currentEvolution double
---@return UtilityBiterSelection_UnitChanceEntry[]
BiterSelection._CalculateSpecificBiterSelectionProbabilities = function(spawnerType, currentEvolution)
    local rawUnitProbabilities = game.entity_prototypes[spawnerType].result_units
    local currentEvolutionProbabilities = {} ---@type UtilityBiterSelection_UnitChanceEntry[]
    for _, possibility in pairs(rawUnitProbabilities) do
        local startSpawnPointIndex ---@type int
        for spawnPointIndex, spawnPoint in pairs(possibility.spawn_points) do
            if spawnPoint.evolution_factor <= currentEvolution then
                startSpawnPointIndex = spawnPointIndex
            end
        end
        if startSpawnPointIndex ~= nil then
            local startSpawnPoint = possibility.spawn_points[startSpawnPointIndex]
            local endSpawnPoint
            if possibility.spawn_points[startSpawnPointIndex + 1] ~= nil then
                endSpawnPoint = possibility.spawn_points[startSpawnPointIndex + 1]
            else
                endSpawnPoint = { evolution_factor = 1.0, weight = startSpawnPoint.weight }
            end

            local weight
            if startSpawnPoint.evolution_factor ~= endSpawnPoint.evolution_factor then
                local evoRange = endSpawnPoint.evolution_factor - startSpawnPoint.evolution_factor
                local weightRange = endSpawnPoint.weight - startSpawnPoint.weight
                local evoRangeMultiplier = (currentEvolution - startSpawnPoint.evolution_factor) / evoRange
                weight = (weightRange * evoRangeMultiplier) + startSpawnPoint.weight
            else
                weight = startSpawnPoint.weight
            end
            table.insert(currentEvolutionProbabilities, { chance = weight, unitName = possibility.unit })
        end
    end
    currentEvolutionProbabilities = RandomChance.NormaliseChanceList(currentEvolutionProbabilities, "chance") ---@type UtilityBiterSelection_UnitChanceEntry[]
    return currentEvolutionProbabilities
end

--- Find the highest evolution worm turret's name that is below the required evolution level.
---@param evolution double # The evolution the worm turret must be below.
---@return string|nil wormTurret
BiterSelection._CalculateSpecificWormForEvolution = function(evolution)
    local turrets = game.get_filtered_entity_prototypes({ { filter = "turret" }, { mode = "and", filter = "build-base-evolution-requirement", comparison = "≤", value = evolution }, { mode = "and", filter = "flag", flag = "placeable-enemy" }, { mode = "and", filter = "flag", flag = "player-creation", invert = true } })
    if #turrets == 0 then
        return nil
    end

    local sortedTurrets = {} ---@type LuaEntityPrototype[]
    for _, turret in pairs(turrets) do
        table.insert(sortedTurrets, turret)
    end

    table.sort(
        sortedTurrets,
        function(a, b)
            return a.build_base_evolution_requirement > b.build_base_evolution_requirement
        end
    )
    return sortedTurrets[1].name
end

return BiterSelection
