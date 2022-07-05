--- Library functions to help manage adding and handling Factorio commands.
--- Requires the utility "constants" file to be populated within the root of the mod.

local Commands = {}
local BooleanUtils = require("utility.boolean-utils")
local Constants = require("constants")
local Colors = require("utility.colors")

--- Register a function to be triggered when a command is run. Includes support to restrict usage to admins.
---
--- Call from OnLoad and will remove any existing identically named command so no risk of double registering error.
---
--- When the command is run the ComamndFunction recieves a single argument of type "CustomCommandData".
---@param name string
---@param helpText LocalisedString
---@param commandFunction function
---@param adminOnly boolean
Commands.Register = function(name, helpText, commandFunction, adminOnly)
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
Commands.GetArgumentsFromCommand = function(parameterString)
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
                        table.insert(args, Commands._StringToTypedObject(currentString))
                        currentString = ""
                    end
                else
                    currentString = currentString .. char
                end
            elseif not inQuotedString and char == " " then
                if currentString ~= "" then
                    table.insert(args, Commands._StringToTypedObject(currentString))
                    currentString = ""
                end
            elseif inQuotedString then
                if char == escapeChar then
                    prevCharEscape = true
                else
                    if char == closeChar and not prevCharEscape then
                        inQuotedString = false
                        table.insert(args, Commands._StringToTypedObject(currentString))
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
                    table.insert(args, Commands._StringToTypedObject(currentString))
                    currentString = ""
                end
            end
        end
    end
    if currentString ~= "" then
        table.insert(args, Commands._StringToTypedObject(currentString))
    end

    return args
end

--- Parses a command's generic argument and checks it is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any
---@param requiredType table|boolean|string|number @ The type of value we want.
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName string @ The argument name in its hierachy. Used in error messages.
---@return boolean argumentValid
Commands.ParseGenericArgument = function(value, requiredType, mandatory, commandName, argumentName)
    if mandatory and value == nil then
        -- Mandatory and not provided so fail.
        game.print(Constants.ModFriendlyName .. " - command " .. commandName .. " required " .. argumentName .. " to be populated.", Colors.red)
        return false
    elseif mandatory or (not mandatory and value ~= nil) then
        -- Is either mandatory and not nil (implicit), or not mandatory and is provided, so check it both ways.

        -- Check the type and handle the results.
        if type(value) ~= requiredType then
            -- Wrong type so fail.
            game.print(Constants.ModFriendlyName .. " - command " .. commandName .. " required " .. argumentName .. " to be of type " .. requiredType .. " when provided.", Colors.red)
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

--- Parses a command's argument and checks it is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any
---@param requiredType "'double'"|"'integer'" @ The specific number type we want.
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName string @ The argument name in its hierachy. Used in error messages.
---@param numberMinLimit? number|nil @ An optional minimum allowed value can be specified.
---@param numberMaxLimit? number|nil @ An optional maximum allowed value can be specified.
---@return boolean argumentValid
Commands.ParseNumberArgument = function(value, requiredType, mandatory, commandName, argumentName, numberMinLimit, numberMaxLimit)
    -- Check its valid for generic requirements first.
    if not Commands.ParseGenericArgument(value, "number", mandatory, commandName, argumentName) then
        return false
    end

    -- If value is nil and it passed the generic requirements which handles mandatory then end this parse successfully.
    if value == nil then
        return true
    end

    local isWrongType = false

    -- If theres a specific fake type check that first.
    if requiredType == "integer" then
        -- Theres no check for a double as that can be anything.
        if math.floor(value) ~= value then
            -- Not an integer.
            isWrongType = true
        end
        if isWrongType then
            game.print(Constants.ModFriendlyName .. " - command " .. commandName .. " required " .. argumentName .. " to be of type " .. requiredType .. " when provided.", Colors.red)
            return false
        end
    end

    -- Check if the number is within limits, if restrictions are provided.
    if numberMinLimit ~= nil and value < numberMinLimit then
        isWrongType = true
    end
    if numberMaxLimit ~= nil and value > numberMaxLimit then
        isWrongType = true
    end
    if isWrongType then
        game.print(Constants.ModFriendlyName .. " - command " .. commandName .. " - argument " .. argumentName .. " must be between " .. numberMinLimit .. " and " .. numberMaxLimit, Colors.red)
        return false
    end

    return true
end

--- Parses a command's string argument and checks it is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName string @ The argument name in its hierachy. Used in error messages.
---@param allowedStrings? table<string, any>|nil @ A limited array of allowed strings can be specified as a table of string keys with non nil values.
---@return boolean argumentValid
Commands.ParseStringArgument = function(value, mandatory, commandName, argumentName, allowedStrings)
    -- Check its valid for generic requirements first.
    if not Commands.ParseGenericArgument(value, "string", mandatory, commandName, argumentName) then
        return false
    end

    -- If value is nil and it passed the generic requirements which handles mandatory then end this parse successfully.
    if value == nil then
        return true
    end

    -- Check the value is in the allowed strings requirement if provided.
    if allowedStrings ~= nil then
        if allowedStrings[value] == nil then
            game.print(Constants.ModFriendlyName .. " - command " .. commandName .. " - argument " .. argumentName .. " must be one of the allowed text strings.", Colors.red)
            return false
        end
    end

    return true
end

--- Parses a command's table argument and checks it is the required type and is provided if mandatory. Gets the mod name from Constants.ModFriendlyName.
---@param value any
---@param mandatory boolean
---@param commandName string @ The ingame commmand name. Used in error messages.
---@param argumentName string @ The argument name in its hierachy. Used in error messages.
---@param allowedKeys? table<string, any>|nil @ A limited array of allowed keys of the table can be specified as a table of string keys with non nil values.
---@return boolean argumentValid
Commands.ParseTableArgument = function(value, mandatory, commandName, argumentName, allowedKeys)
    -- Check its valid for generic requirements first.
    if not Commands.ParseGenericArgument(value, "table", mandatory, commandName, argumentName) then
        return false
    end

    -- If value is nil and it passed the generic requirements which handles mandatory then end this parse successfully.
    if value == nil then
        return true
    end

    -- Check the value's keys are in the allowed key requirement if provided.
    if allowedKeys ~= nil then
        for key in pairs(value) do
            if allowedKeys[key] == nil then
                game.print(Constants.ModFriendlyName .. " - command " .. commandName .. " - argument " .. argumentName .. " includes a non supported key: " .. tostring(key), Colors.red)
                return false
            end
        end
    end

    return true
end

--- Internal commands function that returns the input text as its correct type.
---@param inputText string
---@return nil|number|boolean|table|string typedValue
Commands._StringToTypedObject = function(inputText)
    if inputText == "nil" then
        return nil
    end
    local castedText = tonumber(inputText)
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

return Commands
