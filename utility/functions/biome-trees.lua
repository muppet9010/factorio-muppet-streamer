--[[
    Used to get tile (biome) approperiate trees, rather than just select any old tree. Means they will generally fit in to the map better, although vanilla forest types don't always fully match the biome they are in.
    Will only nicely handle vanilla tiles and trees, modded tiles will get a random tree if they are a land-ish type tile.
    Require the file and call the desired functions when needed (non _ functions at top of file). No pre-setup required.
]]
local Utils = require("utility/utils")
local Logging = require("utility/logging")

local BaseGameData = require("utility/functions/biome-trees-data/base-game")
local AlienBiomesData = require("utility/functions/biome-trees-data/alien-biomes")

local BiomeTrees = {}
local logNonPositives = true
local logPositives = true
local logData = false

BiomeTrees.GetBiomeTreeName = function(surface, position)
    -- Returns the tree name or nil if tile isn't land type
    BiomeTrees._ObtainRequiredData()
    local tile = surface.get_tile(position)
    local tileData = global.UTILITYBIOMETREES.tileData[tile.name]
    if tileData == nil then
        local tileName = tile.hidden_tile
        tileData = global.UTILITYBIOMETREES.tileData[tileName]
        if tileData == nil then
            if logNonPositives then
                Logging.LogPrint("Failed to get tile data for ''" .. tostring(tile.name) .. "'' and hidden tile '" .. tostring(tileName) .. "'")
            end
            return BiomeTrees._GetTruelyRandomTreeForTileCollision(tile)
        end
    end
    if tileData.type ~= "allow-trees" then
        return nil
    end

    local rangeInt = math.random(1, #tileData.tempRanges)
    local tempRange = tileData.tempRanges[rangeInt]
    local moistureRange = tileData.moistureRanges[rangeInt]
    local tempScaleMultiplyer = Utils.GetRandomFloatInRange(tempRange[1], tempRange[2])
    local tileTemp = global.UTILITYBIOMETREES.environmentData.tileTempCalcFunc(tempScaleMultiplyer)
    local tileMoisture = Utils.GetRandomFloatInRange(moistureRange[1], moistureRange[2])

    local suitableTrees = {}
    local currentChance = 0
    -- Make sure we find a tree of some type. Start as accurate as possible and then beocme less precise.
    for accuracy = 1, 1.5, 0.1 do
        for _, tree in pairs(global.UTILITYBIOMETREES.treeData) do
            if tileTemp >= tree.tempRange[1] / accuracy and tileTemp <= tree.tempRange[2] * accuracy and tileMoisture >= tree.moistureRange[1] / accuracy and tileMoisture <= tree.moistureRange[2] * accuracy then
                if (tree.tile_restrictions == nil) or (tree.tile_restrictions ~= nil and tree.tile_restrictions[tileData.name]) then
                    local treeEntry = {
                        chanceStart = currentChance,
                        chanceEnd = currentChance + tree.probability,
                        tree = tree
                    }
                    table.insert(suitableTrees, treeEntry)
                    currentChance = treeEntry.chanceEnd
                end
            end
        end
        if #suitableTrees > 0 then
            if logPositives then
                Logging.LogPrint(#suitableTrees .. " found on accuracy: " .. accuracy)
            end
            break
        end
    end
    if #suitableTrees == 0 then
        if logNonPositives then
            Logging.LogPrint("No tree found for conditions: tile: " .. tileData.name .. "   temp: " .. tileTemp .. "    moisture: " .. tileMoisture)
        end
        return BiomeTrees._GetTruelyRandomTreeForTileCollision(tile)
    end
    if logPositives then
        Logging.LogPrint("trees found for conditions: tile: " .. tileData.name .. "   temp: " .. tileTemp .. "    moisture: " .. tileMoisture)
    end

    local highestChance, treeName, treeFound = suitableTrees[#suitableTrees].chanceEnd, nil, false
    local chanceValue = math.random() * highestChance
    for _, treeEntry in pairs(suitableTrees) do
        if chanceValue >= treeEntry.chanceStart and chanceValue <= treeEntry.chanceEnd then
            treeName = treeEntry.tree.name
            treeFound = true
            break
        end
    end
    if not treeFound then
        return nil
    end

    -- Check the tree type still exists, if not re-generate data and run process again. There's no startup event requried with this method.
    if game.entity_prototypes[treeName] == nil then
        BiomeTrees._ObtainRequiredData(true)
        return BiomeTrees.GetBiomeTreeName(surface, position)
    else
        return treeName
    end
end

BiomeTrees.AddBiomeTreeNearPosition = function(surface, position, distance)
    -- Returns the tree entity if one found and created or nil
    BiomeTrees._ObtainRequiredData()
    local treeType = BiomeTrees.GetBiomeTreeName(surface, position)
    if treeType == nil then
        if logNonPositives then
            Logging.LogPrint("no tree was found")
        end
        return nil
    end
    local newPosition = surface.find_non_colliding_position(treeType, position, distance, 0.2)
    if newPosition == nil then
        if logNonPositives then
            Logging.LogPrint("No position for new tree found")
        end
        return nil
    end
    local newTree = surface.create_entity {name = treeType, position = newPosition, force = "neutral", raise_built = true}
    if newTree == nil then
        Logging.LogPrint("Failed to create tree at found position")
        return nil
    end
    if logPositives then
        Logging.LogPrint("tree added successfully, type: " .. treeType .. "    position: " .. newPosition.x .. ", " .. newPosition.y)
    end
    return newTree
end

BiomeTrees._GetTruelyRandomTreeForTileCollision = function(tile)
    if tile.collides_with("player-layer") then
        -- Is a non-land tile
        return nil
    else
        return global.UTILITYBIOMETREES.randomTrees[math.random(#global.UTILITYBIOMETREES.randomTrees)]
    end
end

BiomeTrees._ObtainRequiredData = function(forceReload)
    if forceReload then
        global.UTILITYBIOMETREES = nil
    end
    global.UTILITYBIOMETREES = global.UTILITYBIOMETREES or {}
    global.UTILITYBIOMETREES.environmentData = global.UTILITYBIOMETREES.environmentData or BiomeTrees._GetEnvironmentData()
    global.UTILITYBIOMETREES.tileData = global.UTILITYBIOMETREES.tileData or global.UTILITYBIOMETREES.environmentData.tileData
    global.UTILITYBIOMETREES.treeData = global.UTILITYBIOMETREES.treeData or BiomeTrees._GetTreeData()
    global.UTILITYBIOMETREES.randomTrees = global.UTILITYBIOMETREES.randomTrees or BiomeTrees._GetRandomTrees()

    if logData then
        Logging.LogPrint(serpent.block(global.UTILITYBIOMETREES.treeData))
        Logging.LogPrint(serpent.block(global.UTILITYBIOMETREES.tileData))
    end
end

BiomeTrees._GetEnvironmentData = function()
    -- Used to handle the differing tree to tile value relationships of mods vs base game.
    local environmentData = {}
    if game.active_mods["alien-biomes"] then
        environmentData.moistureRangeAttributeName = {optimal = "aux_optimal", range = "aux_range"}
        environmentData.tileTempCalcFunc = function(tempScaleMultiplyer)
            return math.min(125, math.max(-15, tempScaleMultiplyer * 100)) -- on scale of -0.5 to 1.5 = -50 to 150. -15 is lowest temp tree +125 is highest temp tree.
        end
        environmentData.tileData = BiomeTrees._AddTilesDetails(AlienBiomesData.GetTileData())
        HERE
        -- DO A TILE COLOUR TO TREE COLOR RANGES
        for _, details in pairs(environmentData.tileData) do
            if details.tags ~= nil then
                local newTags, colors = {}, {"grey" = {}"green"}
                for tag in pairs(details.tags) do
                    if tag == "grey" then
                        newTags[white] = "white"
                    elseif colors[tag] then
                        newTags[tag] = tag
                    end
                end
                details.tags = newTags
            end
        end
        environmentData.treeMetaData = AlienBiomesData.GetTreeMetaData()
    else
        environmentData.moistureRangeAttributeName = {optimal = "water_optimal", range = "water_range"}
        environmentData.tileTempCalcFunc = function(tempScaleMultiplyer)
            return math.max(5, (tempScaleMultiplyer * 35))
        end
        environmentData.tileData = BiomeTrees._AddTilesDetails(BaseGameData.GetTileData())
        environmentData.treeMetaData = {}
    end
    return environmentData
end

BiomeTrees._GetTreeData = function()
    local treeData = {}
    local environmentData = global.UTILITYBIOMETREES.environmentData
    local moistureRangeAttributeName = global.UTILITYBIOMETREES.environmentData.moistureRangeAttributeName
    for _, prototype in pairs(game.get_filtered_entity_prototypes({{filter = "type", type = "tree"}, {mode = "and", filter = "autoplace"}})) do
        Logging.LogPrint(prototype.name, logData)
        local autoplace = nil
        for _, peak in pairs(prototype.autoplace_specification.peaks) do
            if peak.temperature_optimal ~= nil then
                autoplace = peak
            end
        end
        if autoplace ~= nil then
            -- Use really wide range defaults for missing moisture values as likely unspecified by mods to mean ALL.
            treeData[prototype.name] = {
                name = prototype.name,
                tempRange = {
                    autoplace.temperature_optimal - autoplace.temperature_range,
                    autoplace.temperature_optimal + autoplace.temperature_range
                },
                moistureRange = {
                    (autoplace[moistureRangeAttributeName.optimal] or 0) - (autoplace[moistureRangeAttributeName.range] or 0),
                    (autoplace[moistureRangeAttributeName.optimal] or 1) + (autoplace[moistureRangeAttributeName.range] or 0)
                },
                probability = prototype.autoplace_specification.max_probability
            }
            if environmentData.treeMetaData[prototype.name] ~= nil then
                treeData[prototype.name].tags = environmentData.treeMetaData[prototype.name][1]
                treeData[prototype.name].tile_restrictions = environmentData.treeMetaData[prototype.name][2]
            end
        end
    end
    return treeData
end

BiomeTrees._GetRandomTrees = function()
    local randomTrees = {}
    for treeName in pairs(game.get_filtered_entity_prototypes({{filter = "type", type = "tree"}})) do
        table.insert(randomTrees, treeName)
    end
    return randomTrees
end

BiomeTrees._AddTileDetails = function(tileDetails, tileName, type, range1, range2, tags)
    local tempRanges = {}
    local moistureRanges = {}
    if range1 ~= nil then
        table.insert(tempRanges, {range1[1][1] or 0, range1[2][1] or 0})
        table.insert(moistureRanges, {range1[1][2] or 0, range1[2][2] or 0})
    end
    if range2 ~= nil then
        table.insert(tempRanges, {range2[1][1] or 0, range2[2][1] or 0})
        table.insert(moistureRanges, {range2[1][2] or 0, range2[2][2] or 0})
    end
    tileDetails[tileName] = {name = tileName, type = type, tempRanges = tempRanges, moistureRanges = moistureRanges, tags = tags}
end

BiomeTrees._AddTilesDetails = function(tilesDetails)
    local tileDetails = {}
    for name, details in pairs(tilesDetails) do
        BiomeTrees._AddTileDetails(tileDetails, name, details[1], details[2], details[3], details[4])
    end
    return tileDetails
end

return BiomeTrees
