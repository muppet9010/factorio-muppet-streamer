-- Library to register and handle GUI element buttons being clicked, allows registering and handling functions in a modular way.
-- Must call the MonitorGuiClickActions() function once in root of control.lua for this library to be activated.
-- Requires the utility "constants" file to be populated within the root of the mod.

local GuiActionsClick = {} ---@class Utility_GuiActionsClick
local Constants = require("constants")
MOD = MOD or {} ---@class MOD
MOD.guiClickActions = MOD.guiClickActions or {} ---@type table<string, function>

---@class UtilityGuiActionsClick_ActionData # The response object passed to the callback function when the GUI element is clicked. Registered with GuiActionsClick.RegisterGuiForClick().
---@field actionName string # The action name registered to this GUI element being clicked.
---@field playerIndex uint # The player_index of the player who clicked the GUI.
---@field data any # The data argument passed in when registering this function action name.
---@field eventData on_gui_click # The raw Factorio event data for the on_gui_click event.

--------------------------------------------------------------------------------------------
--                                    Public Functions
--------------------------------------------------------------------------------------------

--- Must be called once within the mod to activate the library for reacting to gui clicks. On other direct registering to the "on_gui_click" event is allowed within the mod.
---
--- Called from the root of Control.lua or from OnLoad.
GuiActionsClick.MonitorGuiClickActions = function()
    script.on_event(defines.events.on_gui_click, GuiActionsClick._HandleGuiClickAction)
end

--- Called from OnLoad() from each script file.
---@param actionName string # A unique name for this function to be registered with.
---@param actionFunction fun(callbackData: UtilityGuiActionsClick_ActionData) # The callback function for when the actionName linked GUI element is clicked.
GuiActionsClick.LinkGuiClickActionNameToFunction = function(actionName, actionFunction)
    if actionName == nil or actionFunction == nil then
        error("GuiActions.LinkGuiClickActionNameToFunction called with missing arguments")
    end
    MOD.guiClickActions[actionName] = actionFunction
end

--- Generally called from the GuiUtil library now, but can be called manually from OnLoad().
---
--- Called to register a button or sprite-button GuiElement's name and type to a specific GUI click action name and optional standard data (global to all players). Only needs to be run once per mod.
---@param elementName string # The name of the element. Must be unique within mod once elementName and elementType arguments are combined together.
---@param elementType string # The type of the element. Must be unique within mod once elementName and elementType arguments are combined together.
---@param actionName string # The actionName of the registered function to be called when the GUI element is clicked.
---@param data? any|nil # Any provided data will be passed through to the actionName's registered function upon the GUI element being clicked.
---@param disabled? boolean|nil # If TRUE then click not registered (for use with GUI templating). Otherwise FALSE or nil will registered normally.
GuiActionsClick.RegisterGuiForClick = function(elementName, elementType, actionName, data, disabled)
    if elementName == nil or elementType == nil or actionName == nil then
        error("GuiActions.RegisterGuiForClick called with missing arguments")
    end

    -- Check no unsupported attributes have been passed in.
    if type(actionName) ~= "string" then
        error("GuiActionsClick.RegisterGuiForClick passed a non string type actionName '" .. elementName .. "' and type '" .. elementType .. "'")
    end

    local name = GuiActionsClick._GenerateGuiElementName(elementName, elementType)
    global.UTILITYGUIACTIONSGUICLICK = global.UTILITYGUIACTIONSGUICLICK or {} ---@type table<string, UtilityGuiActionsClick_GuiClickDetails>
    if not disabled then
        global.UTILITYGUIACTIONSGUICLICK[name] = { actionName = actionName, data = data }
    else
        global.UTILITYGUIACTIONSGUICLICK[name] = nil
    end
end

--- Called when desired to remove a specific button GuiElement from triggering its action.
---
--- Should be called to remove links for buttons when their elements are removed to stop global data lingering. But newly registered functions will overwrite them so not critical to remove.
---@param elementName string # Corresponds to the same argument name on GuiActionsClick.RegisterGuiForClick().
---@param elementType string # Corresponds to the same argument name on GuiActionsClick.RegisterGuiForClick().
GuiActionsClick.RemoveGuiForClick = function(elementName, elementType)
    if elementName == nil then
        error("GuiActions.RemoveButtonName called with missing arguments")
    end
    if global.UTILITYGUIACTIONSGUICLICK == nil then
        return
    end
    local name = GuiActionsClick._GenerateGuiElementName(elementName, elementType)
    global.UTILITYGUIACTIONSGUICLICK[name] = nil
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Called when each on_gui_click event occurs and identifies any registered actionName functions to trigger.
---@param rawFactorioEventData on_gui_click
GuiActionsClick._HandleGuiClickAction = function(rawFactorioEventData)
    if global.UTILITYGUIACTIONSGUICLICK == nil then
        return
    end
    local clickedElementName = rawFactorioEventData.element.name
    local guiClickDetails = global.UTILITYGUIACTIONSGUICLICK[clickedElementName]
    if guiClickDetails ~= nil then
        local actionName = guiClickDetails.actionName
        local actionFunction = MOD.guiClickActions[actionName]
        local actionData = { actionName = actionName, playerIndex = rawFactorioEventData.player_index, data = guiClickDetails.data, eventData = rawFactorioEventData }
        if actionFunction == nil then
            error("ERROR: GUI Click Handler - no registered action for name: '" .. tostring(actionName) .. "'")
        end
        actionFunction(actionData)
    else
        return
    end
end

--- Makes a UtilityGuiActionsClick_GuiElementName by combining the element's name and type.
---
--- Just happens to be the same as in GuiUtil, but not a requirement.
---@param elementName string
---@param elementType string
---@return UtilityGuiActionsClick_GuiElementName guiElementName
GuiActionsClick._GenerateGuiElementName = function(elementName, elementType)
    if elementName == nil or elementType == nil then
        return nil
    else
        return Constants.ModName .. "-" .. elementName .. "-" .. elementType
    end
end

---@alias UtilityGuiActionsClick_GuiElementName string # A single unique string made by combining an elements name and type with mod name.

---@class UtilityGuiActionsClick_GuiClickDetails
---@field actionName string
---@field data table

return GuiActionsClick
