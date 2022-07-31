--[[
    Generic EmmyLua classes. You don't need to require this file anywhere, EmmyLua will discover it within the workspace.
--]]
--
---@meta
---@diagnostic disable
--
--
--
--
--
--
--
--
--[[




Example of defining a dictionary as containing all the same type of values en-bulk.
With just this you can't valid the dictionary level, just the selected value in it.

---@type {[string]:Color}
local Colors = {}




Often a Factorio returned type will differ from expected due to it having different types for its read and write. There are ongoing works to fix this, but for now just "@as" to fix it with a comment that its a work around and not an intentional "@as".
NOTE: in the below example the * from the end of each line needs to be removed so the comment closes. Its just in this example reference the whole block is already in a comment and so we can't let it close on each line.

local player = game.players[1] -- Is type of LuaPlayer.
local force ---@type LuaForce
force = player.force --[[@as LuaForce @Debugger Sumneko temp fix for different read/write]*]

--]]
--
