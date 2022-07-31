-- Vanilla - 1.1.5
local Data = {} ---@class Utility_BiomeTrees_BaseGame

Data.GetTileData = function()
    -- Any tile not listed will have a random tree placed on it assuming the player can walk on the tile, otherwise no tree.
    return {
        ["grass-1"] = { "allow-trees", { { 0, 0.7 }, { 1, 1 } } },
        ["grass-2"] = { "allow-trees", { { 0.45, 0.45 }, { 1, 0.8 } } },
        ["grass-3"] = { "allow-trees", { { 0, 0.6 }, { 0.65, 0.9 } } },
        ["grass-4"] = { "allow-trees", { { 0, 0.5 }, { 0.55, 0.7 } } },
        ["dry-dirt"] = { "allow-trees", { { 0.45, 0 }, { 0.55, 0.35 } } },
        ["dirt-1"] = { "allow-trees", { { 0, 0.25 }, { 0.45, 0.3 } }, { { 0.4, 0 }, { 0.45, 0.25 } } },
        ["dirt-2"] = { "allow-trees", { { 0, 0.3 }, { 0.45, 0.35 } } },
        ["dirt-3"] = { "allow-trees", { { 0, 0.35 }, { 0.55, 0.4 } } },
        ["dirt-4"] = { "allow-trees", { { 0.55, 0 }, { 0.6, 0.35 } }, { { 0.6, 0.3 }, { 1, 0.35 } } },
        ["dirt-5"] = { "allow-trees", { { 0, 0.4 }, { 0.55, 0.45 } } },
        ["dirt-6"] = { "allow-trees", { { 0, 0.45 }, { 0.55, 0.5 } } },
        ["dirt-7"] = { "allow-trees", { { 0, 0.5 }, { 0.55, 0.55 } } },
        ["sand-1"] = { "allow-trees", { { 0, 0 }, { 0.25, 0.15 } } },
        ["sand-2"] = { "allow-trees", { { 0, 0.15 }, { 0.3, 0.2 } }, { { 0.25, 0 }, { 0.3, 0.15 } } },
        ["sand-3"] = { "allow-trees", { { 0, 0.2 }, { 0.4, 0.25 } }, { { 0.3, 0 }, { 0.4, 0.2 } } },
        ["red-desert-0"] = { "allow-trees", { { 0.55, 0.35 }, { 1, 0.5 } } },
        ["red-desert-1"] = { "allow-trees", { { 0.6, 0 }, { 0.7, 0.3 } }, { { 0.7, 0.25 }, { 1, 0.3 } } },
        ["red-desert-2"] = { "allow-trees", { { 0.7, 0 }, { 0.8, 0.25 } }, { { 0.8, 0.2 }, { 1, 0.25 } } },
        ["red-desert-3"] = { "allow-trees", { { 0.8, 0 }, { 1, 0.2 } } },
        ["water"] = { "water" },
        ["deepwater"] = { "water" },
        ["water-green"] = { "water" },
        ["deepwater-green"] = { "water" },
        ["water-shallow"] = { "water" },
        ["water-mud"] = { "water" },
        ["out-of-map"] = { "no-trees" },
        ["landfill"] = { "allow-trees", { { 0, 0 }, { 0.25, 0.15 } } }, --same as sand-1
        ["nuclear-ground"] = { "allow-trees", { { 0, 0 }, { 0.25, 0.15 } } } --same as sand-1
    }
end

return Data
