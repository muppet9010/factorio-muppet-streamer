-- Library to support using mod settings to accept a JSON list (array) of values for N instances of something. Rather than having to add lots of repeat mod settings entry boxes.
-- So you can have 3 settings; 1 each for name, type and number. Then the user can provide either a single value for each or a JSON list of values and this will automatically separate the settings and group them together based on submission order.

-- CODE NOTE: This is a bit of a weird feature, but implemented in Biter Hunt Group mod a long time ago. If it needs using for a new project I think it needs a review and cleansing as its just weird and likely has a lot of edge cases from trying to Sumneko type it. A number of the handling functions just don't seem that logical and Sumneko can struggle to handle them as such.

local SettingsManager = {} ---@class Utility_SettingsManager
local BooleanUtils = require("utility.helper-utils.boolean-utils")
local LoggingUtils = require("utility.helper-utils.logging-utils")

---@class UtilitySettingsManager_ExpectedValueTypes
SettingsManager.ExpectedValueTypes = {
    string = { name = "string", hasChildren = false }, ---@type UtilitySettingsManager_ExpectedValueType
    number = { name = "number", hasChildren = false }, ---@type UtilitySettingsManager_ExpectedValueType
    boolean = { name = "boolean", hasChildren = false }, ---@type UtilitySettingsManager_ExpectedValueType
    arrayOfStrings = { name = "arrayOfStrings", hasChildren = true, childExpectedValueType = SettingsManager.ExpectedValueTypes.string }, ---@type UtilitySettingsManager_ExpectedValueType
    arrayOfNumbers = { name = "arrayOfNumbers", hasChildren = true, childExpectedValueType = SettingsManager.ExpectedValueTypes.number }, ---@type UtilitySettingsManager_ExpectedValueType
    arrayOfBooleans = { name = "arrayOfBooleans", hasChildren = true, childExpectedValueType = SettingsManager.ExpectedValueTypes.boolean } ---@type UtilitySettingsManager_ExpectedValueType
}
---@class UtilitySettingsManager_ExpectedValueType
---@field name string # Same as key in the ExpectedValueTypes table.
---@field hasChildren boolean # If the expected type is a list.
---@field childExpectedValueType UtilitySettingsManager_ExpectedValueType # The type of entry in the list.

---@alias UtilityMultipleValuesInSettings_GlobalGroupsContainer table<uint, UtilityMultipleValuesInSettings_GlobalGroupsContainerOccurrence> # Key'd by the the occurrence number of the grouped settings (id argument when retrieving setting values).
---@alias UtilityMultipleValuesInSettings_GlobalGroupsContainerOccurrence table<string, UtilityMultipleValuesInSettings_GlobalGroupsContainerOccurrenceSetting>
---@alias UtilityMultipleValuesInSettings_GlobalGroupsContainerOccurrenceSetting table<string, boolean|number|string|nil>

---@alias UtilityMultipleValuesInSettings_DefaultSettingsContainer table<string, boolean|number|string|nil>  # Key'd by the setting name.

----------------------------------------------------------------------------------
--                          PUBLIC FUNCTIONS
----------------------------------------------------------------------------------

--[[
    If only 1 value is passed it sets ID 0 as that value. If array of expected values is received then each ID above 0 uses the array value and ID 0 is set as the defaultValue.
    Value is converted to the expected type. If nil is returned this is deemed as invalid data entry and default value is returned along with non stopping error message.
    The expectedType value is passed to callback function "valueHandlingFunction" to be processed uniquely for each setting. If this is omitted then the value is just straight assigned without any processing.
    Clears all instances of the setting from all groups in the groups container before updating. Only way to remove old stale data.
]]
---@param factorioSettingType 'startup'|'global'|'player' # The Factorio setting type.
---@param factorioSettingName string # The name of the Factorio setting.
---@param expectedValueType UtilitySettingsManager_ExpectedValueType
---@param defaultSettingsContainer table # Just pass in a reference to an empty table (not nil) in factorio mod `global`. Same table can be used for all settings and container names.
---@param defaultValue boolean|number|string|nil # The default raw value to be passed in to the provided valueHandlingFunction.
---@param globalGroupsContainer table # Just pass in a reference to an empty table (not nil) in factorio mod `global`. Same table can be used for all settings and container names.
---@param globalSettingContainerName 'settings'|string # A unique name for this group of settings. Not sure when you would want separate groups of settings as it would allow repeat instances of the same setting.
---@param globalSettingName string # The setting name that's used for storing and retrieving the value in this feature.
---@param valueHandlingFunction? fun(value: any):any|nil # A function that is run on the value of each occurrence of the setting to process the value before recording it.
SettingsManager.HandleSettingWithArrayOfValues = function(factorioSettingType, factorioSettingName, expectedValueType, defaultSettingsContainer, defaultValue, globalGroupsContainer, globalSettingContainerName, globalSettingName, valueHandlingFunction)
    if expectedValueType == nil or expectedValueType == "" then
        error("Setting '[" .. tostring(factorioSettingType) .. "][" .. tostring(factorioSettingName) .. "]' has no value type coded.")
    elseif expectedValueType.name == nil or SettingsManager.ExpectedValueTypes[expectedValueType.name] == nil then
        error("Setting '[" .. tostring(factorioSettingType) .. "][" .. tostring(factorioSettingName) .. "]' has an invalid value type coded: '" .. tostring(expectedValueType.name) .. "'")
    end

    ---@cast defaultSettingsContainer UtilityMultipleValuesInSettings_DefaultSettingsContainer # Done so that the function's type is clear when calling.
    ---@cast globalGroupsContainer UtilityMultipleValuesInSettings_GlobalGroupsContainer # Done so that the function's type is clear when calling.

    for _, group in pairs(globalGroupsContainer) do
        ---@cast group UtilityMultipleValuesInSettings_GlobalGroupsContainerOccurrence # Sumneko is struggling to deal with the weird code structure.
        group[globalSettingContainerName][globalSettingName] = nil
    end

    -- Set a default function to be run if one wasn't provided.
    valueHandlingFunction = valueHandlingFunction or function(value)
        return value
    end

    local values = settings[factorioSettingType][factorioSettingName].value ---@type boolean|number|string|nil # This is whatever the user has put in the text box.
    local tableOfValues ---@type AnyBasic|nil
    if type(values) == "string" then
        tableOfValues = game.json_to_table(values)
    end

    local isMultipleGroups
    if tableOfValues == nil or type(tableOfValues) ~= "table" then
        isMultipleGroups = false
    else -- is a table type of value for setting
        ---@cast tableOfValues table<uint, boolean|number|string>
        if not expectedValueType.hasChildren then
            isMultipleGroups = true
        else
            for _, v in pairs(tableOfValues) do
                if v ~= nil and type(v) == "table" then
                    isMultipleGroups = true
                    break
                end
            end
            isMultipleGroups = isMultipleGroups or false
        end
    end

    if isMultipleGroups then
        ---@cast tableOfValues -nil # If it was nil this logic branch couldn't be reached.
        for id, value in pairs(tableOfValues) do
            local thisGlobalSettingContainer = SettingsManager._CreateGlobalGroupSettingsContainer(globalGroupsContainer, id, globalSettingContainerName)
            local typedValue = SettingsManager._ValueToType(value, expectedValueType)
            if typedValue ~= nil then
                thisGlobalSettingContainer[globalSettingName] = valueHandlingFunction(typedValue)
            else
                thisGlobalSettingContainer[globalSettingName] = valueHandlingFunction(defaultValue)
                LoggingUtils.LogPrintWarning("Setting '[" .. factorioSettingType .. "][" .. factorioSettingName .. "]' for entry number '" .. id .. "' has an invalid value type. Expected a '" .. expectedValueType.name .. "' but got the value '" .. tostring(value) .. "', so using default value of '" .. tostring(defaultValue) .. "'")
            end
        end
        defaultSettingsContainer[globalSettingName] = valueHandlingFunction(defaultValue)
    else
        local value = tableOfValues or values
        local typedValue = SettingsManager._ValueToType(value, expectedValueType)
        if typedValue ~= nil then
            defaultSettingsContainer[globalSettingName] = valueHandlingFunction(typedValue)
        else
            defaultSettingsContainer[globalSettingName] = valueHandlingFunction(defaultValue)
            if not (expectedValueType.hasChildren and value == "") then
                -- If its an arrayOf type setting and an empty string is input don't show an error. Blank string is valid as well as an empty array JSON.
                LoggingUtils.LogPrintWarning("Setting '[" .. factorioSettingType .. "][" .. factorioSettingName .. "]' isn't a valid JSON array and has an invalid value type for a single value. Expected a single or array of '" .. expectedValueType.name .. "' but got the value '" .. tostring(value) .. "', so using default value of '" .. tostring(defaultValue) .. "'")
            end
        end
    end
end

--- Get the specific occurrence (id) value for the specific setting and container.
---@param globalGroupsContainer table # Just pass in a reference to an empty table (not nil) in factorio mod `global`. Same table can be used for all settings and container names.
---@param id uint # The occurrence number of the grouped settings.
---@param globalSettingContainerName 'settings'|string # A unique name for this group of settings. Not sure when you would want separate groups of settings as it would allow repeat instances of the same setting.
---@param globalSettingName string # The setting name that's used for storing and retrieving the value in this feature.
---@param defaultSettingsContainer table # Just pass in a reference to an empty table (not nil) in factorio mod `global`. Same table can be used for all settings and container names.
---@return boolean|number|string|nil
SettingsManager.GetSettingValueForId = function(globalGroupsContainer, id, globalSettingContainerName, globalSettingName, defaultSettingsContainer)
    ---@cast defaultSettingsContainer UtilityMultipleValuesInSettings_DefaultSettingsContainer # Done so that the function's type is clear when calling.
    ---@cast globalGroupsContainer UtilityMultipleValuesInSettings_GlobalGroupsContainer # Done so that the function's type is clear when calling.
    local thisGroup = globalGroupsContainer[id]
    if thisGroup ~= nil and thisGroup[globalSettingContainerName] ~= nil and thisGroup[globalSettingContainerName][globalSettingName] ~= nil then
        return thisGroup[globalSettingContainerName][globalSettingName]
    end
    if defaultSettingsContainer ~= nil and defaultSettingsContainer[globalSettingName] ~= nil then
        return defaultSettingsContainer[globalSettingName]
    end
    error("Trying to get mod setting '" .. globalSettingName .. "' that doesn't exist")
end

----------------------------------------------------------------------------------
--                          PRIVATE FUNCTIONS
----------------------------------------------------------------------------------

--- Creates an entry in the global container for this setting name. Usually only used for testing as the main SettingsManager.HandleSettingWithArrayOfValues() handles this for standard use.
---@param globalGroupsContainer table # Just pass in a reference to an empty table (not nil) in factorio mod `global`. Same table can be used for all settings and container names.
---@param id uint # The occurrence number of the grouped settings.
---@param globalSettingContainerName 'settings'|string # A unique name for this group of settings. Not sure when you would want separate groups of settings as it would allow repeat instances of the same setting.
---@return UtilityMultipleValuesInSettings_GlobalGroupsContainerOccurrenceSetting occurrenceSettingGlobalGroupContainer # The created occurrence of the setting in the global container.
SettingsManager._CreateGlobalGroupSettingsContainer = function(globalGroupsContainer, id, globalSettingContainerName)
    ---@cast globalGroupsContainer UtilityMultipleValuesInSettings_GlobalGroupsContainer # Done so that the function's type is clear when calling.
    globalGroupsContainer[id] = globalGroupsContainer[id] or {}
    globalGroupsContainer[id][globalSettingContainerName] = globalGroupsContainer[id][globalSettingContainerName] or {}
    return globalGroupsContainer[id][globalSettingContainerName]
end

-- Strips any % characters from a number value to avoid silly user entry issues. Soft converts the supplied value in to the expected type (not sure if wise?).
---@param value string|number|boolean|table|string[]|number[]|boolean[]|table[]|nil
---@param expectedType UtilitySettingsManager_ExpectedValueType
---@return boolean|number|string|nil|table
SettingsManager._ValueToType = function(value, expectedType)
    if expectedType == SettingsManager.ExpectedValueTypes.string then
        if type(value) == "string" then
            return value
        else
            return nil
        end
    elseif expectedType == SettingsManager.ExpectedValueTypes.number then
        value = string.gsub(tostring(value), "%%", "")
        return tonumber(value)
    elseif expectedType == SettingsManager.ExpectedValueTypes.boolean then
        return BooleanUtils.ToBoolean(value--[[@as boolean|string|int]] )
    elseif expectedType.hasChildren then
        if type(value) ~= "table" then
            return nil
        end ---@cast value string[]|number[]|boolean[]|table[]

        local tableOfTypedValues = {} ---@type any[]
        for k, v in pairs(value) do
            local typedV = SettingsManager._ValueToType(v, expectedType.childExpectedValueType)
            if typedV ~= nil then
                tableOfTypedValues[k] = typedV
            else
                return nil
            end
        end
        return tableOfTypedValues
    end
end

return SettingsManager
