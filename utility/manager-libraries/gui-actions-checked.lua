-- Library to register and handle GUI element's being checked/unchecked, allows registering and handling functions in a modular way.
-- Must call the MonitorGuiCheckActions() function once in root of control.lua for this library to be activated.
-- Requires the utility "constants" file to be populated within the root of the mod.

local GuiActionsChecked = {} ---@class Utility_GuiActionsChecked
local Constants = require("constants")
MOD = MOD or {} ---@class MOD
MOD.guiCheckedActions = MOD.guiCheckedActions or {} ---@type table<string, function>

---@class UtilityGuiActionsChecked_ActionData # The response object passed to the callback function when the GUI element is checked/unchecked. Registered with GuiActionsChecked.RegisterGuiForCheckedStateChange().
---@field actionName string # The action name registered to this GUI element being checked.
---@field playerIndex uint # The player_index of the player who checked the GUI.
---@field data any # The data argument passed in when registering this function action name.
---@field eventData on_gui_checked_state_changed # The raw Factorio event data for the on_gui_checked_state_changed event.

--------------------------------------------------------------------------------------------
--                                    Public Functions
--------------------------------------------------------------------------------------------

--- Must be called once within the mod to activate the library for reacting to gui checked. On other direct registering to the "on_gui_checked_state_changed" event is allowed within the mod.
---
--- Called from the root of Control.lua or from OnLoad.
GuiActionsChecked.MonitorGuiCheckedActions = function()
    script.on_event(defines.events.on_gui_checked_state_changed, GuiActionsChecked._HandleGuiCheckedAction)
end

--- Called from OnLoad() from each script file.
---@param actionName string # A unique name for this function to be registered with.
---@param actionFunction fun(callbackData: UtilityGuiActionsChecked_ActionData) # The callback function for when the actionName linked GUI element is checked.
GuiActionsChecked.LinkGuiCheckedActionNameToFunction = function(actionName, actionFunction)
    if actionName == nil or actionFunction == nil then
        error("GuiActions.LinkGuiCheckedActionNameToFunction called with missing arguments")
    end
    MOD.guiCheckedActions[actionName] = actionFunction
end

--- Generally called from the GuiUtil library now, but can be called manually from OnLoad().
---
--- Called to register a checkbox's name and type to a specific GUI checked action name and optional standard data (global to all players). Only needs to be run once per mod.
---@param elementName string # The name of the element. Must be unique within mod once elementName and elementType arguments are combined together.
---@param elementType string # The type of the element. Must be unique within mod once elementName and elementType arguments are combined together.
---@param actionName string # The actionName of the registered function to be called when the GUI element is checked.
---@param data? any|nil # Any provided data will be passed through to the actionName's registered function upon the GUI element being checked.
---@param disabled? boolean|nil # If TRUE then checked not registered (for use with GUI templating). Otherwise FALSE or nil will registered normally.
GuiActionsChecked.RegisterGuiForCheckedStateChange = function(elementName, elementType, actionName, data, disabled)
    if elementName == nil or elementType == nil or actionName == nil then
        error("GuiActions.RegisterGuiForCheckedStateChange called with missing arguments")
    end
    local name = GuiActionsChecked._GenerateGuiElementName(elementName, elementType)
    global.UTILITYGUIACTIONSGUICHECKED = global.UTILITYGUIACTIONSGUICHECKED or {} ---@type table<string, UtilityGuiActionsChecked_GuiCheckedDetails>
    if not disabled then
        global.UTILITYGUIACTIONSGUICHECKED[name] = { actionName = actionName, data = data }
    else
        global.UTILITYGUIACTIONSGUICHECKED[name] = nil
    end
end

--- Called when desired to remove a specific checkbox from triggering its action.
---
--- Should be called to remove links for checkboxes when their elements are removed to stop global data lingering. But newly registered functions will overwrite them so not critical to remove.
---@param elementName string # Corresponds to the same argument name on GuiActionsChecked.RegisterGuiForCheckedStateChange().
---@param elementType string # Corresponds to the same argument name on GuiActionsChecked.RegisterGuiForCheckedStateChange().
GuiActionsChecked.RemoveGuiForCheckedStateChange = function(elementName, elementType)
    if elementName == nil then
        error("GuiActions.RemoveButtonName called with missing arguments")
    end
    if global.UTILITYGUIACTIONSGUICHECKED == nil then
        return
    end
    local name = GuiActionsChecked._GenerateGuiElementName(elementName, elementType)
    global.UTILITYGUIACTIONSGUICHECKED[name] = nil
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Called when each on_gui_checked_state_changed event occurs and identifies any registered actionName functions to trigger.
---@param rawFactorioEventData on_gui_checked_state_changed
GuiActionsChecked._HandleGuiCheckedAction = function(rawFactorioEventData)
    if global.UTILITYGUIACTIONSGUICHECKED == nil then
        return
    end
    local checkedElementName = rawFactorioEventData.element.name
    local guiCheckedDetails = global.UTILITYGUIACTIONSGUICHECKED[checkedElementName]
    if guiCheckedDetails ~= nil then
        local actionName = guiCheckedDetails.actionName
        local actionFunction = MOD.guiCheckedActions[actionName]
        local actionData = { actionName = actionName, playerIndex = rawFactorioEventData.player_index, data = guiCheckedDetails.data, eventData = rawFactorioEventData }
        if actionFunction == nil then
            error("ERROR: GUI Checked Handler - no registered action for name: '" .. tostring(actionName) .. "'")
        end
        actionFunction(actionData)
    else
        return
    end
end

--- Makes a UtilityGuiActionsChecked_GuiElementName by combining the element's name and type.
---
--- Just happens to be the same as in GuiUtil, but not a requirement.
---@param elementName string
---@param elementType string
---@return UtilityGuiActionsChecked_GuiElementName guiElementName
GuiActionsChecked._GenerateGuiElementName = function(elementName, elementType)
    if elementName == nil or elementType == nil then
        return nil
    else
        return Constants.ModName .. "-" .. elementName .. "-" .. elementType
    end
end

---@alias UtilityGuiActionsChecked_GuiElementName string # A single unique string made by combining an elements name and type with mod name.

---@class UtilityGuiActionsChecked_GuiCheckedDetails
---@field actionName string
---@field data table

return GuiActionsChecked
