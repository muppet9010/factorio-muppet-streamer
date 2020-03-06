local Utils = require("utility/utils")
--local Logging = require("utility/logging")

local Events = {}
MOD = MOD or {}
MOD.events = MOD.events or {}
MOD.customEventNameToId = MOD.customEventNameToId or {}

-- Called either from the root of Control.lua or from OnLoad for vanilla events and custom events.
-- Filtered events have to expect to recieve results outside of their filter. As an event can only be registered one time, with multiple instances the most lienient or merged filters for all instances must be applied.
Events.RegisterEvent = function(eventName, filterData)
    if eventName == nil then
        error("Events.RegisterEvent called with missing arguments")
    end
    local eventId
    if Utils.GetTableKeyWithValue(defines.events, eventName) ~= nil then
        eventId = eventName
        if filterData ~= nil then
            local currentFilter, currentHandler = script.get_event_filter(eventId), script.get_event_handler(eventId)
            if currentHandler ~= nil then
                if currentFilter == nil then
                    --event registered with no filter, so already fully lienent.
                    return
                else
                    --add new filter to old filter and let it be re-applied.
                    currentFilter[1].mode = "or"
                    for _, currentFilterEntry in pairs(currentFilter) do
                        table.insert(filterData, currentFilterEntry)
                    end
                end
            --else
            --no current handler so just let our filter be set.
            end
        --else
        --we're not filtering so just blindly overwrite whatever is there safely.
        end
    elseif MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    elseif type(eventName) == "number" then
        eventId = eventName
    else
        eventId = script.generate_event_name()
        MOD.customEventNameToId[eventName] = eventId
    end
    script.on_event(eventId, Events._HandleEvent, filterData)
end

--Called from the root of Control.lua for custom inputs (key bindings) as their names are handled specially.
Events.RegisterCustomInput = function(actionName)
    if actionName == nil then
        error("Events.RegisterCustomInput called with missing arguments")
    end
    script.on_event(actionName, Events._HandleEvent)
end

--Called from OnLoad() from each script file. Handles all event types and custom inputs.
Events.RegisterHandler = function(eventName, handlerName, handlerFunction)
    if eventName == nil or handlerName == nil or handlerFunction == nil then
        error("Events.RegisterHandler called with missing arguments")
    end
    local eventId
    if MOD.customEventNameToId[eventName] ~= nil then
        eventId = MOD.customEventNameToId[eventName]
    else
        eventId = eventName
    end
    MOD.events[eventId] = MOD.events[eventId] or {}
    MOD.events[eventId][handlerName] = handlerFunction
end

--Called when needed
Events.RemoveHandler = function(eventName, handlerName)
    if eventName == nil or handlerName == nil then
        error("Events.RemoveHandler called with missing arguments")
    end
    if MOD.events[eventName] == nil then
        return
    end
    MOD.events[eventName][handlerName] = nil
end

--inputName used by custom_input , with eventId used by all other events
Events._HandleEvent = function(eventData)
    local eventId, inputName = eventData.name, eventData.input_name
    if MOD.events[eventId] ~= nil then
        for _, handlerFunction in pairs(MOD.events[eventId]) do
            handlerFunction(eventData)
        end
    elseif MOD.events[inputName] ~= nil then
        for _, handlerFunction in pairs(MOD.events[inputName]) do
            handlerFunction(eventData)
        end
    end
end

--Called when needed, but not before tick 0 as they are ignored
Events.RaiseEvent = function(eventData)
    eventData.tick = game.tick
    local eventName = eventData.name
    if defines.events[eventName] ~= nil then
        script.raise_event(defines.events[eventName], eventData)
    elseif MOD.customEventNameToId[eventName] ~= nil then
        local eventId = MOD.customEventNameToId[eventName]
        script.raise_event(eventId, eventData)
    elseif type(eventName) == "number" then
        script.raise_event(eventName, eventData)
    else
        error("WARNING: raise event called that doesn't exist: " .. eventName)
    end
end

--Called from anywhere, including OnStartup in tick 0. This won't be passed out to other mods however, only run within this mod.
Events.RaiseInternalEvent = function(eventData)
    eventData.tick = game.tick
    local eventName = eventData.name
    if defines.events[eventName] ~= nil then
        Events._HandleEvent(eventData)
    elseif MOD.customEventNameToId[eventName] ~= nil then
        eventData.name = MOD.customEventNameToId[eventName]
        Events._HandleEvent(eventData)
    elseif type(eventName) == "number" then
        Events._HandleEvent(eventData)
    else
        error("WARNING: raise event called that doesn't exist: " .. eventName)
    end
end

return Events
