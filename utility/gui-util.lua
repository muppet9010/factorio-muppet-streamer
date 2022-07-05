-- Library to support making, storing and accessing GUI elements. Allows making GUIs via a templating layout with GuiUtil.AddElement().
-- Requires the utility "constants" file to be populated within the root of the mod.
-- Designed on the basis that the mod doesn't need to store references to the GUI Elements it creates and the structures involved with that. As they can all be obtained via the managed storage with the element name and type to improve code readability.

local GuiUtil = {}
local TableUtils = require("utility.table-utils")
local GuiActionsClick = require("utility.gui-actions-click")
local GuiActionsChecked = require("utility.gui-actions-checked")
local Logging = require("utility.logging")
local Constants = require("constants")
local StyleDataStyleVersion = require("utility.style-data").styleVersion

---@alias UtilityGuiUtil_StoreName string @ A named container that GUI elements have their references saved within under the GUI elements name and type. Used to provide logical seperation of GUI elements stored. Typically used for different GUis or major sections of a GUI, as the destroy GUI element functions can handle whole StoreNames automatically.
---@alias UtilityGuiUtil_GuiElementName string @ A generally unique string made by combining an elements name and type with mod name. However if storing references to the created elements within the libraries player element reference storage we need never obtain the GUI element by name and thus it doesn't have to be unique. Does need to be unique within the StoreName however. Format is: ModName-ElementName-ElementType ,i.e. "my_mod-topHeading-label".

--- Takes generally everything that GuiElement.add() accepts in Factorio API with the below key differences:
--- - Compulsory "parent" argument of who to create the GUI element under if it isn't a child element itself.
--- - Doesn't support the "name" attribute, but offers "descriptiveName" instead. See the attributes details.
---@class UtilityGuiUtil_ElementDetails_Add : UtilityGuiUtil_ElementDetails_LuaGuiElement.add_param
--- The GUI element this newly created element will be a child of. Not needed (ignored) if this ElementDetails is specificed as a child within another ElementDetails specification.
---@field parent? LuaGuiElement|nil
--- A descriptive name of the element. If provided will be automatically merged with the element's type and the mod name to make a semi unique reference name of type UtilityGuiUtil_GuiElementName that the GUI element will have as its "name" attribute.
---@field descriptiveName? string|nil
---@field storeName? UtilityGuiUtil_StoreName|nil
---@field style? UtilityGuiUtil_ElementDetails_style|nil
---@field styling? UtilityGuiUtil_ElementDetails_styling|nil
---@field caption? UtilityGuiUtil_ElementDetails_caption|nil
---@field tooltip? UtilityGuiUtil_ElementDetails_caption|nil
--- An array of other Element Details to recursively add in this hierachy. Parent argument isn't required for children and is ignored if provided for them as it's worked out during recursive loop of creating the children.
---@field children? UtilityGuiUtil_ElementDetails_Add[]|nil
---@field registerClick? UtilityGuiUtil_ElementDetails_registerClick|nil
---@field registerCheckedStateChange? UtilityGuiUtil_ElementDetails_registerCheckedStateChange|nil
--- If TRUE will return this Gui element when created in a table of elements with returnElement enabled. Key will be the elements UtilityGuiUtil_GuiElementName and the value a reference to the element. The UtilityGuiUtil_GuiElementName can be worked out by the calling function using GuiUtil.GenerateGuiElementName().
---
--- Defaults to FALSE if not provided.
---@field returnElement? boolean|nil
--- If TRUE will mean the GUI Element is ignored and not added. To allow more natural templating as the value can be pre-calculated and then applied to a standard template being passed in to this function to not include certain elements.
---
--- Defaults to FALSE if not provided.
---@field exclude? boolean|nil
---@field attributes? UtilityGuiUtil_ElementDetails_attributes|nil

---@class UtilityGuiUtil_ElementDetails_RegisterClickOption @ Option of ElementDetails for calling GuiActionsClick.RegisterGuiForClick() as part of the Gui element creation.
---@field actionName string @ The actionName of the registered function to be called when the GUI element is clicked.
---@field data table @ Any provided data will be passed through to the actionName's registered function upon the GUI element being clicked.
---@field disabled boolean If TRUE then click not registered (for use with GUI templating). Otherwise FALSE or nil will register normally.

---@class UtilityGuiUtil_ElementDetails_RegisterCheckedOption @ Option of ElementDetails for calling GuiActionsChecked.RegisterGuiForCheckedStateChange() as part of the Gui element creation.
---@field actionName string @ The actionName of the registered function to be called when the GUI element is checked/unchecked.
---@field data table @ Any provided data will be passed through to the actionName's registered function upon the GUI element being checked/unchecked.
---@field disabled boolean If TRUE then checked state change not registered (for use with GUI templating). Otherwise FALSE or nil will register normally.

--- Limited subset of UtilityGuiUtil_ElementDetails_Add options that can be updated on an existing Gui Element, plus the writable LuaGuiElement attributes.
---
--- Review the LuaGuiElement documentation for which attributes can be directly set on an existing element (https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement).
---@class UtilityGuiUtil_ElementDetails_Update : UtilityGuiUtil_ElementDetails_LuaGuiElement.updatable
---@field style? UtilityGuiUtil_ElementDetails_style|nil
---@field styling? UtilityGuiUtil_ElementDetails_styling|nil
---@field caption? UtilityGuiUtil_ElementDetails_caption|nil
---@field tooltip? UtilityGuiUtil_ElementDetails_caption|nil
---@field registerClick? UtilityGuiUtil_ElementDetails_registerClick|nil
---@field registerCheckedStateChange? UtilityGuiUtil_ElementDetails_registerCheckedStateChange|nil
---@field attributes? UtilityGuiUtil_ElementDetails_attributes|nil

--- Add Gui Elements in a manner supporting short-hand features, nested GUI structures and templating features. See the param type for detailed information on its features and usage.
---@param elementDetails UtilityGuiUtil_ElementDetails_Add
---@return table<string, LuaGuiElement> returnElements @ Provided if returnElement option is TRUE. Table of UtilityGuiUtil_GuiElementName keys to LuaGuiElement values.
GuiUtil.AddElement = function(elementDetails)
    -- Reference the "name" key by this indirect way to avoid EmmyLua picking it up. Have to use new reference and type as we set it.
    ---@type table
    local elementDetailsNoClass = elementDetails

    -- Catch any mistakes.
    if elementDetailsNoClass.name ~= nil then
        error("GuiUtil.AddElement() doesn't support the 'name' attribute being provided, use 'descriptiveName' instead.")
    end
    if elementDetails[1] ~= nil then
        error("GuiUtil.AddElement() recieved a non-key'd value. This is a syntax mistake in the ElementDetails as something is outside of a list.")
    end
    if elementDetails.style ~= nil and type(elementDetails.style) ~= "string" then
        error("GuiUtil.AddElement() had a style attribute set other than a string. Common causes are a table being passed in as MuppetStyles hasn't been qualified to a final style string.")
    end
    if elementDetails["styleing"] ~= nil then
        error("GuiUtil.AddElement() had a 'styleing' attribute, this is a typo for 'styling'.")
    end

    -- If its being intentionally excluded from being created due to the templating.
    if elementDetails.exclude == true then
        return
    end

    elementDetailsNoClass.name = GuiUtil.GenerateGuiElementName(elementDetails.descriptiveName, elementDetails.type)
    elementDetails.caption = GuiUtil._ReplaceLocaleNameSelfWithGeneratedName(elementDetails, "caption")
    elementDetails.tooltip = GuiUtil._ReplaceLocaleNameSelfWithGeneratedName(elementDetails, "tooltip")
    if elementDetails.style ~= nil and string.sub(elementDetails.style, 1, 7) == "muppet_" then
        elementDetails.style = elementDetails.style .. StyleDataStyleVersion
    end
    local attributes, returnElement, storeName, styling, registerClick, registerCheckedStateChange, children = elementDetails.attributes, elementDetails.returnElement, elementDetails.storeName, elementDetails.styling, elementDetails.registerClick, elementDetails.registerCheckedStateChange, elementDetails.children
    elementDetails.attributes, elementDetails.returnElement, elementDetails.storeName, elementDetails.styling, elementDetails.registerClick, elementDetails.registerCheckedStateChange, elementDetails.children = nil, nil, nil, nil, nil, nil, nil

    local element = elementDetails.parent.add(elementDetails)

    local returnElements = {}
    if returnElement then
        if elementDetailsNoClass.descriptiveName == nil then
            error("GuiUtil.AddElement returnElement attribute requires element descriptiveName to be supplied.")
        else
            returnElements[elementDetailsNoClass.name] = element
        end
    end
    if storeName ~= nil then
        if elementDetailsNoClass.descriptiveName == nil then
            error("GuiUtil.AddElement storeName attribute requires element descriptiveName to be supplied.")
        else
            GuiUtil.AddElementToPlayersReferenceStorage(element.player_index, storeName, elementDetailsNoClass.name, element)
        end
    end
    if styling ~= nil then
        GuiUtil._ApplyStylingArgumentsToElement(element, styling)
    end
    if registerClick ~= nil then
        if elementDetailsNoClass.descriptiveName == nil then
            error("GuiUtil.AddElement registerClick attribute requires element descriptiveName to be supplied.")
        else
            GuiActionsClick.RegisterGuiForClick(elementDetailsNoClass.descriptiveName, elementDetails.type, registerClick.actionName, registerClick.data, registerClick.disabled)
        end
    end
    if registerCheckedStateChange ~= nil then
        if elementDetailsNoClass.descriptiveName == nil then
            error("GuiUtil.AddElement registerCheckedStateChange attribute requires element descriptiveName to be supplied.")
        else
            GuiActionsChecked.RegisterGuiForCheckedStateChange(elementDetailsNoClass.descriptiveName, elementDetails.type, registerCheckedStateChange.actionName, registerCheckedStateChange.data, registerCheckedStateChange.disabled)
        end
    end
    if attributes ~= nil then
        for k, v in pairs(attributes) do
            if type(v) == "function" then
                v = v()
            end
            element[k] = v
        end
    end
    if children ~= nil then
        for _, child in pairs(children) do
            if type(child) ~= "table" then
                error("GuiUtil.AddElement called with 'children' not a table of children, but instead a single child.")
            else
                child.parent = element
                local childReturnElements = GuiUtil.AddElement(child)
                if childReturnElements ~= nil then
                    returnElements = TableUtils.TableMergeCopies({returnElements, childReturnElements})
                end
            end
        end
    end
    if TableUtils.GetTableNonNilLength(returnElements) then
        return returnElements
    else
        return nil
    end
end

--- Add a LuaGuiElement to a player's reference storage that was created manually, not via GuiUtil.AddElement().
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
---@param guiElementName UtilityGuiUtil_GuiElementName
---@param element LuaGuiElement
GuiUtil.AddElementToPlayersReferenceStorage = function(playerIndex, storeName, guiElementName, element)
    GuiUtil._CreatePlayersElementReferenceStorage(playerIndex, storeName)
    global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][guiElementName] = element
end

--- Get a LuaGuiElement from a player's reference storage.
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
---@param elementName string
---@param elementType string
GuiUtil.GetElementFromPlayersReferenceStorage = function(playerIndex, storeName, elementName, elementType)
    GuiUtil._CreatePlayersElementReferenceStorage(playerIndex, storeName)
    return global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][GuiUtil.GenerateGuiElementName(elementName, elementType)]
end

--- Apply updated attributes to an existing GuiElement found in the player's reference storage. Supports changing approperiate ElementDetail attributes and some Factorio attributes as per UtilityGuiUtil_ElementDetails_Update.
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
---@param elementName string
---@param elementType string
---@param changes UtilityGuiUtil_ElementDetails_Update @ See the UtilityGuiUtil_ElementDetails_Update type for what can be updated with this function.
---@param ignoreMissingElement boolean @ If TRUE and the GUI element doesn't exist it won't error. If FALSE or nil and the GUI element doesn't exist an error will be raised.
---@return LuaGuiElement
GuiUtil.UpdateElementFromPlayersReferenceStorage = function(playerIndex, storeName, elementName, elementType, changes, ignoreMissingElement)
    ignoreMissingElement = ignoreMissingElement or false
    local element = GuiUtil.GetElementFromPlayersReferenceStorage(playerIndex, storeName, elementName, elementType)

    -- Handle if the element isn't found.
    if element == nil then
        if not ignoreMissingElement then
            error("GuiUtil.UpdateElementFromPlayersReferenceStorage didn't find a GUI element for name '" .. elementName .. "' and type '" .. elementType .. "'")
        else
            return nil
        end
    end

    -- Handle if the element has been removed by something unexpectedly. This will flag a text warning and not hard error for legacy reasons.
    if not element.valid then
        Logging.LogPrint("WARNING: Muppet GUI - A mod tried to update a GUI, buts the GUI is invalid. This is either a bug, or another mod deleted this GUI. Hopefully closing the affected GUI and re-opening it will resolve this. GUI details: player: '" .. game.get_player(playerIndex).name .. "', storeName: '" .. storeName .. "', element Name: '" .. elementName .. "', element Type: '" .. elementType .. "'")
        return nil
    end

    -- Check no unsupported attributes have been passed in.
    -- Do as array of key names as this way EmmyLua doesn't flag that they're not part of the class.
    if changes["storeName"] ~= nil then
        error("GuiUtil.UpdateElementFromPlayersReferenceStorage doesn't support storeName for element name '" .. elementName .. "' and type '" .. elementType .. "'")
    end
    if changes["returnElement"] ~= nil then
        error("GuiUtil.UpdateElementFromPlayersReferenceStorage doesn't support returnElement for element name '" .. elementName .. "' and type '" .. elementType .. "'")
    end
    if changes["children"] ~= nil then
        error("GuiUtil.UpdateElementFromPlayersReferenceStorage doesn't support children for element name '" .. elementName .. "' and type '" .. elementType .. "'")
    end

    -- Process the supported attributes that can be changed.
    local generatedName = GuiUtil.GenerateGuiElementName(elementName, elementType)
    if changes.style ~= nil and string.sub(changes.style, 1, 7) == "muppet_" then
        changes.style = changes.style .. StyleDataStyleVersion
    end
    if changes.styling ~= nil then
        GuiUtil._ApplyStylingArgumentsToElement(element, changes.styling)
        changes.styling = nil
    end
    if changes.registerClick ~= nil then
        GuiActionsClick.RegisterGuiForClick(elementName, elementType, changes.registerClick.actionName, changes.registerClick.data, changes.registerClick.disabled)
        changes.registerClick = nil
    end
    if changes.attributes ~= nil then
        for k, v in pairs(changes.attributes) do
            if type(v) == "function" then
                v = v()
            end
            element[k] = v
        end
        changes.attributes = nil
    end

    for argName, argValue in pairs(changes) do
        if argName == "caption" or argName == "tooltip" then
            argValue = GuiUtil._ReplaceLocaleNameSelfWithGeneratedName({name = generatedName, [argName] = argValue}, argName)
        end
        element[argName] = argValue
    end

    return element
end

--- Destroys a Gui element found within a players reference storage and removes the reference from the player storage.
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
---@param elementName string
---@param elementType string
GuiUtil.DestroyElementInPlayersReferenceStorage = function(playerIndex, storeName, elementName, elementType)
    local guiElementName = GuiUtil.GenerateGuiElementName(elementName, elementType)
    if global.GUIUtilPlayerElementReferenceStorage ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex] ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] ~= nil and global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][guiElementName] ~= nil then
        if global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][guiElementName].valid then
            global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][guiElementName].destroy()
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName][guiElementName] = nil
    end
end

--- Destroys all GUI elements within a players reference storage and removes the reference storage space for them.
---@param playerIndex Id
---@param storeName? UtilityGuiUtil_StoreName|nil @ If provided filters the removal to that storeName, otherwise does all storeNames for this player.
GuiUtil.DestroyPlayersReferenceStorage = function(playerIndex, storeName)
    if global.GUIUtilPlayerElementReferenceStorage == nil or global.GUIUtilPlayerElementReferenceStorage[playerIndex] == nil then
        return
    end
    if storeName == nil then
        for _, store in pairs(global.GUIUtilPlayerElementReferenceStorage[playerIndex]) do
            for _, element in pairs(store) do
                if element.valid then
                    element.destroy()
                end
            end
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex] = nil
    else
        if global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] == nil then
            return
        end
        for _, element in pairs(global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName]) do
            if element.valid then
                element.destroy()
            end
        end
        global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] = nil
    end
end

--- Calculates a UtilityGuiUtil_GuiElementName by combining the element's name and type.
---@param elementName string
---@param elementType string
---@return string UtilityGuiUtil_GuiElementName
GuiUtil.GenerateGuiElementName = function(elementName, elementType)
    --- Just happens to be the same as in GuiActionsClick, but not a requirement.
    if elementName == nil or elementType == nil then
        return nil
    else
        return Constants.ModName .. "-" .. elementName .. "-" .. elementType
    end
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Create a global state store for this player's GUI elements within the scope of this mod.
---@param playerIndex Id
---@param storeName UtilityGuiUtil_StoreName
GuiUtil._CreatePlayersElementReferenceStorage = function(playerIndex, storeName)
    global.GUIUtilPlayerElementReferenceStorage = global.GUIUtilPlayerElementReferenceStorage or {}
    global.GUIUtilPlayerElementReferenceStorage[playerIndex] = global.GUIUtilPlayerElementReferenceStorage[playerIndex] or {}
    global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] = global.GUIUtilPlayerElementReferenceStorage[playerIndex][storeName] or {}
end

--- Applies an array of styling options to an existing Gui element.
---@param element LuaGuiElement
---@param stylingArgs table<LuaStyle, any> @ A table of LuaStyle options to be applied. Table key is the style name, with the table value as the styles value to set.
GuiUtil._ApplyStylingArgumentsToElement = function(element, stylingArgs)
    if element == nil or (not element.valid) then
        return
    end
    if stylingArgs.column_alignments ~= nil then
        for k, v in pairs(stylingArgs.column_alignments) do
            element.style.column_alignments[k] = v
        end
        stylingArgs.column_alignments = nil
    end
    for k, v in pairs(stylingArgs) do
        element.style[k] = v
    end
end

--- Returns the specified attributeName's locale string from the elementDetails, while replacing the string "self" if found with an autogenerated locale string. The auto generated string is in the form: "gui-" + TYPE + "." + UtilityGuiUtil_GuiElementName. i.e. "gui-caption.my_mod-topHeading-label". So it matches if a standard locale naming scheme is in use.
---@param elementDetails UtilityGuiUtil_ElementDetails_Add
---@param attributeName "'caption'"|"''tooltip"
---@return string
GuiUtil._ReplaceLocaleNameSelfWithGeneratedName = function(elementDetails, attributeName)
    -- Reference the "name" key by this indirect way to avoid EmmyLua picking it up. Can use array reference as just reading it.
    local attributeNamesValue = elementDetails[attributeName]
    if attributeNamesValue == nil then
        -- The given attributeName doesn't exist for this elementDetails.
        attributeNamesValue = nil
    elseif attributeNamesValue == "self" then
        -- Value is directly "self". So a direct string.
        if elementDetails.descriptiveName == nil then
            error("GuiUtil._ReplaceLocaleNameSelfWithGeneratedName called with 'self value for an element with no name attribute.")
        end
        attributeNamesValue = {"gui-" .. attributeName .. "." .. elementDetails["name"]}
    elseif type(attributeNamesValue) == "table" and attributeNamesValue[1] ~= nil and attributeNamesValue[1] == "self" then
        -- Value is an array with the first value of "self". So a localised string with "self" as the locale name.
        if elementDetails.descriptiveName == nil then
            error("GuiUtil._ReplaceLocaleNameSelfWithGeneratedName called with 'self value for an element with no name attribute.")
        end
        attributeNamesValue[1] = "gui-" .. attributeName .. "." .. elementDetails["name"]
    end
    return attributeNamesValue
end

--------------------------------------------------------------------------
-- Custom Objects for use in mutliple public classes
--------------------------------------------------------------------------
---@meta
---@diagnostic disable

--- A table of LuaStyle attribute names and values (key/value) to be applied post element creation (after style). Saves having to capture the added element and then set style attributes one at a time in calling code.
---
--- [Styling documentation](https://lua-api.factorio.com/latest/LuaStyle.html)
---@alias UtilityGuiUtil_ElementDetails_styling table<string, StringOrNumber|boolean|nil>

--- Text displayed on the child element. For frames, this is their title. For other elements, like buttons or labels, this is the content. Whilst this attribute may be used on all elements, it doesn't make sense for tables and flows as they won't display it.
---
--- Passing the string "self" as the value or localised string name will be auto replaced to its unique mod auto generated name under gui-caption. This avoids having to duplicate name when defining the element's attributes. The auto generated string is in the form: "gui-" + TYPE + "." + MOD NAME from constants + "-" + NAME attribute value. i.e. "gui-caption.my_mod-firstLabel". So it matches if a standard locale naming scheme is in use.
---
--- [View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@alias UtilityGuiUtil_ElementDetails_caption LocalisedString

--- Tooltip of the child element.
---
--- Passing the string "self" as the value or localised string name will be auto replaced to its unique mod auto generated name under gui-tooltip. This avoids having to duplicate name when defining the element's attributes. The auto generated string is in the form: "gui-" + TYPE + "." + MOD NAME from constants + "-" + NAME attribute value. i.e. "gui-tooltip.my_mod-firstLabel". So it matches if a standard locale naming scheme is in use.
---
--- [View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@alias UtilityGuiUtil_ElementDetails_tooltip LocalisedString

--- If populated registers a function to be triggered when a user clicks on the GUI element. Does this by passing the supplied table of arguments to GuiActionsClick.RegisterGuiForClick() which configures and manages detection of the click and the functions calling. See that library and function for full usage details.
---
--- Note: this is registered each time its run, but as its a single registration globally within the mod under the given name the entries can safely overwrite each other. The data attribute isn't per player, but instead is a global context for all players who trigger this click. Data is intended for uses like passing element name/type details to generic response functions.
---
--- If being used make sure to review Gui-Actions-Click.lua and its GuiActionsClick.MonitorGuiClickActions() function as its a prereq for the features usage. Also need to register the click actionName to a callback function with GuiActionsClick.LinkGuiClickActionNameToFunction().
---@alias UtilityGuiUtil_ElementDetails_registerClick UtilityGuiUtil_ElementDetails_RegisterClickOption

--- If populated registers a function to be triggered when a user checks/un-checks the GUI element. Does this by passing the supplied table of arguments to GuiActionsChecked.RegisterGuiForCheckedStateChange() which configures and manages detection of the checked state change and the functions calling. See that library and function for full usage details.
---
--- Note: this is registered each time its run, but as its a single registration globally within the mod under the given name the entries can safely overwrite each other. The data attribute isn't per player, but instead is a global context for all players who trigger this click. Data is intended for uses like passing element name/type details to generic response functions.
---
--- If being used make sure to review Gui-Actions-Checked.lua and its GuiActionsChecked.MonitorGuiCheckedActions() function as its a prereq for the features usage. Also need to register the checked actionName to a callback function with GuiActionsChecked.LinkGuiCheckedActionNameToFunction().
---@alias UtilityGuiUtil_ElementDetails_registerCheckedStateChange UtilityGuiUtil_ElementDetails_RegisterCheckedOption

--- A table of key/value pairs that is applied to the element via the API post element creation. Intended for the occasioanl adhock attributes you want to update or can't set during the add() API function. i.e. drag_target or auto_center.
---
--- [View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html)
---
--- The value can be a function if you want it to be executed post element creation. Attribute example:
--- `{ drag_target = function() return GuiUtil.GetElementFromPlayersReferenceStorage(player.index, "ShopGui", "shopGuiMain", "frame") end }`
---@alias UtilityGuiUtil_ElementDetails_attributes table<string, any>

--- Style of the child element.
---
--- Value will be checked for starting with "muppet_" and if so automatically merged with the style-data version included in this mod to create the correct full style name. So it automatically handles the fact that muppet styling prototypes are version controlled.
---
--- [View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@alias UtilityGuiUtil_ElementDetails_style string

--------------------------------------------------------------------------
-- A copy of the the base game's LuaGuiElement.add_param, but without the following attributes as they are included in my parent class; name, style, caption, tooltip.
-- Copied from 1.1.58
--------------------------------------------------------------------------

---@class UtilityGuiUtil_ElementDetails_LuaGuiElement.add_param
---The kind of element to add. Has to be one of the GUI element types listed at the top of this page.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field type string
---Name of the child element.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field enabled boolean|nil
---Whether the child element is visible. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field visible boolean|nil
---Whether the child element is ignored by interaction. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field ignored_by_interaction boolean|nil
---Style of the child element.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field tags Tags|nil
---Location in its parent that the child element should slot into. By default, the child will be appended onto the end.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field index uint|nil
---Where to position the child element when in the `relative` element.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field anchor GuiAnchor|nil
---Applies to **"button"**: (optional)
---Which mouse buttons the button responds to. Defaults to `"left-and-right"`.
---
---Applies to **"sprite-button"**: (optional)
---The mouse buttons that the button responds to. Defaults to `"left-and-right"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field mouse_button_filter MouseButtonFlags|nil
---Applies to **"flow"**: (optional)
---The initial direction of the flow's layout. See [LuaGuiElement::direction](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.direction). Defaults to `"horizontal"`.
---
---Applies to **"frame"**: (optional)
---The initial direction of the frame's layout. See [LuaGuiElement::direction](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.direction). Defaults to `"horizontal"`.
---
---Applies to **"line"**: (optional)
---The initial direction of the line. Defaults to `"horizontal"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field direction string|nil
---Applies to **"table"**: (required)
---Number of columns. This can't be changed after the table is created.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field column_count uint
---Applies to **"table"**: (optional)
---Whether the table should draw vertical grid lines. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field draw_vertical_lines boolean|nil
---Applies to **"table"**: (optional)
---Whether the table should draw horizontal grid lines. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field draw_horizontal_lines boolean|nil
---Applies to **"table"**: (optional)
---Whether the table should draw a single horizontal grid line after the headers. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field draw_horizontal_line_after_headers boolean|nil
---Applies to **"table"**: (optional)
---Whether the content of the table should be vertically centered. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field vertical_centering boolean|nil
---Applies to **"textfield"**: (optional)
---The initial text contained in the textfield.
---
---Applies to **"text-box"**: (optional)
---The initial text contained in the text-box.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field text string|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field numeric boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field allow_decimal boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field allow_negative boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field is_password boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field lose_focus_on_confirm boolean|nil
---Applies to **"textfield"**: (optional)
---Defaults to `false`.
---
---Applies to **"text-box"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field clear_and_focus_on_right_click boolean|nil
---Applies to **"progressbar"**: (optional)
---The initial value of the progressbar, in the range [0, 1]. Defaults to `0`.
---
---Applies to **"slider"**: (optional)
---The initial value for the slider. Defaults to `minimum_value`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field value double|nil
---Applies to **"checkbox"**: (required)
---The initial checked-state of the checkbox.
---
---Applies to **"radiobutton"**: (required)
---The initial checked-state of the radiobutton.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field state boolean
---Applies to **"sprite-button"**: (optional)
---Path to the image to display on the button.
---
---Applies to **"sprite"**: (optional)
---Path to the image to display.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field sprite SpritePath|nil
---Applies to **"sprite-button"**: (optional)
---Path to the image to display on the button when it is hovered.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field hovered_sprite SpritePath|nil
---Applies to **"sprite-button"**: (optional)
---Path to the image to display on the button when it is clicked.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field clicked_sprite SpritePath|nil
---Applies to **"sprite-button"**: (optional)
---The number shown on the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field number double|nil
---Applies to **"sprite-button"**: (optional)
---Formats small numbers as percentages. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field show_percent_for_small_numbers boolean|nil
---Applies to **"sprite"**: (optional)
---Whether the widget should resize according to the sprite in it. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field resize_to_sprite boolean|nil
---Applies to **"scroll-pane"**: (optional)
---Policy of the horizontal scroll bar. Possible values are `"auto"`, `"never"`, `"always"`, `"auto-and-reserve-space"`, `"dont-show-but-allow-scrolling"`. Defaults to `"auto"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field horizontal_scroll_policy string|nil
---Applies to **"scroll-pane"**: (optional)
---Policy of the vertical scroll bar. Possible values are `"auto"`, `"never"`, `"always"`, `"auto-and-reserve-space"`, `"dont-show-but-allow-scrolling"`. Defaults to `"auto"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field vertical_scroll_policy string|nil
---Applies to **"drop-down"**: (optional)
---The initial items in the dropdown.
---
---Applies to **"list-box"**: (optional)
---The initial items in the listbox.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field items LocalisedString[]|nil
---Applies to **"drop-down"**: (optional)
---The index of the initially selected item. Defaults to 0.
---
---Applies to **"list-box"**: (optional)
---The index of the initially selected item. Defaults to 0.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field selected_index uint|nil
---Applies to **"camera"**: (required)
---The position the camera centers on.
---
---Applies to **"minimap"**: (optional)
---The position the minimap centers on. Defaults to the player's current position.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field position MapPosition
---Applies to **"camera"**: (optional)
---The surface that the camera will render. Defaults to the player's current surface.
---
---Applies to **"minimap"**: (optional)
---The surface the camera will render. Defaults to the player's current surface.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field surface_index uint|nil
---Applies to **"camera"**: (optional)
---The initial camera zoom. Defaults to `0.75`.
---
---Applies to **"minimap"**: (optional)
---The initial camera zoom. Defaults to `0.75`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field zoom double|nil
---Applies to **"choose-elem-button"**: (required)
---The type of the button - one of the following values.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field elem_type string
---Applies to **"choose-elem-button"**: (optional)
---If type is `"item"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field item string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"tile"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field tile string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"entity"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field entity string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"signal"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field signal SignalID|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"fluid"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field fluid string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"recipe"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field recipe string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"decorative"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field decorative string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"item-group"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field item-group string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"achievement"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field achievement string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"equipment"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field equipment string|nil
---Applies to **"choose-elem-button"**: (optional)
---If type is `"technology"` - the default value for the button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field technology string|nil
---Applies to **"choose-elem-button"**: (optional)
---Filters describing what to show in the selection window. See [LuaGuiElement::elem_filters](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.elem_filters).
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field elem_filters PrototypeFilter[]|nil
---Applies to **"slider"**: (optional)
---The minimum value for the slider. Defaults to `0`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field minimum_value double|nil
---Applies to **"slider"**: (optional)
---The maximum value for the slider. Defaults to `30`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field maximum_value double|nil
---Applies to **"slider"**: (optional)
---The minimum value the slider can move. Defaults to `1`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field value_step double|nil
---Applies to **"slider"**: (optional)
---Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field discrete_slider boolean|nil
---Applies to **"slider"**: (optional)
---Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field discrete_values boolean|nil
---Applies to **"minimap"**: (optional)
---The player index the map should use. Defaults to the current player.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field chart_player_index uint|nil
---Applies to **"minimap"**: (optional)
---The force this minimap should use. Defaults to the player's current force.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field force string|nil
---Applies to **"tab"**: (optional)
---The text to display after the normal tab text (designed to work with numbers).
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field badge_text LocalisedString|nil
---Applies to **"switch"**: (optional)
---Possible values are `"left"`, `"right"`, or `"none"`. If set to "none", `allow_none_state` must be `true`. Defaults to `"left"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field switch_state string|nil
---Applies to **"switch"**: (optional)
---Whether the switch can be set to a middle state. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field allow_none_state boolean|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field left_label_caption LocalisedString|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field left_label_tooltip LocalisedString|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field right_label_caption LocalisedString|nil
---Applies to **"switch"**: (optional)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.add)
---@field right_label_tooltip LocalisedString|nil

--------------------------------------------------------------------------
-- A copy of the the base game's LuaGuiElement UPDATABLE attributes, but without the following attributes as they are included in my parent class; name, style, caption, tooltip.
-- Copied from 1.1.53
--------------------------------------------------------------------------

---@class UtilityGuiUtil_ElementDetails_LuaGuiElement.updatable
---[RW]
---Whether this textfield (when in numeric mode) allows decimal numbers.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.allow_decimal)
---
---_Can only be used if this is textfield_
---@field allow_decimal boolean
---[RW]
---Whether this textfield (when in numeric mode) allows negative numbers.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.allow_negative)
---
---_Can only be used if this is textfield_
---@field allow_negative boolean
---[RW]
---Whether the `"none"` state is allowed for this switch.
---
---**Note:** This can't be set to false if the current switch_state is 'none'.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.allow_none_state)
---
---_Can only be used if this is switch_
---@field allow_none_state boolean
---[RW]
---Sets the anchor for this relative widget. Setting `nil` clears the anchor.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.anchor)
---@field anchor GuiAnchor
---[RW]
---Whether this frame auto-centers on window resize when stored in [LuaGui::screen](https://lua-api.factorio.com/latest/LuaGui.html#LuaGui.screen).
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.auto_center)
---
---_Can only be used if this is frame_
---@field auto_center boolean
---[RW]
---The text to display after the normal tab text (designed to work with numbers)
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.badge_text)
---
---_Can only be used if this is tab_
---@field badge_text LocalisedString
---[RW]
---Makes it so right-clicking on this textfield clears and focuses it.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.clear_and_focus_on_right_click)
---
---_Can only be used if this is textfield or text-box_
---@field clear_and_focus_on_right_click boolean
---[RW]
---The image to display on this sprite-button when it is clicked.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.clicked_sprite)
---@field clicked_sprite SpritePath
---[RW]
---The frame drag target for this flow, frame, label, table, or empty-widget.
---
---**Note:** drag_target can only be set to a frame stored directly in [LuaGui::screen](https://lua-api.factorio.com/latest/LuaGui.html#LuaGui.screen) or `nil`.
---
---**Note:** drag_target can only be set on child elements in [LuaGui::screen](https://lua-api.factorio.com/latest/LuaGui.html#LuaGui.screen).
---
---**Note:** drag_target can only be set to a higher level parent element (this element must be owned at some nested level by the drag_target).
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.drag_target)
---@field drag_target LuaGuiElement
---[RW]
---Whether this table should draw a horizontal grid line below the first table row.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.draw_horizontal_line_after_headers)
---
---_Can only be used if this is table_
---@field draw_horizontal_line_after_headers boolean
---[RW]
---Whether this table should draw horizontal grid lines.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.draw_horizontal_lines)
---
---_Can only be used if this is table_
---@field draw_horizontal_lines boolean
---[RW]
---Whether this table should draw vertical grid lines.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.draw_vertical_lines)
---
---_Can only be used if this is table_
---@field draw_vertical_lines boolean
---[RW]
---The elem filters of this choose-elem-button or `nil` if there are no filters.
---
---The compatible type of filter is determined by elem_type:
---- Type `"item"` - [ItemPrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#ItemPrototypeFilter)
---- Type `"tile"` - [TilePrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#TilePrototypeFilter)
---- Type `"entity"` - [EntityPrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#EntityPrototypeFilter)
---- Type `"signal"` - Does not support filters
---- Type `"fluid"` - [FluidPrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#FluidPrototypeFilter)
---- Type `"recipe"` - [RecipePrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#RecipePrototypeFilter)
---- Type `"decorative"` - [DecorativePrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#DecorativePrototypeFilter)
---- Type `"item-group"` - Does not support filters
---- Type `"achievement"` - [AchievementPrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#AchievementPrototypeFilter)
---- Type `"equipment"` - [EquipmentPrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#EquipmentPrototypeFilter)
---- Type `"technology"` - [TechnologyPrototypeFilter](https://lua-api.factorio.com/latest/Concepts.html#TechnologyPrototypeFilter)
---
---**Note:** Writing to this field does not change or clear the currently selected element.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.elem_filters)
---
---### Example
---This will configure a choose-elem-button of type `"entity"` to only show items of type `"furnace"`.
---```
---button.elem_filters = {{filter = "type", type = "furnace"}}
---```
---
---### Example
---Then, there are some types of filters that work on a specific kind of attribute. The following will configure a choose-elem-button of type `"entity"` to only show entities that have their `"hidden"` [flags](https://lua-api.factorio.com/latest/Concepts.html#EntityPrototypeFlags) set.
---```
---button.elem_filters = {{filter = "hidden"}}
---```
---
---### Example
---Lastly, these filters can be combined at will, taking care to specify how they should be combined (either `"and"` or `"or"`. The following will filter for any `"entities"` that are `"furnaces"` and that are not `"hidden"`.
---```
---button.elem_filters = {{filter = "type", type = "furnace"}, {filter = "hidden", invert = true, mode = "and"}}
---```
---
---_Can only be used if this is choose-elem-button_
---@field elem_filters PrototypeFilter[]
---[RW]
---The elem value of this choose-elem-button or `nil` if there is no value.
---
---**Note:** The `"signal"` type operates with [SignalID](https://lua-api.factorio.com/latest/Concepts.html#SignalID), while all other types use strings.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.elem_value)
---
---_Can only be used if this is choose-elem-button_
---@field elem_value string|SignalID
---[RW]
---Whether this GUI element is enabled. Disabled GUI elements don't trigger events when clicked.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.enabled)
---@field enabled boolean
---[RW]
---The entity associated with this entity-preview, camera, minimap or `nil` if no entity is associated.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.entity)
---@field entity LuaEntity
---[RW]
---The force this minimap is using or `nil` if no force is set.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.force)
---@field force string
---[RW]
---Policy of the horizontal scroll bar. Possible values are `"auto"`, `"never"`, `"always"`, `"auto-and-reserve-space"`, `"dont-show-but-allow-scrolling"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.horizontal_scroll_policy)
---
---_Can only be used if this is scroll-pane_
---@field horizontal_scroll_policy string
---[RW]
---The image to display on this sprite-button when it is hovered.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.hovered_sprite)
---
---_Can only be used if this is sprite-button_
---@field hovered_sprite SpritePath
---[RW]
---Whether this GUI element is ignored by interaction. This makes clicks on this element 'go through' to the GUI element or even the game surface below it.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.ignored_by_interaction)
---@field ignored_by_interaction boolean
---[RW]
---Whether this textfield displays as a password field, which renders all characters as `*`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.is_password)
---
---_Can only be used if this is textfield_
---@field is_password boolean
---[RW]
---The items in this dropdown or listbox.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.items)
---@field items LocalisedString[]
---[RW]
---The text shown for the left switch label.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.left_label_caption)
---
---_Can only be used if this is switch_
---@field left_label_caption LocalisedString
---[RW]
---The tooltip shown on the left switch label.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.left_label_tooltip)
---
---_Can only be used if this is switch_
---@field left_label_tooltip LocalisedString
---[RW]
---The location of this widget when stored in [LuaGui::screen](https://lua-api.factorio.com/latest/LuaGui.html#LuaGui.screen), or `nil` if not set or not in [LuaGui::screen](https://lua-api.factorio.com/latest/LuaGui.html#LuaGui.screen).
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.location)
---@field location GuiLocation<int,int>
---[RW]
---Whether this choose-elem-button can be changed by the player.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.locked)
---
---_Can only be used if this is choose-elem-button_
---@field locked boolean
---[RW]
---Whether this textfield loses focus after [defines.events.on_gui_confirmed](https://lua-api.factorio.com/latest/defines.html#defines.events.on_gui_confirmed) is fired.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.lose_focus_on_confirm)
---
---_Can only be used if this is textfield_
---@field lose_focus_on_confirm boolean
---[RW]
---The player index this minimap is using.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.minimap_player_index)
---
---_Can only be used if this is minimap_
---@field minimap_player_index uint
---[RW]
---The mouse button filters for this button or sprite-button.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.mouse_button_filter)
---@field mouse_button_filter MouseButtonFlags
---[RW]
---The number to be shown in the bottom right corner of this sprite-button. Set this to `nil` to show nothing.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.number)
---@field number double
---[RW]
---Whether this textfield is limited to only numberic characters.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.numeric)
---
---_Can only be used if this is textfield_
---@field numeric boolean
---[RW]
---The position this camera or minimap is focused on, if any.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.position)
---@field position MapPosition<int,int>
---[RW]
---Whether this text-box is read-only. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.read_only)
---
---_Can only be used if this is text-box_
---@field read_only boolean
---[RW]
---Whether the image widget should resize according to the sprite in it. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.resize_to_sprite)
---@field resize_to_sprite boolean
---[RW]
---The text shown for the right switch label.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.right_label_caption)
---
---_Can only be used if this is switch_
---@field right_label_caption LocalisedString
---[RW]
---The tooltip shown on the right switch label.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.right_label_tooltip)
---
---_Can only be used if this is switch_
---@field right_label_tooltip LocalisedString
---[RW]
---Whether the contents of this text-box are selectable. Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.selectable)
---
---_Can only be used if this is text-box_
---@field selectable boolean
---[RW]
---The selected index for this dropdown or listbox. Returns `0` if none is selected.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.selected_index)
---@field selected_index uint
---[RW]
---The selected tab index for this tabbed pane or `nil` if no tab is selected.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.selected_tab_index)
---
---_Can only be used if this is tabbed-pane_
---@field selected_tab_index uint
---[RW]
---Related to the number to be shown in the bottom right corner of this sprite-button. When set to `true`, numbers that are non-zero and smaller than one are shown as a percentage rather than the value. For example, `0.5` will be shown as `50%` instead.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.show_percent_for_small_numbers)
---@field show_percent_for_small_numbers boolean
---[RW]
---The value of this slider element.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.slider_value)
---
---_Can only be used if this is slider_
---@field slider_value double
---[RW]
---The image to display on this sprite-button or sprite in the default state.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.sprite)
---@field sprite SpritePath
---[RW]
---Is this checkbox or radiobutton checked?
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.state)
---
---_Can only be used if this is CheckBox or RadioButton_
---@field state boolean
---[RW]
---The surface index this camera or minimap is using.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.surface_index)
---@field surface_index uint
---[RW]
---The switch state (left, none, right) for this switch.
---
---**Note:** If [LuaGuiElement::allow_none_state](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.allow_none_state) is false this can't be set to `"none"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.switch_state)
---
---_Can only be used if this is switch_
---@field switch_state string
---[RW]
---The tags associated with this LuaGuiElement.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.tags)
---@field tags Tags
---[RW]
---The text contained in this textfield or text-box.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.text)
---
---_Can only be used if this is textfield or text-box_
---@field text string
---[RW]
---How much this progress bar is filled. It is a value in the range [0, 1].
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.value)
---
---_Can only be used if this is progressbar_
---@field value double
---[RW]
---Whether the content of this table should be vertically centered. Overrides [LuaStyle::column_alignments](https://lua-api.factorio.com/latest/LuaStyle.html#LuaStyle.column_alignments). Defaults to `true`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.vertical_centering)
---
---_Can only be used if this is table_
---@field vertical_centering boolean
---[RW]
---Policy of the vertical scroll bar. Possible values are `"auto"`, `"never"`, `"always"`, `"auto-and-reserve-space"`, `"dont-show-but-allow-scrolling"`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.vertical_scroll_policy)
---
---_Can only be used if this is scroll-pane_
---@field vertical_scroll_policy string
---[RW]
---Sets whether this GUI element is visible or completely hidden, taking no space in the layout.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.visible)
---@field visible boolean
---[RW]
---Whether this text-box will word-wrap automatically. Defaults to `false`.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.word_wrap)
---
---_Can only be used if this is text-box_
---@field word_wrap boolean
---[RW]
---The zoom this camera or minimap is using.
---
---[View documentation](https://lua-api.factorio.com/latest/LuaGuiElement.html#LuaGuiElement.zoom)
---@field zoom double

return GuiUtil
