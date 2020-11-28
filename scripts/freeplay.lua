local Freeplay = {}
local Utils = require("utility/utils")

Freeplay.OnStartup = function()
    if settings.startup["muppet_streamer-disable_intro_message"].value then
        Utils.DisableIntroMessage()
    end
    if settings.startup["muppet_streamer-disable_rocket_win"].value then
        Utils.DisableWinOnRocket()
    end
    local startingReveal = settings.startup["muppet_streamer-starting_reveal"].value
    if startingReveal >= 0 then
        Utils.SetStartingMapReveal(startingReveal)
    end
end

return Freeplay
