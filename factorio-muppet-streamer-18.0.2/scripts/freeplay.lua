local Freeplay = {}
local Utils = require("utility/utils")

Freeplay.OnLoad = function()
    if settings.startup["muppet_streamer-disable_silo_counter"].value then
        Utils.DisableSiloScript()
    end
end

Freeplay.OnStartup = function()
    if settings.startup["muppet_streamer-disable_intro_message"].value then
        Utils.DisableIntroMessage()
    end
    if settings.startup["muppet_streamer-disable_rocket_win"].value then
        Utils.DisableWinOnRocket()
    end
end

return Freeplay
