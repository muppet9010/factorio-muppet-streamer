--- Library functions to help manage adding and handling Factorio commands.
--- Requires the utility "constants" file to be populated within the root of the mod.

local CommandsUtils = {}
local BooleanUtils = require("utility.helper-utils.boolean-utils")
local Constants = require("constants")
local Colors = require("utility.lists.colors")
local TableUtils = require("utility.helper-utils.table-utils")
local LoggingUtils = require("utility.helper-utils.logging-utils")

--- Register a function to be triggered when a command is run. Includes support to restrict usage to admins.
---
--- Call from OnLoad and will remove any existing identically named command so no risk of double registering error.
---
--- When the command is run the ComamndFunction recieves a single argument of type "CustomCommandData".
---@param name string
---@param helpText LocalisedString
---@param commandFunction function
---@param adminOnly boolean
CommandsUtils.Register = function(name, helpText, commandFunction, adminOnly)
    commands.remove_command(name)
    local handlerFunction
    if not adminOnly then
        handlerFunction = commandFunction
    elseif adminOnly then
        handlerFunction = function(data)
            if data.player_index == nil then
                commandFunction(data)
            else
                local player = game.get_player(data.player_index)
                if player.admin then
                    commandFunction(data)
                else
                    player.print("Must be an admin to run command: " .. data.name, Colors.red)
                end
            end
        end
    end
    commands.add_command(name, helpText, handlerFunction)
end

--- Breaks out the various arguments from a command's single parameter string. Each argument will be converted in to its appropriate type.
---
--- Supports multiple string arguments seperated by a space as a commands parameter. Can use pairs of single or double quotes to define the start and end of an argument string with spaces in it. Supports JSON array [] and dictionary {} of N depth and content characters.
---
--- String quotes can be escaped by "\"" within their own quote type, ie: 'don\'t' will come out as "don't". Note the same quote type rule, i.e. "don\'t" will come out as "don\'t" . Otherwise the escape character \ wil be passed through as regular text.
---@param parameterString string
---@return any[] arguments
CommandsUtils.GetArgumentsFromCommand = function(parameterString)
    local args = {}
    if parameterString == nil or parameterString == "" or parameterString == " " then
        return args
    end
    local openCloseChars = {
        ["{"] = "}",
        ["["] = "]",
        ['"'] = '"',
        ["'"] = "'"
    }
    local escapeChar = "\\"

    local currentString, inQuotedString, inJson, openChar, closeChar, jsonSteppedIn, prevCharEscape = "", false, false, "", "", 0, false
    for char in string.gmatch(parameterString, ".") do
        if not inJson then
            if char == "{" or char == "[" then
                inJson = true
                openChar = char
                closeChar = openCloseChars[openChar]
                currentString = char
            elseif not inQuotedString and char ~= " " then
                if char == '"' or char == "'" then
                    inQuotedString = true
                    openChar = char
                    closeChar = openCloseChars[openChar]
                    if currentString ~= "" then
                        table.insert(args, CommandsUtils._StringToTypedObject(currentString))
                        currentString = ""
                    end
                else
                    currentString = currentString .. char
                end
            elseif not inQuotedString and char == " " then
                if currentString ~= "" then
                    table.insert(args, CommandsUtils._StringToTypedObject(currentString))
                    currentString = ""
                end
            elseif inQuotedString then
                if char == escapeChar then
                    prevCharEscape = true
                else
                    if char == closeChar and not prevCharEscape then
                        inQuotedString = false
                        table.insert(args, CommandsUtils._StringToTypedObject(currentString))
                        currentString = ""
                    elseif char == closeChar and prevCharEscape then
                        prevCharEscape = false
                        currentString = currentString .. char
                    elseif prevCharEscape then
                        prevCharEscape = false
                        currentString = currentString .. escapeChar .. char
                    else
                        currentString = currentString .. char
                    end
                end
            end
        else
            currentString = currentString .. char
            if char == openChar then
                jsonSteppedIn = jsonSteppedIn + 1
            elseif char == closeChar then
                if jsonSteppedIn > 0 then
                    jsonSteppedIn = jsonSteppedIn - 1
                else
                    inJson = false
                    table.insert(args, CommandsUtils._StringToTypedObject(currentString))
                    currentString = ""
                end
            end
        end
    end
    if currentString ~= "" then
        table.insert(args, CommandsUtils._StringToTypedObject(currentString))
    end

    return args
end

--- Prints and logs a command error in the same style as other command setting/argument errors are handled.
---@param commandName string @ The ingame commmand name.
---@param argumentName? string|nil @ The setting name if wanted to be included in error.
---@param errorText string @ If starts without a leading space one will be added.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
CommandsUtils.LogPrintError = function(commandName, argumentName, errorText, commandString)
    CommandsUtils._LogPrint(LoggingUtils.LogPrintError, commandName, argumentName, errorText, commandString)
end

--- Prints and logs a command warning in the same style as other command setting/argument errors are handled.
---@param commandName string @ The ingame commmand name.
---@param argumentName? string|nil @ The setting name if wanted to be included in error.
---@param errorText string @ If starts without a leading space one will be added.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
CommandsUtils.LogPrintWarning = function(commandName, argumentName, errorText, commandString)
    CommandsUtils._LogPrint(LoggingUtils.LogPrintWarning, commandName, argumentName, errorText, commandString)
end

--- Gets the commands parameter string as a table of values. Used when a command only takes a single argument object and that is a table of options.
---@param commandParamaterString string|nil @ The text string passed in on the command.
---@param mandatory boolean @ If false then passign in nothing won't flag an error message, but will still error on malformed text string.
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param allowedSettingNames string[] @ The setting names that are allowed in this command. Warns (not errors) about any that aren't expected. The values of this table are read as its a list of strings (done for easier calling of the function).
---@return table<string, any>|nil dataTable @ The dataTable of arguments or nil if invalid or none provided.
CommandsUtils.GetSettingsTableFromCommandParamaterString = function(commandParamaterString, mandatory, commandName, allowedSettingNames)
    commandParamaterString = commandParamaterString or ""
    local dataTable = game.json_to_table(commandParamaterString)

    -- If populated check its valid.
    if commandParamaterString ~= "" and dataTable == nil then
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " requires details in JSON format when provided.")
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandParamaterString)
        return nil
    end

    -- If mandatory check its populated.
    if mandatory and dataTable == nil then
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " requires details to be populated.")
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandParamaterString)
        return nil
    end

    -- If its not mandatory and not populated then its fine.
    if not mandatory and dataTable == nil then
        return nil
    end

    -- Check its a table.
    if type(dataTable) ~= "table" then
        -- Wrong type so fail.
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " requires details to be a table in JSON format. Received type " .. type(dataTable) .. " instead.")
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandParamaterString)
        return nil
    end ---@cast dataTable table<string, any>

    -- Flag any unexpected setting names. This doesn;t cause a nil return and so the command can try and continue with this setting being ignored.
    for inputSettingName in pairs(dataTable) do
        local keyFound = false
        for _, allowedSettingName in pairs(allowedSettingNames) do
            if allowedSettingName == inputSettingName then
                keyFound = true
                break
            end
        end

        if not keyFound then
            LoggingUtils.LogPrintWarning(Constants.ModFriendlyName .. " - command " .. commandName .. " received an unsupported setting that will be ignored: " .. tostring(inputSettingName))
            if TableUtils.GetTableNonNilLength(allowedSettingNames) < 20 then
                LoggingUtils.LogPrintWarning("Allowed settings are: " .. TableUtils.TableValueToCommaString(allowedSettingNames))
            else
                LoggingUtils.LogPrintWarning("Allowed settings list is too long to show here. See mod documentation")
            end
            LoggingUtils.LogPrintWarning(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandParamaterString)
        end
    end

    return dataTable
end

--- Check a command's argument value is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName. Does not convert strings to numbers.
---@param value any @ Will accept any data type and validate it.
---@param requiredType "'double'"|"'int'" @ The specific number type we want.
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName? string|nil @ The argument name in its hierachy. Used in error messages.
---@param numberMinLimit? double|nil @ An optional minimum allowed value can be specified.
---@param numberMaxLimit? double|nil @ An optional maximum allowed value can be specified.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
---@return boolean argumentValid
CommandsUtils.CheckNumberArgument = function(value, requiredType, mandatory, commandName, argumentName, numberMinLimit, numberMaxLimit, commandString)
    -- Check its valid for generic requirements first.
    if not CommandsUtils.CheckGenericArgument(value, "number", mandatory, commandName, argumentName, commandString) then
        return false
    end ---@cast value double|nil

    -- If value is nil and it passed the generic requirements which checks mandatory if needed, then end this parse successfully.
    if value == nil then
        return true
    end ---@cast value double

    -- If theres a specific fake type check that first.
    -- Theres no check for a double as that can be anything.
    if requiredType == "int" then
        local isWrongType = false

        if math.floor(value) ~= value then
            -- Not an int.
            isWrongType = true
        end

        if isWrongType then
            LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " required '" .. argumentName .. "' to be of type '" .. requiredType .. "' when provided. Received type '" .. "double" .. "' instead.")
            if commandString ~= nil then
                LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
            end
            return false
        end
    end

    -- Check if the number is within limits, if restrictions are provided.
    local numberOutsideLimits = false
    if numberMinLimit ~= nil and value < numberMinLimit then
        numberOutsideLimits = true
    end
    if numberMaxLimit ~= nil and value > numberMaxLimit then
        numberOutsideLimits = true
    end
    if numberOutsideLimits then
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. (argumentName and " - argument '" .. argumentName .. "'" or "") .. "' must be between " .. numberMinLimit .. " and " .. numberMaxLimit .. ". Received value of '" .. value .. "' instead.")
        return false
    end

    return true
end

--- Check a command's string argument value is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any @ Will accept any data type and validate it.
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName? string|nil @ The argument name in its hierachy. Used in error messages.
---@param allowedStrings? table<string, any>|nil @ A limited array of allowed strings can be specified as a table of string keys with non nil values. Designed to recieve an enum type object.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
---@return boolean argumentValid
CommandsUtils.CheckStringArgument = function(value, mandatory, commandName, argumentName, allowedStrings, commandString)
    --View blank strings equal to nil.
    if value == "" then
        value = nil
    end

    -- Check its valid for generic requirements first.
    if not CommandsUtils.CheckGenericArgument(value, "string", mandatory, commandName, argumentName, commandString) then
        return false
    end ---@cast value string|nil

    -- If value is nil and it passed the generic requirements which handles mandatory then end this parse successfully.
    if value == nil then
        return true
    end ---@cast value string

    -- Check the value is in the allowed strings requirement if provided.
    if allowedStrings ~= nil then
        if allowedStrings[value] == nil then
            LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. (argumentName and " - argument '" .. argumentName .. "'" or "") .. "' must be one of the allowed text strings.")
            if TableUtils.GetTableNonNilLength(allowedStrings) < 20 then
                LoggingUtils.LogPrintError("Allowed text strings are: " .. TableUtils.TableKeyToCommaString(allowedStrings))
            else
                LoggingUtils.LogPrintError("Allowed strings list is too long to list here. See mod documentation")
            end
            if commandString ~= nil then
                LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
            end
            return false
        end
    end

    return true
end

--- Check a command's boolean argument value is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any @ Will accept any data type and validate it.
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName? string|nil @ The argument name in its hierachy. Used in error messages.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
---@return boolean argumentValid
CommandsUtils.CheckBooleanArgument = function(value, mandatory, commandName, argumentName, commandString)
    -- Check its valid for generic requirements first.
    if not CommandsUtils.CheckGenericArgument(value, "boolean", mandatory, commandName, argumentName, commandString) then
        return false
    end ---@cast value boolean|nil

    -- If value is nil and it passed the generic requirements which handles mandatory then end this parse successfully.
    if value == nil then
        return true
    end ---@cast value boolean

    return true
end

--- Check a command's table argument value is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any @ Will accept any data type and validate it.
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName? string|nil @ The argument name in its hierachy. Used in error messages.
---@param allowedKeys? table<string, any>|nil @ A limited array of allowed keys of the table can be specified as a table of string keys with non nil values. Designed to recieve an enum type object.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
---@return boolean argumentValid
CommandsUtils.CheckTableArgument = function(value, mandatory, commandName, argumentName, allowedKeys, commandString)
    -- Check its valid for generic requirements first.
    if not CommandsUtils.CheckGenericArgument(value, "table", mandatory, commandName, argumentName, commandString) then
        return false
    end ---@cast value table|nil

    -- If value is nil and it passed the generic requirements which handles mandatory then end this parse successfully.
    if value == nil then
        return true
    end ---@cast value table<any, any>

    -- Check the value's keys are in the allowed key requirement if provided.
    if allowedKeys ~= nil then
        for key in pairs(value) do
            if type(key) ~= "string" then
                LoggingUtils.LogPrintError("Invalid keys data type, expects string keys but got a '" .. type(key) .. "' with the value of: " .. tostring(key))
                if commandString ~= nil then
                    LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
                end
                return false
            end
            if allowedKeys[key] == nil then
                LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. (argumentName and " - argument '" .. argumentName .. "'" or "") .. " includes a non supported key: " .. tostring(key))
                if TableUtils.GetTableNonNilLength(allowedKeys) < 20 then
                    LoggingUtils.LogPrintError("Allowed keys are: " .. TableUtils.TableKeyToCommaString(allowedKeys))
                else
                    LoggingUtils.LogPrintError("Allowed keys list is too long to list here. See mod documentation")
                end
                if commandString ~= nil then
                    LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
                end
                return false
            end
        end
    end

    return true
end

--- Check a command's generic argument value is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any @ Will accept any data type and validate it.
---@param requiredType table|boolean|string|number @ The type of value we want.
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName? string|nil @ The argument name in its hierachy. Used in error messages.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
---@return boolean argumentValid
CommandsUtils.CheckGenericArgument = function(value, requiredType, mandatory, commandName, argumentName, commandString)
    if mandatory and value == nil then
        -- Mandatory and not provided so fail.
        LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " required '" .. argumentName .. "' to be populated.")
        if commandString ~= nil then
            LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
        end
        return false
    elseif mandatory or (not mandatory and value ~= nil) then
        -- Is either mandatory and not nil (implicit), or not mandatory and is provided, so check it both ways.

        -- Check the type and handle the results.
        if type(value) ~= requiredType then
            -- Wrong type so fail.
            LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " required '" .. argumentName .. "' to be of type '" .. requiredType .. "' when provided. Received type '" .. type(value) .. "' instead.")
            if commandString ~= nil then
                LoggingUtils.LogPrintError(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
            end
            return false
        else
            -- Right type
            return true
        end
    else
        -- Not mandatory and value is nil. So its a non provided optional argument.
        return true
    end
end

----------------------------------------------------------------------------------
--                          PRIVATE FUNCTIONS
----------------------------------------------------------------------------------

--- Internal commands function that returns the input text as its correct type.
---@param inputText string
---@return nil|number|boolean|table|string typedValue
CommandsUtils._StringToTypedObject = function(inputText)
    if inputText == "nil" then
        return nil
    end
    local castedText = tonumber(inputText) ---@type nil|number|boolean|table|string
    if castedText ~= nil then
        return castedText
    end
    castedText = BooleanUtils.ToBoolean(inputText)
    if castedText ~= nil then
        return castedText
    end

    -- Only try to handle JSON to table conversation if it looks like a JSON string. The games built in conversation handler can return some non JSON things as other basic types, but with some special characters being stripped in the process.
    local firstCharacter = string.sub(inputText, 1, 1)
    if firstCharacter == "{" or firstCharacter == "[" then
        castedText = game.json_to_table(inputText)
        if castedText ~= nil then
            return castedText
        end
    end

    return inputText
end

--- Prints and logs a command error/warning using the provided logging function in the same style as other command setting/argument errors are handled.
---@param logprintFunction function @ The logging function to use.
---@param commandName string @ The ingame commmand name.
---@param argumentName? string|nil @ The setting name if wanted to be included in error.
---@param errorText string @ If starts without a leading space one will be added.
---@param commandString? string|nil @ If provided it will be included in error messages. Not needed for operational use.
CommandsUtils._LogPrint = function(logprintFunction, commandName, argumentName, errorText, commandString)
    if string.sub(errorText, 1, 1) ~= "" then
        errorText = " " .. errorText
    end

    local text = Constants.ModFriendlyName .. " - command " .. commandName .. (argumentName and " - argument '" .. argumentName .. "'" or "") .. errorText
    logprintFunction(text)

    if commandString ~= nil and commandString ~= "" then
        logprintFunction(Constants.ModFriendlyName .. " - command " .. commandName .. " recieved text: " .. commandString)
    end
end

return CommandsUtils
