-- Returns and caches prototype attributes as requested to save future API calls. Values stored in Lua global varaible and populated as requested, as doesn't need persisting. Gets auto refreshed on game load and thus accounts for any change of attributes from mods.
local PrototypeAttributes = {}

MOD = MOD or {}
MOD.UTILITYPrototypeAttributes = MOD.UTILITYPrototypeAttributes or {} ---@type UtilityPrototypeAttributes_CachedTypes

--- Returns the request attribute of a prototype.
---
--- Obtains from the Lua global variable caches if present, otherwise obtains the result and caches it before returning it.
---@param prototypeType UtilityPrototypeAttributes_PrototypeTypes
---@param prototypeName string
---@param attributeName string
---@return any @ attribute value, can include nil.
PrototypeAttributes.GetAttribute = function(prototypeType, prototypeName, attributeName)
    local utilityPrototypeAttributes = MOD.UTILITYPrototypeAttributes

    local typeCache
    if utilityPrototypeAttributes[prototypeType] ~= nil then
        typeCache = utilityPrototypeAttributes[prototypeType]
    else
        utilityPrototypeAttributes[prototypeType] = {}
        typeCache = utilityPrototypeAttributes[prototypeType]
    end

    local prototypeCache
    if typeCache[prototypeName] ~= nil then
        prototypeCache = typeCache[prototypeName]
    else
        typeCache[prototypeName] = {}
        prototypeCache = typeCache[prototypeName]
    end

    local attributeCache = prototypeCache[attributeName]
    if attributeCache ~= nil then
        return attributeCache.value
    else
        local resultPrototype
        if prototypeType == PrototypeAttributes.PrototypeTypes.entity then
            resultPrototype = game.entity_prototypes[prototypeName]
        elseif prototypeType == PrototypeAttributes.PrototypeTypes.item then
            resultPrototype = game.item_prototypes[prototypeName]
        elseif prototypeType == PrototypeAttributes.PrototypeTypes.fluid then
            resultPrototype = game.fluid_prototypes[prototypeName]
        elseif prototypeType == PrototypeAttributes.PrototypeTypes.tile then
            resultPrototype = game.tile_prototypes[prototypeName]
        elseif prototypeType == PrototypeAttributes.PrototypeTypes.equipment then
            resultPrototype = game.equipment_prototypes[prototypeName]
        elseif prototypeType == PrototypeAttributes.PrototypeTypes.recipe then
            resultPrototype = game.recipe_prototypes[prototypeName]
        elseif prototypeType == PrototypeAttributes.PrototypeTypes.technology then
            resultPrototype = game.technology_prototypes[prototypeName]
        end
        local resultValue = resultPrototype[attributeName]
        prototypeCache[attributeName] = {value = resultValue}
        return resultValue
    end
end

---@class UtilityPrototypeAttributes_PrototypeTypes @ not all prototype types are supported at present as not needed before.
PrototypeAttributes.PrototypeTypes = {
    entity = "entity",
    item = "item",
    fluid = "fluid",
    tile = "tile",
    equipment = "equipment",
    recipe = "recipe",
    technology = "technology"
}

---@alias UtilityPrototypeAttributes_CachedTypes table<string, UtilityPrototypeAttributes_CachedPrototypes> @ a table of each prototype type name (key) and the prototypes it has of that type.
---@alias UtilityPrototypeAttributes_CachedPrototypes table<string, UtilityPrototypeAttributes_CachedAttributes> @ a table of each prototype name (key) and the attributes if has of that prototype.
---@alias UtilityPrototypeAttributes_CachedAttributes table<string, UtilityPrototypeAttributes_CachedAttribute> @ a table of each attribute name (key) and their cached values stored in the container.
---@class UtilityPrototypeAttributes_CachedAttribute @ Container for the cached value. If it exists the value is cached. An empty table signifies that the cached value is nil.
---@field value any @ the value of the attribute. May be nil if thats the attributes real value.

return PrototypeAttributes
