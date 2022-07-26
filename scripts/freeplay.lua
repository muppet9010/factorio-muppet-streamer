local Freeplay = {} ---@class Freeplay
local GameUtils = require("utility.helper-utils.game-utils")

Freeplay.OnStartup = function()
    if settings.startup["muppet_streamer-disable_intro_message"].value --[[@as boolean]] == true then
        GameUtils.DisableIntroMessage()
    end
    if settings.startup["muppet_streamer-disable_rocket_win"].value --[[@as boolean]] == true then
        GameUtils.DisableWinOnRocket()
    end
    local startingReveal = settings.startup["muppet_streamer-starting_reveal"].value --[[@as int @ Can be -1 for not set (Factorio Settings), or 0+ as a set value.]]
    if startingReveal >= 0 then
        GameUtils.SetStartingMapReveal(startingReveal --[[@as uint]])
    end
end

return Freeplay
