All of the commands take a table of options as a JSON string when they are called to provide the configuration of the command. All of the command examples include this format and so can be copy/pasted straight into the game.

#### Argument Data Types

- INTEGER = expects a whole number and not a fraction. So `1.5` is a bad value. Integers are not wrapped in double quotes.
- DECIMAL = can take a fraction, i.e `0.25` or `54.28437`. In some usage cases the final result will be rounded to a degree when processed, i.e. `0.4` seconds will have to be rounded to a single tick accuracy to be timed within the game. Decimals are not wrapped in double quotes.
- BOOLEAN = expects either `true` or `false`. Booleans are not wrapped in double quotes.
- STRING = a text string wrapped in double quotes, i.e. `"some text"`
- STRING_LIST = a comma separated list of things in a single string, i.e. `"Player1,player2, Player3  "`. Any leading or trailing spaces will be removed from each entry in the list. The casing (capitalisation) of things must match the case within factorio exactly, i.e. player names must have the same case as within Factorio. This can be a single thing in a string, i.e. `"Player1"`.
- POSITION = Arguments that accept a position will accept either a table or an array for the positional data. Both formats are recording 2 coordinates, an `x` and `y` value. They can be provided as either a table JSON string `{"x":10, "y":-5}` or as a shorter array JSON string `[10, -5]`.
- OBJECT = some features accept an object as an argument. These are detailed in the Notes for those functions. This is a dictionary of keys and values in JSON format (a table). The arguments each command accepts is an example of this.

#### Argument Requirements

- Mandatory = the option must be provided.
- Mandatory Special = the option is/can be mandatory, see the details on the option for specifics.
- Optional = you are free to include or exclude the option. The default value will be listed and used when the option isn't included or is a nil value. As well as not including optional options you can also pass in `null` to JSON strings or `nil` to Lua objects, if you wish to have the option name included to improve readability between different commands. While `null` isn't part of the JSON specification, the Factorio JSON string to Lua Object does handle it.

#### Number ranges

- Many options will have non-documented common sense minimum number requirements. i.e. you can't have a malfunctioning flamethrower activated for 0 or less bursts. These will raise a warning on screen and the command won't run.
- Many options will have non-documented maximum values at extremes. The known ones will be capped to the maximum allowed, i.e. number of seconds to delay an event for. However, so will be unknown about and are generally Factorio internal limits, so will not be prevented and may cause crashes. For this reason experimenting with ridiculously large numbers isn't advised.