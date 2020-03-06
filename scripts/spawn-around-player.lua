local SpawnAroundPlayer = {}
local Commands = require("utility/commands")
local Logging = require("utility/logging")
local EventScheduler = require("utility/event-scheduler")
local Utils = require("utility/utils")

SpawnAroundPlayer.CreateGlobals = function()
    global.spawnAroundPlayer = global.spawnAroundPlayer or {}
    global.spawnAroundPlayer.nextId = global.spawnAroundPlayer.nextId or 0
end

SpawnAroundPlayer.OnLoad = function()
    Commands.Register("muppet_streamer_spawn_around_player", {"api-description.muppet_streamer_spawn_around_player"}, SpawnAroundPlayer.SpawnAroundPlayerCommand)
    EventScheduler.RegisterScheduledEventType("SpawnAroundPlayer.SpawnAroundPlayer", SpawnAroundPlayer.SpawnAroundPlayer)
end

SpawnAroundPlayer.SpawnAroundPlayerCommand = function(command)
    local errorMessageStart = "ERROR: muppet_streamer_spawn_around_player command "
    local commandData = game.json_to_table(command.parameter)
    if commandData == nil or type(commandData) ~= "table" then
        Logging.LogPrint(errorMessageStart .. "requires details in JSON format.")
        return
    end

end

SpawnAroundPlayer.SpawnAroundPlayer = function(eventData)

end

return SpawnAroundPlayer