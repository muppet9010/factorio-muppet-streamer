--[[
    Events is used to register one or more functions to be run when a script.event occurs.
    It supports defines.events and custom events. Also offers a raise event method.
    Intended for use with a modular script design to avoid having to link to each modulars functions in a centralised event handler.
]]
--

local TableUtils = require("utility.table-utils")

local Events = {}
MOD = MOD or {}
MOD.eventsById = MOD.eventsById or {} ---@type UtilityEvents_EventHandlerObject[]
MOD.eventIdHandlerNameToEventIdsListIndex = MOD.eventIdHandlerNameToEventIdsListIndex or {} ---@type table<string, int> A way to get the id key from MOD.eventsById for a specific event id and handler name.
MOD.eventsByActionName = MOD.eventsByActionName or {} ---@type UtilityEvents_EventHandlerObject[]
MOD.eventActionNameHandlerNameToEventActionNamesListIndex = MOD.eventActionNameHandlerNameToEventActionNamesListIndex or {} ---@type table<string, int> @ A way to get the id key from MOD.eventsByActionName for a specific action name and handler name.
MOD.customEventNameToId = MOD.customEventNameToId or {} ---@type table<string, int>
MOD.eventFilters = MOD.eventFilters or {} ---@type table<int, table<string, table>>

---@class UtilityEvents_EventData : EventData @ The class is the minimum being passed through to the recieveing event handler function. It will include any Factorio event specific fields in it.
---@field input_name? string|nil @ Used by custom input event handlers registered with Events.RegisterHandlerCustomInput() as the actionName.

--- Called from OnLoad() from each script file. Registers the event in Factorio and the handler function for all event types and custom events.
---@param eventName defines.events|string @ Either Factorio event or a custom modded event name.
---@param handlerName string @ Unique name of this event handler instance. Used to avoid duplicate handler registration and if removal is required.
---@param handlerFunction function @ The function that is called when the event triggers. When the function is called it will recieve the standard single Factorio event specific data table argument.
---@param thisFilterData? EventFilter[]|nil @ List of Factorio EventFilters the mod should recieve this eventName occurances for or nil for all occurances. If an empty table (not nil) is passed in then nothing is registered for this handler (silently rejected). Filtered events have to expect to recieve results outside of their own filters. As a Factorio event type can only be subscribed to one time with a combined Filter list of all desires across the mod.
---@return uint @ Useful for custom event names when you need to store the eventId to return via a remote interface call.
Events.RegisterHandlerEvent = function(eventName, handlerName, handlerFunction, thisFilterData)
    if eventName == nil or handlerName == nil or handlerFunction == nil then
        error("Events.RegisterHandlerEvent called with missing arguments")
    end
    local eventId = Events._RegisterEvent(eventName, handlerName, thisFilterData)
    if eventId == nil then
        return nil
    end
    if MOD.eventIdHandlerNameToEventIdsListIndex[eventId] == nil or MOD.eventIdHandlerNameToEventIdsListIndex[eventId][handlerName] == nil then
        -- Is the first registering of this unique handler name for this event id.
        MOD.eventsById[eventId] = MOD.eventsById[eventId] or {}
        table.insert(MOD.eventsById[eventId], {handlerName = handlerName, handlerFunction = handlerFunction})
        MOD.eventIdHandlerNameToEventIdsListIndex[eventId] = MOD.eventIdHandlerNameToEventIdsListIndex[eventId] or {}
        MOD.eventIdHandlerNameToEventIdsListIndex[eventId][handlerName] = #MOD.eventsById[eventId]
    else
        -- Is a re-registering of a unique handler name for this event id, so just update everything.
        MOD.eventsById[eventId][MOD.eventIdHandlerNameToEventIdsListIndex[eventId][handlerName]] = {handlerName = handlerName, handlerFunction = handlerFunction}
    end
    return eventId
end

--- Called from OnLoad() from each script file. Registers the custom inputs (key bindings) as their names in Factorio and the handler function for all just custom inputs. These are handled specially in Factorio.
---@param actionName string @ custom input name (key binding).
---@param handlerName string @ Unique handler name.
---@param handlerFunction function @ Function to be triggered on action.
Events.RegisterHandlerCustomInput = function(actionName, handlerName, handlerFunction)
    if actionName == nil then
        error("Events.RegisterHandlerCustomInput called with missing arguments")
    end
    script.on_event(actionName, Events._HandleEvent)
    if MOD.eventActionNameHandlerNameToEventActionNamesListIndex[actionName] == nil or MOD.eventActionNameHandlerNameToEventActionNamesListIndex[actionName][handlerName] == nil then
        -- Is the first registering of this unique handler name for this action name.
        MOD.eventsByActionName[actionName] = MOD.eventsByActionName[actionName] or {}
        table.insert(MOD.eventsByActionName[actionName], {handlerName = handlerName, handlerFunction = handlerFunction})
        MOD.eventActionNameHandlerNameToEventActionNamesListIndex[actionName] = MOD.eventActionNameHandlerNameToEventActionNamesListIndex[actionName] or {}
        MOD.eventActionNameHandlerNameToEventActionNamesListIndex[actionName][handlerName] = #MOD.eventsByActionName[actionName]
    else
        -- Is a re-registering of a unique handler name for this action name, so just update everything.
        MOD.eventsByActionName[actionName][MOD.eventActionNameHandlerNameToEventActionNamesListIndex[actionName][handlerName]] = {handlerName = handlerName, handlerFunction = handlerFunction}
    end
end

--- Called from OnLoad() from the script file. Registers the custom event name and returns an event ID for use by other mods in subscribing to custom events.
---@param eventName string
---@return uint eventId @ Bespoke event id for this custom event.
Events.RegisterCustomEventName = function(eventName)
    if eventName == nil then
        error("Events.RegisterCustomEventName called with missing arguments")
    end
    local eventId
    if MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    else
        eventId = script.generate_event_name()
        MOD.customEventNameToId[eventName] = eventId
    end
    return eventId
end

--- Called when needed
---@param eventName defines.events|string @ Either a default Factorio event or a custom input action name.
---@param handlerName string @ The unique handler name to remove from this eventName.
Events.RemoveHandler = function(eventName, handlerName)
    if eventName == nil or handlerName == nil then
        error("Events.RemoveHandler called with missing arguments")
    end
    if MOD.eventsById[eventName] ~= nil then
        for i, handler in pairs(MOD.eventsById[eventName]) do
            if handler.handlerName == handlerName then
                table.remove(MOD.eventsById[eventName], i)
                break
            end
        end
    elseif MOD.eventsByActionName[eventName] ~= nil then
        for i, handler in pairs(MOD.eventsByActionName[eventName]) do
            if handler.handlerName == handlerName then
                table.remove(MOD.eventsByActionName[eventName], i)
                break
            end
        end
    end
end

--- Called when needed, but not before tick 0 as they are ignored. Can either raise a custom registered event registered by Events.RegisterCustomEventName(), or one of the limited events defined in the API: https://lua-api.factorio.com/latest/LuaBootstrap.html#LuaBootstrap.raise_event.
---
--- Older Factorio versions allowed for raising any base Factorio event yourself, so review on upgrade.
---@param eventData UtilityEvents_EventData
Events.RaiseEvent = function(eventData)
    eventData.tick = game.tick
    local eventName = eventData.name
    if type(eventName) == "number" then
        script.raise_event(eventName, eventData)
    elseif MOD.customEventNameToId[eventName] ~= nil then
        local eventId = MOD.customEventNameToId[eventName]
        script.raise_event(eventId, eventData)
    else
        error("WARNING: raise event called that doesn't exist: " .. eventName)
    end
end

--- Called from anywhere, including OnStartup in tick 0. This won't be passed out to other mods however, only run within this mod.
---
--- This calls this mod's event handler bypassing the Factorio event system.
---@param eventData UtilityEvents_EventData
Events.RaiseInternalEvent = function(eventData)
    eventData.tick = game.tick
    local eventName = eventData.name
    if type(eventName) == "number" then
        Events._HandleEvent(eventData)
    elseif MOD.customEventNameToId[eventName] ~= nil then
        eventData.name = MOD.customEventNameToId[eventName]
        Events._HandleEvent(eventData)
    else
        error("WARNING: raise event called that doesn't exist: " .. eventName)
    end
end

--------------------------------------------------------------------------------------------
--                                    Internal Functions
--------------------------------------------------------------------------------------------

--- Runs when an event is triggered and calls all of the approperiate registered functions.
---@param eventData UtilityEvents_EventData
Events._HandleEvent = function(eventData)
    -- input_name only populated by custom_input, with eventId used by all other events
    -- Numeric for loop is faster than pairs and this logic is black boxed from code developer using library.
    if eventData.input_name == nil then
        -- All non custom input events (majority).
        local eventsById = MOD.eventsById[eventData.name]
        for i = 1, #eventsById do
            eventsById[i].handlerFunction(eventData)
        end
    else
        -- Custom Input type event.
        local eventsByInputName = MOD.eventsByActionName[eventData.input_name]
        for i = 1, #eventsByInputName do
            eventsByInputName[i].handlerFunction(eventData)
        end
    end
end

--- Registers the function in to the mods event to function matrix. Handles merging filters between multiple functions on the same event.
---@param eventName string
---@param thisFilterName string @ The handler name.
---@param thisFilterData? table|nil
---@return uint|nil
Events._RegisterEvent = function(eventName, thisFilterName, thisFilterData)
    if eventName == nil then
        error("Events.RegisterEvent called with missing arguments")
    end
    local eventId  ---@type uint
    local filterData  ---@type table
    thisFilterData = TableUtils.DeepCopy(thisFilterData) -- Deepcopy it so if a persisted or shared table is passed in we don't cause changes to source table.
    if type(eventName) == "number" then
        eventId = eventName
        if thisFilterData ~= nil then
            if TableUtils.IsTableEmpty(thisFilterData) then
                -- filter isn't nil, but has no data, so as this won't register to any filters just drop it.
                return nil
            end
            MOD.eventFilters[eventId] = MOD.eventFilters[eventId] or {}
            MOD.eventFilters[eventId][thisFilterName] = thisFilterData
            local currentFilter, currentHandler = script.get_event_filter(eventId), script.get_event_handler(eventId)
            if currentHandler ~= nil and currentFilter == nil then
                -- an event is registered already and has no filter, so already fully lienent.
                return eventId
            else
                -- add new filter to any existing old filter and let it be re-applied.
                filterData = {}
                for _, filterTable in pairs(MOD.eventFilters[eventId]) do
                    filterTable[1].mode = "or"
                    for _, filterEntry in pairs(filterTable) do
                        table.insert(filterData, filterEntry)
                    end
                end
            end
        end
    elseif MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    else
        eventId = script.generate_event_name()
        MOD.customEventNameToId[eventName] = eventId
    end
    script.on_event(eventId, Events._HandleEvent, filterData)
    return eventId
end

return Events

---@class UtilityEvents_EventHandlerObject
---@field handlerName string
---@field handlerFunction function
