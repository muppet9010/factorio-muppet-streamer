-- Library to register and handle base game GUIs being opened, allows registering and handling functions in a modular way.
-- This is for hooking in to base game entities that when left clicked by the player open a base game GUI, i.e. market. This library is used to fire a mod function when a GUI is opened to do some action, normally replace the base game GUI with a custom GUI. Given that you can't just make clickable entities in Factorio.
-- Includes 2 registration methods, one for all instances of a specific GUI type (defines.gui_type) and another for when any GUI on a specific entity unit_number is opened. Both allow custom data to be stored at registration time and will include a reference to the entity clicked in the standard Factorio event fields (on_gui_opened).

local GuiActionsOpened = {} ---@class Utility_GuiActionsOpened
MOD = MOD or {} ---@class MOD
MOD.guiOpenedActions = MOD.guiOpenedActions or {} ---@type table<string, function>

---@class UtilityGuiActionsOpened_ActionData # The response object passed to the callback function when the GUI element is opened. Registered with GuiActionsOpened.LinkGuiOpenedActionNameToFunction().
---@field actionName string # The action name registered to this GUI element being opened.
---@field playerIndex uint # The player_index of the player who opened the GUI.
---@field entity LuaEntity|nil # The entity that was clicked to open the GUI, if one was.
---@field data any # The data argument passed in when registering this function action name.
---@field eventData on_gui_opened # The raw Factorio event data for the on_gui_opened event.

--------------------------------------------------------------------------------------------
--                                    Public Functions
--------------------------------------------------------------------------------------------

-- Called from the root of Control.lua
GuiActionsOpened.MonitorGuiOpenedActions = function()
    script.on_event(defines.events.on_gui_opened, GuiActionsOpened._HandleGuiOpenedAction)
end

--- Called from OnLoad() from each script file.
---@param actionName string # A unique name for this function to be registered with.
---@param actionFunction fun(callbackData: UtilityGuiActionsOpened_ActionData) # The callback function for when the actionName linked GUI element is opened.
GuiActionsOpened.LinkGuiOpenedActionNameToFunction = function(actionName, actionFunction)
    if actionName == nil or actionFunction == nil then
        error("GuiActions.LinkGuiOpenedActionNameToFunction called with missing arguments")
    end
    MOD.guiOpenedActions[actionName] = actionFunction
end

-- Called to register a specific entities GUI being opened to a named action.
---@param entity LuaEntity # The entity to react to having a GUI opened on it.
---@param actionName string # The actionName of the registered function to be called when the GUI element is opened.
---@param data? table|nil # Any provided data will be passed through to the actionName's registered function upon the GUI element being opened.
GuiActionsOpened.RegisterEntityForGuiOpenedAction = function(entity, actionName, data)
    if entity == nil or actionName == nil then
        error("GuiActions.RegisterEntityForGuiOpenedAction called with missing arguments")
    end
    data = data or {}
    global.UTILITYGUIACTIONSENTITYGUIOPENED = global.UTILITYGUIACTIONSENTITYGUIOPENED or {} ---@type table<uint, table<string, table|nil>>
    local entity_unitNumber = entity.unit_number
    if entity_unitNumber == nil then
        error("GuiActionsOpened.RegisterEntityForGuiOpenedAction() only supports entities with populated unit_number field.")
    end
    global.UTILITYGUIACTIONSENTITYGUIOPENED[entity_unitNumber] = global.UTILITYGUIACTIONSENTITYGUIOPENED[entity_unitNumber] or {}
    global.UTILITYGUIACTIONSENTITYGUIOPENED[entity_unitNumber][actionName] = data
end

--- Called when desired to remove a specific entities GUI being opened from triggering its action.
---
--- Should be called to remove links for buttons when their elements are removed to stop global data lingering. But newly registered functions will overwrite them so not critical to remove.
---@param entity LuaEntity  # Corresponds to the same argument name on GuiActionsOpened.RegisterEntityForGuiOpenedAction().
---@param actionName string # Corresponds to the same argument name on GuiActionsOpened.RegisterEntityForGuiOpenedAction().
GuiActionsOpened.RemoveEntityForGuiOpenedAction = function(entity, actionName)
    if entity == nil or actionName == nil then
        error("GuiActions.RemoveEntityForGuiOpenedAction called with missing arguments")
    end
    local entity_unitNumber = entity.unit_number
    if entity_unitNumber == nil then
        error("GuiActionsOpened.RemoveEntityForGuiOpenedAction() only supports entities with populated unit_number field.")
    end
    if global.UTILITYGUIACTIONSENTITYGUIOPENED == nil or global.UTILITYGUIACTIONSENTITYGUIOPENED[entity_unitNumber] == nil then
        return
    end
    global.UTILITYGUIACTIONSENTITYGUIOPENED[entity_unitNumber][actionName] = nil
end

-- Called to register a specific GUI type being opened to a named action.
---@param guiType defines.gui_type|'all' # the gui type to react to or `all` types.
---@param actionName string # The actionName of the registered function to be called when the GUI element is opened.
---@param data? table|nil # Any provided data will be passed through to the actionName's registered function upon the GUI element being opened.
GuiActionsOpened.RegisterActionNameForGuiTypeOpened = function(guiType, actionName, data)
    if guiType == nil or actionName == nil then
        error("GuiActions.RegisterActionNameForGuiTypeOpened called with missing arguments")
    end
    data = data or {}
    global.UTILITYGUIACTIONSGUITYPEOPENED = global.UTILITYGUIACTIONSGUITYPEOPENED or {} ---@type table<defines.gui_type|'all', table<string, table|nil>>
    global.UTILITYGUIACTIONSGUITYPEOPENED[guiType] = global.UTILITYGUIACTIONSGUITYPEOPENED[guiType] or {}
    global.UTILITYGUIACTIONSGUITYPEOPENED[guiType][actionName] = data
end

-- Called when desired to remove a specific GUI type opening from triggering its action.
---
--- Should be called to remove links for buttons when their elements are removed to stop global data lingering. But newly registered functions will overwrite them so not critical to remove.
---@param guiType defines.gui_type|'all' # Corresponds to the same argument name on GuiActionsOpened.RegisterActionNameForGuiTypeOpened().
---@param actionName string # Corresponds to the same argument name on GuiActionsOpened.RegisterActionNameForGuiTypeOpened().
GuiActionsOpened.RemoveActionNameForGuiTypeOpened = function(guiType, actionName)
    if guiType == nil or actionName == nil then
        error("GuiActions.RemoveActionNameForGuiTypeOpened called with missing arguments")
    end
    if global.UTILITYGUIACTIONSGUITYPEOPENED == nil or global.UTILITYGUIACTIONSGUITYPEOPENED[guiType] == nil then
        return
    end
    global.UTILITYGUIACTIONSGUITYPEOPENED[guiType][actionName] = nil
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Called when each on_gui_opened event occurs and identifies any registered actionName functions to trigger.
---@param rawFactorioEventData on_gui_opened
GuiActionsOpened._HandleGuiOpenedAction = function(rawFactorioEventData)
    local guiType, entityOpened = rawFactorioEventData.gui_type, rawFactorioEventData.entity

    if global.UTILITYGUIACTIONSGUITYPEOPENED ~= nil and guiType ~= nil then
        for _, guiTypeHandled in pairs({ guiType, "all" }) do
            if global.UTILITYGUIACTIONSGUITYPEOPENED[guiTypeHandled] ~= nil then
                for actionName, data in pairs(global.UTILITYGUIACTIONSGUITYPEOPENED[guiTypeHandled]) do
                    local actionFunction = MOD.guiOpenedActions[actionName]
                    local actionData = { actionName = actionName, playerIndex = rawFactorioEventData.player_index, guiType = guiTypeHandled, data = data, eventData = rawFactorioEventData }
                    if actionFunction == nil then
                        error("ERROR: Entity GUI Opened Handler - no registered action for name: '" .. tostring(actionName) .. "'")
                    end
                    actionFunction(actionData)
                end
            end
        end
    end

    if global.UTILITYGUIACTIONSENTITYGUIOPENED ~= nil and entityOpened ~= nil then
        local entityOpened_unitNumber = entityOpened.unit_number
        -- If the entity has a unit_number then we could have registered something for it, otherwise we couldn't have registered anything so no need to check.
        if entityOpened_unitNumber ~= nil and global.UTILITYGUIACTIONSENTITYGUIOPENED[entityOpened_unitNumber] ~= nil then
            for actionName, data in pairs(global.UTILITYGUIACTIONSENTITYGUIOPENED[entityOpened_unitNumber]) do
                local actionFunction = MOD.guiOpenedActions[actionName]
                local actionData = { actionName = actionName, playerIndex = rawFactorioEventData.player_index, entity = entityOpened, data = data, eventData = rawFactorioEventData }
                if actionFunction == nil then
                    error("ERROR: Entity GUI Opened Handler - no registered action for name: '" .. tostring(actionName) .. "'")
                end
                actionFunction(actionData)
            end
        end
    end
end

return GuiActionsOpened
