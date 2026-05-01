extends CharacterBody2D

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const GAME_SETTINGS := preload("res://scripts/game_settings.gd")
const BUILD_SYSTEM := preload("res://scripts/build/build_system.gd")
const PLAYER_SAVE_CODEC := preload("res://scripts/player/player_save_codec.gd")
const PLAYER_STATE_FACTORY := preload("res://scripts/player/player_state_factory.gd")
const PLAYER_LIFECYCLE_FLOW := preload("res://scripts/player/player_lifecycle_flow.gd")
const PLAYER_STORY_STYLES := preload("res://scripts/player/player_story_styles.gd")
const PLAYER_ROLE_PRESENTER := preload("res://scripts/player/player_role_presenter.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")
const PLAYER_MATH := preload("res://scripts/player/player_math.gd")
const PLAYER_ROLE_STAT_FLOW := preload("res://scripts/player/player_role_stat_flow.gd")
const PLAYER_BUILD_STATE := preload("res://scripts/player/player_build_state.gd")
const PLAYER_UPGRADE_OPTIONS := preload("res://scripts/player/player_upgrade_options.gd")
const PLAYER_LEVEL_OPTIONS := preload("res://scripts/player/player_level_options.gd")
const PLAYER_LEVEL_FLOW := preload("res://scripts/player/player_level_flow.gd")
const PLAYER_CARD_APPLIER := preload("res://scripts/player/player_card_applier.gd")
const PLAYER_UPGRADE_APPLIER := preload("res://scripts/player/player_upgrade_applier.gd")
const PLAYER_SLOT_RESONANCE_FLOW := preload("res://scripts/player/player_slot_resonance_flow.gd")
const PLAYER_REWARD_APPLIER := preload("res://scripts/player/player_reward_applier.gd")
const PLAYER_SKILL_COOLDOWN_SLOTS := preload("res://scripts/player/player_skill_cooldown_slots.gd")
const PLAYER_SKILL_COOLDOWN_FLOW := preload("res://scripts/player/player_skill_cooldown_flow.gd")
const PLAYER_STAT_PAYLOAD := preload("res://scripts/player/player_stat_payload.gd")
const PLAYER_RUN_SAVE_STATE := preload("res://scripts/player/player_run_save_state.gd")
const PLAYER_AUTHORED_EFFECTS := preload("res://scripts/player/player_authored_effects.gd")
const PLAYER_PROJECTILE_SPAWNER := preload("res://scripts/player/player_projectile_spawner.gd")
const PLAYER_DAMAGE_HELPERS := preload("res://scripts/player/player_damage_helpers.gd")
const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_COMBAT_RESULT_FLOW := preload("res://scripts/player/player_combat_result_flow.gd")
const PLAYER_COMBAT_MODIFIERS := preload("res://scripts/player/player_combat_modifiers.gd")
const PLAYER_THEME_SKILL_FLOW := preload("res://scripts/player/player_theme_skill_flow.gd")
const PLAYER_EQUIPMENT_FLOW := preload("res://scripts/player/player_equipment_flow.gd")
const PLAYER_HEALTH_VISUALS := preload("res://scripts/player/player_health_visuals.gd")
const PLAYER_TIMER_FLOW := preload("res://scripts/player/player_timer_flow.gd")
const PLAYER_ULTIMATE_FLOW := preload("res://scripts/player/player_ultimate_flow.gd")
const PLAYER_SWITCH_FLOW := preload("res://scripts/player/player_switch_flow.gd")
const PLAYER_SURVIVAL_FLOW := preload("res://scripts/player/player_survival_flow.gd")
const PLAYER_RESOURCE_FLOW := preload("res://scripts/player/player_resource_flow.gd")
const PLAYER_MAGE_BOMBARDMENT_FLOW := preload("res://scripts/player/player_mage_bombardment_flow.gd")
const PLAYER_ATTACK_LOOP_FLOW := preload("res://scripts/player/player_attack_loop_flow.gd")
const PLAYER_CAMERA_FEEDBACK := preload("res://scripts/player/player_camera_feedback.gd")
const PLAYER_MAP_BOUNDS_FLOW := preload("res://scripts/player/player_map_bounds_flow.gd")
const PLAYER_FIELD_EFFECT_FLOW := preload("res://scripts/player/player_field_effect_flow.gd")
const PLAYER_BUILD_PROGRESS_FLOW := preload("res://scripts/player/player_build_progress_flow.gd")
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
const DANGZHEN_SWORD_FAN_ABILITY := preload("res://scripts/abilities/dangzhen_sword_fan_ability.gd")
const SWORDSMAN_BLADE_STORM_ABILITY := preload("res://scripts/abilities/swordsman_blade_storm_ability.gd")
const MAGE_DANGZHEN_WAVE_ABILITY := preload("res://scripts/abilities/dangzhen_mage_wave_ability.gd")
const MAGE_TIDAL_SURGE_ABILITY := preload("res://scripts/abilities/mage_tidal_surge_ability.gd")
const DANGZHEN_GUNNER_BEAM_ABILITY := preload("res://scripts/abilities/dangzhen_gunner_beam_ability.gd")
const GUNNER_INFINITE_RELOAD_ABILITY := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
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

const DANGZHEN_PREVIEW_ACTIVE := false
const DANGZHEN_ONLY_BUILD_ACTIVE := true
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

const ROLE_SWITCH_COOLDOWN := 7.0
const SWITCH_INVULNERABILITY := 0.2
const ENERGY_PASSIVE_REGEN := 0.0
const ENERGY_PER_HIT := 0.3
const ENERGY_PER_KILL := 1.1
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
const SLOT_RESONANCE_FIRST_THRESHOLD := 3
const SLOT_RESONANCE_SECOND_THRESHOLD := 6
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
var auto_attack_enabled: bool = false
var roles: Array = []
var role_upgrade_levels: Dictionary = {}
var background_cooldowns: Dictionary = {}
var build_slot_levels: Dictionary = {}
var card_pick_levels: Dictionary = {}
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
var slot_resonances_unlocked: Dictionary = {}
var role_special_states: Dictionary = {}
var special_reward_levels: Dictionary = {}
var theme_skill_trigger_depth: int = 0
var theme_blood_reflux_cooldown: float = 0.0
var swordsman_blade_storm_ability = SWORDSMAN_BLADE_STORM_ABILITY.new()
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
var entry_haste_interval_bonus: float = 0.0
var entry_haste_move_speed_multiplier: float = 1.0
var relay_window_remaining: float = 0.0
var relay_ready_role_id: String = ""
var relay_from_role_id: String = ""
var relay_label: String = ""
var relay_bonus_pending: bool = false
var standby_entry_role_id: String = ""
var standby_entry_label: String = ""
var standby_entry_remaining: float = 0.0
var standby_entry_damage_multiplier: float = 1.0
var standby_entry_interval_bonus: float = 0.0
var guard_cover_remaining: float = 0.0
var guard_cover_damage_multiplier: float = 1.0
var team_combo_remaining: float = 0.0
var team_combo_damage_multiplier: float = 1.0
var team_combo_move_multiplier: float = 1.0
var team_combo_background_multiplier: float = 1.0
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
var role_cycle_marks: Dictionary = {}
var role_mana_values: Dictionary = {}
var role_ultimate_energy_lock_remaining: Dictionary = {}
var role_share_initialized: bool = false
var role_visual_time: float = 0.0
var active_role_visual_hidden: bool = false
var active_role_visual_hidden_role_id: String = ""
var runtime_texture_cache: Dictionary = {}
var swordsman_role = SWORDSMAN_ROLE.new()
var swordsman_attack_chain: int = 0
var swordsman_dangzhen_fan_ability = DANGZHEN_SWORD_FAN_ABILITY.new()
var gunner_role = GUNNER_ROLE.new()
var gunner_attack_chain: int = 0
var gunner_dangzhen_beam_ability = DANGZHEN_GUNNER_BEAM_ABILITY.new()
var gunner_infinite_reload_ability = GUNNER_INFINITE_RELOAD_ABILITY.new()
var mage_role = MAGE_ROLE.new()
var mage_attack_chain: int = 0
var mage_dangzhen_wave_ability = MAGE_DANGZHEN_WAVE_ABILITY.new()
var mage_tidal_surge_ability = MAGE_TIDAL_SURGE_ABILITY.new()
var gunner_lock_target: Node2D
var gunner_lock_stacks: int = 0
var gem_collection_elapsed: float = 0.0
var contact_check_elapsed: float = 0.0
var execution_pact_burst_active: bool = false
var chain_reaction_active: bool = false
var clean_tide_active: bool = false
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
	return PLAYER_TEXTURE_LOADER.create_white_key_material(
		WHITE_KEY_SHADER,
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
	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.DOWN
	return PLAYER_AUTHORED_EFFECTS.spawn_scaled_animated_scene(
		self,
		SWORD_SLASH_EFFECT_SCENE,
		SWORD_SLASH_SCENE_SIZE,
		SWORD_SLASH_SCENE_VISIBLE_BOUNDS,
		SWORD_SLASH_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() - Vector2.DOWN.angle(),
		Vector2(max(18.0, thickness * 2.0), max(72.0, radius * 2.0)),
		13,
		max(0.24, duration),
		mirror_horizontal
	)

func _spawn_sword_omnislash_scene_effect(center: Vector2, direction: Vector2, length: float, thickness: float) -> Node2D:
	var playback_direction: Vector2 = direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	return PLAYER_AUTHORED_EFFECTS.spawn_scaled_animated_scene(
		self,
		SWORD_OMNISLASH_EFFECT_SCENE,
		SWORD_OMNISLASH_SCENE_SIZE,
		SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS,
		SWORD_OMNISLASH_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() - Vector2.RIGHT.angle(),
		Vector2(max(120.0, length), max(28.0, thickness * 1.18)),
		15,
		0.2
	)

func _set_active_role_visual_hidden(hidden: bool) -> void:
	PLAYER_VISUAL_STATE.set_active_role_visual_hidden(self, hidden)

func _spawn_authored_scene_effect(scene: PackedScene, scene_size: Vector2, visible_bounds: Rect2, center: Vector2, rotation_radians: float, scale_multiplier: float, z_index: int = 12) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_authored_scene_effect(self, scene, scene_size, visible_bounds, center, rotation_radians, scale_multiplier, z_index)

func _spawn_sword_fan_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	var playback_direction := direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	return PLAYER_AUTHORED_EFFECTS.spawn_scaled_animated_scene(
		self,
		SWORD_FAN_EFFECT_SCENE,
		SWORD_FAN_SCENE_SIZE,
		SWORD_FAN_SCENE_VISIBLE_BOUNDS,
		SWORD_FAN_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() + PI,
		Vector2(138.0, 74.0) * scale_multiplier,
		12,
		0.24,
		false,
		1.0,
		false
	)

func _get_dangzhen_sword_visual_size(split_level: int, huichao_level: int) -> Vector2:
	return PLAYER_MATH.get_dangzhen_sword_visual_size(split_level, huichao_level)

func _get_dangzhen_gunner_beam_hit_half_width(visual_thickness: float) -> float:
	return PLAYER_MATH.get_dangzhen_gunner_beam_hit_half_width(visual_thickness, GUNNER_INTERSECT_VISUAL_SCALE)

func _spawn_gunner_intersect_scene_effect(center: Vector2, direction: Vector2, visual_length: float = 112.0, visual_thickness: float = 18.0, gather_visual_length: float = -1.0) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_owner_gunner_intersect_effect(self, center, direction, visual_length, visual_thickness, gather_visual_length)

func _get_dangzhen_gunner_range_multiplier(huichao_level: int) -> float:
	return PLAYER_MATH.get_dangzhen_gunner_range_multiplier(huichao_level)

func _get_gunner_intersect_combo_duration() -> float:
	return PLAYER_AUTHORED_EFFECTS.get_owner_gunner_intersect_combo_duration(self)

func _spawn_mage_gathering_scene_effect(center: Vector2, direction: Vector2, scale_multiplier: float = 1.0) -> Node2D:
	var playback_direction := direction.normalized()
	if playback_direction.length_squared() <= 0.001:
		playback_direction = Vector2.RIGHT
	return _spawn_authored_scene_effect(
		MAGE_GATHERING_EFFECT_SCENE,
		MAGE_GATHERING_SCENE_SIZE,
		MAGE_GATHERING_SCENE_VISIBLE_BOUNDS,
		center,
		playback_direction.angle() - Vector2.RIGHT.angle(),
		1.55 * scale_multiplier,
		12
	)

func _spawn_mage_boom_scene_effect(center: Vector2, radius: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_scaled_animated_scene(
		self,
		MAGE_BOOM_EFFECT_SCENE,
		MAGE_BOOM_SCENE_SIZE,
		MAGE_BOOM_SCENE_VISIBLE_BOUNDS,
		MAGE_BOOM_IMPACT_FOCUS_BOUNDS,
		center,
		0.0,
		Vector2(max(80.0, radius * 4.0), max(184.0, radius * 4.9)),
		14,
		0.3
	)

func _get_dangzhen_qichao_damage(role_id: String, qichao_level: int) -> float:
	return PLAYER_MATH.get_dangzhen_qichao_damage(role_id, qichao_level)

func _spawn_mage_warning_scene_effect(center: Vector2, radius: float) -> Node2D:
	return PLAYER_AUTHORED_EFFECTS.spawn_scaled_animated_scene(
		self,
		MAGE_WARNING_EFFECT_SCENE,
		MAGE_WARNING_SCENE_SIZE,
		MAGE_WARNING_SCENE_VISIBLE_BOUNDS,
		MAGE_WARNING_SCENE_VISIBLE_BOUNDS,
		center,
		0.0,
		Vector2(max(80.0, radius * 4.0), max(42.0, radius * 1.2)),
		13,
		0.2
	)

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

func _build_slot_progress_data() -> Dictionary:
	return PLAYER_STATE_FACTORY.build_slot_progress_data()

func _make_slot_resonance_key(slot_id: String, threshold: int) -> String:
	return PLAYER_SLOT_RESONANCE_FLOW.make_slot_resonance_key(slot_id, threshold)

func _is_slot_resonance_unlocked(slot_id: String, threshold: int) -> bool:
	return PLAYER_SLOT_RESONANCE_FLOW.is_slot_resonance_unlocked(self, slot_id, threshold)

func _unlock_slot_resonance(slot_id: String, threshold: int) -> void:
	PLAYER_SLOT_RESONANCE_FLOW.unlock_slot_resonance(self, slot_id, threshold)

func _check_slot_resonance_unlocks() -> void:
	PLAYER_SLOT_RESONANCE_FLOW.check_slot_resonance_unlocks(self)

func configure_story_loadout(team_order: Array, equipped_styles: Dictionary) -> void:
	var ordered_roles: Array = []
	for role_variant in team_order:
		var role_id := str(role_variant)
		for role_data in roles:
			if str(role_data.get("id", "")) == role_id:
				ordered_roles.append(role_data)
				break
	for role_data in roles:
		if not ordered_roles.has(role_data):
			ordered_roles.append(role_data)
	roles = ordered_roles
	for role_id in ["swordsman", "gunner", "mage"]:
		story_equipped_styles[role_id] = str(equipped_styles.get(role_id, "default"))
	active_role_index = clamp(active_role_index, 0, max(0, roles.size() - 1))
	_update_active_role_state()

func _uses_blank_upgrade_fallback() -> bool:
	return DANGZHEN_ONLY_BUILD_ACTIVE

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
	return BUILD_SYSTEM.get_slot_label(slot_id)

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

func _get_primary_attribute_damage_bonus(role_id: String) -> float:
	return PLAYER_ATTRIBUTE_FLOW.get_primary_attribute_damage_bonus(self, role_id)

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
	return PLAYER_EQUIPMENT_FLOW.get_role_energy_gain_bonus(self, role_id)

func _get_role_equipment_skill_range_multiplier(role_id: String) -> float:
	return float(PLAYER_EQUIPMENT_FLOW.get_role_bonus_summary(self, role_id).get("skill_range_multiplier", 1.0))

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
	return PLAYER_BUILD_STATE.get_card_level(card_pick_levels, card_id)

func _get_build_final_set_data(set_key: String) -> Dictionary:
	return BUILD_SYSTEM.get_final_set_data(set_key)

func _add_special_reward_level(reward_id: String, amount: int = 1) -> int:
	return PLAYER_BUILD_STATE.add_special_reward_level(special_reward_levels, reward_id, amount)

func _has_swordsman_blade_storm_reward() -> bool:
	return PLAYER_BUILD_STATE.has_swordsman_blade_storm_reward(special_reward_levels) \
		or BUILD_SYSTEM.is_theme_unlocked(card_pick_levels, special_reward_levels, "branch_omni_edge")

func _can_offer_swordsman_blade_storm_reward() -> bool:
	return PLAYER_BUILD_STATE.can_offer_swordsman_blade_storm_reward(
		card_pick_levels,
		special_reward_levels,
		_get_build_final_set_data("battle_dangzhen")
	)

func _has_gunner_infinite_reload_reward() -> bool:
	return PLAYER_BUILD_STATE.has_gunner_infinite_reload_reward(special_reward_levels) \
		or BUILD_SYSTEM.is_theme_unlocked(card_pick_levels, special_reward_levels, "branch_blood_shield")

func _can_offer_gunner_infinite_reload_reward() -> bool:
	return PLAYER_BUILD_STATE.can_offer_gunner_infinite_reload_reward(
		card_pick_levels,
		special_reward_levels,
		_get_build_final_set_data("battle_dangzhen")
	)

func _has_mage_tidal_surge_reward() -> bool:
	return PLAYER_BUILD_STATE.has_mage_tidal_surge_reward(special_reward_levels) \
		or BUILD_SYSTEM.is_theme_unlocked(card_pick_levels, special_reward_levels, "branch_tri_finale")

func _can_offer_mage_tidal_surge_reward() -> bool:
	return PLAYER_BUILD_STATE.can_offer_mage_tidal_surge_reward(
		card_pick_levels,
		special_reward_levels,
		_get_build_final_set_data("battle_dangzhen")
	)

func _make_small_boss_reward_option(option_id: String, title: String, description: String) -> Dictionary:
	return {
		"id": option_id,
		"slot": "special",
		"slot_label": "\u5956\u52B1",
		"title": title,
		"description": description,
		"preview_description": description,
		"exact_description": description
	}

func _make_small_boss_blank_reward_option(index: int) -> Dictionary:
	return _make_small_boss_reward_option("small_boss_blank_%d" % index, "\u7A7A\u767D\u5361\u724C", "\u5360\u4F4D\u5956\u52B1\uFF0C\u540E\u7EED\u66FF\u6362\u3002")

func _deprecated_get_small_boss_reward_options_v1() -> Array:
	return []

func _has_elite_relic(relic_id: String) -> bool:
	return PLAYER_BUILD_STATE.has_unlocked_flag(elite_relics_unlocked, relic_id)

func _unlock_elite_relic(relic_id: String) -> void:
	elite_relics_unlocked[relic_id] = true

func _get_role_theme_color(role_id: String) -> Color:
	return PLAYER_BUILD_PROGRESS_FLOW.get_role_theme_color(self, role_id)

func _announce_completed_final_set(set_key: String) -> void:
	PLAYER_BUILD_PROGRESS_FLOW.announce_completed_final_set(self, set_key)

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

func _activate_team_combo(duration: float, damage_multiplier: float, move_multiplier: float, background_multiplier: float) -> void:
	PLAYER_SWITCH_FLOW.activate_team_combo(self, duration, damage_multiplier, move_multiplier, background_multiplier)

func _mark_role_cycle(role_id: String) -> void:
	PLAYER_SWITCH_FLOW.mark_role_cycle(self, role_id)

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
	return PLAYER_EQUIPMENT_FLOW.get_skill_range_multiplier(self)

func _get_equipment_cooldown_multiplier() -> float:
	return PLAYER_EQUIPMENT_FLOW.get_cooldown_multiplier(self)

func _apply_equipment_passives(delta: float) -> void:
	PLAYER_EQUIPMENT_FLOW.apply_passives(self, delta)

func _try_equipment_dodge() -> bool:
	return PLAYER_EQUIPMENT_FLOW.try_dodge(self)

func _unhandled_input(event: InputEvent) -> void:
	PLAYER_SURVIVAL_FLOW.unhandled_input(self, event)

func _physics_process(delta: float) -> void:
	PLAYER_SURVIVAL_FLOW.physics_process(self, delta)
	if not is_dead:
		PLAYER_MAP_BOUNDS_FLOW.clamp_to_active_map_bounds(self)

func _update_timers(delta: float) -> void:
	role_visual_time += delta
	ROLE_RESOURCE_STATE.tick_locks(role_ultimate_energy_lock_remaining, roles, delta)
	_sync_active_role_ultimate_state()
	if hurt_cooldown_remaining > 0.0:
		hurt_cooldown_remaining = max(0.0, hurt_cooldown_remaining - delta)
	if switch_invulnerability_remaining > 0.0:
		switch_invulnerability_remaining = max(0.0, switch_invulnerability_remaining - delta)
	if level_up_delay_remaining > 0.0:
		level_up_delay_remaining = max(0.0, level_up_delay_remaining - delta)
		if level_up_delay_remaining <= 0.0:
			_try_request_level_up()
	if switch_cooldown_remaining > 0.0:
		switch_cooldown_remaining = max(0.0, switch_cooldown_remaining - delta)
	if enemy_move_slow_remaining > 0.0:
		enemy_move_slow_remaining = max(0.0, enemy_move_slow_remaining - delta)
		if enemy_move_slow_remaining <= 0.0:
			enemy_move_slow_multiplier = 1.0
	PLAYER_THEME_SKILL_FLOW.update_cooldowns(self, delta)
	if swordsman_dangzhen_fan_ability != null:
		swordsman_dangzhen_fan_ability.update(delta)
	if gunner_dangzhen_beam_ability != null:
		gunner_dangzhen_beam_ability.update(delta)
	if gunner_infinite_reload_ability != null:
		gunner_infinite_reload_ability.update(self, delta)
	if mage_tidal_surge_ability != null:
		mage_tidal_surge_ability.update(delta)
	if mage_dangzhen_wave_ability != null:
		mage_dangzhen_wave_ability.update(delta)
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability.update(self, delta)
	_try_trigger_independent_sword_qichao()
	_try_trigger_independent_gunner_qichao()
	_try_trigger_independent_mage_qichao()
	_try_trigger_swordsman_blade_storm()
	_try_trigger_gunner_infinite_reload()
	_try_trigger_mage_tidal_surge()
	if perpetual_motion_cooldown_remaining > 0.0:
		perpetual_motion_cooldown_remaining = max(0.0, perpetual_motion_cooldown_remaining - delta)
	_apply_developer_no_cooldown()
	if switch_power_remaining > 0.0:
		switch_power_remaining = max(0.0, switch_power_remaining - delta)
		if switch_power_remaining <= 0.0:
			switch_power_role_id = ""
			switch_power_damage_multiplier = 1.0
			switch_power_interval_bonus = 0.0
			switch_power_label = ""
			_update_fire_timer()
	if entry_blessing_remaining > 0.0:
		entry_blessing_remaining = max(0.0, entry_blessing_remaining - delta)
		if entry_blessing_remaining <= 0.0:
			_clear_entry_blessing()
	if standby_entry_remaining > 0.0:
		standby_entry_remaining = max(0.0, standby_entry_remaining - delta)
		if standby_entry_remaining <= 0.0:
			_clear_standby_entry_buff()
	if guard_cover_remaining > 0.0:
		guard_cover_remaining = max(0.0, guard_cover_remaining - delta)
		if guard_cover_remaining <= 0.0:
			guard_cover_damage_multiplier = 1.0
	if team_combo_remaining > 0.0:
		team_combo_remaining = max(0.0, team_combo_remaining - delta)
		if team_combo_remaining <= 0.0:
			team_combo_damage_multiplier = 1.0
			team_combo_move_multiplier = 1.0
			team_combo_background_multiplier = 1.0
	if borrow_fire_remaining > 0.0:
		borrow_fire_remaining = max(0.0, borrow_fire_remaining - delta)
		if borrow_fire_remaining <= 0.0:
			borrow_fire_role_id = ""
			borrow_fire_damage_multiplier = 1.0
			borrow_fire_interval_bonus = 0.0
			borrow_fire_background_multiplier = 1.0
			_update_fire_timer()
	if post_ultimate_flow_remaining > 0.0:
		post_ultimate_flow_remaining = max(0.0, post_ultimate_flow_remaining - delta)
		if post_ultimate_flow_remaining <= 0.0:
			post_ultimate_flow_background_multiplier = 1.0
	if ultimate_guard_remaining > 0.0:
		ultimate_guard_remaining = max(0.0, ultimate_guard_remaining - delta)
		if ultimate_guard_remaining <= 0.0:
			ultimate_guard_damage_multiplier = 1.0
	if frenzy_remaining > 0.0:
		frenzy_remaining = max(0.0, frenzy_remaining - delta)
		if frenzy_remaining <= 0.0:
			frenzy_stacks = 0
			frenzy_overkill_counter = 0
	if relay_window_remaining > 0.0:
		relay_window_remaining = max(0.0, relay_window_remaining - delta)
		if relay_window_remaining <= 0.0:
			relay_ready_role_id = ""
			relay_from_role_id = ""
			relay_label = ""
			relay_bonus_pending = false
	for role_data in roles:
		var role_id := str(role_data.get("id", ""))
		if role_id == str(_get_active_role().get("id", "")):
			role_standby_elapsed[role_id] = 0.0
		else:
			role_standby_elapsed[role_id] = float(role_standby_elapsed.get(role_id, 0.0)) + delta
	_update_camera_shake(delta)

func _apply_developer_no_cooldown() -> void:
	if not DEVELOPER_MODE.should_ignore_cooldowns():
		return
	switch_cooldown_remaining = 0.0
	perpetual_motion_cooldown_remaining = 0.0
	if swordsman_dangzhen_fan_ability != null:
		swordsman_dangzhen_fan_ability.cooldown_remaining = 0.0
	if gunner_dangzhen_beam_ability != null:
		gunner_dangzhen_beam_ability.cooldown_remaining = 0.0
	if gunner_infinite_reload_ability != null:
		gunner_infinite_reload_ability.cooldown_remaining = 0.0
	if mage_dangzhen_wave_ability != null:
		mage_dangzhen_wave_ability.cooldown_remaining = 0.0
	if mage_tidal_surge_ability != null:
		mage_tidal_surge_ability.cooldown_remaining = 0.0
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability.cooldown_remaining = 0.0

func _regenerate_energy(delta: float) -> void:
	PLAYER_SURVIVAL_FLOW.regenerate_energy(self, delta)

func _update_facing_direction() -> void:
	PLAYER_SURVIVAL_FLOW.update_facing_direction(self)

func _toggle_attack_aim_mode() -> void:
	auto_attack_enabled = not auto_attack_enabled
	var mode_text := "\u81ea\u52a8\u653b\u51fb" if auto_attack_enabled else "\u9f20\u6807\u8ddf\u968f"
	_spawn_combat_tag(global_position + Vector2(0.0, -48.0), mode_text, Color(0.72, 0.96, 1.0, 1.0))
	stats_changed.emit(get_stat_summary())

func _get_attack_aim_direction(fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	return PLAYER_SURVIVAL_FLOW.get_attack_aim_direction(self, fallback_direction)

func _update_background_effects(delta: float) -> void:
	PLAYER_ATTACK_LOOP_FLOW.update_background_effects(self, delta)

func _trigger_background_effect(role_index: int) -> void:
	PLAYER_ATTACK_LOOP_FLOW.trigger_background_effect(self, role_index)

func _perform_active_attack() -> void:
	PLAYER_ATTACK_LOOP_FLOW.perform_active_attack(self)

func _trigger_dangzhen_sword_qichao_preview(attack_direction: Vector2, attack_damage: float, role_id: String) -> int:
	if swordsman_dangzhen_fan_ability == null:
		return 0
	return swordsman_dangzhen_fan_ability.try_trigger(self, attack_direction, role_id)

func _execute_dangzhen_gunner_beam(origin: Vector2, fire_direction: Vector2, damage_amount: float, role_id: String) -> int:
	if gunner_dangzhen_beam_ability == null:
		return 0
	return gunner_dangzhen_beam_ability.execute_beam(self, origin, fire_direction, damage_amount, role_id)

func _trigger_dangzhen_gunner_qichao_preview(shot_direction: Vector2, attack_damage: float, role_id: String) -> int:
	if gunner_dangzhen_beam_ability == null:
		return 0
	return gunner_dangzhen_beam_ability.try_trigger(self, shot_direction, role_id)

func _get_live_mouse_aim_direction(fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	return _get_attack_aim_direction(fallback_direction)

func _try_trigger_independent_mage_qichao() -> void:
	if is_dead or level_up_active:
		return
	var active_role_id := str(_get_active_role().get("id", ""))
	if active_role_id != "mage":
		return
	if mage_dangzhen_wave_ability == null or not mage_dangzhen_wave_ability.can_trigger(self, active_role_id):
		return
	var wave_direction: Vector2 = _get_live_mouse_aim_direction(facing_direction)
	mage_dangzhen_wave_ability.try_trigger(self, wave_direction, active_role_id)

func _try_trigger_independent_sword_qichao() -> void:
	if is_dead or level_up_active:
		return
	var active_role_id := str(_get_active_role().get("id", ""))
	if active_role_id != "swordsman":
		return
	if _get_card_level("battle_dangzhen_qichao") <= 0:
		return
	if swordsman_dangzhen_fan_ability == null or not swordsman_dangzhen_fan_ability.can_trigger(self, active_role_id):
		return
	var attack_direction: Vector2 = _get_live_mouse_aim_direction(facing_direction)
	var dangzhen_hits := _trigger_dangzhen_sword_qichao_preview(attack_direction, _get_role_damage(active_role_id), active_role_id)
	if dangzhen_hits > 0:
		_register_attack_result(active_role_id, dangzhen_hits, false)

func _try_trigger_independent_gunner_qichao() -> void:
	if is_dead or level_up_active:
		return
	var active_role_id := str(_get_active_role().get("id", ""))
	if active_role_id != "gunner":
		return
	if is_gunner_infinite_reload_active():
		return
	if gunner_dangzhen_beam_ability == null or not gunner_dangzhen_beam_ability.can_trigger(self, active_role_id):
		return
	var shot_direction: Vector2 = _get_live_mouse_aim_direction(facing_direction)
	var dangzhen_hits := _trigger_dangzhen_gunner_qichao_preview(shot_direction, _get_role_damage(active_role_id), active_role_id)
	if dangzhen_hits > 0:
		_register_attack_result(active_role_id, dangzhen_hits, false)

func _try_trigger_swordsman_blade_storm() -> void:
	var active_role_id := str(_get_active_role().get("id", ""))
	if swordsman_blade_storm_ability == null or not swordsman_blade_storm_ability.can_trigger(self, active_role_id):
		return
	_start_swordsman_blade_storm()

func _try_trigger_gunner_infinite_reload() -> void:
	if is_dead or level_up_active:
		return
	if gunner_infinite_reload_ability == null:
		return
	var active_role_id := str(_get_active_role().get("id", ""))
	if not gunner_infinite_reload_ability.can_trigger(self, active_role_id):
		return
	_start_gunner_infinite_reload()

func _start_swordsman_blade_storm() -> void:
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability.try_trigger(self)
	return
	_spawn_combat_tag(global_position + Vector2(0.0, -66.0), "閸撴垵鍨夋搴㈡瘹", Color(0.42, 0.9, 1.0, 1.0))

func _trigger_swordsman_blade_storm_tick() -> void:
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability._trigger_tick(self)

func _ensure_swordsman_blade_storm_effect() -> void:
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability.restore_effect_if_active(self)

func _update_swordsman_blade_storm_effect(delta: float) -> void:
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability._update_effect(self, delta)

func _stop_swordsman_blade_storm() -> void:
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability.stop()

func _cleanup_gunner_infinite_reload_effects() -> void:
	if gunner_infinite_reload_ability != null:
		gunner_infinite_reload_ability._cleanup_effects()

func _register_gunner_infinite_reload_effect(effect: Node2D) -> void:
	if gunner_infinite_reload_ability != null:
		gunner_infinite_reload_ability.register_effect(effect)

func _start_gunner_infinite_reload() -> void:
	if gunner_infinite_reload_ability != null:
		gunner_infinite_reload_ability.try_trigger(self)

func _trigger_gunner_infinite_reload_tick() -> void:
	if gunner_infinite_reload_ability != null:
		gunner_infinite_reload_ability._trigger_tick(self)

func _stop_gunner_infinite_reload() -> void:
	if gunner_infinite_reload_ability != null:
		gunner_infinite_reload_ability.stop()

func is_gunner_infinite_reload_active() -> bool:
	return gunner_infinite_reload_ability != null and gunner_infinite_reload_ability.is_active()

func _try_trigger_mage_tidal_surge() -> void:
	if is_dead or level_up_active:
		return
	var active_role_id := str(_get_active_role().get("id", ""))
	if mage_tidal_surge_ability == null or not mage_tidal_surge_ability.can_trigger(self, active_role_id):
		return
	_start_mage_tidal_surge()

func _start_mage_tidal_surge() -> void:
	if mage_tidal_surge_ability == null:
		return
	var base_direction: Vector2 = _get_live_mouse_aim_direction(facing_direction)
	mage_tidal_surge_ability.try_trigger(self, base_direction)

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

func _schedule_repeating_sequence(interval: float, repeat_count: int, callback: Callable) -> void:
	PLAYER_ULTIMATE_FLOW.schedule_repeating_sequence(self, interval, repeat_count, callback)

func _fire_gunner_entry_wave(role_id: String, wave_index: int) -> void:
	PLAYER_SWITCH_FLOW.fire_gunner_entry_wave(self, role_id, wave_index)

func _spawn_gunner_entry_wave_batch(role_id: String, wave_index: int, start_index: int) -> void:
	PLAYER_SWITCH_FLOW.spawn_gunner_entry_wave_batch(self, role_id, wave_index, start_index)

func _start_mage_entry_bombardment(role_id: String, bombard_centers: Array) -> void:
	PLAYER_SWITCH_FLOW.start_mage_entry_bombardment(self, role_id, bombard_centers)

func _show_mage_entry_bombardment_warning(center: Vector2) -> void:
	PLAYER_SWITCH_FLOW.show_mage_entry_bombardment_warning(self, center)

func _trigger_mage_entry_bombardment_impact(role_id: String, center: Vector2) -> void:
	PLAYER_SWITCH_FLOW.trigger_mage_entry_bombardment_impact(self, role_id, center)

func _start_basic_mage_bombardment(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.start_basic_mage_bombardment(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _trigger_basic_mage_bombardment_impact(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.trigger_basic_mage_bombardment_impact(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _resolve_basic_mage_bombardment_damage(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool, advance_attack_chain: bool = true) -> void:
	PLAYER_MAGE_BOMBARDMENT_FLOW.resolve_basic_mage_bombardment_damage(self, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)

func _get_enemy_nearest_to_position(position: Vector2) -> Node2D:
	if position == Vector2.ZERO:
		return _get_closest_enemy()
	return PLAYER_TARGETING.get_enemy_nearest_to_position(get_tree().get_nodes_in_group("enemies"), position)

func _get_enemy_near_position(position: Vector2, max_distance: float) -> Node2D:
	return PLAYER_TARGETING.get_enemy_near_position(get_tree().get_nodes_in_group("enemies"), position, max_distance)

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

func _get_enemy_meta_int(enemy: Node, key: String) -> int:
	return PLAYER_DAMAGE_HELPERS.get_enemy_meta_int(enemy, key)

func _get_enemy_meta_float(enemy: Node, key: String) -> float:
	return PLAYER_DAMAGE_HELPERS.get_enemy_meta_float(enemy, key)

func _apply_role_damage_lifesteal(source_role_id: String, damage_amount: float) -> void:
	PLAYER_DAMAGE_HELPERS.apply_role_damage_lifesteal(self, source_role_id, damage_amount)

func _get_gunner_distance_damage_multiplier(distance: float) -> float:
	return PLAYER_DAMAGE_HELPERS.get_gunner_distance_damage_multiplier(distance)

func _get_enemy_hit_radius(enemy: Node) -> float:
	return PLAYER_DAMAGE_HELPERS.get_enemy_hit_radius(enemy)

func _deal_damage_to_enemy(enemy: Node, damage_amount: float, source_role_id: String, vulnerability_bonus: float = 0.0, vulnerability_duration: float = 2.0, slow_multiplier: float = 1.0, slow_duration: float = 0.0, source_position: Variant = null) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	var break_level := _get_card_level("battle_break")
	var final_damage := damage_amount
	if source_role_id == "gunner":
		var attack_origin: Vector2 = global_position
		if source_position is Vector2:
			attack_origin = source_position
		final_damage *= _get_gunner_distance_damage_multiplier(attack_origin.distance_to(enemy.global_position))
	var break_stacks := 0
	var break_max_stacks := 0
	var break_expire_time := 0.0
	var break_ready := false
	if break_level > 0:
		break_stacks = _get_enemy_meta_int(enemy, "player_break_stacks")
		break_max_stacks = 4 if break_level == 1 else 5
		break_expire_time = _get_enemy_meta_float(enemy, "player_break_expire")
		break_ready = bool(enemy.get_meta("player_break_ready")) if enemy.has_meta("player_break_ready") else false
		if role_visual_time > break_expire_time:
			break_stacks = 0
			break_ready = false
		var break_multiplier: float = [0.06, 0.07, 0.08][break_level - 1]
		final_damage *= 1.0 + min(break_stacks, break_max_stacks) * break_multiplier
		if break_level >= 2 and break_stacks >= break_max_stacks:
			final_damage *= 1.1
	var killed := false
	if damage_amount > 0.0 and enemy.has_method("take_damage"):
		killed = bool(enemy.take_damage(final_damage))
		_apply_role_damage_lifesteal(source_role_id, final_damage)
		if str(enemy.get("enemy_kind")) == "boss":
			_add_kill_energy(_get_boss_damage_energy(final_damage))
		if killed:
			_add_kill_energy(_get_kill_energy_from_enemy(enemy))
	if vulnerability_bonus > 0.0 and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(vulnerability_bonus, vulnerability_duration)
	if slow_duration > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_multiplier, slow_duration)
	if break_level > 0:
		break_stacks = min(break_max_stacks, break_stacks + 1)
		enemy.set_meta("player_break_stacks", break_stacks)
		enemy.set_meta("player_break_expire", role_visual_time + 1.8)
		if break_stacks >= break_max_stacks and break_level >= 3:
			if break_ready and enemy.has_method("take_damage"):
				var bonus_kill := bool(enemy.take_damage(damage_amount * 0.6))
				if bonus_kill and source_role_id != "":
					_register_attack_result(source_role_id, 1, true)
				enemy.set_meta("player_break_ready", false)
			else:
				enemy.set_meta("player_break_ready", true)
		elif break_stacks < break_max_stacks:
			enemy.set_meta("player_break_ready", false)
	return killed

func _damage_enemies_in_radius(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count: int = 0
	var resolved_role_id := source_role_id
	if resolved_role_id == "":
		resolved_role_id = str(_get_active_role().get("id", ""))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) > radius + _get_enemy_hit_radius(enemy):
			continue

		var killed: bool = false
		killed = _deal_damage_to_enemy(enemy, damage_amount, resolved_role_id, vulnerability_bonus, 2.5, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(resolved_role_id, 1, true)

	return hit_count

func _pull_enemies_toward(center: Vector2, radius: float, pull_strength: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var distance: float = center.distance_to(enemy.global_position)
		if distance <= 1.0 or distance > radius:
			continue
		var pull_step: float = min(pull_strength, distance - 4.0)
		if pull_step <= 0.0:
			continue
		var pull_ratio: float = 1.0 - distance / radius
		enemy.global_position = enemy.global_position.move_toward(center, max(4.0, pull_step * (0.55 + pull_ratio * 0.7)))

func _damage_enemies_in_line(start_position: Vector2, end_position: Vector2, width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count: int = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, start_position, end_position)
		if closest_point.distance_to(enemy.global_position) > width + _get_enemy_hit_radius(enemy):
			continue

		var killed: bool = false
		killed = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration, start_position)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _damage_enemies_in_oriented_rect(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count: int = 0
	var long_axis: Vector2 = axis_direction.normalized()
	if long_axis.length_squared() <= 0.001:
		long_axis = Vector2.DOWN
	var short_axis: Vector2 = Vector2(-long_axis.y, long_axis.x)
	var half_length: float = rect_length * 0.5
	var half_width: float = rect_width * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_position: Vector2 = enemy.global_position
		var to_enemy: Vector2 = enemy_position - center
		var enemy_radius: float = _get_enemy_hit_radius(enemy)
		var local_long: float = abs(to_enemy.dot(long_axis))
		var local_short: float = abs(to_enemy.dot(short_axis))
		if local_long > half_length + enemy_radius:
			continue
		if local_short > half_width + enemy_radius:
			continue

		var killed: bool = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _damage_enemies_in_oriented_rect_unique(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, hit_registry: Dictionary, source_role_id: String = "") -> int:
	var hit_count: int = 0
	var long_axis: Vector2 = axis_direction.normalized()
	if long_axis.length_squared() <= 0.001:
		long_axis = Vector2.DOWN
	var short_axis: Vector2 = Vector2(-long_axis.y, long_axis.x)
	var half_length: float = rect_length * 0.5
	var half_width: float = rect_width * 0.5
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_id: int = enemy.get_instance_id()
		if hit_registry.has(enemy_id):
			continue
		var enemy_position: Vector2 = enemy.global_position
		var to_enemy: Vector2 = enemy_position - center
		var enemy_radius: float = _get_enemy_hit_radius(enemy)
		var local_long: float = abs(to_enemy.dot(long_axis))
		var local_short: float = abs(to_enemy.dot(short_axis))
		if local_long > half_length + enemy_radius:
			continue
		if local_short > half_width + enemy_radius:
			continue

		hit_registry[enemy_id] = true
		var killed: bool = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _damage_enemies_in_ellipse(center: Vector2, horizontal_radius: float, vertical_radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
	var hit_count: int = 0
	var safe_horizontal_radius: float = max(1.0, horizontal_radius)
	var safe_vertical_radius: float = max(1.0, vertical_radius)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_position: Vector2 = enemy.global_position
		var enemy_radius: float = _get_enemy_hit_radius(enemy)
		var normalized_x: float = (enemy_position.x - center.x) / (safe_horizontal_radius + enemy_radius)
		var normalized_y: float = (enemy_position.y - center.y) / (safe_vertical_radius + enemy_radius)
		if normalized_x * normalized_x + normalized_y * normalized_y > 1.0:
			continue

		var killed: bool = _deal_damage_to_enemy(enemy, damage_amount, source_role_id if source_role_id != "" else str(_get_active_role().get("id", "")), vulnerability_bonus, 2.0, slow_multiplier, slow_duration)
		hit_count += 1
		if killed:
			_register_attack_result(source_role_id if source_role_id != "" else _get_active_role()["id"], 1, true)

	return hit_count

func _schedule_swordsman_slash_followthrough(center: Vector2, axis_direction: Vector2, rect_length: float, rect_width: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, animation_duration: float, source_role_id: String, hit_registry: Dictionary) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null or SWORD_SLASH_DAMAGE_FOLLOW_PULSES <= 0:
		return

	var controller := Node2D.new()
	controller.name = "SwordsmanSlashFollowthroughController"
	current_scene.add_child(controller)

	var tween := controller.create_tween()
	var pulse_interval: float = max(0.03, animation_duration / float(SWORD_SLASH_DAMAGE_FOLLOW_PULSES + 1))
	for pulse_index in range(SWORD_SLASH_DAMAGE_FOLLOW_PULSES):
		tween.tween_interval(pulse_interval)
		tween.tween_callback(func() -> void:
			_damage_enemies_in_oriented_rect_unique(center, axis_direction, rect_length, rect_width, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, hit_registry, source_role_id)
		)
	tween.tween_callback(controller.queue_free)

func _apply_gunner_lock(target_enemy: Node2D, lock_level: int) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		gunner_lock_target = null
		gunner_lock_stacks = 0
		return

	if gunner_lock_target == null or not is_instance_valid(gunner_lock_target) or gunner_lock_target != target_enemy:
		gunner_lock_target = target_enemy
		gunner_lock_stacks = 0

	gunner_lock_stacks += 1
	if target_enemy.has_method("apply_vulnerability"):
		target_enemy.apply_vulnerability(0.04 * lock_level, 1.4 + 0.2 * lock_level)

	var required_stacks: int = max(1, 3 - lock_level)
	if gunner_lock_stacks < required_stacks:
		return

	gunner_lock_stacks = 0
	gunner_lock_target = null
	var bonus_damage := _get_role_damage("gunner") * (0.36 + lock_level * 0.14)
	var locked_kill := false
	locked_kill = _deal_damage_to_enemy(target_enemy, bonus_damage, "gunner")
	if lock_level >= 2:
		var splash_hits := _damage_enemies_in_radius(target_enemy.global_position, 26.0 + lock_level * 5.0, _get_role_damage("gunner") * (0.12 + lock_level * 0.03), 0.02, 1.0, 0.0)
		if splash_hits > 0:
			_register_attack_result("gunner", splash_hits, false)
	_register_attack_result("gunner", 1, locked_kill)

func _update_active_role_state() -> void:
	PLAYER_EQUIPMENT_FLOW.recalculate_active_equipment_stats(self, false)
	PLAYER_VISUAL_STATE.update_active_role_state(self)

func _setup_hurt_core_visual() -> void:
	PLAYER_HEALTH_VISUALS.setup_hurt_core_visual(self, PLAYER_HURT_CORE_RADIUS, PLAYER_HURT_CORE_OUTLINE_WIDTH)

func _update_hurt_core_visual(role_data: Dictionary = {}) -> void:
	PLAYER_HEALTH_VISUALS.update_hurt_core_visual(self, role_data, PLAYER_HURT_CORE_OFFSET)

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
	var polygon := get_node_or_null("Polygon2D") as Polygon2D
	if polygon != null:
		polygon.visible = false

	for child in get_children():
		if child is Node and str(child.name).begins_with("RoleVisualRoot"):
			remove_child(child)
			child.free()

	var visual_root := Node2D.new()
	visual_root.name = "RoleVisualRoot"
	add_child(visual_root)
	var sprite := Sprite2D.new()
	sprite.name = "RoleSprite"
	if not _configure_role_sprite(sprite, str(role_data["id"])):
		if polygon != null:
			polygon.visible = true
			polygon.color = role_data["color"]
			if PLAYER_VISUAL_STATE.is_role_visual_hidden(str(role_data["id"]), active_role_visual_hidden, active_role_visual_hidden_role_id):
				polygon.visible = false
		sprite.queue_free()
		return
	visual_root.add_child(sprite)
	var should_hide := PLAYER_VISUAL_STATE.is_role_visual_hidden(str(role_data["id"]), active_role_visual_hidden, active_role_visual_hidden_role_id)
	if sprite != null:
		sprite.visible = not should_hide
	if polygon != null and not should_hide:
		polygon.visible = false

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

func _prepare_relay_window(from_role_index: int, to_role_index: int, exit_hits: int, entry_hits: int) -> void:
	PLAYER_SWITCH_FLOW.prepare_relay_window(self, from_role_index, to_role_index, exit_hits, entry_hits)

func _trigger_relay_success(role_id: String, hit_count: int) -> void:
	PLAYER_SWITCH_FLOW.trigger_relay_success(self, role_id, hit_count)

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

func _get_role_special_state(role_id: String) -> Dictionary:
	return PLAYER_RESOURCE_FLOW.get_role_special_state(self, role_id)

func _get_closest_enemy() -> Node2D:
	return PLAYER_TARGETING.get_owner_closest_enemy(self)

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
	if amount <= 0.0:
		return
	var active_role_id := _get_active_role_id()
	for role_data in roles:
		var role_id := str(role_data.get("id", ""))
		if role_id == "":
			continue
		if _get_role_ultimate_lock_remaining(role_id) > 0.0 and not DEVELOPER_MODE.should_unlock_ultimate_freely():
			continue
		var gain_scale: float = 1.0 if role_id == active_role_id else BACKGROUND_ULTIMATE_ENERGY_GAIN_RATIO
		var base_energy_gain_multiplier: float = energy_gain_multiplier - equipment_energy_gain_bonus + _get_role_equipment_energy_gain_bonus(role_id)
		var adjusted_amount: float = amount * gain_scale * max(0.01, base_energy_gain_multiplier) * _get_ultimate_energy_gain_multiplier_for_role(role_id)
		if adjusted_amount <= 0.0:
			continue
		var updated_mana := _add_role_mana(role_id, adjusted_amount, false)
		if role_id == active_role_id and _has_elite_relic("elite_reactor") and is_equal_approx(updated_mana, max_mana):
			_activate_switch_power(active_role_id, "\u6EE1\u80FD\u53CD\u5E94", 2.8, 1.14, 0.04)
	_emit_active_mana_changed()

func _get_kill_energy_from_enemy(enemy: Node) -> float:
	if enemy == null or not is_instance_valid(enemy):
		return 0.0
	var enemy_kind: String = str(enemy.get("enemy_kind"))
	if enemy_kind == "boss":
		return 0.0
	if enemy_kind == "elite":
		return 10.0 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
	var reward_tier: int = int(enemy.get("reward_tier"))
	match reward_tier:
		2:
			return 1.1 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		3:
			return 1.5 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		4:
			return 2.0 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER
		_:
			return 0.8 * SMALL_ENEMY_KILL_ENERGY_MULTIPLIER

func _get_boss_damage_energy(damage_amount: float) -> float:
	if damage_amount <= 0.0:
		return 0.0
	var energy_amount: float = sqrt(damage_amount) * 0.18
	return clamp(energy_amount, 0.25, 2.0)

func _get_ultimate_energy_cost() -> float:
	return PLAYER_ULTIMATE_FLOW.get_ultimate_energy_cost(self)

func _can_use_ultimate() -> bool:
	return PLAYER_ULTIMATE_FLOW.can_use_ultimate(self)

func _build_ultimate_cast_payload() -> Dictionary:
	return PLAYER_ULTIMATE_FLOW.build_ultimate_cast_payload(self)

func _get_ultimate_level_damage_multiplier() -> float:
	return PLAYER_ULTIMATE_FLOW.get_ultimate_level_damage_multiplier(self)

func _register_attack_result(role_id: String, hit_count: int, killed: bool) -> void:
	_trigger_relay_success(role_id, hit_count)
	_apply_entry_lifesteal(role_id, hit_count, killed)
	_apply_theme_hit_returns(role_id, hit_count, killed)
	if hit_count > 0 and _get_card_level("battle_chain") > 0:
		_trigger_chain_reaction(role_id)
	if hit_count >= 2 and _get_card_level("battle_tide") > 0:
		_trigger_clean_tide(role_id)
	if killed and _has_elite_relic("elite_execution_pact") and not execution_pact_burst_active:
		execution_pact_burst_active = true
		_spawn_burst_effect(global_position + facing_direction * 20.0, 42.0, Color(1.0, 0.62, 0.4, 0.16), 0.16)
		_damage_enemies_in_radius(global_position + facing_direction * 20.0, 42.0, _get_role_damage(role_id) * 0.34, 0.0, 1.0, 0.0)
		execution_pact_burst_active = false
	if killed and _has_elite_relic("elite_battle_frenzy"):
		var previous_stacks := frenzy_stacks
		frenzy_stacks = min(8, frenzy_stacks + 1)
		frenzy_remaining = 5.0
		if previous_stacks >= 8 and frenzy_stacks >= 8:
			frenzy_overkill_counter += 1
			if frenzy_overkill_counter >= 6:
				frenzy_overkill_counter = 0


func _apply_theme_hit_returns(role_id: String, hit_count: int, killed: bool) -> void:
	PLAYER_COMBAT_RESULT_FLOW.apply_theme_hit_returns(self, role_id, hit_count, killed)
	PLAYER_THEME_SKILL_FLOW.apply_attack_theme_skills(self, role_id, hit_count, killed)

func _apply_entry_lifesteal(role_id: String, hit_count: int, killed: bool) -> void:
	if entry_blessing_remaining <= 0.0:
		return
	if entry_blessing_role_id != role_id:
		return
	if entry_lifesteal_ratio <= 0.0 or hit_count <= 0:
		return

	var capped_hits: int = min(hit_count, 6)
	var estimated_damage: float = _get_role_damage(role_id) * float(capped_hits) * 0.55
	if killed:
		estimated_damage += _get_role_damage(role_id) * 0.35
	var heal_amount: float = estimated_damage * entry_lifesteal_ratio
	if heal_amount > 0.0:
		_heal(heal_amount)

func _heal(amount: float) -> void:
	PLAYER_RESOURCE_FLOW.heal(self, amount)

func _trigger_chain_reaction(role_id: String) -> void:
	var chain_level := _get_card_level("battle_chain")
	if chain_level <= 0 or chain_reaction_active:
		return
	chain_reaction_active = true
	var search_center := global_position + facing_direction * 28.0
	var search_radius := 220.0
	var bounce_count := 1 if chain_level == 1 else 2
	var chain_damage_ratio: float = [0.45, 0.55, 0.65][chain_level - 1]
	var previous_target: Node2D = null
	var from_position := search_center
	for bounce_index in range(bounce_count):
		var chosen_target: Node2D = null
		var best_distance := search_radius
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if enemy == previous_target:
				continue
			var distance := from_position.distance_to(enemy.global_position)
			if distance > best_distance:
				continue
			best_distance = distance
			chosen_target = enemy
		if chosen_target == null:
			break
		_spawn_dash_line_effect(from_position, chosen_target.global_position, Color(0.92, 0.56, 1.0, 0.9), 6.0, 0.1)
		_spawn_target_lock_effect(chosen_target.global_position, 18.0 + chain_level * 4.0, Color(0.92, 0.56, 1.0, 0.76), 0.12)
		_spawn_burst_effect(chosen_target.global_position, 22.0 + chain_level * 4.0, Color(0.72, 0.38, 1.0, 0.2), 0.12)
		var chain_kill := _deal_damage_to_enemy(chosen_target, _get_role_damage(role_id) * chain_damage_ratio, role_id, 0.02 * chain_level, 1.8, 1.0, 0.0)
		_register_attack_result(role_id, 1, chain_kill)
		previous_target = chosen_target
		from_position = chosen_target.global_position
	if chain_level >= 3:
		_add_energy(2.0)
	chain_reaction_active = false

func _trigger_clean_tide(role_id: String) -> void:
	var tide_level := _get_card_level("battle_tide")
	if tide_level <= 0 or clean_tide_active:
		return
	clean_tide_active = true
	var tide_radius: float = [32.0, 40.0, 48.0][tide_level - 1]
	var tide_damage_ratio: float = [0.45, 0.55, 0.65][tide_level - 1]
	var tide_center: Vector2 = global_position + facing_direction * (28.0 + tide_radius * 0.4)
	_spawn_ring_effect(tide_center, tide_radius * 1.2, Color(0.3, 0.92, 1.0, 0.76), 6.0, 0.16)
	_spawn_burst_effect(tide_center, tide_radius * 1.08, Color(0.18, 0.84, 1.0, 0.2), 0.14)
	var slow_multiplier := 1.0
	var slow_duration := 0.0
	if tide_level >= 2:
		slow_multiplier = 0.8
		slow_duration = 0.8
	var tide_hits := _damage_enemies_in_radius(tide_center, tide_radius, _get_role_damage(role_id) * tide_damage_ratio, 0.0, slow_multiplier, slow_duration)
	if tide_hits > 0:
		_register_attack_result(role_id, tide_hits, false)
	if tide_level >= 3:
		_add_energy(6.0)
	clean_tide_active = false

func _spawn_attack_aftershock(center: Vector2, role_id: String) -> void:
	var aftershock_level := _get_card_level("battle_aftershock")
	if aftershock_level <= 0:
		return
	var level_index: int = clamp(aftershock_level - 1, 0, 2)
	var radius: float = [48.0, 64.0, 80.0][level_index]
	var damage_ratio: float = [0.35, 0.45, 0.55][level_index]
	var pulse_count := 2 if aftershock_level == 1 else 3
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var controller := Node2D.new()
	controller.name = "AttackAftershockController"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	for pulse_index in range(pulse_count):
		if pulse_index > 0:
			tween.tween_interval(0.12)
		tween.tween_callback(func() -> void:
			var current_radius: float = radius + pulse_index * 14.0
			var current_damage: float = _get_role_damage(role_id) * damage_ratio
			var accent := _get_role_theme_color(role_id)
			_spawn_ring_effect(center, current_radius, Color(min(1.0, accent.r + 0.14), min(1.0, accent.g + 0.14), min(1.0, accent.b + 0.18), 0.88), 8.0, 0.2)
			_spawn_burst_effect(center, current_radius * 0.94, Color(accent.r, accent.g, accent.b, 0.26), 0.18)
			match role_id:
				"swordsman":
					var angle_shift := pulse_index * 0.18
					_spawn_crescent_wave_effect(center, Vector2.RIGHT.rotated(angle_shift), current_radius * 0.96, Color(0.24, 0.94, 1.0, 0.7), 0.2, 220.0, 18.0 + pulse_index * 4.0)
					_spawn_crescent_wave_effect(center, Vector2.RIGHT.rotated(PI + angle_shift), current_radius * 0.82, Color(1.0, 0.2, 0.16, 0.48), 0.18, 200.0, 14.0 + pulse_index * 3.0)
				"gunner":
					_spawn_radial_rays_effect(center, current_radius * 1.06, 8 + aftershock_level * 2 + pulse_index * 2, Color(1.0, 0.66, 0.34, 0.7), 4.0 + pulse_index, 0.2, pulse_index * 0.14)
				"mage":
					_spawn_frost_sigils_effect(center, current_radius * 0.76, Color(0.9, 0.98, 1.0, 0.84), 0.2)
					_spawn_vortex_effect(center, current_radius * 0.42, Color(0.72, 0.8, 1.0, 0.34), 0.2)
			var slow_multiplier := 1.0
			var slow_duration := 0.0
			if aftershock_level >= 2:
				slow_multiplier = 0.75
				slow_duration = 1.0
			var shock_hits := _damage_enemies_in_radius(center, current_radius, current_damage, 0.0, slow_multiplier, slow_duration)
			if shock_hits > 0:
				_register_attack_result(role_id, shock_hits, false)
		)
	tween.tween_callback(controller.queue_free)


func _trigger_theme_blood_reflux_counter(incoming_amount: float) -> void:
	PLAYER_THEME_SKILL_FLOW.trigger_blood_reflux_counter(self, incoming_amount)

func _play_player_hurt_feedback() -> void:
	_queue_camera_shake(6.0, 0.16)
	_pulse_player_visual(1.18, 0.16)
	_spawn_burst_effect(get_hurtbox_center(), 54.0, Color(1.0, 0.3, 0.3, 0.18), 0.16)

func _trigger_swordsman_counter() -> void:
	var special_data: Dictionary = _get_role_special_state("swordsman")
	var counter_level: int = int(special_data.get("counter_level", 0))
	if counter_level <= 0:
		return

	var radius: float = 62.0 + counter_level * 14.0
	var damage_amount: float = _get_role_damage("swordsman") * (0.38 + counter_level * 0.14)
	_spawn_combat_tag(global_position + Vector2(0.0, -24.0), "\u53CD\u51FB", Color(1.0, 0.84, 0.48, 1.0))
	_spawn_guard_effect(global_position, radius, Color(1.0, 0.84, 0.46, 0.22), 0.18)
	_spawn_burst_effect(global_position, radius, Color(1.0, 0.76, 0.38, 0.22), 0.16)
	var hits: int = _damage_enemies_in_radius(global_position, radius, damage_amount, 0.08 * counter_level, 1.0, 0.0)
	if hits > 0:
		_register_attack_result("swordsman", hits, false)
		_heal(1.2 + counter_level * 0.5)
		switch_invulnerability_remaining = max(switch_invulnerability_remaining, 0.05 + counter_level * 0.02)

func _count_enemies_in_radius(center: Vector2, radius: float) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if center.distance_to(enemy.global_position) <= radius:
			count += 1
	return count

func _record_card_pick(slot_id: String, option_id: String) -> void:
	PLAYER_BUILD_PROGRESS_FLOW.record_card_pick(self, slot_id, option_id)

func _apply_battle_card(option_id: String) -> bool:
	return PLAYER_CARD_APPLIER.apply_battle_card(self, option_id)

func _apply_combat_card(option_id: String) -> bool:
	return PLAYER_CARD_APPLIER.apply_combat_card(self, option_id)

func _apply_skill_card(option_id: String) -> bool:
	return PLAYER_CARD_APPLIER.apply_skill_card(self, option_id)

func apply_upgrade(option_id: String) -> void:
	PLAYER_UPGRADE_APPLIER.apply_upgrade(self, option_id)

func get_attribute_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_attribute_upgrade_options(self)

func get_all_upgrade_options() -> Array:
	return PLAYER_UPGRADE_OPTIONS.build_all_upgrade_options_for_developer_mode(
		_get_body_upgrade_pool(),
		_get_combat_upgrade_pool(),
		_get_skill_upgrade_pool(),
		_uses_blank_upgrade_fallback(),
		_get_fallback_upgrade_pool(),
		_make_endless_blank_upgrade_option()
	)

func _deprecated_get_developer_card_options_v1() -> Array:
	return []

func _deprecated_get_developer_card_options_v2() -> Array:
	return []


func get_small_boss_reward_options() -> Array:
	return PLAYER_LEVEL_FLOW.get_small_boss_reward_options(self)

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
	return
	var position_data = data.get("position", [0.0, 0.0])
	if position_data.size() >= 2:
		global_position = Vector2(float(position_data[0]), float(position_data[1]))

	var saved_active_role_index := int(data.get("active_role_index", active_role_index))
	level = int(data.get("level", level))
	experience = int(data.get("experience", experience))
	experience_to_next_level = max(1, int(data.get("experience_to_next_level", experience_to_next_level)))
	pending_level_ups = max(0, int(data.get("pending_level_ups", pending_level_ups)))
	max_health = float(data.get("max_health", max_health))
	max_mana = float(data.get("max_mana", max_mana))
	current_health = float(data.get("current_health", current_health))
	role_mana_values = _build_role_resource_state_data(0.0)
	role_ultimate_energy_lock_remaining = _build_role_resource_state_data(0.0)
	var saved_role_mana_values: Dictionary = data.get("role_mana_values", {})
	if saved_role_mana_values is Dictionary and not saved_role_mana_values.is_empty():
		ROLE_RESOURCE_STATE.apply_saved_mana(role_mana_values, saved_role_mana_values, max_mana)
	else:
		var fallback_role_id: String = str(roles[clamp(saved_active_role_index, 0, max(0, roles.size() - 1))].get("id", ""))
		if fallback_role_id != "":
			ROLE_RESOURCE_STATE.set_mana(role_mana_values, fallback_role_id, float(data.get("current_mana", current_mana)), max_mana)
	var saved_role_locks: Dictionary = data.get("role_ultimate_energy_lock_remaining", {})
	if saved_role_locks is Dictionary and not saved_role_locks.is_empty():
		ROLE_RESOURCE_STATE.apply_saved_locks(role_ultimate_energy_lock_remaining, saved_role_locks)
	else:
		var fallback_lock_role_id: String = str(roles[clamp(saved_active_role_index, 0, max(0, roles.size() - 1))].get("id", ""))
		if fallback_lock_role_id != "":
			ROLE_RESOURCE_STATE.set_lock_remaining(role_ultimate_energy_lock_remaining, fallback_lock_role_id, float(data.get("ultimate_energy_lock_remaining", 0.0)))
	hurt_cooldown_remaining = max(0.0, float(data.get("hurt_cooldown_remaining", 0.0)))
	switch_invulnerability_remaining = max(0.0, float(data.get("switch_invulnerability_remaining", 0.0)))
	level_up_delay_remaining = max(0.0, float(data.get("level_up_delay_remaining", 0.0)))
	switch_cooldown_remaining = max(0.0, float(data.get("switch_cooldown_remaining", 0.0)))
	enemy_move_slow_multiplier = float(data.get("enemy_move_slow_multiplier", 1.0))
	enemy_move_slow_remaining = max(0.0, float(data.get("enemy_move_slow_remaining", 0.0)))
	theme_blood_reflux_cooldown = max(0.0, float(data.get("theme_blood_reflux_cooldown", 0.0)))
	if swordsman_dangzhen_fan_ability == null:
		swordsman_dangzhen_fan_ability = DANGZHEN_SWORD_FAN_ABILITY.new()
	swordsman_dangzhen_fan_ability.cooldown_remaining = max(0.0, float(data.get("swordsman_dangzhen_slash_cooldown_remaining", 0.0)))
	if gunner_dangzhen_beam_ability == null:
		gunner_dangzhen_beam_ability = DANGZHEN_GUNNER_BEAM_ABILITY.new()
	gunner_dangzhen_beam_ability.cooldown_remaining = max(0.0, float(data.get("gunner_dangzhen_beam_cooldown_remaining", 0.0)))
	if gunner_infinite_reload_ability == null:
		gunner_infinite_reload_ability = GUNNER_INFINITE_RELOAD_ABILITY.new()
	gunner_infinite_reload_ability.apply_save_data({
		"cooldown_remaining": float(data.get("gunner_infinite_reload_cooldown_remaining", 0.0)),
		"active_remaining": float(data.get("gunner_infinite_reload_remaining", 0.0)),
		"tick_remaining": float(data.get("gunner_infinite_reload_tick_remaining", 0.0))
	})
	if mage_dangzhen_wave_ability == null:
		mage_dangzhen_wave_ability = MAGE_DANGZHEN_WAVE_ABILITY.new()
	mage_dangzhen_wave_ability.cooldown_remaining = max(0.0, float(data.get("mage_dangzhen_wave_cooldown_remaining", 0.0)))
	if mage_tidal_surge_ability == null:
		mage_tidal_surge_ability = MAGE_TIDAL_SURGE_ABILITY.new()
	mage_tidal_surge_ability.cooldown_remaining = max(0.0, float(data.get("mage_tidal_surge_cooldown_remaining", 0.0)))
	if swordsman_blade_storm_ability == null:
		swordsman_blade_storm_ability = SWORDSMAN_BLADE_STORM_ABILITY.new()
	swordsman_blade_storm_ability.apply_save_data({
		"cooldown_remaining": float(data.get("swordsman_blade_storm_cooldown_remaining", 0.0)),
		"active_remaining": float(data.get("swordsman_blade_storm_remaining", 0.0)),
		"tick_remaining": float(data.get("swordsman_blade_storm_tick_remaining", 0.0))
	})
	speed = float(data.get("speed", speed))
	pickup_radius = float(data.get("pickup_radius", pickup_radius))
	energy_gain_multiplier = float(data.get("energy_gain_multiplier", energy_gain_multiplier))
	global_damage_multiplier = float(data.get("global_damage_multiplier", global_damage_multiplier))
	background_interval_multiplier = float(data.get("background_interval_multiplier", background_interval_multiplier))
	ultimate_cost_multiplier = float(data.get("ultimate_cost_multiplier", ultimate_cost_multiplier))
	damage_taken_multiplier = float(data.get("damage_taken_multiplier", damage_taken_multiplier))
	role_switch_cooldown_bonus = float(data.get("role_switch_cooldown_bonus", role_switch_cooldown_bonus))
	switch_power_remaining = float(data.get("switch_power_remaining", 0.0))
	switch_power_role_id = str(data.get("switch_power_role_id", ""))
	switch_power_damage_multiplier = float(data.get("switch_power_damage_multiplier", 1.0))
	switch_power_interval_bonus = float(data.get("switch_power_interval_bonus", 0.0))
	switch_power_label = str(data.get("switch_power_label", ""))
	pending_entry_blessing_source_role_id = str(data.get("pending_entry_blessing_source_role_id", ""))
	entry_blessing_role_id = str(data.get("entry_blessing_role_id", ""))
	entry_blessing_label = str(data.get("entry_blessing_label", ""))
	entry_blessing_remaining = float(data.get("entry_blessing_remaining", 0.0))
	entry_lifesteal_ratio = float(data.get("entry_lifesteal_ratio", 0.0))
	entry_haste_interval_bonus = float(data.get("entry_haste_interval_bonus", 0.0))
	entry_haste_move_speed_multiplier = float(data.get("entry_haste_move_speed_multiplier", 1.0))
	relay_window_remaining = float(data.get("relay_window_remaining", 0.0))
	relay_ready_role_id = str(data.get("relay_ready_role_id", ""))
	relay_from_role_id = str(data.get("relay_from_role_id", ""))
	relay_label = str(data.get("relay_label", ""))
	relay_bonus_pending = bool(data.get("relay_bonus_pending", false))
	standby_entry_role_id = str(data.get("standby_entry_role_id", ""))
	standby_entry_label = "寰呮満钃勫娍"
	standby_entry_remaining = float(data.get("standby_entry_remaining", 0.0))
	standby_entry_damage_multiplier = float(data.get("standby_entry_damage_multiplier", 1.0))
	standby_entry_interval_bonus = float(data.get("standby_entry_interval_bonus", 0.0))
	guard_cover_remaining = float(data.get("guard_cover_remaining", 0.0))
	guard_cover_damage_multiplier = float(data.get("guard_cover_damage_multiplier", 1.0))
	team_combo_remaining = float(data.get("team_combo_remaining", 0.0))
	team_combo_damage_multiplier = float(data.get("team_combo_damage_multiplier", 1.0))
	team_combo_move_multiplier = float(data.get("team_combo_move_multiplier", 1.0))
	team_combo_background_multiplier = float(data.get("team_combo_background_multiplier", 1.0))
	borrow_fire_role_id = str(data.get("borrow_fire_role_id", ""))
	borrow_fire_remaining = float(data.get("borrow_fire_remaining", 0.0))
	borrow_fire_damage_multiplier = float(data.get("borrow_fire_damage_multiplier", 1.0))
	borrow_fire_interval_bonus = float(data.get("borrow_fire_interval_bonus", 0.0))
	borrow_fire_background_multiplier = float(data.get("borrow_fire_background_multiplier", 1.0))
	post_ultimate_flow_remaining = float(data.get("post_ultimate_flow_remaining", 0.0))
	post_ultimate_flow_background_multiplier = float(data.get("post_ultimate_flow_background_multiplier", 1.0))
	ultimate_guard_remaining = float(data.get("ultimate_guard_remaining", 0.0))
	ultimate_guard_damage_multiplier = float(data.get("ultimate_guard_damage_multiplier", 1.0))
	perpetual_motion_cooldown_remaining = float(data.get("perpetual_motion_cooldown_remaining", 0.0))
	frenzy_remaining = float(data.get("frenzy_remaining", 0.0))
	frenzy_stacks = int(data.get("frenzy_stacks", 0))
	frenzy_overkill_counter = int(data.get("frenzy_overkill_counter", 0))
	role_standby_elapsed = data.get("role_standby_elapsed", role_standby_elapsed).duplicate(true)
	role_cycle_marks = data.get("role_cycle_marks", role_cycle_marks).duplicate(true)
	role_share_initialized = bool(data.get("role_share_initialized", false))
	active_role_index = saved_active_role_index
	role_upgrade_levels = data.get("role_upgrade_levels", role_upgrade_levels).duplicate(true)
	background_cooldowns = data.get("background_cooldowns", background_cooldowns).duplicate(true)
	build_slot_levels = data.get("build_slot_levels", build_slot_levels).duplicate(true)
	var saved_card_pick_levels: Variant = data.get("card_pick_levels", card_pick_levels)
	if saved_card_pick_levels is Dictionary:
		card_pick_levels = BUILD_SYSTEM.normalize_dangzhen_card_levels(saved_card_pick_levels)
	var saved_special_reward_levels: Variant = data.get("special_reward_levels", special_reward_levels)
	if saved_special_reward_levels is Dictionary:
		special_reward_levels = BUILD_SYSTEM.normalize_dangzhen_reward_levels(saved_special_reward_levels)
	elite_relics_unlocked = data.get("elite_relics_unlocked", elite_relics_unlocked).duplicate(true)
	attribute_training_levels = _normalize_attribute_training_data(data.get("attribute_training_levels", attribute_training_levels))
	_sync_swordsman_trait_health_bonus()
	slot_resonances_unlocked = data.get("slot_resonances_unlocked", slot_resonances_unlocked).duplicate(true)
	role_special_states = data.get("role_special_states", role_special_states).duplicate(true)
	roles = _normalize_loaded_roles(data.get("roles", roles))
	story_equipped_styles = data.get("story_equipped_styles", story_equipped_styles).duplicate(true)
	if swordsman_blade_storm_ability != null:
		swordsman_blade_storm_ability.restore_effect_if_active(self)
	_initialize_existing_role_shares()
	level_up_active = false
	is_dead = false

	_update_active_role_state()
	fire_timer.start()

	experience_changed.emit(experience, experience_to_next_level, level)
	stats_changed.emit(get_stat_summary())
	health_changed.emit(current_health, max_health)
	_emit_active_mana_changed()

func resume_pending_level_ups() -> void:
	_try_request_level_up()

func _delay_level_up_requests(duration: float) -> void:
	if duration <= 0.0:
		return
	level_up_delay_remaining = max(level_up_delay_remaining, duration)

func _try_request_level_up() -> void:
	if is_dead or level_up_active or pending_level_ups <= 0 or level_up_delay_remaining > 0.0:
		return

	pending_level_ups -= 1
	level_up_active = true
	level_up_requested.emit(_build_upgrade_options())

func _build_upgrade_options() -> Array:
	return PLAYER_LEVEL_FLOW.build_upgrade_options(self)

func _get_body_upgrade_pool() -> Array:
	var active_role_id: String = str(_get_active_role().get("id", ""))
	return BUILD_SYSTEM.get_upgrade_pool("body", card_pick_levels, special_reward_levels, active_role_id)

func _get_combat_upgrade_pool() -> Array:
	var active_role_id: String = str(_get_active_role().get("id", ""))
	return BUILD_SYSTEM.get_upgrade_pool("combat", card_pick_levels, special_reward_levels, active_role_id)

func _get_skill_upgrade_pool() -> Array:
	var active_role_id: String = str(_get_active_role().get("id", ""))
	return BUILD_SYSTEM.get_upgrade_pool("skill", card_pick_levels, special_reward_levels, active_role_id)

func _get_fallback_upgrade_pool() -> Array:
	return [
		PLAYER_UPGRADE_OPTIONS.make_upgrade_option("body", _get_upgrade_slot_label("body"), "fallback_body_reforge", "体魄重铸", "所有角色伤害与生存能力小幅提升。"),
		PLAYER_UPGRADE_OPTIONS.make_upgrade_option("combat", _get_upgrade_slot_label("combat"), "fallback_combat_reforge", "轮换重铸", "切人冷却与后台攻击节奏小幅优化。"),
		PLAYER_UPGRADE_OPTIONS.make_upgrade_option("skill", _get_upgrade_slot_label("skill"), "fallback_skill_reforge", "技能重铸", "大招能量获取与技能强度小幅提升。")
	]

func _make_endless_blank_upgrade_option() -> Dictionary:
	return PLAYER_UPGRADE_OPTIONS.make_endless_blank_upgrade_option(_get_upgrade_slot_label("body"))

func _record_build_pick(slot_id: String) -> void:
	PLAYER_BUILD_PROGRESS_FLOW.record_build_pick(self, slot_id)

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
	_spawn_slash_effect(center, direction.rotated(0.78), length, width, color, duration)
	_spawn_slash_effect(center, direction.rotated(-0.78), length, width, color, duration)

func _spawn_thrust_effect(start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float, show_arrow: bool = true) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_thrust_effect(self, start_position, end_position, color, width, duration, show_arrow)

func _spawn_guard_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_guard_effect(self, center, radius, color, duration, _build_circle_polygon(radius))

func _spawn_combat_tag(position: Vector2, text: String, color: Color) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_combat_tag(self, position, text, color, SHOW_GAMEPLAY_TEXT_HINTS)

func _spawn_ring_effect(center: Vector2, radius: float, color: Color, width: float, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_ring_effect(self, center, radius, color, width, duration, _build_circle_polygon(radius))

func _spawn_mage_bombardment_warning_effect(center: Vector2, radius: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_mage_bombardment_warning_effect(self, center, radius, _build_circle_polygon(radius * 0.82))

func _spawn_mage_bombardment_fall_effect(center: Vector2, radius: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_mage_bombardment_fall_effect(self, center, radius, _build_circle_polygon(radius * 0.28))

func _spawn_pulsing_field(center: Vector2, radius: float, color: Color, pulse_count: int, interval: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var controller := Node2D.new()
	controller.global_position = center
	current_scene.add_child(controller)

	var tween := controller.create_tween()
	for pulse_index in range(max(1, pulse_count)):
		if pulse_index > 0:
			tween.tween_interval(interval)
		tween.tween_callback(Callable(self, "_trigger_field_pulse").bind(center, radius, color, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration))
	tween.tween_callback(controller.queue_free)

func _trigger_field_pulse(center: Vector2, radius: float, color: Color, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float) -> void:
	_spawn_ring_effect(center, radius, Color(color.r, color.g, color.b, min(0.9, color.a + 0.35)), 6.0, 0.18)
	_spawn_burst_effect(center, radius, color, 0.18)
	if slow_duration > 0.0:
		_spawn_frost_sigils_effect(center, max(18.0, radius * 0.58), Color(0.84, 0.98, 1.0, 0.72), 0.18)
	_damage_enemies_in_radius(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration)

func _spawn_burst_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_burst_effect(self, center, color, duration, _build_circle_polygon(radius))

func _spawn_frost_sigils_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_frost_sigils_effect(self, center, radius, color, duration)

func _spawn_vortex_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_owner_vortex_effect(self, center, radius, color, duration)

func _spawn_target_lock_effect(center: Vector2, radius: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_PRIMITIVES.spawn_target_lock_effect(self, center, radius, color, duration, _build_circle_polygon(radius))

func _build_circle_polygon(radius: float) -> PackedVector2Array:
	return PLAYER_MATH.build_circle_polygon(radius)

func _build_arc_points(radius: float, arc_degrees: float) -> PackedVector2Array:
	return PLAYER_MATH.build_arc_points(radius, arc_degrees)

func _build_arc_band_polygon(outer_radius: float, inner_radius: float, arc_degrees: float) -> PackedVector2Array:
	return PLAYER_MATH.build_arc_band_polygon(outer_radius, inner_radius, arc_degrees)

func _die() -> void:
	PLAYER_RESOURCE_FLOW.die(self)
