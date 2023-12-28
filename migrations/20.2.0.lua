local EventScheduler = require("utility.manager-libraries.event-scheduler")

-- Check any existing scheduled events and if thy include bytecode then error to avoid losing them in this save moving forwards.
-- The user will have to manually deal with this to be able to continue. Unexpected to ever be an issue.
-- The technical details are all lifted from the delayed-lua.lua file.
-- Have to do this raw due to bugs in EventScheduler utility, but they can't be fixed without updating the whole library which includes break changes. So just do it raw for now.
local scheduledEventTicks = global.UTILITYSCHEDULEDFUNCTIONS
if scheduledEventTicks ~= nil then
    for _, scheduledEventTypes in pairs(scheduledEventTicks) do
        for scheduledEventTypeName, scheduledEvents in pairs(scheduledEventTypes) do
            if scheduledEventTypeName == "DelayedLua.ActionDelayedLua" then
                for _, eventData in pairs(scheduledEvents) do
                    if eventData ~= nil then
                        local functionString = eventData.functionString --[[@as string]]
                        if functionString ~= nil then
                            -- Make sure the provided string isn't bytecode.
                            if string.find(functionString, "^\27LuaR\0\1\4\8\4\8\0\25") ~= nil then
                                -- Has a Lua header, so is bytecode.
                                error("Delayed Lua - delayed function has bytecode in it. This is incompatible with the new mod version and Factorio, but can't be auto corrected. Contact mod author for advice on how to handle this situation.")
                            end
                        end
                    end
                end
            end
        end
    end
end
