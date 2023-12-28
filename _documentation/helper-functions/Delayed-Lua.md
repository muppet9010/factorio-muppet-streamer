Provides a way to schedule Lua code to be run at a later date. Includes remote interfaces to add and cancel scheduled Lua code, plus a way to update it's persisted data if required.

> Fire artillery at the player after a random delay time, but a few seconds before the shells fire warn the player. In real world you might make the delays much larger so the streamer forgets about the artillery that will come later some time.

```
/sc
local warnPlayerFunctionString = [==[ function(delayedData)
    rendering.draw_text({text="take cover !", surface=delayedData.player.surface, target=delayedData.player.character or delayedData.player.position, scale=2, time_to_live=180, color = {1,1,1}, alignment="center"})
end ]==]
local player = game.connected_players[1]
local delaySeconds = math.random(6, 10)
remote.call('muppet_streamer', 'run_command', 'muppet_streamer_schedule_explosive_delivery', {delay=delaySeconds, explosiveCount=10, explosiveType="artilleryShell", target=player.name, accuracyRadiusMax=10})
remote.call("muppet_streamer", "add_delayed_lua", (delaySeconds-3)*60, warnPlayerFunctionString, {player=player})
```

-------------------------



# Technical Feature

All of the Muppet Streamer effects include delay options, however, many other mods and direct Lua code do not include options to delay the effect. Often streamers will want to have some warning text or other effect happen before large events. This Delayed Lua helper function provides a way to achieve this without requiring the use of a mod to achieve the delay. In more complicated usage cases creating a dedicated mod to achieve the desired effect may be advisable, including if you need to react to Factorio events.

This is a technically involved code helper function, rather than a friendly streamer effect. As such the streamer will need to be comfortable writing Lua code and handling any edge cases within their Lua code, i.e. the player dyeing during the delay or effect, or the targeted player being kicked from the server.

The examples included in this document can be just copy & pasted in to your game for testing. They won't handle ever odd situation that may occur and are provided for demonstrating the features in a standard gameplay situation. All examples target the first online player returned by Factorio using `game.connected_players`, which in testing is envisaged to be you.

-------------------------



# Add delayed Lua function

This remote interface is the way to schedule a Lua code function to be run at a later date. Please read the usage notes carefully as there are many limitations and considerations to its usage.

#### Syntax

```
remote.call("muppet_streamer", "add_delayed_lua", [DELAY], [FUNCTION_STRING], [DATA])
```

#### Arguments

| Argument Name | Required | Details |
| --- | --- | --- |
| DELAY | Mandatory | How many ticks before the Lua function is run. A `0` tick delay makes it happen instantly. |
| FUNCTION_STRING | Mandatory | The Lua code you want run after the delay within a Lua function. The function will have the `DATA` argument passed in to it as its single parameter. The function must be provided as a string. Examples use `[==[` and `]==]` to delimit the string as that way any `"` within it don't need escaping. |
| DATA | Optional | A Lua table that is passed in to the Lua function when it's run. This table is provided at scheduling time and persisted until the functions execution time. It is the only way to pass in data to the delayed Lua function. |

#### Returns

None of the returned values have to be captured in to a variable, unless you actively want to use it for a follow up remote interface call to cancel the delayed Lua function or to update its cached data object.

| Returned order number | Details |
| --- | --- |
| First | The schedule Id of the delayed Lua function. This can be used by the `remove_delayed_lua` remote interface to cancel the scheduled Lua function. Typically only used in more complicated usage cases. See the `remove_delayed_lua` remote interface for usage examples. |

#### Notes

- The delayed Lua function is run in an error safe manner where any error is caught, rather than crashing the game. The high level error is printed to screen along with the name of a file created in the Factorio `script-data` folder with the full error details in it. These error detail files are only uniquely named within a single run of a single save game, as they are just the Id of the delayed Lua function and not unique across Factorio saves, etc.
- If you pass in an actual Lua function, rather than the string version of it you will get an error from Factorio: `Cannot execute command. Error: Can't copy object of type function`.
- The Lua function will be run in isolation to the Lua state when it was scheduled. This means you can't pass anything in to the function other than via the DATA Lua table. See the bad example below for further details. As the Lua function is stringified it's references to any variable declared outside of it are lost before it is run. If you do this then when the delayed function runs you will likely get errors about: `attempt to index upvalue`. For this reason its advised to use different variable names outside of the scheduled function to avoid your confusion; You'll see this in the examples, specifically the `data` variable as it exists within the delayed Lua function and outside of the function when it is initially scheduled.
- The `DATA` passed in to each `add_delayed_lua` remote interface call is effectively deep copied when stored for running later. So a shared function data table passed in to multiple delayed Lua code remote interface calls won't be kept in sync between each delayed function.
- This feature is save/load safe and is why a lot of the limitations/oddities of usage exist. These are required to avoid the end user having to make a mod to achieve the delay.

#### Example - Concept

A very simple demonstration of using a single delayed Lua function that prints to screen the game tick of when its queued and run. Includes demonstration passing in of data.

```
/sc
local testFunctionString = [==[ function(delayedData)
    game.print(game.tick .. " - delayed - name: " .. delayedData.name)
end ]==]

local outerData = {name = "me"}

remote.call("muppet_streamer", "add_delayed_lua", 60, testFunctionString, outerData)
game.print(game.tick .. " - queued time")
```

#### Example - Multiple delayed Lua code

For 30 seconds the player will damage any vehicle they are in every second.

We do this by scheduling many delayed functions to run once every second for the next 30 seconds. With every execution of this function confirming the game state before doing anything. The code is targetting player number 1 in the game.

```
/sc
local damageVehicleFunctionString = [==[ function(delayedData)
    local vehicle = delayedData.player.vehicle
    if vehicle ~= nil then
        local maxHealth = vehicle.prototype.max_health
        vehicle.damage(maxHealth/10, delayedData.player.force, "acid", delayedData.player.character)
    end
end ]==]

local outerData = {player = game.connected_players[1]}

for i=0, 30 do
    remote.call("muppet_streamer", "add_delayed_lua", i*60, damageVehicleFunctionString, outerData)
end
```

#### Example - Looping Delayed Lua code

Until the player dies remove 50 HP from them every second. No limit on how long this will run for, just until the player doesn't have a character alive any more.

We do this by scheduling one Delayed Lua function that checks if the player is still alive, if they are they suffer 1 damage and the same function text is scheduled again for 1 second later. This utilises the fact that we can safely store the function's text in the `data` and then each time the function is run it can use this initially stored function text to schedule the next Delayed Lua function. Each time the function is run it is a fresh instance from the raw text version and so no persistence exists between the functions, other than the standard persisted `data` object. The code is targetting player number 1 in the game.

```
/sc
local damagePlayerFunctionString = [==[ function(delayedData)
    if delayedData.player.character == nil then
        game.print(delayedData.player.name .. " died after " .. delayedData.cycles .. " damage cycles !")
        return
    end
    delayedData.player.character.damage(50, delayedData.player.force, "acid")
    delayedData.cycles = delayedData.cycles + 1
    game.print(delayedData.player.name .. " damaged " .. delayedData.cycles .. " times")
    remote.call("muppet_streamer", "add_delayed_lua", 60, delayedData.damagePlayerFunctionString, delayedData)
end ]==]

local outerData = {player = game.connected_players[1], damagePlayerFunctionString = damagePlayerFunctionString, cycles = 0}

remote.call("muppet_streamer", "add_delayed_lua", 60, damagePlayerFunctionString, outerData)
```

#### Example - Bad data passing

A demonstration of passing bad data in to the delayed function code. These bad things are all titled `bad`. While they will work if you run the lua code directly, they won't survive the stringify process to store the delayed function in Factorio to make it save/load safe.

```
/sc
local badVariable = "me"
local badFunction = function()
    game.print("bad function")
end
local goodCommonVariableName = "outerValue"
local goodDataPassedIn = {name = "muppet9010}

local testFunctionString = [==[ function(delayedData)
    game.print(badVariable)
    badFunction()

    local _goodCommonVariableName = "innerValue"
    game.print(delayedData.name .. " logged as an " .. _goodCommonVariableName)
end ]==]

remote.call("muppet_streamer", "add_delayed_lua", 60, testFunctionString, goodDataPassedIn)
```

-------------------------



# Remove delayed Lua function

This remote interface is the way to remove a previously scheduled Lua code function. It's only used in more complicated usage cases.

#### Syntax

```
remote.call("muppet_streamer", "remove_delayed_lua", [SCHEDULE_ID])
```

#### Arguments

| Argument Name | Required | Details |
| --- | --- | --- |
| SCHEDULE_ID | Mandatory | This is the schedule Id that the `remove_delayed_lua` remote interface removes so it doesn't run. |

#### Returns

None of the returned values have to be captured in to a variable, unless you actively want to check for the successful removal.

| Returned order number | Details |
| --- | --- |
| First | If a delayed Lua function with the provide scheduleId existed and was removed or not. Returns a `boolean`` value. |

#### Notes

- A trick to remove a series of later delayed Lua functions is to add them backwards (latest first). Then you can store the Id of each additional scheduled function and pass this in to the next function scheduled. This lets the earlier run functions know about the later queued functions. See the `Example - Cancel later scheduled functions` for demonstration.

#### Example - Concept

A very simple demonstration of adding 3 scheduled functions and then removing the second one. So that only the first and third print to screen with their 1 second delay between each originally scheduled functions.

```
/sc
local printRunFunctionString = [==[ function(delayedData)
    game.print("run: " .. delayedData.name .. " at: " .. game.tick)
end ]==]

remote.call("muppet_streamer", "add_delayed_lua", 60, printRunFunctionString, {name = "first"})
local secondScheduledId = remote.call("muppet_streamer", "add_delayed_lua", 120, printRunFunctionString, {name = "second"})
remote.call("muppet_streamer", "add_delayed_lua", 180, printRunFunctionString, {name = "third"})

game.print("queued time: " .. game.tick)

remote.call("muppet_streamer", "remove_delayed_lua", secondScheduledId)
```

#### Example - Cancel later scheduled functions

If the player is found to have died during 30 seconds we create an enemy worm near their body. Only happens on their first death.

Every second during 30 seconds we check if the player has no character. Assuming they were playing normally this would signify that they have died. Once we discover they have died we create a behemoth worm near their position, which should be their body still. We then remove all future delayed function calls in this series so that only 1 worm is created, as otherwise for the remainder of the 30 seconds every second that the player remains dead we would add a new worm.

The code is targetting player number 1 in the game. Also this example idea is on the edge of needing a proper mod as really it should react to the players death Factorio event, however, we are instead polling every second to see if they have just died.

When adding the 30 delayed functions (1 per second) we add them backwards (latest first). This is so that we can build up a list of the scheduled function Ids to be run after the delayed function we are currently adding and pass this list in to each delayed function's `data` object. This way when a given delayed function reacts to the players death it knows about all of the later (still to occur) delayed functions and can remove them. While we are adding them to the same `data` Lua table in the code during registering the delayed functions, remember that the `data` table is effectively DeepCopied upon receipt when adding each delayed function and so at each scheduled function's execution time it has a unique list of just the delayed schedule Ids that will be run after it.

```
/sc
local playerDiedFunctionString = [==[ function(delayedData)
    if delayedData.player.character == nil then
        local surface = delayedData.player.surface
        local wormPosition = surface.find_non_colliding_position("behemoth-worm-turret", delayedData.player.position, 10, 0.1)
        if wormPosition ~= nil then
            surface.create_entity({name="behemoth-worm-turret", position=wormPosition, force="enemy"})
        end
        for _, scheduleId in pairs(delayedData.laterScheduleIds) do
            remote.call("muppet_streamer", "remove_delayed_lua", scheduleId)
        end
    end
end ]==]

local outerData = {player = game.connected_players[1], laterScheduleIds = {}}

for i=30, 0, -1 do
    local scheduleId = remote.call("muppet_streamer", "add_delayed_lua", i*60, playerDiedFunctionString, outerData)
    outerData.laterScheduleIds[#outerData.laterScheduleIds+1] = scheduleId
end
```

-------------------------



# Get delayed Lua function data

This remote interface is the way to get the `data` Lua table of a previously scheduled Lua code function. It's only useful when you later update the data back in to the delayed function with the `set_delayed_lua_data` remote interface.

#### Syntax

```
remote.call("muppet_streamer", "get_delayed_lua_data", [SCHEDULE_ID])
```

#### Arguments

| Argument Name | Required | Details |
| --- | --- | --- |
| SCHEDULE_ID | Mandatory | This is the schedule Id that the `get_delayed_lua_data` remote interface returns the `data` Lua table from. |

#### Returns

You don't technically have to capture the returned value, but the remote interface's only purpose is to return the `data` Lua table.

| Returned order number | Details |
| --- | --- |
| First | The `data` Lua table of the delayed Lua function with the provided schedule Id. This will either be a Lua table `{}` or may be `nil` if no data table was set when the delayed function was added, as its an optional argument. |

#### Example - Concept

A very simple demonstration of getting the data from a previously scheduled Lua function. This is entirely an abstract use case, see the `set_delayed_lua_data` examples for real world use cases.

```
/sc
local testFunctionString = [==[ function(delayedData)
    game.print("delayed - name: " .. delayedData.name)
end ]==]

local outerData = {name = "me"}

local scheduleId = remote.call("muppet_streamer", "add_delayed_lua", 60, testFunctionString, outerData)

local delayedData = remote.call("muppet_streamer", "get_delayed_lua_data", scheduleId)
game.print("future scheduled - name: " .. delayedData.name)
```

-------------------------



# Set delayed Lua function data

This remote interface is the way to set the `data` Lua table of a previously scheduled Lua code function.

#### Syntax

```
remote.call("muppet_streamer", "set_delayed_lua_data", [SCHEDULE_ID], [DATA])
```

#### Arguments

| Argument Name | Required | Details |
| --- | --- | --- |
| SCHEDULE_ID | Mandatory | This is the schedule Id that the `set_delayed_lua_data` remote interface set the `data` Lua table for. |
| DATA | Optional | This is the `data` that will be set for the delayed Lua function. It can either be a Lua table or nil. See `data` for the `add_delayed_lua` remote interface for full details on how this data will be used when the delayed Lua function is executed later on.

#### Returns

None of the returned values have to be captured in to a variable, unless you actively want to check for the successful update.

| Returned order number | Details |
| --- | --- |
| First | If a delayed Lua function with the provide scheduleId existed and was updated or not. Returns a `boolean`` value. |

#### Example - Concept

A very simple demonstration of getting the data from a previously scheduled Lua function and setting it back to update it.

```
/sc
local testFunctionString = [==[ function(delayedData)
    game.print("delayed - name: " .. delayedData.name)
end ]==]

local outerData = {name = "me"}

local scheduleId = remote.call("muppet_streamer", "add_delayed_lua", 60, testFunctionString, outerData)
game.print("original - name: " .. outerData.name)

local obtainedDelayedData = remote.call("muppet_streamer", "get_delayed_lua_data", scheduleId)
obtainedDelayedData.name = obtainedDelayedData.name .. "UPDATED"
remote.call("muppet_streamer", "set_delayed_lua_data", scheduleId, obtainedDelayedData)
```

#### Example - Updating a delayed function's data.

After 5 and 10 seconds we reward the player based on if they were in a vehicle 5 seconds prior. So at 0 seconds we decide the reward they will receive after 5 seconds, and at 5 seconds we decide the reward they will receive after 10 seconds.

We schedule the same function to run in 5 and 10 seconds. Then we update the 5 second delayed function's data with the schedule Id of the 10 second delayed function, plus if the player is in a vehicle at 0 seconds. When the 5 second delayed function executes, as well as giving it's own reward to the player based on it's data, it also checks if the player is currently in a vehicle and adds this to the 10 second delayed function's data. Then when the 10 second delayed function runs it knows what reward to give the player from 5 seconds previous.

```
/sc
local rewardPlayerFunctionString = [==[ function(delayedData)
    if delayedData.hadVehicle == true then
        delayedData.player.insert({name="rocket-fuel", count=10})
        game.print(game.tick .. " - there was a vehicle recently, so have some fuel")
    elseif delayedData.hadVehicle == false then
        delayedData.player.insert({name="exoskeleton-equipment", count=1})
        game.print(game.tick .. " - no vehicle recently, so have some exoskeleton legs")
    else
        game.print(game.tick .. " - failure, no hadVehicle state set")
    end

    if delayedData.nextScheduledId ~= nil then
        local nextDelayedData = remote.call("muppet_streamer", "get_delayed_lua_data", delayedData.nextScheduledId)
        nextDelayedData.hadVehicle = nextDelayedData.player.driving
        remote.call("muppet_streamer", "set_delayed_lua_data", delayedData.nextScheduledId, nextDelayedData)
    end
end ]==]

local player = game.connected_players[1]
local playerHasVehicle = player.driving

local firstScheduledId = remote.call("muppet_streamer", "add_delayed_lua", 300, rewardPlayerFunctionString, nil)
local secondScheduledId = remote.call("muppet_streamer", "add_delayed_lua", 600, rewardPlayerFunctionString, {player = player})

local firstScheduledData = {player = player, nextScheduledId = secondScheduledId, hadVehicle = playerHasVehicle}
remote.call("muppet_streamer", "set_delayed_lua_data", firstScheduledId, firstScheduledData)
```

-------------------------



# Rich features using Delayed Lua

I have previously developed some complex features for streamers using Delayed Lua. These are highly customisable by the user, and entire sections of the feature could be removed or added to as desired.
[Muppet's features made with Delayed Lua (separate github)](https://github.com/muppet9010/Factorio-Integration-Lua-Snippets)

## Biter Pet

Creates a behemoth biter that follows the player around and protects them.
[Biter Pet usage details (separate github)](https://github.com/muppet9010/Factorio-Integration-Lua-Snippets/blob/master/Biter%20Pet/Usage%20Details.md)

This script has some features over a simple biter creation command:

- It will keep on following the player as they get in and out of vehicles.
- The biter can be given a personal name in colored text as a nice touch for chat integrations when streaming.
- The biter will have its state/activity included in a label on it.
- If the player dies the biter will stay at their body until they return to the biter to collect it again.
- The biter will follow the player within some set ranges when just moving around.
- When the biter enters combat it can stray much further from the player, but if it gets too far then it will break off combat and return to its master. This means if the player runs away from a biter base your pet will eventually follow assuming it is still alive.
- The biter type is selected based on the enemy force evolution.
- It can also have bonus health based on enemy evolution. If so it will have a shared total health bar to show it's real and bonus health. Bonus health regenerates just like normal health when the biter is fully healed on real health.



-------------------------



# Code development and testing notes

- If using the Factorio Modding Tool Kit extension and running Factorio within Visual Studio Code then you can add a breakpoint in to a Lua script using: `__DebugAdapter.breakpoint()`
- The functionString in the examples are delimited by `[==[` and `]==]`, however you can use other valid Lua string delimiters. The traditional `"` with escaping inner quotes would look like: `local functionString = "function(delayedData) game.print(delayedData.name .. \" is great!\") end"`
- During development and testing of Lua code the functionString can be run directly and then copied into the functionString. Just make sure that all variables and scopes/contexts are considered. An approach to this is to prefix variable names used both outside and within the functionString differently. In the Bad Data Passing example in this page I prefix the inner variable names with `_`. I also do this in my larger real world use cases such as [Biter Pets (separate github)](https://github.com/muppet9010/Factorio-Integration-Lua-Snippets/blob/master/Biter%20Pet/Usage%20Details.md).
- The advantage of doing features via Delayed Lua over a mod is when extreme flexibility is desired. For example I use them when creating things that multiple streamers want to use, but each one has varying desires. I don't have to make either a mod per streamer or a single mod that supported every possible combination a streamer may desire. Each streamer could change any part they wished, add or remove parts from them.