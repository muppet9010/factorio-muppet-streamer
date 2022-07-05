--[[
    All Lua table type related utils functions.
]]
--

local TableUtils = {}
local factorioUtil = require("__core__.lualib.util")
local string_rep = string.rep

--- Copies a table and all of its children all the way down.
---@type fun(object:table):table
TableUtils.DeepCopy = factorioUtil.table.deepcopy

--- Takes an array of tables and returns a new table with copies of their contents. Merges children when they are tables togeather, but non table data types will have the latest value as the result.
---@type fun(tables:table[]):table
TableUtils.TableMergeCopies = factorioUtil.merge

--- Takes an array of tables and returns a new table with references to their top level contents. Does a shallow merge, so just the top level key/values. Last duplicate key's value processed will be the final result.
---@param sourceTables table[]
---@return table mergedTable
TableUtils.TableMergeOrigionalsShallow = function(sourceTables)
    local mergedTable = {}
    for _, sourceTable in pairs(sourceTables) do
        for k in pairs(sourceTable) do
            mergedTable[k] = sourceTable[k]
        end
    end
    return mergedTable
end

---@param table table
---@return boolean
TableUtils.IsTableEmpty = function(table)
    if table == nil or next(table) == nil then
        return true
    else
        return false
    end
end

--- Count how many entries are in a table. It naturally excludes those that have a nil value.
---@param table table
---@return integer
TableUtils.GetTableNonNilLength = function(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

--- Generally this can be done inline, still included here as a reference to how to do this.
---@param table table
---@return StringOrNumber
TableUtils.GetFirstTableKey = function(table)
    return next(table)
end

--- Generally this can be done inline, still included here as a reference to how to do this.
---@param table table
---@return any
TableUtils.GetFirstTableValue = function(table)
    return table[next(table)]
end

---@param table table
---@return uint
TableUtils.GetMaxKey = function(table)
    local max_key = 0
    for k in pairs(table) do
        if k > max_key then
            max_key = k
        end
    end
    return max_key
end

---@param table table
---@param indexCount integer
---@return any
TableUtils.GetTableValueByIndexCount = function(table, indexCount)
    local count = 0
    for _, v in pairs(table) do
        count = count + 1
        if count == indexCount then
            return v
        end
    end
end

--- Makes a list of the input table's keys in their current order.
---@param aTable table
---@return StringOrNumber[]
TableUtils.TableKeyToArray = function(aTable)
    local newArray = {}
    for key in pairs(aTable) do
        table.insert(newArray, key)
    end
    return newArray
end

--- Makes a comma seperated text string from a table's keys. Includes spaces after each comma.
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.
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
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.
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
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.t
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
---@param aTable table @ doesn't support commas in values or nested tables. Really for logging.t
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
    return TableUtils._TableContentsToJSON(targetTable, name, singleLineOutput, tablesLogged)
end
TableUtils._TableContentsToJSON = function(targetTable, name, singleLineOutput, tablesLogged, indent, stopTraversing)
    local newLineCharacter = "\r\n"
    indent = indent or 1
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
                    local subStopTraversing = nil
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
                    local subStopTraversing = nil
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

---@param theTable table
---@param value StringOrNumber
---@param returnMultipleResults? boolean|nil @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList? boolean|nil @ Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return StringOrNumber[] @ table of keys.
TableUtils.GetTableKeyWithValue = function(theTable, value, returnMultipleResults, isValueAList)
    local keysFound = {}
    for k, v in pairs(theTable) do
        if not isValueAList then
            if v == value then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            if v == value then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        end
    end
    return keysFound
end

---@param theTable table
---@param innerKey StringOrNumber
---@param innerValue StringOrNumber
---@param returnMultipleResults? boolean|nil @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList? boolean|nil @ Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return StringOrNumber[] @ table of keys.
TableUtils.GetTableKeyWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults, isValueAList)
    local keysFound = {}
    for k, innerTable in pairs(theTable) do
        if not isValueAList then
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        else
            if innerTable[innerKey] ~= nil and innerTable[innerKey] == innerValue then
                if not returnMultipleResults then
                    return k
                end
                table.insert(keysFound, k)
            end
        end
    end
    return keysFound
end

---@param theTable table
---@param innerKey StringOrNumber
---@param innerValue StringOrNumber
---@param returnMultipleResults? boolean|nil @ Can return a single result (returnMultipleResults = false/nil) or a list of results (returnMultipleResults = true)
---@param isValueAList? boolean|nil @ Can have innerValue as a string/number (isValueAList = false/nil) or as a list of strings/numbers (isValueAList = true)
---@return table[] @ table of values, which must be a table to have an inner key/value.
TableUtils.GetTableValueWithInnerKeyValue = function(theTable, innerKey, innerValue, returnMultipleResults, isValueAList)
    local valuesFound = {}
    for _, innerTable in pairs(theTable) do
        if not isValueAList then
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

TableUtils.TableValuesToKey = function(tableWithValues)
    if tableWithValues == nil then
        return nil
    end
    local newTable = {}
    for _, value in pairs(tableWithValues) do
        newTable[value] = value
    end
    return newTable
end

TableUtils.TableInnerValueToKey = function(refTable, innerValueAttributeName)
    if refTable == nil then
        return nil
    end
    local newTable = {}
    for _, value in pairs(refTable) do
        newTable[value[innerValueAttributeName]] = value
    end
    return newTable
end

return TableUtils
