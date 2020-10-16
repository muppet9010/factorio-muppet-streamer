local Teleport = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")
local Events = require("utility/events")

Teleport.CreateGlobals = function()
    global.teleport = global.teleport or {}
    global.teleport.nextId = global.teleport.nextId or 0
end

Teleport.OnLoad = function()
    Commands.Register("muppet_streamer_teleport", {"api-description.muppet_streamer_teleport"}, Teleport.TeleportCommand, true)
    EventScheduler.RegisterScheduledEventType("Teleport.Teleport", Teleport.Teleport)
end

Teleport.OnStartup = function()
end

Teleport.TeleportCommand = function(command)
end

Teleport.Teleport = function(event)
end

return Teleport
