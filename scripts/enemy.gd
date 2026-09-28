extends Node2D

@warning_ignore("unused_signal")
signal defeated(enemy_kind: String)

const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")
const ENEMY_BOSS_VISUALS := preload("res://scripts/enemies/enemy_boss_visuals.gd")
const ENEMY_DAMAGE := preload("res://scripts/enemies/enemy_damage.gd")
const ENEMY_DROPS := preload("res://scripts/enemies/enemy_drops.gd")
const ENEMY_HIT_FEEDBACK := preload("res://scripts/enemies/enemy_hit_feedback.gd")
const ENEMY_MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")
const ENEMY_PROFILE_APPLIER := preload("res://scripts/enemies/enemy_profile_applier.gd")
const ENEMY_PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
const ENEMY_RUNTIME_STATE := preload("res://scripts/enemies/enemy_runtime_state.gd")
const ENEMY_SAVE_DATA := preload("res://scripts/enemies/enemy_save_data.gd")
const ENEMY_STATUS_EFFECTS := preload("res://scripts/enemies/enemy_status_effects.gd")
const ENEMY_STATUS_VISUALS := preload("res://scripts/enemies/enemy_status_visuals.gd")
const ENEMY_SPATIAL_GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")
const ENEMY_BODY_SEPARATION := preload("res://scripts/enemies/enemy_body_separation.gd")
const ENEMY_MOTION_THROTTLE := preload("res://scripts/enemies/enemy_motion_throttle.gd")
const ENEMY_POOL_LIFECYCLE := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")
const ENEMY_STATUS_VISUAL_THROTTLE := preload("res://scripts/enemies/enemy_status_visual_throttle.gd")
const ENEMY_BATCH_ELIGIBILITY := preload("res://scripts/enemies/enemy_batch_eligibility.gd")
const ENEMY_TRAIT_FLAGS := preload("res://scripts/enemies/enemy_trait_flags.gd")
const ENEMY_TRAIT_BEHAVIOR := preload("res://scripts/enemies/enemy_trait_behavior.gd")
const ENEMY_TURRET_BOMBARD := preload("res://scripts/enemies/enemy_turret_bombard.gd")
const ENEMY_RUNTIME_PROCESS := preload("res://scripts/enemies/enemy_runtime_process.gd")
const ENEMY_VISUALS := preload("res://scripts/enemies/enemy_visuals.gd")
const ENEMY_OCCLUSION_SORT := preload("res://scripts/enemies/enemy_occlusion_sort.gd")
const ENEMY_GLUTTON_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_behavior.gd")
const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")
const ENEMY_ROSE_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_rose_behavior.gd")
const ENEMY_SKULLTOMB_BEHAVIOR := preload("res://scripts/enemies/enemy_skulltomb_behavior.gd")

@export var speed: float = 80.0
@export var max_health: float = 20.0
@export var damage_reduction_value: float = 0.0
@export var armor: float = 0.0
@export var attack: float = 10.0
@export var damage_reduction_rate: float = 0.0
var stalwart_body_cooldown: float = 0.0
var basic_shot_timer: float = 0.0
var heavy_armor_remaining: float = 0.0
var heavy_armor_cooldown: float = 20.0
var runner_haste_remaining: float = 0.0
var runner_haste_cooldown: float = 0.0
const ENEMY_STALWART_BODY := preload("res://scripts/enemies/enemy_stalwart_body.gd")
@export var touch_damage: float = 10.0
@export var contact_radius: float = 36.0:
	set(value):
		contact_radius = value
		body_collision_radius_dirty = true
		ENEMY_SPATIAL_GRID.invalidate_body_bounds()
@export var body_collision_radius: float = -1.0:
	set(value):
		body_collision_radius = value
		body_collision_radius_dirty = true
		ENEMY_SPATIAL_GRID.invalidate_body_bounds()
@export var experience_reward: int = 10
@export var reward_tier: int = 1
@export var exp_gem_scene: PackedScene = preload("res://scenes/exp_gem.tscn")
@export var heart_pickup_scene: PackedScene = preload("res://scenes/heart_pickup.tscn")
@export var projectile_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")

var target: Node2D
var current_health: float
var slow_multiplier: float = 1.0
var slow_timer: float = 0.0
var vulnerability_bonus: float = 0.0
var fury_armor_shred: float = 0.0
var fury_armor_shred_remaining: float = 0.0
var vulnerability_timer: float = 0.0
var bleed_damage_per_second: float = 0.0
var bleed_timer: float = 0.0
var enemy_kind: String = "normal"
var archetype_id: String = "chaser"
var behavior_id: String = "chaser"
var secondary_behavior_id: String = ""
var profile_visual_scene: PackedScene
var base_scale: Vector2 = Vector2.ONE
var status_visual_time: float = 0.0
var status_root: Node2D
var slow_ring: Line2D
var vulnerability_ring: Line2D
var trait_ring: Line2D
var dash_warning_ring: Line2D
var dash_warning_rect: Polygon2D
var touch_damage_ring: Line2D
var display_color: Color = Color(0.34, 0.8, 1.0, 1.0)

var preferred_distance: float = 220.0
var shot_interval: float = 1.8
var shot_timer: float = 0.0
var projectile_speed: float = 240.0
var projectile_damage: float = 8.0
var projectile_lifetime: float = 4.0
var projectile_spread: float = 0.0
var projectile_count: int = 1
var projectile_color: Color = Color(-1.0, -1.0, -1.0, -1.0)
var projectile_visual_style: String = ""

var acceleration_interval: float = 0.0
var acceleration_boost: float = 1.8
var acceleration_duration: float = 0.0
var acceleration_timer: float = 0.0
var acceleration_remaining: float = 0.0

var dash_interval: float = 0.0
var dash_duration: float = 0.0
var dash_speed_multiplier: float = 2.4
var dash_windup_duration: float = 0.42
var dash_timer: float = 0.0
var dash_windup_remaining: float = 0.0
var dash_remaining: float = 0.0
var dash_distance_remaining: float = 0.0
var elite_charge_haste_remaining: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

var strafe_sign: float = 1.0
var projectile_split_count: int = 0
var projectile_split_after: float = 0.0
var projectile_split_spread: float = 1.2
var projectile_split_pattern: String = "fan"
var projectile_split_speed_scale: float = 0.88
var projectile_split_damage_scale: float = 0.72
var projectile_split_lifetime_scale: float = 0.72
var projectile_split_size_scale: float = 0.75
var projectile_split_hit_radius_scale: float = 0.8

var glutton_absorb_radius: float = 0.0
var glutton_speed_gain_per_gem: float = 0.0
var glutton_scale_gain_per_gem: float = 0.0
var glutton_max_bonus_speed: float = 0.0
var glutton_bonus_speed: float = 0.0
var glutton_aura_radius: float = 0.0
var glutton_aura_damage: float = 0.0
var glutton_heart_heal_scale: float = 1.0
var drop_absorber: Node = null
var glutton_aura_hits_by_enemy_id: Dictionary = {}
var glutton_skill_think_timer: float = 0.0
var glutton_skill_state: String = ""
var glutton_skill_state_remaining: float = 0.0
var glutton_skill_action: String = ""
var glutton_skill_action_remaining: float = 0.0
var glutton_skill_warning_shapes: Array = []
var glutton_warning_nodes: Array = []
var glutton_cast_lock_active: bool = false
var glutton_cast_lock_position: Vector2 = Vector2.ZERO
var glutton_recent_skill: String = ""
var glutton_war_stomp_remaining: float = 0.0
var glutton_war_stomp_cast_lock_remaining: float = 0.0
var glutton_war_stomp_cooldown_remaining: float = 0.0
var glutton_war_stomp_cast_shake_elapsed: float = 0.0
var glutton_war_stomp_tick_elapsed: float = 0.0
var glutton_war_stomp_hit_registry: Dictionary = {}
var glutton_active_wood_spike_hitboxes: Array = []
var glutton_active_twine_hitboxes: Array = []
var glutton_growth_carry: float = 0.0
var glutton_entangle_damage_remaining: float = 0.0
var glutton_entangle_damage_elapsed: float = 0.0
var rebirth_lives_remaining: int = 0
var rebirth_delay: float = 2.0
var rebirth_timer: float = 0.0
var rebirth_slow_multiplier: float = 0.5
var rebirth_slow_duration: float = 6.0
var skulltomb_summon_interval: float = 20.0
var skulltomb_summon_timer: float = 0.0
var skulltomb_summon_windup: float = 0.7
var skulltomb_summon_windup_remaining: float = 0.0
var skulltomb_aging_aura_radius: float = 750.0
var skulltomb_aging_aura_current_health_drain_ratio: float = 0.12
var skulltomb_aging_aura_max_health_damage_ratio: float = 0.005
var skulltomb_min_soldiers: int = 10
var skulltomb_buff_duration: float = 5.0
var skulltomb_death_player_slow_multiplier: float = 0.25
var skulltomb_death_player_slow_duration: float = 5.0
var skulltomb_death_soldier_speed_multiplier: float = 1.2
var skulltomb_death_shot_frequency_multiplier: float = 1.3
var skulltomb_tomb_scene: PackedScene
var skulltomb_tomb_instance: Node2D
var skulltomb_channel_ring: Line2D
var skulltomb_channel_fill: Polygon2D
var skulltomb_death_ring: Line2D
var skulltomb_area_instance: Node2D
var skulltomb_area_remaining: float = 0.0
var skulltomb_area_damage_elapsed: float = 0.0
var skulltomb_aging_aura_elapsed: float = 0.0
var skulltomb_area_center: Vector2 = Vector2.ZERO
var skulltomb_summon_target_center: Vector2 = Vector2.ZERO
var skulltomb_area_radius: float = 0.0
var skulltomb_pending_spawns: Array = []
var skulltomb_spawn_elapsed: float = 0.0
var skulltomb_spawn_vertex_index: int = 0
var skulltomb_charge_interval: float = 9.0
var skulltomb_charge_timer: float = 0.0
var skulltomb_charge_decision_timer: float = 0.0
var skulltomb_charge_active: bool = false
var skulltomb_charge_windup_duration: float = 2.0
var skulltomb_charge_windup_remaining: float = 0.0
var skulltomb_charge_distance: float = 0.0
var skulltomb_charge_speed_multiplier: float = 2.0
var skulltomb_charge_push_distance: float = 116.0
var skulltomb_charge_target_position: Vector2 = Vector2.ZERO
var skull_soldier_speed_multiplier: float = 1.0
var skull_soldier_speed_timer: float = 0.0
var skull_damage_immune_timer: float = 0.0
var skullshot_attack_frequency_multiplier: float = 1.0
var skullshot_attack_frequency_timer: float = 0.0
var turret_bombard_interval: float = 0.0
var turret_bombard_timer: float = 0.0
var turret_bombard_radius: float = 96.0
var turret_bombard_projectiles: int = 8
var rose_split_timer: float = 15.0

var boss_radial_interval: float = 0.95
var boss_radial_timer: float = 0.0
var boss_radial_bullets: int = 12
var boss_sine_interval: float = 3.2
var boss_sine_cooldown: float = 0.0
var boss_sine_stream_duration: float = 1.6
var boss_sine_stream_remaining: float = 0.0
var boss_sine_stream_rate: float = 0.14
var boss_sine_stream_timer: float = 0.0
var boss_danmaku_pattern: int = -1
var boss_danmaku_wave: int = 6
var boss_danmaku_count: int = 0
var boss_danmaku_rotation: float = 0.0
var boss_danmaku_spin: float = 1.0
var boss_routine: Dictionary = {}
var boss_aimed_shots_remaining: int = 0
var boss_aimed_shot_timer: float = 0.0
var boss_turning_interval: float = 4.0
var boss_turning_timer: float = 0.0
var boss_turning_bullets: int = 8
var boss_turning_sign: float = 1.0

# Performance: cached trait booleans (updated via _sync_trait_flags)
var _is_shooter: bool = false
var _is_dasher: bool = false
var _is_accelerator: bool = false
var _is_turret: bool = false
var _is_glutton: bool = false
var _is_swarm: bool = false
var _is_boss: bool = false
var _is_rebirth: bool = false
# P1: cached per-frame target vectors
var _cached_to_target: Vector2 = Vector2.ZERO
var _cached_distance_to_target: float = 0.0
var _cached_direction_to_target: Vector2 = Vector2.RIGHT
var boss_orbit_sign: float = 1.0
var boss_pattern_rotation: float = 0.0
var boss_display_name: String = "被污染的魔法石"
var boss_shield_max_health: float = 0.0
var boss_battle_elapsed: float = 0.0
var boss_phase: int = 1
var boss_phase_three_elapsed: float = 0.0
var boss_phase_three_intro_remaining: float = 0.0
var boss_phase_transition_target: int = 0
var boss_shield_break_intro_played: bool = false
var boss_shield_break_visual_intro_active: bool = false
var boss_split_interval: float = 5.8
var boss_split_timer: float = 0.0
var boss_laser_interval: float = 8.5
var boss_laser_timer: float = 0.0
var boss_laser_duration: float = 5.0
var boss_laser_remaining: float = 0.0
var boss_laser_rotation: float = 0.0
var boss_laser_spin_duration: float = 1.75
var boss_laser_start_rotation: float = 0.0
var boss_laser_final_rotation: float = 0.0
var boss_laser_hit_timer: float = 0.0
var boss_orbit_bomb_interval: float = 10.0
var boss_orbit_bomb_timer: float = 0.0
var boss_orbit_bomb_remaining: float = 0.0
var boss_orbit_bomb_angle: float = 0.0
var boss_orbit_bomb_shot_timer: float = 0.0
var boss_orbit_pull_remaining: float = 0.0
var boss_peacock_interval: float = 9.0
var boss_peacock_timer: float = 0.0
var boss_peacock_charge_remaining: float = 0.0
var boss_attack_pressure_scale: float = 1.0
var glutton_absorb_elapsed: float = 0.0
var boss_helper_root: Node2D
var boss_laser_lines: Array[Line2D] = []
var boss_laser_core_lines: Array[Line2D] = []
var boss_orbit_ball: Node2D
var boss_peacock_markers: Array[Polygon2D] = []
var boss_phase_charge_rings: Array[Line2D] = []
var boss_visual_instance: Node2D
var profile_initialized: bool = false
var hit_flash_remaining: float = 0.0
var separation_push: Vector2 = Vector2.ZERO
var cached_separation_velocity: Vector2 = Vector2.ZERO
var separation_refresh_frame: int = -1
var body_collision_reference_scale: float = 1.0:
	set(value):
		body_collision_reference_scale = value
		body_collision_radius_dirty = true
		ENEMY_SPATIAL_GRID.invalidate_body_bounds()
var body_collision_radius_dirty: bool = true
var cached_body_collision_scale := Vector2(INF, INF)
var cached_body_collision_radius: float = 0.0
var status_visual_refresh_frame: int = -1
var throttled_motion_delta: float = 0.0
var motion_refresh_frame: int = -1
var cached_motion_visual: Node
var cached_motion_visual_moving: bool = false
var cached_motion_visual_facing_sign: int = 0
var pooled_inactive: bool = false
# Explicit velocity (was inherited from CharacterBody2D)
var velocity: Vector2 = Vector2.ZERO
var batch_simulation_enabled: bool = false

func _init() -> void:
	set_notify_local_transform(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE:
		body_collision_radius_dirty = true
		ENEMY_SPATIAL_GRID.invalidate_body_bounds()
	elif what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED:
		var current_scale: Vector2 = scale
		if current_scale != cached_body_collision_scale:
			cached_body_collision_scale = current_scale
			body_collision_radius_dirty = true
			ENEMY_SPATIAL_GRID.invalidate_body_bounds()

func _ready() -> void:
	ENEMY_RUNTIME_PROCESS.ready(self)

func get_body_collision_radius() -> float:
	# Transform notifications run in-tree; detached profile/preview nodes use a check.
	if not is_inside_tree() and scale != cached_body_collision_scale:
		body_collision_radius_dirty = true
	if body_collision_radius_dirty:
		cached_body_collision_scale = scale
		cached_body_collision_radius = ENEMY_BODY_SEPARATION.calculate_body_collision_radius(maxf(absf(cached_body_collision_scale.x), absf(cached_body_collision_scale.y)), body_collision_reference_scale, body_collision_radius, contact_radius)
		body_collision_radius_dirty = false
	return cached_body_collision_radius

func _exit_tree() -> void:
	clear_runtime_effects_after_defeat()
	ENEMY_RUNTIME_PROCESS.exit_tree(self)

func _physics_process(delta: float) -> void:
	if batch_simulation_enabled and can_use_batch_simulation():
		return
	ENEMY_RUNTIME_PROCESS.physics_process(self, delta)

func batch_physics_process(delta: float) -> void:
	ENEMY_RUNTIME_PROCESS.physics_process(self, delta)

func can_use_batch_simulation() -> bool:
	return ENEMY_BATCH_ELIGIBILITY.can_batch(self)

func get_batch_ineligibility_reason() -> String:
	return ENEMY_BATCH_ELIGIBILITY.get_ineligibility_reason(self)

func apply_enemy_profile(kind: String, profile: Dictionary) -> void:
	pooled_inactive = false
	ENEMY_PROFILE_APPLIER.apply_profile(self, kind, profile)
	_sync_trait_flags()
	_reset_runtime_state(true)
	_apply_visuals(display_color)
	if enemy_kind == "boss":
		_ensure_boss_visual()
		_ensure_boss_helpers()

func _reset_runtime_state(randomize_timers: bool) -> void:
	ENEMY_RUNTIME_STATE.reset(self, randomize_timers)

func get_boss_ui_payload() -> Dictionary:
	var boss_bar_max_health: float = max_health
	var shield_max_health: float = 0.0
	if enemy_kind == "boss":
		boss_bar_max_health = ENEMY_BOSS_STATE.get_phase_bar_max_health(self)
		shield_max_health = ENEMY_BOSS_STATE.get_boss_shield_max_health(self)
	var shield_health: float = clamp(current_health - boss_bar_max_health, 0.0, shield_max_health)
	var payload: Dictionary = {
		"name": boss_display_name,
		"enemy_kind": enemy_kind,
		"current_health": current_health,
		"max_health": boss_bar_max_health,
		"shield_health": shield_health,
		"shield_max_health": shield_max_health,
		"phase": boss_phase,
		"hide_health": enemy_kind == "boss" and boss_phase_transition_target > 0
	}
	if archetype_id == "boss_spellcore":
		payload["status"] = ENEMY_BOSS_STATE.ROUTINE.get_status(self)
	elif behavior_id == "glutton" and ENEMY_GLUTTON_SKILL_BEHAVIOR.is_war_stomp_active(self):
		payload["status"] = {
			"label": "战争践踏",
			"remaining": float(glutton_war_stomp_remaining),
			"duration": ENEMY_GLUTTON_SKILL_BEHAVIOR.get_war_stomp_duration()
		}
	elif behavior_id == "skulltomb" and float(skulltomb_area_remaining) > 0.0:
		payload["status"] = {
			"label": "死亡领域",
			"remaining": float(skulltomb_area_remaining),
			"duration": ENEMY_SKULLTOMB_BEHAVIOR.SUMMON_AREA_DURATION
		}
	return payload

func _ensure_boss_helpers() -> void:
	ENEMY_BOSS_VISUALS.ensure_boss_helpers(self)

func _ensure_boss_orbit_ball() -> void:
	ENEMY_BOSS_VISUALS.ensure_boss_orbit_ball(self)

func _clear_boss_orbit_ball() -> void:
	ENEMY_BOSS_VISUALS.clear_boss_orbit_ball(self)

func _ensure_boss_peacock_markers(count: int) -> void:
	ENEMY_BOSS_VISUALS.ensure_boss_peacock_markers(self, count)

func _clear_boss_peacock_markers() -> void:
	ENEMY_BOSS_VISUALS.clear_boss_peacock_markers(self)

func clear_runtime_effects_after_defeat() -> void:
	if enemy_kind == "boss":
		_clear_boss_runtime_effects()
	elif behavior_id == "rose":
		ENEMY_ROSE_SKILL_BEHAVIOR.clear_runtime_effects_after_defeat(self)
	elif behavior_id == "skulltomb":
		ENEMY_SKULLTOMB_BEHAVIOR.clear_runtime_effects_after_defeat(self)

func _clear_boss_runtime_effects() -> void:
	boss_routine.clear()
	boss_danmaku_wave = 6
	boss_aimed_shots_remaining = 0
	boss_laser_remaining = 0.0
	boss_laser_hit_timer = 0.0
	boss_orbit_bomb_remaining = 0.0
	boss_orbit_pull_remaining = 0.0
	boss_peacock_charge_remaining = 0.0
	boss_phase_three_intro_remaining = 0.0
	boss_phase_transition_target = 0
	boss_shield_break_visual_intro_active = false

	for laser in boss_laser_lines:
		if laser != null and is_instance_valid(laser):
			laser.visible = false
	for laser_core in boss_laser_core_lines:
		if laser_core != null and is_instance_valid(laser_core):
			laser_core.visible = false

	_clear_boss_orbit_ball()
	_clear_boss_peacock_markers()
	ENEMY_BOSS_VISUALS.clear_boss_phase_three_charge_visuals(self)
	ENEMY_PROJECTILES.clear_projectiles_from_source(self)
	if target != null and is_instance_valid(target) and target.has_method("_sync_orbit_pull_status"):
		target._sync_orbit_pull_status(0.0, global_position)

func _compute_velocity(delta: float) -> Vector2:
	return ENEMY_MOVEMENT.compute_velocity(self, delta)

func _apply_direct_motion(delta: float) -> void:
	if preload("res://scripts/enemies/enemy_dasher_charge.gd").is_active(self):
		preload("res://scripts/enemies/enemy_dasher_charge.gd").move(self, delta)
		return
	if velocity.length_squared() <= 0.001:
		return
	global_position += velocity * delta

func _should_skip_motion_frame(delta: float) -> bool:
	return ENEMY_MOTION_THROTTLE.should_skip_motion_frame(self, delta)

func _get_motion_refresh_interval() -> int:
	return ENEMY_MOTION_THROTTLE.get_motion_refresh_interval(self)

func _is_scene_under_enemy_pressure() -> bool:
	return ENEMY_MOTION_THROTTLE.is_scene_under_enemy_pressure(self)

func _should_update_status_visual_frame() -> bool:
	return ENEMY_STATUS_VISUAL_THROTTLE.should_update_status_visual_frame(self)

func _get_status_visual_refresh_interval() -> int:
	return ENEMY_STATUS_VISUAL_THROTTLE.get_status_visual_refresh_interval(self)

func _update_behavior_state(delta: float) -> void:
	ENEMY_TRAIT_BEHAVIOR.update_behavior_state(self, delta)

func _update_boss_trait(delta: float) -> void:
	ENEMY_BOSS_STATE.update_boss_trait(self, delta)

func has_trait(trait_id: String) -> bool:
	return ENEMY_TRAIT_FLAGS.has_trait(self, trait_id)

func _sync_trait_flags() -> void:
	ENEMY_TRAIT_FLAGS.sync_trait_flags(self)

func _spawn_projectile(origin: Vector2, shot_direction: Vector2, shot_speed: float, shot_damage: float, shot_lifetime: float, color: Color, mode: String, extra_config: Dictionary = {}) -> Node:
	return ENEMY_PROJECTILES.spawn_projectile(self, origin, shot_direction, shot_speed, shot_damage, shot_lifetime, color, mode, extra_config)

func _apply_visuals(color_override = null) -> void:
	ENEMY_VISUALS.apply_visuals(self, color_override)

func _update_motion_visual() -> void:
	ENEMY_VISUALS.update_motion_visual(self)

func _ensure_boss_visual() -> void:
	ENEMY_BOSS_VISUALS.ensure_boss_visual(self)

func _update_status_timers(delta: float) -> void:
	ENEMY_STATUS_EFFECTS.tick_timers(self, delta)

func _update_bleed(delta: float) -> void:
	ENEMY_STATUS_EFFECTS.tick_bleed(self, delta)

func take_damage(amount: float, is_critical: bool = false) -> bool:
	return ENEMY_DAMAGE.take_damage(self, amount, is_critical)

func try_stalwart_body_damage() -> float:
	return ENEMY_STALWART_BODY.try_trigger(self)

func take_batched_damage(amount: float, is_critical: bool = false) -> bool:
	return ENEMY_DAMAGE.apply_damage(self, amount, false, is_critical)

func activate_pooled_enemy() -> void:
	batch_simulation_enabled = false
	ENEMY_POOL_LIFECYCLE.activate_pooled_enemy(self)

func release_after_defeat() -> bool:
	return ENEMY_POOL_LIFECYCLE.release_after_defeat(self)

func _prepare_for_pool() -> void:
	batch_simulation_enabled = false
	ENEMY_POOL_LIFECYCLE.prepare_for_pool(self)

func apply_slow(multiplier: float, duration: float) -> void:
	ENEMY_STATUS_EFFECTS.apply_slow(self, multiplier, duration)

func apply_slow_silent(multiplier: float, duration: float) -> void:
	ENEMY_STATUS_EFFECTS.apply_slow_without_status_visuals(self, multiplier, duration)

func apply_vulnerability(bonus: float, duration: float) -> void:
	ENEMY_STATUS_EFFECTS.apply_vulnerability(self, bonus, duration)

func apply_fury_armor_shred(amount: float, duration: float) -> void:
	if amount <= 0.0 or duration <= 0.0:
		return
	fury_armor_shred = maxf(fury_armor_shred, amount)
	fury_armor_shred_remaining = duration
	_spawn_status_burst(Color(1.0, 0.4, 0.2, 0.5), 22.0)

func apply_bleed(damage_per_second: float, duration: float) -> void:
	ENEMY_STATUS_EFFECTS.apply_bleed(self, damage_per_second, duration)

func _ensure_status_visuals() -> void:
	ENEMY_STATUS_VISUALS.ensure_status_visuals(self)

func _update_status_visuals() -> void:
	ENEMY_STATUS_VISUALS.update_status_visuals(self)

func _has_status_visual_pressure() -> bool:
	return ENEMY_STATUS_VISUAL_THROTTLE.has_status_visual_pressure(self)

func _has_timed_behavior_traits() -> bool:
	return ENEMY_TRAIT_FLAGS.has_timed_behavior_traits(self)

func _spawn_status_burst(color: Color, radius: float) -> void:
	ENEMY_STATUS_VISUALS.spawn_status_burst(self, color, radius)

func _spawn_dash_trail(direction_vector: Vector2, length: float) -> void:
	ENEMY_STATUS_VISUALS.spawn_dash_trail(self, direction_vector, length)

func _drop_experience_gem() -> void:
	ENEMY_DROPS.drop_experience_gem(self)

func _maybe_drop_heart() -> void:
	ENEMY_DROPS.maybe_drop_heart(self)

func _maybe_drop_bones() -> void:
	ENEMY_DROPS.maybe_drop_bones(self)

func absorb_exp_gem(gem) -> int:
	return ENEMY_GLUTTON_BEHAVIOR.absorb_exp_gem(self, gem)

func absorb_heart(heart) -> float:
	return ENEMY_GLUTTON_BEHAVIOR.absorb_heart(self, heart)

func get_glutton_player_touch_radius() -> float:
	return ENEMY_GLUTTON_BEHAVIOR.get_player_touch_radius(self)

func get_glutton_player_touch_shape() -> Dictionary:
	return ENEMY_GLUTTON_BEHAVIOR.get_player_touch_shape(self)

func get_glutton_passive_player_touch_shape() -> Dictionary:
	return ENEMY_GLUTTON_BEHAVIOR.get_passive_player_touch_shape(self)

func get_save_data() -> Dictionary:
	return ENEMY_SAVE_DATA.get_save_data(self)

func apply_save_data(data: Dictionary, target_node: Node2D) -> void:
	ENEMY_SAVE_DATA.apply_save_data(self, data, target_node)

func _play_hit_feedback(damage_amount: float, killed: bool, is_critical: bool = false) -> void:
	ENEMY_HIT_FEEDBACK.play_hit_feedback(self, damage_amount, killed, is_critical)

func _play_light_hit_feedback() -> void:
	ENEMY_HIT_FEEDBACK.play_light_hit_feedback(self)

func _get_hit_flash_alpha() -> float:
	return ENEMY_HIT_FEEDBACK.get_hit_flash_alpha(hit_flash_remaining)

func _apply_hit_flash_alpha_to_node(node: Node, alpha: float) -> void:
	ENEMY_HIT_FEEDBACK.apply_hit_flash_alpha_to_node(node, alpha)

func _register_runtime_enemy() -> void:
	ENEMY_POOL_LIFECYCLE.register_runtime_enemy(self)

func _unregister_runtime_enemy() -> void:
	ENEMY_POOL_LIFECYCLE.unregister_runtime_enemy(self)
