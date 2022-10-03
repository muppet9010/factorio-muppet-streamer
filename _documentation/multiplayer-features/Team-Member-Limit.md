A way to soft limit the number of players on the map and options to use either Factorio research or RCON commands to increase it.

Intended for use by a single streamer and so the simple one line GUI in the top left reports the current number of team members to the streamer (players on the server - 1).



#### Features Usage

The Team Member Limit feature's usage is controlled via the startup setting `Team member technology pack count`. It defaults to `-1` for disabled. When being used the limit on players can be increased either by technology research or from Command/Remote Interface, but not both.

- A value of `-1` disables the entire feature. This is needed as the feature adds GUIs and shortcuts, thus if you aren't using it you don't want these present.
- A value of `0` hides the technology from the research screen and enables the Command and Remote Interface to be used to change the max player limit.
- A value of greater than `0` shows the technology in the research screen and prevents the Command and Remote Interface from being used.



#### Technology Research

Research to increase the number of team members. Requires vanilla Factorio science packs to exist. Cost is configurable and the research levels increase in science pack complexity. Includes infinite options that double in cost each time.



#### Command and Remote Interface

Command and Remote interface to increase the max team member count by a set amount.

Command:

- syntax: `/muppet_streamer_change_team_member_max NUMBER`
- example to increase by 2: `/muppet_streamer_change_team_member_max 2`

Remote Interface:

- syntax: muppet_streamer , increase_team_member_level , NUMBER
- example to increase by 2: `remote.call('muppet_streamer', 'increase_team_member_level', 2)`