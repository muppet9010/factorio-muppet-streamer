--[[
    All Lua table type related utils functions.
]]
--

local TableUtils = {} ---@class Utility_TableUtils
local string_rep = string.rep

--- Copies a table and all of its children all the way down.
--- Based on code from Factorio "__core__.lualib.util.lua", table.deepcopy().
---@param object table @ The object to copy.
---@return table
TableUtils.DeepCopy = function(object)
    local lookup_table = {} ---@type table<any, any>
    return TableUtils._DeepCopy_InnerCopy(object, lookup_table)
end

--- Takes an array of tables and returns a new table with copies of their contents. Merges children when they are tables togeather, but non table data types will have the latest value as the result.
--- Based on code from Factorio "__core__.lualib.util.lua", util.merge().
---@param tables table<any, any>[]
---@return table mergedTable
TableUtils.TableMergeCopies = function(tables)
    local ret = {} ---@type table<any, any>
    for _, table in ipairs(tables) do
        for k, v in pairs(table) do
            if (type(v) == "table") then
                if (type(ret[k] or false) == "table") then
                    ret[k] = TableUtils.TableMergeCopies {ret[k], v}
                else
                    ret[k] = TableUtils.DeepCopy(v)
                end
            else
                ret[k] = v
            end
        end
    end
    return ret
end

--- Takes an array of tables and returns a new table with references to their top level contents. Does a shallow merge, so just the top level key/values. Last duplicate key's value processed will be the final result.
---@param sourceTables table<any,any>[]
---@return table mergedTable
TableUtils.TableMergeOrigionalsShallow = function(sourceTables)
    local mergedTable = {} ---@type table<any, any>
    for _, sourceTable in pairs(sourceTables) do
        for k in pairs(sourceTable) do
            mergedTable[k] = sourceTable[k]
        end
    end
    return mergedTable
end

--- Checks if a table is empty or not. A nil value table is considered empty.
---@param aTable table
---@return boolean
TableUtils.IsTableEmpty = function(aTable)
    if aTable == nil or next(aTable) == nil then
        return true
    else
        return false
    end
end

--- Count how many entries are in a table. It naturally excludes those that have a nil value.
---@param aTable table<any,any>
---@return int
TableUtils.GetTableNonNilLength = function(aTable)
    local count = 0
    for _ in pairs(aTable) do
        count = count + 1
    end
    return count
end

--- Generally this can be done inline, still included here as a reference to how to do this.
---@param aTable table
---@return string|number
TableUtils.GetFirstTableKey = function(aTable)
    return next(aTable)
end

--- Generally this can be done inline, still included here as a reference to how to do this.
---@param aTable table
---@return any
TableUtils.GetFirstTableValue = function(aTable)
    return aTable[next(aTable)]
end

--- Get the maximum key in a table of gappy keys (not sequential where # would work).
---@param aTable table<any,any>
---@return uint
TableUtils.GetMaxKey = function(aTable)
    local max_key = 0
    for k in pairs(aTable) do
        if k > max_key then
            max_key = k
        end
    end
    return max_key
end

-- Get the X (indexCount) item in the table of a gappy list.
---@param aTable table<any,any>
---@param indexCount int
---@return any
TableUtils.GetTableValueByIndexCount = function(aTable, indexCount)
    local count = 0
    for _, v in pairs(aTable) do
        count = count + 1
        if count == indexCount then
            return v
        end
    end
end

--- Makes a list of the input table's keys in their current order.
---@param aTable table<any,any>
---@return string|number[]
TableUtils.TableKeyToArray = function(aTable)
    local newArray = {}
    for key in pairs(aTable) do
        table.insert(newArray, key)
    end
    return newArray
end

--- Makes a comma seperated text string from a table's keys. Includes spaces after each comma.
---@param aTable table<any,any> @ doesn't support commas in values or nested tables. Really for logging.
---@return string
TableUtils.TableKeyToCommaString = function(aTable)
    local newString
    if TableUtils.IsTableEmpty(aTable) then
        return ""
    end
    for key in pairs(aTable) do
        if newString == nil then
            newString = tostring(key)
        else
            newString = newString .. ", " .. tostring(key)
        end
    end
    return newString
end

--- Makes a comma seperated text string from a table's values. Includes spaces after each comma.
---@param aTable table<any,any> @ doesn't support commas in values or nested tables. Really for logging.
---@return string
TableUtils.TableValueToCommaString = function(aTable)
    local newString
    if TableUtils.IsTableEmpty(aTable) then
        return ""
    end
    for _, value in pairs(aTable) do
        if newString == nil then
            newString = tostring(value)
        else
            newString = newString .. ", " .. tostring(value)
        end
    end
    return newString
end

--- Makes a numbered text string from a table's keys with the keys wrapped in single quotes.
---
--- i.e. 1: 'firstKey', 2: 'secondKey'
---@param aTable table<any,any> @ doesn't support commas in values or nested tables. Really for logging.t
---@return string
TableUtils.TableKeyToNumberedListString = function(aTable)
    local newString
    if TableUtils.IsTableEmpty(aTable) then
        return ""
    end
    local count = 1
    for key in pairs(aTable) do
        if newString == nil then
            newString = count .. ": '" .. tostring(key) .. "'"
        else
            newString = newString .. ", " .. count .. ": '" .. tostring(key) .. "'"
        end
        count = count + 1
    end
    return newString
end

--- Makes a numbered text string from a table's values with the values wrapped in single quotes.
---
--- i.e. 1: 'firstValue', 2: 'secondValue'
---@param aTable table<any,any> @ doesn't support commas in values or nested tables. Really for logging.t
---@return string
TableUtils.TableValueToNumberedListString = function(aTable)
    local newString
    if TableUtils.IsTableEmpty(aTable) then
        return ""
    end
    local count = 1
    for _, value in pairs(aTable) do
        if newString == nil then
            newString = count .. ": '" .. tostring(value) .. "'"
        else
            newString = newString .. ", " .. count .. ": '" .. tostring(value) .. "'"
        end
    end
    return newString
end

-- Stringify a table in to a JSON text string. Options to make it pretty printable.
---@param targetTable table
---@param name? string|nil @ If provided will appear as a "name:JSONData" output.
---@param singleLineOutput? boolean|nil @ If provided and true removes all lines and spacing from the output.
---@return string
TableUtils.TableContentsToJSON = function(targetTable, name, singleLineOutput)
    singleLineOutput = singleLineOutput or false
    local tablesLogged = {}
    return TableUtils._TableContentsToJSON(targetTable, name, singleLineOutput, tablesLogged, 1, false)
end

--- Searches a table of values for a specific value and returns the key(s) of that entry.
---@param theTable table<any,any>
---@param value string|number|string|number[] @ Either a single value or an array of possible values.
---@param returnMultipleResults? boolean|nil @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@return string|number[] @ table of keys.
TableUtils.GetTableKeyWithValue = function(theTable, value, returnMultipleResults)
    local keysFound = {}
    for k, v in pairs(theTable) do
        if type(value) ~= "table" then
            if v == value then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            for _, valueInList in pairs(value) do
                if v == value then
                    if not returnMultipleResults then
                        return k
                    end
                    table.insert(keysFound, k)
                end
            end
        end
    end
    return keysFound
end

--- Searches a table of tables and looks inside the inner table at a specific key for a specific value and returns the key(s) of the outer table entry.
---@param theTable table<any,any>
---@param innerKey string|number
---@param innerValue string|number|string|number[] @ Either a single value or an array of possible values.
---@param returnMultipleResults? boolean|nil @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@return string|number[] @ table of keys.
TableUtils.GetTableKeyWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults)
    local keysFound = {}
    for k, innerTable in pairs(theTable) do
        if type(innerValue) ~= "table" then
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            for _, valueInList in pairs(innerValue) do
                if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                    if not returnMultipleResults then
                        return k
                    end
                    table.insert(keysFound, k)
                end
            end
        end
    end
    return keysFound
end

--- Searches a table of tables and looks inside the inner table at a specific key for a specific value(s) and returns the value(s) of the outer table entry.
---@param theTable table<any,any>
---@param innerKey string|number
---@param innerValue string|number|string|number[] @ Either a single value or an array of possible values.
---@param returnMultipleResults? boolean|nil @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@return table[] @ table of values, which must be a table to have an inner key/value.
TableUtils.GetTableValueWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults)
    local valuesFound = {}
    for _, innerTable in pairs(theTable) do
        if type(innerValue) ~= "table" then
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return innerTable
                end
                table.insert(valuesFound, innerTable)
            end
        else
            for _, valueInList in pairs(innerValue) do
                if innerTable[innerKey] ~= nil and innerTable[innerKey] == valueInList then
                    if not returnMultipleResults then
                        return innerTable
                    end
                    table.insert(valuesFound, innerTable)
                end
            end
        end
    end
    return valuesFound
end

--- Returns a copy of a table's values with each value also being the key. Doesn't clone any internal data structures, so use on tables of tables with care.
---
--- Useful for converting a list in to dictionary of the list items.
---@param tableWithValues table<any,any>|nil
---@return table|nil tableOfKeys @ Returns nil when nil is passed in.
TableUtils.TableValuesToKey = function(tableWithValues)
    if tableWithValues == nil then
        return nil
    end
    local newTable = {} ---@type table<any, any>
    for _, value in pairs(tableWithValues) do
        newTable[value] = value
    end
    return newTable
end

--- Returns a copy of a table's values with each value's named inner key's (innerValueAttributeName) value also being the key. Doesn't clone any internal data structures, so use on tables of tables with care.
---
--- Useful for converting a list of objects in to dictionary of the list items's with a specific inner field being the new dictionary key.
---@param refTable table<any,any>|nil
---@param innerValueAttributeName any
---@return table|nil
TableUtils.TableInnerValueToKey = function(refTable, innerValueAttributeName)
    if refTable == nil then
        return nil
    end
    local newTable = {} ---@type table<any, any>
    for _, value in pairs(refTable) do
        newTable[value[innerValueAttributeName]] = value
    end
    return newTable
end

----------------------------------------------------------------------------------
--                          PRIVATE FUNCTIONS
----------------------------------------------------------------------------------

--- Inner looping of DeepCopy. Kept as seperate function as then its a copy of Factorio core utils.
---@param object any
---@param lookup_table table<any, any>
---@return any
TableUtils._DeepCopy_InnerCopy = function(object, lookup_table)
    if type(object) ~= "table" then
        -- don't copy factorio rich objects
        return object
    elseif object.__self then
        return object
    elseif lookup_table[object] then
        return lookup_table[object]
    end ---@cast object table<any, any>
    local new_table = {} ---@type table<any, any>
    lookup_table[object] = new_table
    for index, value in pairs(object) do
        new_table[TableUtils._DeepCopy_InnerCopy(index, lookup_table)] = TableUtils._DeepCopy_InnerCopy(value, lookup_table)
    end
    return setmetatable(new_table, getmetatable(object))
end

--- Inner looping of TableContentsToJSON.
---@param targetTable table<any, any>
---@param name? string|nil @ If provided will appear as a "name:JSONData" output.
---@param singleLineOutput boolean
---@param tablesLogged table<any, any>
---@param indent uint @ Pass a default of 1 on initial calling.
---@param stopTraversing boolean @ Pass a default of false on initial calling.
---@return string
TableUtils._TableContentsToJSON = function(targetTable, name, singleLineOutput, tablesLogged, indent, stopTraversing)
    local newLineCharacter = "\r\n"
    local indentstring = string_rep(" ", (indent * 4))
    if singleLineOutput then
        newLineCharacter = ""
        indentstring = ""
    end
    tablesLogged[targetTable] = "logged"
    local table_contents = ""
    if TableUtils.GetTableNonNilLength(targetTable) > 0 then
        for k, v in pairs(targetTable) do
            local key, value
            if type(k) == "string" or type(k) == "number" or type(k) == "boolean" then -- keys are always strings
                key = '"' .. tostring(k) .. '"'
            elseif type(k) == "nil" then
                key = '"nil"'
            elseif type(k) == "table" then
                if stopTraversing == true then
                    key = '"CIRCULAR LOOP TABLE"'
                else
                    local subStopTraversing
                    if tablesLogged[k] ~= nil then
                        subStopTraversing = true
                    end
                    key = "{" .. newLineCharacter .. TableUtils._TableContentsToJSON(k, name, singleLineOutput, tablesLogged, indent + 1, subStopTraversing) .. newLineCharacter .. indentstring .. "}"
                end
            elseif type(k) == "function" then
                key = '"' .. tostring(k) .. '"'
            else
                key = '"unhandled type: ' .. type(k) .. '"'
            end
            if type(v) == "string" then
                value = '"' .. tostring(v) .. '"'
            elseif type(v) == "number" or type(v) == "boolean" then
                value = tostring(v)
            elseif type(v) == "nil" then
                value = '"nil"'
            elseif type(v) == "table" then
                if stopTraversing == true then
                    value = '"CIRCULAR LOOP TABLE"'
                else
                    local subStopTraversing
                    if tablesLogged[v] ~= nil then
                        subStopTraversing = true
                    end
                    value = "{" .. newLineCharacter .. TableUtils._TableContentsToJSON(v, name, singleLineOutput, tablesLogged, indent + 1, subStopTraversing) .. newLineCharacter .. indentstring .. "}"
                end
            elseif type(v) == "function" then
                value = '"' .. tostring(v) .. '"'
            else
                value = '"unhandled type: ' .. type(v) .. '"'
            end
            if table_contents ~= "" then
                table_contents = table_contents .. "," .. newLineCharacter
            end
            table_contents = table_contents .. indentstring .. tostring(key) .. ":" .. tostring(value)
        end
    else
        table_contents = indentstring .. ""
    end
    if indent == 1 then
        local resultString = ""
        if name ~= nil then
            resultString = '"' .. name .. '":'
        end
        resultString = resultString .. "{" .. newLineCharacter .. table_contents .. newLineCharacter .. "}"
        return resultString
    else
        return table_contents
    end
end

return TableUtils
