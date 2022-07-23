---@meta

---@class Sound
---@field aggregation? Sound.Aggregation
---@field variations? Sound.Variations[]
---@field filename FileName #Mandatory if SoundVariations is not given
---@field preload? boolean #Only loaded if SoundVariations is not given
---@field speed? float #Only loaded if SoundVariations is not given
---@field min_speed? float #Only loaded if SoundVariations is not given
---@field max_speed? float #Only loaded if SoundVariations is not given
local Sound = {
  allow_random_repeat = false,
  audible_distance_modifier = 1, ---@type double
}

---@class Sound.Aggregation
---@field max_count uint
local SoundAggreation = {
  progress_threshold = 1.0,
  remove = false,
  count_already_playing = false
}

---@class Sound.Variations
---@field filename FileName
local SoundVariations = {
  volume = 1.0,
  preload = false,
  speed = 1.0, --Speed must be >= 1 / 64. This sets both min and max speed.
  min_speed = 1.0, --Not loaded if speed is present. Speed must be >= 1 / 64.
  max_speed = 1.0, --Mandatory if min_speed is present, otherwise not loaded. Must be >= min_speed.
}
