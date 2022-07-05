local Freeplay = {}
local GameUtils = require("utility.game-utils")

Freeplay.OnStartup = function()
    if settings.startup["muppet_streamer-disable_intro_message"].value then
        GameUtils.DisableIntroMessage()
    end
    if settings.startup["muppet_streamer-disable_rocket_win"].value then
        GameUtils.DisableWinOnRocket()
    end
    local startingReveal = settings.startup["muppet_streamer-starting_reveal"].value
    if startingReveal >= 0 then
        GameUtils.SetStartingMapReveal(startingReveal)
    end
end

return Freeplay
