-- Library to register and handle base game GUI types being closed, allows registering and handling functions in a modular way.
-- This is for hooking in to when the player closes a game GUI, i.e. market or a custom GUI window. This library is used to fire a mod function when this specific GUI type is closed to do some action, normally update custom GUI state that the GUI's been closed by the player. Is the closing side of the gui-actions-opened library.

local GuiActionsClosed = {} ---@class Utility_GuiActionsClosed
MOD = MOD or {} ---@class MOD
MOD.guiClosedActions = MOD.guiClosedActions or {} ---@type table<string, function>

---@class UtilityGuiActionsClosed_ActionData # The response object passed to the callback function when the GUI element is closed. Registered with GuiActionsClosed.LinkGuiClosedActionNameToFunction().
---@field actionName string # The action name registered to this GUI element being closed.
---@field playerIndex uint # The player_index of the player who closed the GUI.
---@field data any # The data argument passed in when registering this function action name.
---@field eventData on_gui_closed # The raw Factorio event data for the on_gui_closed event.

--------------------------------------------------------------------------------------------
--                                    Public Functions
--------------------------------------------------------------------------------------------

--- Called from the root of Control.lua
GuiActionsClosed.MonitorGuiClosedActions = function()
    script.on_event(defines.events.on_gui_closed, GuiActionsClosed._HandleGuiClosedAction)
end

--- Called from OnLoad() from each script file
---@param actionName string # A unique name for this function to be registered with.
---@param actionFunction fun(callbackData: UtilityGuiActionsClosed_ActionData) # The callback function for when the actionName linked GUI element is closed.
GuiActionsClosed.LinkGuiClosedActionNameToFunction = function(actionName, actionFunction)
    if actionName == nil or actionFunction == nil then
        error("GuiActions.LinkGuiClosedActionNameToFunction called with missing arguments")
    end
    MOD.guiClosedActions[actionName] = actionFunction
end

--- Called to register a specific GUI type being closed to a named action.
---@param guiType defines.gui_type|'all' # the gui type to react to or `all` types.
---@param actionName string # The actionName of the registered function to be called when the GUI element is closed.
---@param data? table|nil # Any provided data will be passed through to the actionName's registered function upon the GUI element being closed.
GuiActionsClosed.RegisterActionNameForGuiTypeClosed = function(guiType, actionName, data)
    if guiType == nil or actionName == nil then
        error("GuiActions.RegisterActionNameForGuiTypeClosed called with missing arguments")
    end
    data = data or {}
    global.UTILITYGUIACTIONSGUITYPECLOSED = global.UTILITYGUIACTIONSGUITYPECLOSED or {} ---@type table<defines.gui_type|'all', table<string, table|nil>>
    global.UTILITYGUIACTIONSGUITYPECLOSED[guiType] = global.UTILITYGUIACTIONSGUITYPECLOSED[guiType] or {}
    global.UTILITYGUIACTIONSGUITYPECLOSED[guiType][actionName] = data
end

--- Called when desired to remove a specific GUI type closing from triggering its action.
---
--- Should be called to remove links for buttons when their elements are removed to stop global data lingering. But newly registered functions will overwrite them so not critical to remove.
---@param guiType defines.gui_type|'all' # Corresponds to the same argument name on GuiActionsClosed.RegisterActionNameForGuiTypeClosed().
---@param actionName string # Corresponds to the same argument name on GuiActionsClosed.RegisterActionNameForGuiTypeClosed().
GuiActionsClosed.RemoveActionNameForGuiTypeClosed = function(guiType, actionName)
    if guiType == nil or actionName == nil then
        error("GuiActions.RemoveActionNameForGuiTypeClosed called with missing arguments")
    end
    if global.UTILITYGUIACTIONSGUITYPECLOSED == nil or global.UTILITYGUIACTIONSGUITYPECLOSED[guiType] == nil then
        return
    end
    global.UTILITYGUIACTIONSGUITYPECLOSED[guiType][actionName] = nil
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Called when each on_gui_closed event occurs and identifies any registered actionName functions to trigger.
---@param rawFactorioEventData on_gui_closed
GuiActionsClosed._HandleGuiClosedAction = function(rawFactorioEventData)
    local guiType = rawFactorioEventData.gui_type

    if global.UTILITYGUIACTIONSGUITYPECLOSED ~= nil and guiType ~= nil then
        for _, guiTypeHandled in pairs({ guiType, "all" }) do
            if global.UTILITYGUIACTIONSGUITYPECLOSED[guiTypeHandled] ~= nil then
                for actionName, data in pairs(global.UTILITYGUIACTIONSGUITYPECLOSED[guiTypeHandled]) do
                    local actionFunction = MOD.guiClosedActions[actionName]
                    local actionData = { actionName = actionName, playerIndex = rawFactorioEventData.player_index, guiType = guiTypeHandled, data = data, eventData = rawFactorioEventData }
                    if actionFunction == nil then
                        error("ERROR: Entity GUI Closed Handler - no registered action for name: '" .. tostring(actionName) .. "'")
                    end
                    actionFunction(actionData)
                end
            end
        end
    end
end

return GuiActionsClosed
