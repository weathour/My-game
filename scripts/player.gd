extends CharacterBody2D

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const PLAYER_SAVE_CODEC := preload("res://scripts/player/player_save_codec.gd")
const PLAYER_STATE_FACTORY := preload("res://scripts/player/player_state_factory.gd")
const PLAYER_LIFECYCLE_FLOW := preload("res://scripts/player/player_lifecycle_flow.gd")
const PLAYER_STORY_STYLES := preload("res://scripts/player/player_story_styles.gd")
const PLAYER_ROLE_PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")
const PLAYER_MATH := preload("res://scripts/player/player_math.gd")
const PLAYER_ROLE_STAT_FLOW := preload("res://scripts/player/player_role_stat_flow.gd")
const PLAYER_LEVEL_OPTIONS := preload("res://scripts/player/player_level_options.gd")
const PLAYER_LEVEL_FLOW := preload("res://scripts/player/player_level_flow.gd")
const PLAYER_BLESSING_SYSTEM := preload("res://scripts/player/player_blessing_system.gd")
const PLAYER_BLESSING_SKILL_BRIDGE := preload("res://scripts/player/player_blessing_skill_bridge.gd")
const PLAYER_UPGRADE_APPLIER := preload("res://scripts/player/player_upgrade_applier.gd")
const PLAYER_REWARD_APPLIER := preload("res://scripts/player/player_reward_applier.gd")
const PLAYER_SKILL_COOLDOWN_FLOW := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const PLAYER_STAT_PAYLOAD := preload("res://scripts/player/player_stat_payload.gd")
const PLAYER_RUN_SAVE_STATE := preload("res://scripts/player/player_run_save_state.gd")
const PLAYER_AUTHORED_EFFECTS := preload("res://scripts/player/player_authored_effects.gd")
const PLAYER_PROJECTILE_SPAWNER := preload("res://scripts/player/player_projectile_spawner.gd")
const PLAYER_DAMAGE_HELPERS := preload("res://scripts/player/player_damage_helpers.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")
const PLAYER_COMBAT_MODIFIERS := preload("res://scripts/player/player_combat_modifiers.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_HEALTH_VISUALS := preload("res://scripts/player/player_health_visuals.gd")
const PLAYER_TIMER_FLOW := preload("res://scripts/player/player_timer_flow.gd")
const PLAYER_ULTIMATE_FLOW := preload("res://scripts/player/player_ultimate_flow.gd")
const PLAYER_SWITCH_FLOW := preload("res://scripts/player/player_switch_flow.gd")
const PLAYER_SURVIVAL_FLOW := preload("res://scripts/player/player_survival_flow.gd")
const PLAYER_RESOURCE_FLOW := preload("res://scripts/player/player_resource_flow.gd")
const PLAYER_MAGE_BOMBARDMENT_FLOW := preload("res://scripts/player/player_mage_bombardment_flow.gd")
const PLAYER_ATTACK_LOOP_FLOW := preload("res://scripts/player/player_attack_loop_flow.gd")
const PLAYER_ABILITY_FLOW := preload("res://scripts/player/player_ability_flow.gd")
const PLAYER_CAMERA_FEEDBACK := preload("res://scripts/player/player_camera_feedback.gd")
const PLAYER_MAP_BOUNDS_FLOW := preload("res://scripts/player/player_map_bounds_flow.gd")
const PLAYER_FIELD_EFFECT_FLOW := preload("res://scripts/player/player_field_effect_flow.gd")
const PLAYER_ATTRIBUTE_FLOW := preload("res://scripts/player/player_attribute_flow.gd")
const PLAYER_VISUAL_LAYOUT := preload("res://scripts/player/player_visual_layout.gd")
const PLAYER_TEXTURE_LOADER := preload("res://scripts/player/player_texture_loader.gd")
const PLAYER_VISUAL_STATE := preload("res://scripts/player/player_visual_state.gd")
const PLAYER_EFFECT_PRIMITIVES := preload("res://scripts/player/player_effect_primitives.gd")
const ROLE_DATABASE := preload("res://scripts/player/roles/role_database.gd")
const ROLE_ATTRIBUTE_RULES := preload("res://scripts/player/roles/role_attribute_rules.gd")
const ROLE_RESOURCE_STATE := preload("res://scripts/player/roles/role_resource_state.gd")
const SWORDSMAN_ROLE := preload("res://scripts/player/roles/swordsman_role.gd")
const GUNNER_ROLE := preload("res://scripts/player/roles/gunner_role.gd")
const MAGE_ROLE := preload("res://scripts/player/roles/mage_role.gd")
const SWORDSMAN_BLADE_STORM_ABILITY := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const MAGE_TIDAL_SURGE_ABILITY := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")
const GUNNER_INFINITE_RELOAD_ABILITY := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
const MAGE_META_FIELD_ABILITY := preload("res://scripts/abilities/mage_meta_field_ability.gd")
const SWORDSMAN_CRESCENT_WAVE_ABILITY := preload("res://scripts/abilities/swordsman_crescent_wave_ability.gd")
const GUNNER_SHRAPNEL_FIELD_ABILITY := preload("res://scripts/abilities/gunner_shrapnel_field_ability.gd")
const WHITE_KEY_SHADER := preload("res://shaders/white_key.gdshader")
const SWORD_SLASH_EFFECT_SCENE := preload("res://effects/sword/slash3/slasheffect3.tscn")
const SWORD_OMNISLASH_EFFECT_SCENE := preload("res://effects/sword/omnislash/omnislash.tscn")
const SWORD_FAN_EFFECT_SCENE := preload("res://effects/sword/fan/fan.tscn")
const SWORD_TORNADO_EFFECT_SCENE := preload("res://effects/sword/tornado/tornado.tscn")
const GUNNER_INTERSECT_GATHER_EFFECT_SCENE := preload("res://effects/gun/intersect2/gathering-beam.tscn")
const GUNNER_INTERSECT_BEAM_EFFECT_SCENE := preload("res://effects/gun/intersect2/beam.tscn")
const MAGE_BOOM_EFFECT_SCENE := preload("res://effects/wizard/boom/boom.tscn")
const MAGE_WARNING_EFFECT_SCENE := preload("res://effects/wizard/warning/warning.tscn")
const MAGE_GATHERING_EFFECT_SCENE := preload("res://effects/wizard/wave/gathering/gatering.tscn")
const MAGE_WAVE_EFFECT_SCENE := preload("res://effects/wizard/wave/wave.tscn")

const SWORD_FAN_SCENE_SIZE := Vector2(1024.0, 1024.0)
const SWORD_FAN_SCENE_VISIBLE_BOUNDS := Rect2(485.0, 405.0, 117.0, 50.0)
const GUNNER_INTERSECT_SCENE_SIZE := Vector2(1024.0, 1024.0)
const GUNNER_INTERSECT_GATHER_VISIBLE_BOUNDS := Rect2(465.0, 481.0, 416.0, 57.0)
const GUNNER_INTERSECT_BEAM_VISIBLE_BOUNDS := Rect2(465.0, 487.0, 552.0, 49.0)
const GUNNER_INTERSECT_EFFECT_SPEED_SCALE := 2.4375
const GUNNER_INTERSECT_VISUAL_SCALE := 1.5
const MAGE_GATHERING_SCENE_SIZE := Vector2(1024.0, 1024.0)
const MAGE_GATHERING_SCENE_VISIBLE_BOUNDS := Rect2(298.0, 399.0, 102.0, 165.0)

signal experience_changed(current_experience: int, required_experience: int, level: int)
signal level_up_requested(options: Array)
signal stats_changed(summary: Dictionary)
signal health_changed(current_health: float, max_health: float)
signal mana_changed(current_mana: float, max_mana: float)
signal died
signal active_role_changed(role_id: String, role_name: String)
signal blessing_skill_event_announced(event: Dictionary)

const ROLE_SWITCH_COOLDOWN := 7.0
const SWITCH_INVULNERABILITY := 0.2
const ENERGY_PASSIVE_REGEN := 0.0
const ENERGY_PER_HIT := 0.3
const ENERGY_PER_KILL := 1.1
const ULTIMATE_ENERGY_GAIN_GLOBAL_MULTIPLIER := 0.66
const SMALL_ENEMY_KILL_ENERGY_MULTIPLIER := 0.75
const BACKGROUND_ULTIMATE_ENERGY_GAIN_RATIO := 0.3
const ULTIMATE_COST := 90.0
const ULTIMATE_ENERGY_REQUIRED := 100.0
const ULTIMATE_ENERGY_LOCK_AFTER_CAST := 3.2
const SWORD_ULTIMATE_SLASH_INTERVAL := 0.12
const GUNNER_ULTIMATE_WAVE_INTERVAL := 0.14
const MAGE_ULTIMATE_BOMBARD_INTERVAL := 0.24
const GUNNER_ENTRY_WAVE_BULLET_COUNT := 16
const GUNNER_ENTRY_WAVE_BATCH_SIZE := 16
const GUNNER_ENTRY_WAVE_BATCH_INTERVAL := 0.008
const SHOW_GAMEPLAY_TEXT_HINTS := false

const FIRE_RATE_STEP := 0.05
const DAMAGE_STEP := 2.5
const MOVE_SPEED_STEP := 12.0
const PICKUP_RANGE_STEP := 8.0
const ENERGY_GAIN_STEP := 0.08
const HEALTH_STEP := 16.0
const DAMAGE_REDUCTION_STEP := 0.05
const SWITCH_COOLDOWN_STEP := 0.4
const LEVEL_STAT_HEALTH_STEP := 14.0
const LEVEL_STAT_SPEED_STEP := 8.0
const LEVEL_STAT_DAMAGE_STEP := 2.5
const EXIT_SWORD_LIFESTEAL_DURATION := 4.5
const EXIT_SWORD_LIFESTEAL_RATIO := 0.14
const EXIT_GUNNER_HASTE_DURATION := 4.0
const EXIT_GUNNER_ATTACK_INTERVAL_BONUS := 0.08
const EXIT_GUNNER_MOVE_SPEED_MULTIPLIER := 1.18
const ROLE_SHARE_DAMAGE_RATIO := 0.42
const ROLE_SHARE_INTERVAL_RATIO := 0.34
const ROLE_SHARE_RANGE_RATIO := 0.45
const ROLE_SHARE_SKILL_RATIO := 0.4
const SLOT_EVOLUTION_THRESHOLD := 2
const GEM_COLLECTION_INTERVAL := 0.08
const GEM_ATTRACT_RADIUS := 128.8
const GEM_ABSORB_RADIUS := 11.5
const CONTACT_CHECK_INTERVAL := 0.05
const PLAYER_HURT_CORE_RADIUS := 6.16
const PLAYER_HURT_CORE_OUTLINE_WIDTH := 3.0
const PLAYER_HURT_CORE_OFFSET := Vector2.ZERO
const PLAYER_HEALTH_BAR_HEIGHT := 5.0
const PLAYER_HEALTH_BAR_Y_OFFSET := 44.0
const ROLE_SKETCH_TARGET_HEIGHT := 72.0
const ROLE_SKETCH_PATHS := {
	"swordsman": "人设草图/剑士草图.jpg",
	"gunner": "人设草图/枪手草图.jpg",
	"mage": "人设草图/术师草图.jpg"
}
const ROLE_SKETCH_FULL_SIZES := {
	"swordsman": Vector2(589.0, 527.0),
	"gunner": Vector2(589.0, 582.0),
	"mage": Vector2(589.0, 527.0)
}
const ROLE_SKETCH_SCALE_MULTIPLIERS := {
	"swordsman": 1.0,
	"gunner": 1.12,
	"mage": 1.06
}
const ROLE_SKETCH_BASE_POSITIONS := {
	"swordsman": Vector2(14.0, -4.0),
	"gunner": Vector2(2.0, -3.0),
	"mage": Vector2(10.0, -5.0)
}
const ROLE_SKETCH_VISIBLE_BOUNDS := {
	"swordsman": Rect2(161.0, 49.0, 368.0, 430.0),
	"gunner": Rect2(94.0, 16.0, 415.0, 539.0),
	"mage": Rect2(142.0, 31.0, 377.0, 424.0)
}
const SWORD_SLASH_TEXTURE_RELATIVE_PATH := "技能特效/斩击.jpg"
const SWORD_SLASH_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const SWORD_SLASH_VISIBLE_BOUNDS := Rect2(246.0, 537.0, 600.0, 615.0)
const SWORD_SLASH_SCENE_SIZE := Vector2(256.0, 256.0)
const SWORD_SLASH_SCENE_VISIBLE_BOUNDS := Rect2(99.0, 30.0, 27.0, 153.0)
const SWORD_SLASH_DAMAGE_FOLLOW_PULSES := 2
const SWORD_OMNISLASH_SCENE_SIZE := Vector2(1024.0, 1024.0)
const SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS := Rect2(30.0, 344.0, 951.0, 189.0)
const MAGE_WARNING_SCENE_SIZE := Vector2(256.0, 256.0)
const MAGE_WARNING_SCENE_VISIBLE_BOUNDS := Rect2(98.0, 98.0, 59.0, 30.0)
const MAGE_BOOM_SCENE_SIZE := Vector2(256.0, 256.0)
const MAGE_BOOM_SCENE_VISIBLE_BOUNDS := Rect2(101.0, 33.0, 56.0, 92.0)
const MAGE_BOOM_IMPACT_FOCUS_BOUNDS := Rect2(104.0, 99.0, 44.0, 26.0)
const GUNNER_BULLET_TEXTURE_RELATIVE_PATH := "技能特效/子弹.jpg"
const MAGE_BOMBARD_TEXTURE_RELATIVE_PATH := "技能特效/轰炸.jpg"
const MAGE_BOMBARD_TEXTURE_SIZE := Vector2(1200.0, 1600.0)
const MAGE_BOMBARD_VISIBLE_BOUNDS := Rect2(287.0, 434.0, 634.0, 561.0)

const MAGE_ATTACK_EFFECT_SCALE := 0.8
const MAGE_ENTRY_EFFECT_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const MAGE_ENTRY_HIT_RADIUS := 104.0 * MAGE_ATTACK_EFFECT_SCALE
@export var bullet_scene: PackedScene = preload("res://effects/gun/bullet/bullet.tscn")
@export var max_health: float = 110.0
@export var max_mana: float = 100.0
@export var base_speed: float = 192.0
@export var base_pickup_radius: float = 34.0
@export var hurt_cooldown: float = 0.55
@export var experience_to_next_level: int = 30

var fire_timer: Timer
var level: int = 1
var experience: int = 0
var pending_level_ups: int = 0
var level_up_active: bool = false
var current_health: float = 0.0
var current_mana: float = 0.0
var ultimate_energy_lock_remaining: float = 0.0
var hurt_cooldown_remaining: float = 0.0
var switch_invulnerability_remaining: float = 0.0
var level_up_delay_remaining: float = 0.0
var switch_cooldown_remaining: float = 0.0
var enemy_move_slow_multiplier: float = 1.0
var enemy_move_slow_remaining: float = 0.0
var is_dead: bool = false

var speed: float = 0.0
var pickup_radius: float = 0.0
var energy_gain_multiplier: float = 1.0
var global_damage_multiplier: float = 1.0
var background_interval_multiplier: float = 1.0
var ultimate_cost_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var role_switch_cooldown_bonus: float = 0.0

var active_role_index: int = 0
var facing_direction: Vector2 = Vector2.RIGHT
var visual_facing_direction_x: float = 1.0
var auto_attack_enabled: bool = false
var roles: Array = []
var role_upgrade_levels: Dictionary = {}
var background_cooldowns: Dictionary = {}
var role_blessing_levels: Dictionary = {}
var skill_blessing_levels: Dictionary = {}
var blessing_skill_state: Dictionary = {}
var pending_blessing_binding_choices: Array = []
var current_blessing_offer: Dictionary = {}
var elite_relics_unlocked: Dictionary = {}
var equipment_levels: Dictionary = {}
var role_equipment_levels: Dictionary = {}
var equipment_damage_multiplier_bonus: float = 0.0
var equipment_speed_bonus: float = 0.0
var equipment_max_health_bonus: float = 0.0
var equipment_energy_gain_bonus: float = 0.0
var equipment_dodge_chance: float = 0.0
var equipment_health_regen_per_second: float = 0.0
var equipment_low_health_threshold: float = 0.0
var equipment_low_health_damage_taken_multiplier: float = 1.0
var equipment_skill_range_multiplier: float = 1.0
var equipment_cooldown_multiplier: float = 1.0
var attribute_training_levels: Dictionary = {}
var role_special_states: Dictionary = {}
var swordsman_blade_storm_ability = SWORDSMAN_BLADE_STORM_ABILITY.new()
var swordsman_crescent_wave_ability = SWORDSMAN_CRESCENT_WAVE_ABILITY.new()
var camera_node: Camera2D
var camera_base_offset: Vector2 = Vector2.ZERO
var camera_shake_strength: float = 0.0
var camera_shake_time: float = 0.0
var external_camera_shake_strength: float = 0.0
var external_camera_shake_time: float = 0.0
var switch_power_remaining: float = 0.0
var switch_power_role_id: String = ""
var switch_power_damage_multiplier: float = 1.0
var switch_power_interval_bonus: float = 0.0
var switch_power_label: String = ""
var pending_entry_blessing_source_role_id: String = ""
var entry_blessing_role_id: String = ""
var entry_blessing_label: String = ""
var entry_blessing_remaining: float = 0.0
var entry_lifesteal_ratio: float = 0.0
var entry_rescue_remaining: float = 0.0
var entry_rescue_regen_per_second: float = 0.0
var lifesteal_proc_cooldown_remaining: float = 0.0
var entry_haste_interval_bonus: float = 0.0
var entry_haste_move_speed_multiplier: float = 1.0
var standby_entry_role_id: String = ""
var standby_entry_label: String = ""
var standby_entry_remaining: float = 0.0
var standby_entry_damage_multiplier: float = 1.0
var standby_entry_interval_bonus: float = 0.0
var guard_cover_remaining: float = 0.0
var guard_cover_damage_multiplier: float = 1.0
var borrow_fire_role_id: String = ""
var borrow_fire_remaining: float = 0.0
var borrow_fire_damage_multiplier: float = 1.0
var borrow_fire_interval_bonus: float = 0.0
var borrow_fire_background_multiplier: float = 1.0
var post_ultimate_flow_remaining: float = 0.0
var post_ultimate_flow_background_multiplier: float = 1.0
var ultimate_guard_remaining: float = 0.0
var ultimate_guard_damage_multiplier: float = 1.0
var perpetual_motion_cooldown_remaining: float = 0.0
var frenzy_remaining: float = 0.0
var frenzy_stacks: int = 0
var frenzy_overkill_counter: int = 0
var role_standby_elapsed: Dictionary = {}
var role_health_values: Dictionary = {}
var role_mana_values: Dictionary = {}
var role_ultimate_energy_lock_remaining: Dictionary = {}
var role_share_initialized: bool = false
var role_visual_time: float = 0.0
var active_role_visual_hidden: bool = false
var active_role_visual_hidden_role_id: String = ""
var hurt_core_visual_visible: bool = true
var runtime_texture_cache: Dictionary = {}
var white_key_material_cache: Dictionary = {}
var swordsman_role = SWORDSMAN_ROLE.new()
var swordsman_attack_chain: int = 0
var gunner_role = GUNNER_ROLE.new()
var gunner_attack_chain: int = 0
var gunner_infinite_reload_ability = GUNNER_INFINITE_RELOAD_ABILITY.new()
var gunner_shrapnel_field_ability = GUNNER_SHRAPNEL_FIELD_ABILITY.new()
var mage_role = MAGE_ROLE.new()
var mage_attack_chain: int = 0
var mage_tidal_surge_ability = MAGE_TIDAL_SURGE_ABILITY.new()
var mage_meta_field_ability = MAGE_META_FIELD_ABILITY.new()
var gunner_lock_target: Node2D
var gunner_lock_stacks: int = 0
var gem_collection_elapsed: float = 0.0
var contact_check_elapsed: float = 0.0
var execution_pact_burst_active: bool = false
var final_set_unlock_announced: Dictionary = {}
var story_equipped_styles: Dictionary = {
	"swordsman": "default",
	"gunner": "default",
	"mage": "default"
}

func _ready() -> void:
	PLAYER_LIFECYCLE_FLOW.ready(self)

func _get_desktop_sketch_path(relative_path: String) -> String:
	return PLAYER_TEXTURE_LOADER.get_desktop_sketch_path(relative_path)

func _get_project_sketch_path(relative_path: String) -> String:
	return PLAYER_TEXTURE_LOADER.get_project_sketch_path(relative_path)

func _get_cached_runtime_texture(relative_path: String) -> Texture2D:
	return PLAYER_TEXTURE_LOADER.get_cached_runtime_texture(relative_path, runtime_texture_cache)

func _create_white_key_material(value_threshold: float = 0.94, saturation_threshold: float = 0.08, edge_softness: float = 0.03) -> ShaderMaterial:
	return PLAYER_TEXTURE_LOADER.get_cached_white_key_material(
		WHITE_KEY_SHADER,
		white_key_material_cache,
		value_threshold,
		saturation_threshold,
		edge_softness
	)

func _get_role_sprite_offset(role_id: String) -> Vector2:
	return PLAYER_VISUAL_LAYOUT.get_role_sprite_offset(role_id, ROLE_SKETCH_FULL_SIZES, ROLE_SKETCH_VISIBLE_BOUNDS)

func _configure_role_sprite(sprite: Sprite2D, role_id: String) -> bool:
	return PLAYER_VISUAL_STATE.configure_role_sprite(self, sprite, role_id)

func _spawn_sketch_sprite_effect(
		center: Vector2,
		rotation_angle: float,
		texture_path: String,
		full_size: Vector2,
		visible_bounds: Rect2,
		target_visible_size: Vector2,
		duration: float,
		modulate_color: Color = Color.WHITE,
		z_index: int = 13,
		align_visible_center: bool = true,
		preserve_aspect: bool = false,
		value_threshold: float = 0.94,
		saturation_threshold: float = 0.08,
		edge_softness: float = 0.03
	) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sketch_sprite_effect(
		self,
		center,
		rotation_angle,
		texture_path,
		full_size,
		visible_bounds,
		target_visible_size,
		duration,
		modulate_color,
		z_index,
		align_visible_center,
		preserve_aspect,
		value_threshold,
		saturation_threshold,
		edge_softness
	)

func _spawn_sword_slash_scene_effect(center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, thickness: float, mirror_horizontal: bool = false) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sword_slash_scene_effect(self, center, direction, radius, duration, thickness, mirror_horizontal)

func _spawn_sword_omnislash_scene_effect(center: Vector2, direction: Vector2, length: float, thickness: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sword_omnislash_scene_effect(self, center, direction, length, thickness)

func _set_active_role_visual_hidden(hidden: bool) -> void:
	PLAYER_VISUAL_STATE.set_active_role_visual_hidden(self, hidden)

func _spawn_authored_scene_effect(scene: PackedScene, scene_size: Vector2, visible_bounds: Rect2, center: Vector2, rotation_radians: float, scale_multiplier: float, z_index: int = 12) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_authored_scene_effect(self, scene, scene_size, visible_bounds, center, rotation_radians, scale_multiplier, z_index)

func _spawn_sword_fan_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_sword_fan_scene_effect(self, center, direction, scale_multiplier)

func _spawn_gunner_intersect_scene_effect(center: Vector2, direction: Vector2, visual_length: float = 112.0, visual_thickness: float = 18.0, gather_visual_length: float = -1.0) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_owner_gunner_intersect_effect(self, center, direction, visual_length, visual_thickness, gather_visual_length)

func _get_infinite_reload_range_multiplier() -> float:
	return PLAYER_MATH.get_infinite_reload_range_multiplier()

func _get_gunner_intersect_combo_duration() -> float:
	return PLAYER_AUTHORED_EFFECTS.get_owner_gunner_intersect_combo_duration(self)

func _spawn_mage_gathering_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_mage_gathering_scene_effect(self, center, direction, scale_multiplier)

func _spawn_mage_boom_scene_effect(center: Vector2, radius: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_mage_boom_scene_effect(self, center, radius)

func _spawn_mage_warning_scene_effect(center: Vector2, radius: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_mage_warning_scene_effect(self, center, radius)

func _get_downward_perpendicular(direction: Vector2) -> Vector2:
	return PLAYER_MATH.get_downward_perpendicular(direction)

func _get_sword_slash_scene_animation_duration() -> float:
	return PLAYER_AUTHORED_EFFECTS.get_scene_animation_duration(SWORD_SLASH_EFFECT_SCENE, 0.18)

func _get_scene_animation_duration(scene: PackedScene, default_duration: float = 0.18) -> float:
	return PLAYER_AUTHORED_EFFECTS.get_scene_animation_duration(scene, default_duration)

func _build_role_data() -> Array:
	return ROLE_DATABASE.get_role_data()

func _serialize_roles_for_save() -> Array:
	return PLAYER_SAVE_CODEC.serialize_roles_for_save(roles)

func _normalize_loaded_roles(saved_roles: Variant) -> Array:
	return PLAYER_SAVE_CODEC.normalize_loaded_roles(saved_roles, _build_role_data())

func _build_role_upgrade_data() -> Dictionary:
	return ROLE_DATABASE.get_role_upgrade_data()

func _build_background_cooldowns() -> Dictionary:
	return PLAYER_ROLE_STAT_FLOW.build_background_cooldowns(self)

func configure_story_loadout(team_order: Array, equipped_styles: Dictionary) -> void:
	PLAYER_STORY_STYLES.configure_story_loadout(self, team_order, equipped_styles)

func _get_story_style_id(role_id: String) -> String:
	return PLAYER_STORY_STYLES.get_story_style_id(story_equipped_styles, role_id)

func _get_story_style_damage_multiplier(role_id: String) -> float:
	return PLAYER_STORY_STYLES.get_damage_multiplier(_get_story_style_id(role_id))

func _get_story_style_range_multiplier(role_id: String) -> float:
	return PLAYER_STORY_STYLES.get_owner_range_multiplier(self, role_id) * _get_role_equipment_skill_range_multiplier(role_id)

func _get_story_style_interval_bonus(role_id: String) -> float:
	return PLAYER_STORY_STYLES.get_interval_bonus(_get_story_style_id(role_id))

func _get_story_style_extra_pierce(role_id: String) -> int:
	return PLAYER_STORY_STYLES.get_extra_pierce(_get_story_style_id(role_id))

func _get_story_style_bullet_speed_multiplier(role_id: String) -> float:
	return PLAYER_STORY_STYLES.get_bullet_speed_multiplier(_get_story_style_id(role_id))

func _get_story_style_slow_bonus(role_id: String) -> float:
	return PLAYER_STORY_STYLES.get_slow_bonus(_get_story_style_id(role_id))

func _get_upgrade_slot_label(slot_id: String) -> String:
	match slot_id:
		"body":
			return "祝福"
		"combat":
			return "战斗"
		"skill":
			return "技能"
		"special":
			return "奖励"
	return slot_id

func _build_role_special_state_data() -> Dictionary:
	return ROLE_DATABASE.get_role_special_state_data()

func _build_attribute_training_data() -> Dictionary:
	return PLAYER_STATE_FACTORY.build_attribute_training_data()

func _get_role_attribute_key(role_id: String, attribute_key: String) -> String:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_key(role_id, attribute_key)

func _get_role_attribute_level(role_id: String, attribute_key: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_level(self, role_id, attribute_key)

func _increase_role_attribute_level(role_id: String, attribute_key: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.increase_role_attribute_level(self, role_id, attribute_key)

func _normalize_attribute_training_data(data: Variant) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.normalize_attribute_training_data(data)

func _sync_swordsman_trait_health_bonus() -> void:
	PLAYER_ATTRIBUTE_FLOW.sync_swordsman_trait_health_bonus(self)

func _get_attribute_level(attribute_key: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_level(self, attribute_key)

func _add_attribute_levels(deltas: Dictionary) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.add_attribute_levels(self, deltas)

func _format_attribute_level(level: float) -> String:
	return PLAYER_ATTRIBUTE_FLOW.format_attribute_level(level)

func _get_attribute_health_regen_per_second() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_health_regen_per_second(self)

func _get_attribute_mana_regen_per_second() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_mana_regen_per_second(self)

func _get_attribute_dodge_chance() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_dodge_chance(self)

func _get_attribute_pickup_range_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_attribute_pickup_range_bonus(self)

func _get_swordsman_low_health_flat_heal() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_low_health_flat_heal(self)

func _get_swordsman_low_health_threshold() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_low_health_threshold(self)

func _get_gunner_distance_damage_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_distance_damage_bonus(self)

func _get_mage_skill_range_multiplier() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_skill_range_multiplier(self)

func _get_mage_kill_energy_multiplier() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_kill_energy_multiplier(self)

func _get_primary_attribute_damage_bonus(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_primary_attribute_damage_bonus(self, role_id)

func _get_role_trait_level(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_trait_level(self, role_id)

func _get_role_entry_damage_multiplier(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_entry_damage_multiplier(self, role_id)

func _get_swordsman_entry_distance_multiplier() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_entry_distance_multiplier(self)

func _get_swordsman_entry_invulnerability_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_entry_invulnerability_bonus(self)

func _get_swordsman_exit_lifesteal_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_exit_lifesteal_bonus(self)

func _get_swordsman_exit_lifesteal_duration_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_exit_lifesteal_duration_bonus(self)

func _get_gunner_entry_bullet_speed_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_entry_bullet_speed_bonus(self)

func _get_gunner_entry_wave_count() -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_entry_wave_count(self)

func _get_gunner_exit_haste_interval_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_exit_haste_interval_bonus(self)

func _get_gunner_exit_move_speed_multiplier_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_exit_move_speed_multiplier_bonus(self)

func _get_gunner_exit_haste_duration_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_exit_haste_duration_bonus(self)

func _get_mage_entry_radius_multiplier() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_entry_radius_multiplier(self)

func _get_mage_entry_bombard_count() -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_entry_bombard_count(self)

func _get_mage_exit_energy_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_exit_energy_bonus(self)

func _get_mage_exit_slow_field_radius_bonus() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_exit_slow_field_radius_bonus(self)

func _get_mage_exit_slow_field_damage_ratio() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_exit_slow_field_damage_ratio(self)

func _get_balanced_attribute_description(added_amount: float) -> String:
	return PLAYER_ATTRIBUTE_FLOW.get_balanced_attribute_description(self, added_amount)

func _add_common_prosperity() -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.add_common_prosperity(self)

func _get_common_prosperity_switch_cooldown_multiplier() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_common_prosperity_switch_cooldown_multiplier(self)

func _get_swordsman_heart_interval_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_heart_interval_multiplier(level)

func _get_swordsman_heart_range_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_heart_range_multiplier(level)

func _get_swordsman_normal_attack_scale(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_normal_attack_scale(level)

func _get_swordsman_normal_attack_width_scale(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_normal_attack_width_scale(level)

func _get_swordsman_bloodthirst_ratio(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_bloodthirst_ratio(level)

func _get_swordsman_bloodthirst_heal_cap(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_bloodthirst_heal_cap(level)

func _get_swordsman_dodge_chance(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_swordsman_dodge_chance(level)

func _get_gunner_barrage_speed_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_speed_multiplier(level)

func _get_gunner_barrage_interval_reduction(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_interval_reduction(level)

func _get_gunner_barrage_bounce_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_bounce_count(level)

func _get_gunner_barrage_shotgun_wave_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_shotgun_wave_count(level)

func _get_gunner_barrage_shotgun_pellet_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_shotgun_pellet_count(level)

func _get_gunner_barrage_split_count(level: float) -> int:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_barrage_split_count(level)

func _get_gunner_footwork_range_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_footwork_range_multiplier(level)

func _get_gunner_footwork_move_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_footwork_move_multiplier(level)

func _get_gunner_footwork_flat_speed_bonus(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_gunner_footwork_flat_speed_bonus(level)

func _get_mage_arcane_focus_range_multiplier(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_arcane_focus_range_multiplier(level)

func _get_mage_surplus_energy_multiplier(level: float, role_id: String = "") -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_surplus_energy_multiplier(level, role_id)

func _get_mage_surplus_passive_energy_per_second(level: float) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_mage_surplus_passive_energy_per_second(level)

func _get_role_attribute_range_multiplier(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_range_multiplier(self, role_id)

func _get_role_attribute_move_speed_multiplier(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_move_speed_multiplier(self, role_id)

func _get_role_attribute_flat_move_speed_bonus(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_flat_move_speed_bonus(self, role_id)

func _get_role_attack_interval_multiplier(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attack_interval_multiplier(self, role_id)

func _get_role_attack_interval_flat_reduction(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attack_interval_flat_reduction(self, role_id)

func _get_ultimate_energy_gain_multiplier_for_role(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_ultimate_energy_gain_multiplier_for_role(self, role_id)

func _get_role_equipment_damage_multiplier_bonus(role_id: String) -> float:
	return PLAYER_EQUIPMENT_FLOW.get_role_damage_multiplier_bonus(self, role_id)

func _get_role_equipment_energy_gain_bonus(role_id: String) -> float:
	return PLAYER_EQUIPMENT_FLOW.get_role_energy_gain_bonus(self, role_id) + _get_role_blessing_stat_bonus(role_id, "energy_gain")

func _get_role_equipment_skill_range_multiplier(role_id: String) -> float:
	return float(PLAYER_EQUIPMENT_FLOW.get_role_bonus_summary(self, role_id).get("skill_range_multiplier", 1.0)) + _get_role_blessing_stat_bonus(role_id, "skill_range")

func _get_role_equipment_levels(role_id: String) -> Dictionary:
	return PLAYER_EQUIPMENT_FLOW.get_role_equipment_levels(self, role_id)

func _get_role_equipment_bonus_summary(role_id: String) -> Dictionary:
	return PLAYER_EQUIPMENT_FLOW.get_role_bonus_summary(self, role_id)

func transfer_role_equipment_item(equipment_id: String, from_role_id: String, target_role_id: String) -> bool:
	return PLAYER_EQUIPMENT_FLOW.transfer_equipment(self, equipment_id, from_role_id, target_role_id)

func _get_role_attribute_titles(role_id: String) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_titles(role_id)

func _get_role_attribute_titles_for_levels(role_id: String, levels: Dictionary) -> Dictionary:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_titles_for_levels(role_id, levels)

func _get_role_attribute_description(role_id: String, attribute_key: String, next_level: float) -> String:
	return PLAYER_ATTRIBUTE_FLOW.get_role_attribute_description(role_id, attribute_key, next_level)

func _get_attribute_evolved_title_color() -> Color:
	return PLAYER_ATTRIBUTE_FLOW.get_evolved_title_color()

func _is_attribute_evolved(level: float) -> bool:
	return PLAYER_ATTRIBUTE_FLOW.is_attribute_evolved(level)

func _get_max_attribute_level() -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_max_attribute_level()

func _build_role_timing_state_data(default_value: Variant) -> Dictionary:
	return ROLE_DATABASE.get_role_timing_state_data(default_value)

func _build_role_resource_state_data(default_value: Variant) -> Dictionary:
	return ROLE_RESOURCE_STATE.build_for_roles(roles, default_value)

func _build_role_health_state() -> Dictionary:
	return PLAYER_ROLE_STAT_FLOW.build_role_health_state(self)

func _get_active_role_id() -> String:
	return PLAYER_RESOURCE_FLOW.get_active_role_id(self)

func _get_role_mana(role_id: String) -> float:
	return PLAYER_RESOURCE_FLOW.get_role_mana(self, role_id)

func _set_role_mana(role_id: String, value: float, emit_for_active: bool = true) -> void:
	PLAYER_RESOURCE_FLOW.set_role_mana(self, role_id, value, emit_for_active)

func _add_role_mana(role_id: String, amount: float, emit_for_active: bool = true) -> float:
	return PLAYER_RESOURCE_FLOW.add_role_mana(self, role_id, amount, emit_for_active)

func _add_active_role_mana(amount: float, emit_signal: bool = true) -> float:
	return PLAYER_RESOURCE_FLOW.add_active_role_mana(self, amount, emit_signal)

func _get_role_ultimate_lock_remaining(role_id: String) -> float:
	return PLAYER_RESOURCE_FLOW.get_role_ultimate_lock_remaining(self, role_id)

func _set_role_ultimate_lock_remaining(role_id: String, value: float) -> void:
	PLAYER_RESOURCE_FLOW.set_role_ultimate_lock_remaining(self, role_id, value)

func _sync_active_role_ultimate_state() -> void:
	PLAYER_RESOURCE_FLOW.sync_active_role_ultimate_state(self)

func _emit_active_mana_changed() -> void:
	PLAYER_RESOURCE_FLOW.emit_active_mana_changed(self)

func _get_card_level(card_id: String) -> int:
	return 0

func _get_role_blessing_stat_bonus(role_id: String, stat: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_role_stat_bonus(self, role_id, stat)

func _get_skill_blessing_stat_bonus(stat: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_stat_bonus(self, stat)

func _get_skill_blessing_effect_scales(stat: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_effect_scales(self, stat)

func _get_skill_blessing_effect_scales_for_skill(skill_id: String, stat: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_effect_scales_for_skill(self, skill_id, stat)

func get_role_blessing_levels(role_id: String) -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_role_blessing_levels(self, role_id)

func get_skill_blessing_levels() -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_blessing_levels(self)

func can_compose_role_blessing(role_id: String, blessing_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.can_compose_role_blessing(self, role_id, blessing_id)

func can_compose_skill_blessing(blessing_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.can_compose_skill_blessing(self, blessing_id)

func compose_role_blessing(role_id: String, blessing_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.compose_role_blessing(self, role_id, blessing_id)

func compose_skill_blessing(blessing_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.compose_skill_blessing(self, blessing_id)

func _refresh_blessing_skill_unlocks(selected_blessing_id: String = "", selected_tier: int = 0, selected_binding: String = "") -> void:
	PLAYER_BLESSING_SKILL_BRIDGE.refresh_unlocks(self, selected_blessing_id, selected_tier, selected_binding)

func consume_pending_blessing_binding_choice() -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.consume_pending_binding_choice(self)

func build_blessing_binding_options(choice: Dictionary) -> Array:
	return PLAYER_BLESSING_SKILL_BRIDGE.build_binding_options(self, choice)

func apply_blessing_binding_choice(choice: Dictionary, option_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.apply_binding_choice(self, choice, option_id)

func _show_blessing_skill_event_tag(event: Dictionary) -> void:
	PLAYER_BLESSING_SKILL_BRIDGE.show_skill_event_tag(self, event)

func _is_blessing_skill_unlocked(skill_id: String) -> bool:
	return PLAYER_BLESSING_SKILL_BRIDGE.is_skill_unlocked(self, skill_id)

func _get_blessing_skill_tier(skill_id: String) -> int:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_tier(self, skill_id)

func _get_entry_rescue_regen_per_second() -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_entry_rescue_regen_per_second(self)

func _get_hero_entry_effect() -> Dictionary:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_hero_entry_effect(self)

func _get_blessing_skill_quantity_count(skill_id: String) -> int:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_quantity_count(self, skill_id)

func _get_blessing_skill_combo_scales(skill_id: String) -> Array[float]:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_combo_scales(self, skill_id)

func _get_blessing_skill_duration_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_duration_multiplier(self, skill_id)

func get_skill_next_requirement_text(skill_id: String) -> String:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_next_requirement_text(self, skill_id)

func get_skill_graph_text(role_id_filter: String = "") -> String:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_skill_graph_text(self, role_id_filter)

func _get_basic_attack_range_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_basic_attack_range_multiplier(self, skill_id)

func _get_basic_attack_projectile_speed_multiplier(skill_id: String) -> float:
	return PLAYER_BLESSING_SKILL_BRIDGE.get_basic_attack_projectile_speed_multiplier(self, skill_id)

func _has_elite_relic(relic_id: String) -> bool:
	return bool(elite_relics_unlocked.get(relic_id, false))

func _unlock_elite_relic(relic_id: String) -> void:
	elite_relics_unlocked[relic_id] = true

func _get_role_theme_color(role_id: String) -> Color:
	return PLAYER_ROLE_STAT_FLOW.get_role_theme_color(self, role_id)

func _announce_completed_final_set(set_key: String) -> void:
	return

func _apply_team_role_bonus(damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	PLAYER_ROLE_STAT_FLOW.apply_team_role_bonus(self, damage_bonus, interval_bonus, range_bonus, skill_bonus)

func _increase_role_special(role_id: String, key: String, amount: int = 1) -> void:
	PLAYER_RESOURCE_FLOW.increase_role_special(self, role_id, key, amount)

func _increase_team_specials(entries: Array) -> void:
	PLAYER_RESOURCE_FLOW.increase_team_specials(self, entries)

func _get_active_interval_bonus(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_active_interval_bonus(self, role_id)

func _get_effective_attack_interval(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_effective_attack_interval(self, role_id)

func _get_effective_background_attack_interval(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_effective_background_attack_interval(self, role_id)

func _get_effective_background_interval_multiplier() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_effective_background_interval_multiplier(self)

func _clear_standby_entry_buff() -> void:
	PLAYER_SWITCH_FLOW.clear_standby_entry_buff(self)

func _apply_rotation_entry_bonus(role_id: String) -> void:
	PLAYER_SWITCH_FLOW.apply_rotation_entry_bonus(self, role_id)

func _apply_swap_guard(direction: Vector2) -> void:
	PLAYER_SWITCH_FLOW.apply_swap_guard(self, direction)

func _activate_guard_cover() -> void:
	PLAYER_SWITCH_FLOW.activate_guard_cover(self)

func _trigger_rearguard_attack(role_id: String, origin: Vector2, level: int) -> int:
	return PLAYER_SWITCH_FLOW.trigger_rearguard_attack(self, role_id, origin, level)

func _get_priority_target_bonus(enemy: Node) -> float:
	return PLAYER_COMBAT_MODIFIERS.get_priority_target_bonus(self, enemy)

func _is_last_stand_active() -> bool:
	return PLAYER_COMBAT_MODIFIERS.is_last_stand_active(self)

func _get_effective_damage_taken_multiplier() -> float:
	return PLAYER_COMBAT_MODIFIERS.get_effective_damage_taken_multiplier(self)

func _get_equipment_low_health_damage_taken_multiplier() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_low_health_damage_taken_multiplier(self)

func _get_equipment_skill_range_multiplier() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_skill_range_multiplier(self) * _get_role_attribute_range_multiplier(str(_get_active_role().get("id", "")))

func _get_equipment_cooldown_multiplier() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_cooldown_multiplier(self)

func _apply_equipment_passives(delta: float) -> void:
	PLAYER_EQUIPMENT_FLOW.apply_passives(self, delta)

func _try_equipment_dodge() -> bool:
	return PLAYER_EQUIPMENT_FLOW.try_dodge(self)

func _unhandled_input(event: InputEvent) -> void:
	PLAYER_SURVIVAL_FLOW.unhandled_input(self, event)

func _physics_process(delta: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.update_effect_animations(delta)
	PLAYER_AUTHORED_EFFECTS.update_effect_animations(delta)
	PLAYER_VISUAL_STATE.update_visual_pulses(delta)
	PLAYER_SURVIVAL_FLOW.physics_process(self, delta)
	if not is_dead:
		PLAYER_MAP_BOUNDS_FLOW.clamp_to_active_map_bounds(self)

func _update_timers(delta: float) -> void:
	PLAYER_TIMER_FLOW.update_timers(self, delta)

func _apply_developer_no_cooldown() -> void:
	PLAYER_TIMER_FLOW.apply_developer_no_cooldown(self)

func _regenerate_energy(delta: float) -> void:
	PLAYER_SURVIVAL_FLOW.regenerate_energy(self, delta)

func _update_facing_direction() -> void:
	PLAYER_SURVIVAL_FLOW.update_facing_direction(self)

func _toggle_attack_aim_mode() -> void:
	PLAYER_SURVIVAL_FLOW.toggle_attack_aim_mode(self)

func _get_attack_aim_direction(fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	return PLAYER_SURVIVAL_FLOW.get_attack_aim_direction(self, fallback_direction)

func _update_background_effects(delta: float) -> void:
	PLAYER_ATTACK_LOOP_FLOW.update_background_effects(self, delta)

func _trigger_background_effect(role_index: int) -> void:
	PLAYER_ATTACK_LOOP_FLOW.trigger_background_effect(self, role_index)

func _perform_active_attack() -> void:
	PLAYER_ATTACK_LOOP_FLOW.perform_active_attack(self)

func _get_live_mouse_aim_direction(fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	return _get_attack_aim_direction(fallback_direction)

func _try_trigger_swordsman_blade_storm() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_blade_storm(self)

func _try_trigger_swordsman_crescent_wave() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_swordsman_crescent_wave(self)

func _try_trigger_gunner_infinite_reload() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_gunner_infinite_reload(self)

func _try_trigger_gunner_shrapnel_field() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_gunner_shrapnel_field(self)

func _start_swordsman_blade_storm() -> void:
	PLAYER_ABILITY_FLOW.start_swordsman_blade_storm(self)

func _start_swordsman_crescent_wave() -> void:
	PLAYER_ABILITY_FLOW.start_swordsman_crescent_wave(self)

func _trigger_swordsman_blade_storm_tick() -> void:
	PLAYER_ABILITY_FLOW.trigger_swordsman_blade_storm_tick(self)

func _ensure_swordsman_blade_storm_effect() -> void:
	PLAYER_ABILITY_FLOW.ensure_swordsman_blade_storm_effect(self)

func _update_swordsman_blade_storm_effect(delta: float) -> void:
	PLAYER_ABILITY_FLOW.update_swordsman_blade_storm_effect(self, delta)

func _stop_swordsman_blade_storm() -> void:
	PLAYER_ABILITY_FLOW.stop_swordsman_blade_storm(self)

func _cleanup_gunner_infinite_reload_effects() -> void:
	PLAYER_ABILITY_FLOW.cleanup_gunner_infinite_reload_effects(self)

func _register_gunner_infinite_reload_effect(effect: Node2D) -> void:
	PLAYER_ABILITY_FLOW.register_gunner_infinite_reload_effect(self, effect)

func _start_gunner_infinite_reload() -> void:
	PLAYER_ABILITY_FLOW.start_gunner_infinite_reload(self)

func _start_gunner_shrapnel_field() -> void:
	PLAYER_ABILITY_FLOW.start_gunner_shrapnel_field(self)

func _trigger_gunner_infinite_reload_tick() -> void:
	PLAYER_ABILITY_FLOW.trigger_gunner_infinite_reload_tick(self)

func _stop_gunner_infinite_reload() -> void:
	PLAYER_ABILITY_FLOW.stop_gunner_infinite_reload(self)

func is_gunner_infinite_reload_active() -> bool:
	return PLAYER_ABILITY_FLOW.is_gunner_infinite_reload_active(self)

func _get_gunner_infinite_reload_move_speed_multiplier() -> float:
	return PLAYER_ABILITY_FLOW.get_gunner_infinite_reload_move_speed_multiplier(self)

func _try_trigger_mage_tidal_surge() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mage_tidal_surge(self)

func _start_mage_tidal_surge() -> void:
	PLAYER_ABILITY_FLOW.start_mage_tidal_surge(self)

func _try_trigger_mage_meta_field() -> void:
	PLAYER_ABILITY_FLOW.try_trigger_mage_meta_field(self)

func _start_mage_meta_field() -> void:
	PLAYER_ABILITY_FLOW.start_mage_meta_field(self)

func _perform_swordsman_attack() -> void:
	if swordsman_role != null:
		swordsman_role.perform_attack(self)

func _perform_gunner_attack() -> void:
	if gunner_role != null:
		gunner_role.perform_attack(self)

func _perform_mage_attack() -> void:
	if mage_role != null:
		mage_role.perform_attack(self)

func _try_switch_role(new_role_index: int) -> void:
	PLAYER_SWITCH_FLOW.try_switch_role(self, new_role_index)

func _apply_enter_skill(role_index: int) -> int:
	return PLAYER_SWITCH_FLOW.apply_enter_skill(self, role_index)

func _apply_exit_skill(role_index: int) -> int:
	return PLAYER_SWITCH_FLOW.apply_exit_skill(self, role_index)

func _try_use_ultimate() -> void:
	PLAYER_ULTIMATE_FLOW.try_use_ultimate(self)

func _apply_post_ultimate_bonuses(role_id: String, total_duration: float) -> void:
	PLAYER_ULTIMATE_FLOW.apply_post_ultimate_bonuses(self, role_id, total_duration)

func _trigger_ultimate_reprise(role_id: String, reprise_level: int) -> void:
	PLAYER_ULTIMATE_FLOW.trigger_ultimate_reprise(self, role_id, reprise_level)

func _spawn_ultimate_afterglow_effect(role_id: String, duration: float) -> void:
	PLAYER_ULTIMATE_FLOW.spawn_ultimate_afterglow_effect(self, role_id, duration)

func _trigger_ultimate_afterglow_pulse(role_id: String, pulse_index: int) -> void:
	PLAYER_ULTIMATE_FLOW.trigger_ultimate_afterglow_pulse(self, role_id, pulse_index)

func _schedule_repeating_sequence(interval: float, repeat_count: int, callback: Callable, initial_delay: float = 0.0) -> void:
	PLAYER_ULTIMATE_FLOW.schedule_repeating_sequence(self, interval, repeat_count, callback, initial_delay)

func _fire_gunner_entry_wave(role_id: String, wave_index: int, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.fire_gunner_entry_wave(self, role_id, wave_index, damage_scale)

func _spawn_gunner_entry_wave_batch(role_id: String, wave_index: int, start_index: int, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.spawn_gunner_entry_wave_batch(self, role_id, wave_index, start_index, damage_scale)

func _start_mage_entry_bombardment(role_id: String, bombard_centers: Array, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.start_mage_entry_bombardment(self, role_id, bombard_centers, damage_scale)

func _show_mage_entry_bombardment_warning(center: Vector2) -> void:
	PLAYER_SWITCH_FLOW.show_mage_entry_bombardment_warning(self, center)

func _trigger_mage_entry_bombardment_impact(role_id: String, center: Vector2, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_FLOW.trigger_mage_entry_bombardment_impact(self, role_id, center, damage_scale)

func _start_basic_mage_bombardment(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.start_basic_mage_bombardment(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _trigger_basic_mage_bombardment_impact(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.trigger_basic_mage_bombardment_impact(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _resolve_basic_mage_bombardment_damage(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.resolve_basic_mage_bombardment_damage(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _get_enemy_nearest_to_position(position: Vector2) -> Node2D:
	if position == Vector2.ZERO:
		return _get_closest_enemy()
	return PLAYER_TARGETING.get_enemy_nearest_to_position(_get_live_enemies(), position)

func _get_enemy_near_position(position: Vector2, max_distance: float) -> Node2D:
	return PLAYER_TARGETING.get_enemy_near_position(_get_live_enemies(), position, max_distance)

func _get_mage_mouse_bombard_center(base_range: float) -> Vector2:
	return PLAYER_MAGE_BOMBARDMENT_FLOW.get_mage_mouse_bombard_center(self, base_range)

func _apply_role_projectile_modifiers(projectile: Node, role_id: String) -> void:
	PLAYER_PROJECTILE_SPAWNER.apply_role_projectile_modifiers(self, projectile, role_id)

func _spawn_bullet(target_enemy: Node2D, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return PLAYER_PROJECTILE_SPAWNER.spawn_bullet(self, bullet_scene, target_enemy, damage_amount, color, role_id, origin)

func _spawn_directional_bullet(direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return PLAYER_PROJECTILE_SPAWNER.spawn_directional_bullet(self, bullet_scene, direction, damage_amount, color, role_id, origin)

func _spawn_directional_bullet_from_scene(projectile_scene: PackedScene, direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null):
	return PLAYER_PROJECTILE_SPAWNER.spawn_directional_bullet_from_scene(self, projectile_scene, direction, damage_amount, color, role_id, origin)

func _spawn_batched_directional_bullet(direction: Vector2, damage_amount: float, color: Color, role_id: String = "", origin: Variant = null, config: Dictionary = {}) -> bool:
	return PLAYER_PROJECTILE_SPAWNER.spawn_batched_directional_bullet(self, direction, damage_amount, color, role_id, origin, config)

func _spawn_batched_directional_bullet_values(
	direction: Vector2,
	damage_amount: float,
	color: Color,
	role_id: String = "",
	origin: Variant = null,
	speed: float = 620.0,
	lifetime: float = 1.0,
	hit_radius: float = 10.0,
	visual_radius: float = 4.2,
	visual_min_diameter: float = 8.0,
	visual_outline_color: Color = Color(1.0, 1.0, 1.0, 0.0),
	visual_outline_width: float = 0.0,
	enemy_hit_radius_scale: float = 0.2,
	enemy_hit_radius_min: float = 4.0,
	enemy_hit_radius_max: float = 12.0,
	vulnerability_bonus: float = 0.0,
	vulnerability_duration: float = 0.0,
	slow_multiplier: float = 1.0,
	slow_duration: float = 0.0,
	pierce_count: int = 0,
	wave_amplitude: float = 0.0,
	wave_frequency: float = 0.0,
	wave_phase: float = 0.0
) -> bool:
	return PLAYER_PROJECTILE_SPAWNER.spawn_batched_directional_bullet_values(self, direction, damage_amount, color, role_id, origin, speed, lifetime, hit_radius, visual_radius, visual_min_diameter, visual_outline_color, visual_outline_width, enemy_hit_radius_scale, enemy_hit_radius_min, enemy_hit_radius_max, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, pierce_count, wave_amplitude, wave_frequency, wave_phase)

func _get_enemy_meta_int(enemy: Node, key: String) -> int:
	return PLAYER_DAMAGE_HELPERS.get_enemy_meta_int(enemy, key)

func _get_enemy_meta_float(enemy: Node, key: String) -> float:
	return PLAYER_DAMAGE_HELPERS.get_enemy_meta_float(enemy, key)

func _apply_role_damage_lifesteal(source_role_id: String, damage_amount: float) -> void:
	PLAYER_DAMAGE_HELPERS.apply_role_damage_lifesteal(self, source_role_id, damage_amount)

func _get_gunner_distance_damage_multiplier(distance: float) -> float:
	return PLAYER_DAMAGE_HELPERS.get_gunner_distance_damage_multiplier(distance, _get_gunner_distance_damage_bonus())

func _get_enemy_hit_radius(enemy: Node) -> float:
	return PLAYER_DAMAGE_HELPERS.get_enemy_hit_radius(enemy)

func _deal_damage_to_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null) -> bool:
	return PLAYER_DAMAGE_RESOLVER.deal_damage_to_enemy(self, enemy, damage_amount, source_role_id, vulnerability_bonus, vulnerability_duration, slow_multiplier, slow_duration, source_position)

func _damage_enemies_in_radius(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _collect_enemies_in_radius_for_damage_batch(center: Vector2, radius: float) -> Array:
	return PLAYER_DAMAGE_RESOLVER.collect_enemies_in_radius(self, center, radius)

func _damage_enemies_in_radius_batched(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius_batched(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_radius_with_kill_energy(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "", kill_energy_bonus: float = 0.0) -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius_with_kill_energy(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id, kill_energy_bonus)

func _damage_enemies_in_multiple_radii_batched(centers: Array[Vector2], radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_multiple_radii_batched(self, centers, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_shapes_batched(shapes: Array[Dictionary]) -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_shapes_batched(self, shapes)

func _damage_enemies_in_cone_batched(origin: Vector2, direction: Vector2, cone_range: float, cone_angle_radians: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_cone(self, origin, direction, cone_range, cone_angle_radians, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_radius_count_kills(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> Dictionary:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_radius_count_kills(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _pull_enemies_toward(center: Vector2, radius: float, pull_strength: float) -> void:
	PLAYER_DAMAGE_RESOLVER.pull_enemies_toward(self, center, radius, pull_strength)

func _damage_enemies_in_line(start_position: Vector2, end_position: Vector2, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_line(self, start_position, end_position, width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_oriented_rect(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_oriented_rect(self, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_oriented_rect_unique(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_oriented_rect_unique(self, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id)

func _damage_enemies_in_ellipse(center: Vector2, horizontal_radius: float, vertical_radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_ellipse(self, center, horizontal_radius, vertical_radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _damage_enemies_in_cone(origin: Vector2, direction: Vector2, cone_range: float, cone_angle_radians: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	return PLAYER_DAMAGE_RESOLVER.damage_enemies_in_cone(self, origin, direction, cone_range, cone_angle_radians, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, source_role_id)

func _schedule_swordsman_slash_followthrough(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, animation_duration: float, source_role_id: String, hit_registry: Dictionary) -> void:
	PLAYER_DAMAGE_RESOLVER.schedule_swordsman_slash_followthrough(self, center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, animation_duration, source_role_id, hit_registry)

func _apply_gunner_lock(target_enemy: Node2D, lock_level: int) -> void:
	gunner_role.apply_lock(self, target_enemy, lock_level)

func _update_active_role_state() -> void:
	PLAYER_EQUIPMENT_FLOW.recalculate_active_equipment_stats(self, false)
	PLAYER_BLESSING_SYSTEM.apply_active_role_runtime_bonuses(self)
	PLAYER_VISUAL_STATE.update_active_role_state(self)

func _setup_hurt_core_visual() -> void:
	PLAYER_HEALTH_VISUALS.setup_hurt_core_visual(self, PLAYER_HURT_CORE_RADIUS, PLAYER_HURT_CORE_OUTLINE_WIDTH)
	_apply_hurt_core_visibility()

func _update_hurt_core_visual(role_data: Dictionary = {}) -> void:
	PLAYER_HEALTH_VISUALS.update_hurt_core_visual(self, role_data, PLAYER_HURT_CORE_OFFSET)
	_apply_hurt_core_visibility()

func _toggle_hurt_core_visual() -> void:
	PLAYER_HEALTH_VISUALS.toggle_hurt_core_visual(self)

func _apply_hurt_core_visibility() -> void:
	PLAYER_HEALTH_VISUALS.apply_hurt_core_visibility(self)

func _setup_player_health_bar() -> void:
	PLAYER_HEALTH_VISUALS.setup_player_health_bar(self)

func _update_player_health_bar(role_data: Dictionary = {}) -> void:
	PLAYER_HEALTH_VISUALS.update_player_health_bar(self, role_data, PLAYER_HEALTH_BAR_HEIGHT, PLAYER_HEALTH_BAR_Y_OFFSET)

func _get_role_health_bar_width(role_id: String) -> float:
	return PLAYER_VISUAL_LAYOUT.get_player_role_health_bar_width(self, role_id)

func get_hurtbox_center() -> Vector2:
	return PLAYER_HEALTH_VISUALS.get_hurtbox_center(self)

func get_hurtbox_radius() -> float:
	return PLAYER_HURT_CORE_RADIUS

func _update_visuals(role_data: Dictionary) -> void:
	PLAYER_VISUAL_STATE.update_visuals(self, role_data, active_role_visual_hidden, active_role_visual_hidden_role_id)

func _update_fire_timer() -> void:
	PLAYER_VISUAL_STATE.update_fire_timer(self)

func _update_camera_shake(delta: float) -> void:
	PLAYER_CAMERA_FEEDBACK.update_camera_shake(self, delta)

func _queue_camera_shake(strength: float, duration: float) -> void:
	PLAYER_CAMERA_FEEDBACK.queue_camera_shake(self, strength, duration)

func queue_external_camera_shake(strength: float, duration: float) -> void:
	PLAYER_CAMERA_FEEDBACK.queue_external_camera_shake(self, strength, duration)

func _pulse_player_visual(peak_scale: float, duration: float) -> void:
	PLAYER_VISUAL_STATE.pulse_player_visual(self, peak_scale, duration)

func _update_role_idle_visual(_delta: float) -> void:
	PLAYER_VISUAL_STATE.update_role_idle_visual(self, str(_get_active_role()["id"]), facing_direction, role_visual_time)

func _activate_switch_power(role_id: String, label: String, duration: float, damage_multiplier: float, interval_bonus: float) -> void:
	PLAYER_SWITCH_FLOW.activate_switch_power(self, role_id, label, duration, damage_multiplier, interval_bonus)

func _queue_next_entry_blessing(source_role_id: String) -> void:
	PLAYER_SWITCH_FLOW.queue_next_entry_blessing(self, source_role_id)

func _apply_pending_entry_blessing(target_role_id: String) -> void:
	PLAYER_SWITCH_FLOW.apply_pending_entry_blessing(self, target_role_id)

func _clear_entry_blessing() -> void:
	PLAYER_SWITCH_FLOW.clear_entry_blessing(self)

func _apply_switch_payoff(hit_count: int, energy_gain: float, cooldown_refund: float) -> void:
	PLAYER_SWITCH_FLOW.apply_switch_payoff(self, hit_count, energy_gain, cooldown_refund)

func _apply_role_share(source_role_id: String, damage_bonus: float, interval_bonus: float, range_bonus: float, skill_bonus: float) -> void:
	PLAYER_ROLE_STAT_FLOW.apply_role_share(self, source_role_id, damage_bonus, interval_bonus, range_bonus, skill_bonus)

func _initialize_existing_role_shares() -> void:
	PLAYER_ROLE_STAT_FLOW.initialize_existing_role_shares(self)

func _show_switch_banner(prefix: String, title: String, color: Color) -> void:
	PLAYER_SWITCH_FLOW.show_switch_banner(self, prefix, title, color)

func _get_active_role() -> Dictionary:
	return PLAYER_RESOURCE_FLOW.get_active_role(self)

func _get_current_move_speed() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_current_move_speed(self)

func _get_role_damage(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_damage(self, role_id)

func _get_active_role_base_health() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_active_role_base_health(self)

func _get_active_role_max_health() -> float:
	return PLAYER_ROLE_STAT_FLOW.get_active_role_max_health(self)

func _get_role_max_health(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_max_health(self, role_id)

func _get_role_current_health(role_id: String) -> float:
	return PLAYER_ROLE_STAT_FLOW.get_role_current_health(self, role_id)

func _save_active_role_health() -> void:
	PLAYER_ROLE_STAT_FLOW.save_active_role_health(self)

func _add_all_role_current_health(amount: float) -> void:
	PLAYER_ROLE_STAT_FLOW.add_all_role_current_health(self, amount)

func _sync_active_role_max_health(preserve_ratio: bool = true, restore_gain: bool = false) -> void:
	PLAYER_ROLE_STAT_FLOW.sync_active_role_max_health(self, preserve_ratio, restore_gain)

func _get_role_special_state(role_id: String) -> Dictionary:
	return PLAYER_RESOURCE_FLOW.get_role_special_state(self, role_id)

func _get_closest_enemy() -> Node2D:
	return PLAYER_TARGETING.get_owner_closest_enemy(self)

func _get_live_enemies() -> Array:
	return PLAYER_DAMAGE_RESOLVER._get_live_enemies(self)

func _get_candidate_enemies_for_circle(center: Vector2, radius: float) -> Array:
	return PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_circle(self, center, radius)

func _get_touching_enemy_damage(center: Vector2, radius: float, query_padding: float = 36.0) -> float:
	return PLAYER_DAMAGE_RESOLVER.get_touching_enemy_damage(self, center, radius, query_padding)

func _get_farthest_enemy() -> Node2D:
	return PLAYER_TARGETING.get_owner_farthest_enemy(self)

func _get_enemy_targets(count: int, prefer_farthest: bool = false) -> Array:
	return PLAYER_TARGETING.get_owner_enemy_targets(self, count, prefer_farthest)

func _get_low_health_enemy() -> Node2D:
	return PLAYER_TARGETING.get_owner_low_health_enemy(self)

func _get_enemy_in_aim_cone(max_angle_degrees: float, max_distance: float = INF) -> Node2D:
	return PLAYER_TARGETING.get_owner_enemy_in_aim_cone(self, max_angle_degrees, max_distance)

func _get_enemy_cluster_center() -> Vector2:
	return PLAYER_TARGETING.get_owner_enemy_cluster_center(self)

func _get_random_enemy_cluster_centers(count: int) -> Array:
	return PLAYER_TARGETING.get_owner_random_enemy_cluster_centers(self, count)

func _collect_nearby_gems() -> void:
	PLAYER_SURVIVAL_FLOW.collect_nearby_gems(self)

func _check_enemy_contact_damage() -> void:
	PLAYER_SURVIVAL_FLOW.check_enemy_contact_damage(self)

func gain_experience(amount: int) -> void:
	PLAYER_SURVIVAL_FLOW.gain_experience(self, amount)

func grant_developer_level_up() -> void:
	PLAYER_SURVIVAL_FLOW.grant_developer_level_up(self)

func take_damage(amount: float) -> void:
	PLAYER_SURVIVAL_FLOW.take_damage(self, amount)

func apply_enemy_slow(multiplier: float, duration: float) -> void:
	PLAYER_SURVIVAL_FLOW.apply_enemy_slow(self, multiplier, duration)

func _add_energy(amount: float) -> void:
	PLAYER_RESOURCE_FLOW.add_energy(self, amount)

func _add_kill_energy(amount: float) -> void:
	PLAYER_COMBAT_RESULT_FLOW.add_kill_energy(self, amount)

func _get_kill_energy_from_enemy(enemy: Node) -> float:
	return PLAYER_COMBAT_RESULT_FLOW.get_kill_energy_from_enemy(enemy)

func _get_boss_damage_energy(damage_amount: float) -> float:
	return PLAYER_COMBAT_RESULT_FLOW.get_boss_damage_energy(damage_amount)

func _get_ultimate_energy_cost() -> float:
	return PLAYER_ULTIMATE_FLOW.get_ultimate_energy_cost(self)

func _can_use_ultimate() -> bool:
	return PLAYER_ULTIMATE_FLOW.can_use_ultimate(self)

func _build_ultimate_cast_payload() -> Dictionary:
	return PLAYER_ULTIMATE_FLOW.build_ultimate_cast_payload(self)

func _get_ultimate_level_damage_multiplier() -> float:
	return PLAYER_ULTIMATE_FLOW.get_ultimate_level_damage_multiplier(self)

func _register_attack_result(role_id: String, hit_count: int, killed: bool) -> void:
	PLAYER_COMBAT_RESULT_FLOW.register_attack_result(self, role_id, hit_count, killed)


func _apply_theme_hit_returns(role_id: String, hit_count: int, killed: bool) -> void:
	return

func _apply_swordsman_low_health_flat_heal(role_id: String, hit_count: int) -> void:
	PLAYER_COMBAT_RESULT_FLOW.apply_swordsman_low_health_flat_heal(self, role_id, hit_count)

func _apply_role_flat_heal_on_hit(role_id: String, hit_count: int) -> void:
	PLAYER_COMBAT_RESULT_FLOW.apply_role_flat_heal_on_hit(self, role_id, hit_count)

func _apply_entry_lifesteal(role_id: String, hit_count: int, killed: bool) -> void:
	PLAYER_COMBAT_RESULT_FLOW.apply_entry_lifesteal(self, role_id, hit_count, killed)

func _heal(amount: float) -> void:
	PLAYER_RESOURCE_FLOW.heal(self, amount)

func _spawn_attack_aftershock(center: Vector2, role_id: String) -> void:
	return

func _play_player_hurt_feedback() -> void:
	PLAYER_COMBAT_RESULT_FLOW.play_player_hurt_feedback(self)

func _trigger_swordsman_counter() -> void:
	PLAYER_COMBAT_RESULT_FLOW.trigger_swordsman_counter(self)

func _count_enemies_in_radius(center: Vector2, radius: float) -> int:
	return PLAYER_DAMAGE_RESOLVER.count_enemies_in_radius(self, center, radius)

func apply_upgrade(option_id: String) -> void:
	PLAYER_UPGRADE_APPLIER.apply_upgrade(self, option_id)

func get_attribute_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_attribute_upgrade_options(self)

func refresh_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.refresh_upgrade_options(self)

func build_direct_blessing_options() -> Array:
	return PLAYER_LEVEL_FLOW.build_all_blessing_options(self)

func build_tier_blessing_options(tier: int) -> Array:
	return PLAYER_LEVEL_FLOW.build_tier_blessing_options(self, tier)

func get_current_blessing_offer_context() -> Dictionary:
	if current_blessing_offer is Dictionary:
		return (current_blessing_offer.get("context", {}) as Dictionary).duplicate(true)
	return {}

func get_small_boss_reward_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_small_boss_reward_options(self)

func get_boss_skill_reward_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_boss_skill_reward_options(self)

func apply_attribute_upgrade(option_id: String) -> void:
	PLAYER_LEVEL_FLOW.apply_attribute_upgrade(self, option_id)


func get_stat_summary() -> Dictionary:
	return PLAYER_STAT_PAYLOAD.build_from_player(self)

func _get_active_skill_cooldown_slots(attack_interval: float) -> Array:
	return PLAYER_SKILL_COOLDOWN_FLOW.get_active_skill_cooldown_slots(self, attack_interval)

func get_final_core_options() -> Array:
	return PLAYER_LEVEL_OPTIONS.get_final_core_options()

func get_save_data() -> Dictionary:
	return PLAYER_RUN_SAVE_STATE.get_save_data(self)

func apply_save_data(data: Dictionary) -> void:
	PLAYER_RUN_SAVE_STATE.apply_save_data(self, data)

func resume_pending_level_ups() -> void:
	PLAYER_LEVEL_FLOW.resume_pending_level_ups(self)

func _delay_level_up_requests(duration: float) -> void:
	PLAYER_LEVEL_FLOW.delay_level_up_requests(self, duration)

func _try_request_level_up() -> void:
	PLAYER_LEVEL_FLOW.try_request_level_up(self)

func _build_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.build_blessing_upgrade_options(self)

func _get_support_offset(role_id: String, aggressive: bool) -> Vector2:
	return PLAYER_VISUAL_LAYOUT.get_support_offset(role_id, facing_direction, aggressive)

func _spawn_radial_rays_effect(center: Vector2, radius: float, ray_count: int, color: Color, width: float, duration: float, angle_offset: float = 0.0) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_radial_rays_effect(self, center, radius, ray_count, color, width, duration, angle_offset)

func _spawn_slash_effect(center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_slash_effect(self, center, direction, length, width, color, duration)

func _spawn_dash_line_effect(start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_dash_line_effect(self, start_position, end_position, color, width, duration)

func _spawn_crescent_wave_effect(center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_degrees: float = 270.0, thickness: float = 26.0) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_crescent_wave_effect(self, center, direction, radius, color, duration, arc_degrees, thickness)

func _spawn_cross_slash_effect(center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_cross_slash_effect(self, center, direction, length, width, color, duration)

func _spawn_thrust_effect(start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float, show_arrow: bool = true) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_thrust_effect(self, start_position, end_position, color, width, duration, show_arrow)

func _spawn_guard_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_guard_effect(self, center, radius, color, duration)

func _spawn_combat_tag(position: Vector2, text: String, color: Color) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_combat_tag(self, position, text, color, SHOW_GAMEPLAY_TEXT_HINTS)

func _spawn_ring_effect(center: Vector2, radius: float, color: Color, width: float, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_ring_effect(self, center, radius, color, width, duration)

func _spawn_mage_bombardment_warning_effect(center: Vector2, radius: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_mage_bombardment_warning_effect(self, center, radius)

func _spawn_mage_bombardment_fall_effect(center: Vector2, radius: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_mage_bombardment_fall_effect(self, center, radius)

func _spawn_pulsing_field(center: Vector2, radius: float, color: Color, pulse_count: int, interval: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	PLAYER_FIELD_EFFECT_FLOW.spawn_pulsing_field(self, center, radius, color, pulse_count, interval, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)

func _trigger_field_pulse(center: Vector2, radius: float, color: Color, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	PLAYER_FIELD_EFFECT_FLOW.trigger_field_pulse(self, center, radius, color, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)

func _spawn_burst_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_burst_effect(self, center, radius, color, duration)

func _spawn_frost_sigils_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_frost_sigils_effect(self, center, radius, color, duration)

func _spawn_vortex_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_vortex_effect(self, center, radius, color, duration)

func _spawn_target_lock_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_target_lock_effect(self, center, radius, color, duration)

func _build_circle_polygon(radius: float) -> PackedVector2Array:
	return PLAYER_MATH.build_circle_polygon(radius)

func _build_arc_points(radius: float, arc_degrees: float) -> PackedVector2Array:
	return PLAYER_MATH.build_arc_points(radius, arc_degrees)

func _build_arc_band_polygon(outer_radius: float, inner_radius: float, arc_degrees: float) -> PackedVector2Array:
	return PLAYER_MATH.build_arc_band_polygon(outer_radius, inner_radius, arc_degrees)

func _die() -> void:
	PLAYER_RESOURCE_FLOW.die(self)
