---@meta

do
  ---@alias TriggerItem.Type "direct" | "area" | "line" | "cluster"

  ---@alias TriggerDelivery.Type  "instant" | "projectile" | "flame-thrower" | "beam" | "stream" | "artillery"

  ---@alias TriggerEffectItem.Type
  --- | "damage"
  --- | "create-entity"
  --- | "create-explosion"
  --- | "create-fire"
  --- | "create-smoke"
  --- | "create-trivial-smoke"
  --- | "create-particle"
  --- | "create-sticker"
  --- | "create-decorative"
  --- | "nested-result"
  --- | "play-sound"
  --- | "push-back"
  --- | "destroy-cliffs"
  --- | "show-explosion-on-chart"
  --- | "insert-item"
  --- | "script"
  --- | "set-tile"
  --- | "invoke-tile-trigger"
  --- | "destroy-decoratives"
  --- | "camera-effect"

  ---@alias ExplosionPrototypeString string
  ---@alias FluidStreamPrototypeString string
  ---@alias BeamPrototypeString string
  ---@alias ArtilleryProjectilePrototypeString string
  ---@alias ProjectilePrototypeString string
  ---@alias DamageTypePrototypeString string
end

do
  ---@alias DamageTypeFilters.Specification DamageTypeFilters|DamageTypePrototypeString[]|DamageTypePrototypeString
  ---@class DamageTypeFilters
  ---@field types DamageTypePrototypeString[]|DamageTypePrototypeString
  local DamageTypeFilters = {
    whitelist = false
  }

  ---@class TriggerItem
  ---@field type TriggerItem.Type
  ---@field action_delivery TriggerDelivery
  ---@field collision_mask? CollisionMaskLayer[]
  local TriggerItem = {
    ignore_collision_condition = false,
    repeat_count = 1, ---@type uint
    probability = 1.0
  }

  ---@class DirectTriggerItem: TriggerItem
  local DirectTriggerItem = {
    filter_enabled = false,
    type = 'direct'
  }

  ---@alias AreaTriggerItem.collision_mode 'distance-from-collision-box' | 'distance-from-center'
  ---@class AreaTriggerItem: TriggerItem
  ---@field radius double #Mandatory
  local AreaTriggerItem = {
    type = 'area',
    trigger_from_target = false,
    target_entities = true,
    show_in_tooltip = true,
    collision_mode = 'distance-from-collision-box' ---@type AreaTriggerItem.collision_mode
  }

  ---@class ClusterTriggerItem: TriggerItem
  ---@field cluster_count double #Mandatory > 1
  ---@field distance float #Mandatory
  local ClusterTriggerItem = {
    type = 'cluster', ---@type string
    distance_deviation = 0.0
  }

  ---@class LineTriggerItem: TriggerItem
  ---@field range double #Mandatory
  ---@field width double Mandatory
  ---@field range_effects TriggerEffectItem[]
  local LineTriggerItem = {
    type = 'line', ---@type string
  }
end

do
  ---@class TriggerDelivery
  ---@field type TriggerDelivery.Type
  ---@field source_effects? TriggerEffectItem[]
  ---@field target_effects? TriggerEffectItem[]
  local TriggerDelivery = {}

  ---@class InstantTriggerDelivery: TriggerDelivery
  local InstantTriggerDelivery = {}

  ---@class ProjectileTriggerDelivery: TriggerDelivery
  ---@field projectile ProjectilePrototypeString
  ---@field starting_speed float
  local ProjectileTriggerDelivery = {
    starting_speed_deviation = 0.0,
    direction_deviation = 0.0,
    range_deviation = 0.0,
    max_range = 100, ---@type double
    min_range = 0 ---@type double
  }

  ---@class BeamTriggerDelivery: TriggerDelivery
  ---@field beam BeamPrototypeString
  ---@field source_offset? Vector<number, double>
  local BeamTriggerDelivery = {
    add_to_shooter = false,
    max_length = 0, ---@type uint
    duration = 0, ---@type uint
  }

  ---@class FlameThrowerTriggerDelivery: TriggerDelivery
  ---@field explosion ExplosionPrototypeString
  ---@field starting_distance double
  local FlameThrowerTriggerDelivery = {
    direction_deviation = 0.0,
    speed_deviation = 0.0,
    starting_frame_fraction_deviation = 0.0,
    projectile_starting_speed = 1.0
  }

  ---@class StreamTriggerDelivery: TriggerDelivery
  ---@field stream FluidStreamPrototypeString
  ---@field source_offset? Vector<number, double>
  local StreamTriggerDelivery = {}

  ---@class ArtilleryTriggerDelivery: TriggerDelivery
  ---@field projectile ArtilleryProjectilePrototypeString
  ---@field starting-speed float
  local ArtilleryTriggerDelivery = {
    starting_speed_deviation = 0.0,
    direction_deviation = 0.0,
    range_deviation = 0.0,
    trigger_fired_artillery = false
  }
end

do
  ---@class TriggerEffectItem
  ---@field type TriggerEffectItem.Type
  ---@field damage_type_filters? DamageTypeFilters.Specification
  local TriggerEffectItem = {
    repeat_count = 0, ---@type uint16
    repeat_count_deviation = 0, ---@type uint16
    probability = 1.0,
    affect_target = false,
    show_in_tooltip = true,
  }

  ---@class DamageTriggerEffectItem: TriggerEffectItem
  ---@field damage string #DamagePrototype
  local DamageTriggerEffectItem = {
    apply_damage_to_trees = true,
    vaporize = false,
    lower_distance_threshold = 65535, ---@type uint16
    upper_distance_threshold = 65535, ---@type uint16
    lower_damage_modifier = 1.0,
    upper_damage_modiier = 1.0,

  }

  ---@class CreateEntityTriggerEffectItem: TriggerEffectItem
  ---@field entity_name string
  ---@field offset_deviation? BoundingBox
  ---@field tile_collision_mask? CollisionMaskLayer[]
  ---@field offsets? Vector[]
  local CreateEntityTriggerEffectItem = {
    trigger_created_entity = false,
    check_buildability = false,
    show_in_tooltip = false,

  }

  ---@class CreateExplosionTriggerEffectItem: CreateEntityTriggerEffectItem
  local CreateExplosionTriggerEffectItem = {
    max_movement_distance = -1.0,
    max_movement_distance_deviation = 0.0,
    inherit_movement_distance_from_projectile = false,
    cycle_while_moving = false
  }

  ---@class CreateFireTriggerEffectItem: CreateEntityTriggerEffectItem
  local CreateFireTriggerEffectItem = {
    intial_ground_flame_count = 255 ---@type uint8
  }

  ---@class CreateSmokeTriggerEffectItem: CreateEntityTriggerEffectItem
  ---@field speed? Vector
  local CreateSmokeTriggerEffectItem = {
    initial_height = 0.0,
    speed_multiplier = 0.0,
    speed_multiplier_deviation = 0.0,
    starting_frame = 0.0,
    starting_frame_deviation = 0.0,
    starting_frame_speed = 0.0,
    speed_from_center = 0.0,
    speed_from_center_deviation = 0.0
  }

  ---@class CreateTrivialSmokeTriggerEffectItem: TriggerEffectItem
  ---@field smoke_name? string
  ---@field offset_deviation? BoundingBox
  ---@field offsets? Vector[]
  ---@field speed? Vector
  local CreateTrivialSmokeTriggerEffectItem = {
    max_radius = 0.0,
    initial_height = 0.0,
    speed_multiplier = 0.0,
    speed_multiplier_deviation = 0.0,
    starting_frame = 0.0,
    starting_frame_deviation = 0.0,
    starting_frame_speed = 0.0,
    speed_from_center = 0.0,
    speed_from_center_deviation = 0.0
  }

  ---@class CreateParticleTriggerEffectItem: TriggerEffectItem
  ---@field particle_name string
  ---@field initial_height float
  ---@field offset_deviation? BoundingBox
  ---@field tile_collision_mask? CollisionMaskLayer[]
  ---@field offsets? Vector[]
  local CreateParticleTriggerEffectItem = {
    show_in_tooltip = false,
    initial_height_deviation = 0.0,
    initial_vertical_speed = 0.0,
    initial_verticle_speed_deviation = 0.0,
    speed_from_center = 0.0,
    speed_from_center_deviation = 0.0,
    tai_length = 0.0,
    tail_length_deviation = 0.0,
    tail_width = 1.0,
    rotate_offsets = false
  }

  ---@class CreateStickerTriggerEffectItem: TriggerEffectItem
  ---@field sticker string
  local CreateStickerTriggerEffectItem = {
    show_in_tooltip = false,
    trigger_created_entity = false
  }

  ---@class CreateDecorativesTriggerEffectItem: TriggerEffectItem
  ---@field decorative string
  ---@field spawn_max uint16
  ---@field spawn_min_radius float
  ---@field spawn_max_radius float # Must be < 24
  local CreateDecorativesTriggerEffectItem = {
    spawn_min = 0.0,
    radius_curve = 0.5,
    apply_projection = false,
    spread_evenly = false
  }

  ---@class NestedTriggerEffectItem: TriggerEffectItem
  ---@field action TriggerItem
  local NestedTriggerEffectItem = {}

  ---@class PlaySoundTriggerEffectItem: TriggerEffectItem
  ---@field sound Sound|Sound.Variations[]
  local PlaySoundTriggerEffectItem = {
    min_distance = 0.0,
    max_distance = 1e21,
    volume_modifier = 1.0,
    audibile_distance_modifier = 1.0,
    play_on_taret_position = false
  }

  ---@class PushBackTriggerEffectItem: TriggerEffectItem
  ---@field distance float
  local PushBackTriggerEffectItem = {}

  ---@class DestroyCliffsTriggerEffectItem: TriggerEffectItem
  ---@field radius float
  ---@field explosion? ExplosionPrototypeString
  local DestroyCliffsTriggerEffectItem = {}

  ---@class ShowExplosionOnChartTriggerEffectItem: TriggerEffectItem
  ---@field scale float
  local ShowExplosionOnChartTriggerEffectItem = {}

  ---@class InsertItemTriggerEffectItem: TriggerEffectItem
  ---@field item string
  local InsertItemTriggerEffectItem = {
    count = 1 ---@type uint
  }

  ---@class ScriptTriggerEffectItem: TriggerEffectItem
  ---@field effect_id string #The effect_id that will be provided in on_script_trigger_effect
  local ScriptTriggerEffectItem = {}

  ---@class SetTileTriggerEffectItem: TriggerEffectItem
  ---@field tile_name string
  ---@field radius float
  ---@field tile_collision_mask? CollisionMaskLayer[]
  local SetTileTriggerEffectItem = {
    apply_projection = false,
  }

  ---@class InvokeTileEffectTriggerEffectItem: TriggerEffectItem
  ---@field tile_collision_mask? CollisionMaskLayer[]
  local InvokeTileEffectTriggerEffectItem = {}

  ---@class DestroyDecorativesTriggerEffectItem: TriggerEffectItem
  ---@field radius float
  ---@field from_render_layer? RenderLayer
  ---@field to_render_layer? RenderLayer
  local DestroyDecorativesTriggerEffectItem = {
    include_soft_decoratives = false,
    include_decals = false,
    invoke_decorative_trigger = true,
    decoratives_with_trigger_only = false,
  }

  ---@class CamerEffectTriggerEffectItem: TriggerEffectItem
  ---@field efffect string
  ---@field duration uint8
  local CamerEffectTriggerEffectItem = {
    ease_in_duration = 0,
    ease_out_duration = 0,
    delay = 0,
    full_strength_max_distance = 0
  }

end

do
  ---@class AttackParameters
  ---@field range float
  ---@field cooldown float
  ---@field type "projectile" | "beam" | "stream"
  local AttackParameters = {}

  ---@class ProjectileAttackParameters: AttackParameters
  ---@field projectile_center? Vector
  ---@field shell_particle? CircularParticleCreationSpecification[]
  ---@field projectile_creation_parameters? CircularProjectileCreationSpecification[]
  local ProjectileAttackParameters = {
    projectile_creation_distance = 0.0,
    projectile_orientation_offset = 0.0,
  }

  ---@class BeamAttackParameters: AttackParameters
  ---@field source_offset? Vector
  local BeamAttackParameters = {
    source_direction_count = 0, ---@type uint
  }

  ---@class StreamAttackParameters: AttackParameters
  ---@field projectile_creation_parameters? CircularProjectileCreationSpecification[]
  ---@field gun_center_shift? Vector|Vector[]|table<defines.direction, Vector>
  ---@field fluids? table<string, double> @FluidPrototype string, damage_modifier
  local StreamAttackParameters = {
    gun_barrel_length = 0.0,
    fluid_consumption = 0.0
  }
end
