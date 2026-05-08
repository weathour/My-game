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
const ENEMY_TRAIT_BEHAVIOR := preload("res://scripts/enemies/enemy_trait_behavior.gd")
const ENEMY_VISUALS := preload("res://scripts/enemies/enemy_visuals.gd")

@export var speed: float = 80.0
@export var max_health: float = 20.0
@export var touch_damage: float = 10.0
@export var contact_radius: float = 36.0
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
var vulnerability_timer: float = 0.0
var bleed_damage_per_second: float = 0.0
var bleed_timer: float = 0.0
var enemy_kind: String = "normal"
var archetype_id: String = "chaser"
var behavior_id: String = "chaser"
var secondary_behavior_id: String = ""
var base_scale: Vector2 = Vector2.ONE
var status_visual_time: float = 0.0
var status_root: Node2D
var slow_ring: Line2D
var vulnerability_ring: Line2D
var trait_ring: Line2D
var dash_warning_ring: Line2D
var dash_warning_rect: Polygon2D
var display_color: Color = Color(0.34, 0.8, 1.0, 1.0)

var preferred_distance: float = 220.0
var shot_interval: float = 1.8
var shot_timer: float = 0.0
var projectile_speed: float = 240.0
var projectile_damage: float = 8.0
var projectile_lifetime: float = 4.0
var projectile_spread: float = 0.0
var projectile_count: int = 1

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
var dash_direction: Vector2 = Vector2.RIGHT

var strafe_sign: float = 1.0
var projectile_split_count: int = 0
var projectile_split_after: float = 0.0
var projectile_split_spread: float = 1.2

var glutton_absorb_radius: float = 0.0
var glutton_speed_gain_per_gem: float = 0.0
var glutton_scale_gain_per_gem: float = 0.0
var glutton_max_bonus_speed: float = 0.0
var glutton_bonus_speed: float = 0.0
var rebirth_lives_remaining: int = 0
var rebirth_delay: float = 2.0
var rebirth_timer: float = 0.0
var rebirth_slow_multiplier: float = 0.5
var rebirth_slow_duration: float = 6.0
var turret_bombard_interval: float = 0.0
var turret_bombard_timer: float = 0.0
var turret_bombard_radius: float = 96.0
var turret_bombard_projectiles: int = 8

var boss_radial_interval: float = 0.95
var boss_radial_timer: float = 0.0
var boss_radial_bullets: int = 12
var boss_sine_interval: float = 3.2
var boss_sine_cooldown: float = 0.0
var boss_sine_stream_duration: float = 1.6
var boss_sine_stream_remaining: float = 0.0
var boss_sine_stream_rate: float = 0.14
var boss_sine_stream_timer: float = 0.0
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
var boss_display_name: String = "祸月星核"
var boss_battle_elapsed: float = 0.0
var boss_phase: int = 1
var boss_phase_three_elapsed: float = 0.0
var boss_phase_three_intro_remaining: float = 0.0
var boss_split_interval: float = 5.8
var boss_split_timer: float = 0.0
var boss_laser_interval: float = 8.5
var boss_laser_timer: float = 0.0
var boss_laser_duration: float = 3.7
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
# Explicit velocity (was inherited from CharacterBody2D)
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	current_health = max_health if current_health <= 0.0 else min(current_health, max_health)
	base_scale = scale
	if enemy_kind == "":
		enemy_kind = "normal"
	add_to_group("enemies")
	_register_runtime_enemy()
	if not profile_initialized:
		_reset_runtime_state(true)
	_apply_visuals()
	if enemy_kind == "boss":
		_ensure_boss_visual()
		_ensure_boss_helpers()

func _exit_tree() -> void:
	_unregister_runtime_enemy()

func _physics_process(delta: float) -> void:
	if status_root != null or boss_visual_instance != null or hit_flash_remaining > 0.0 or _has_status_visual_pressure():
		status_visual_time += delta
	if hit_flash_remaining > 0.0:
		hit_flash_remaining = max(0.0, hit_flash_remaining - delta)
	if slow_timer > 0.0 or vulnerability_timer > 0.0 or bleed_timer > 0.0:
		_update_status_timers(delta)
	if bleed_timer > 0.0 and bleed_damage_per_second > 0.0:
		_update_bleed(delta)
	if status_root != null or hit_flash_remaining > 0.0 or _has_status_visual_pressure():
		_update_status_visuals()

	if target == null or not is_instance_valid(target):
		velocity = Vector2.ZERO
		_update_motion_visual()
		return

	# P1: cache target vectors once per frame, used by _update_behavior_state and _compute_velocity
	_cached_to_target = target.global_position - global_position
	_cached_distance_to_target = _cached_to_target.length()
	_cached_direction_to_target = _cached_to_target.normalized() if _cached_distance_to_target > 0.001 else Vector2.RIGHT
	if _has_timed_behavior_traits():
		_update_behavior_state(delta)
	velocity = _compute_velocity(delta)
	velocity += _compute_separation_velocity() * 0.85
	_apply_direct_motion(delta)
	_update_motion_visual()

func apply_enemy_profile(kind: String, profile: Dictionary) -> void:
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
	return {
		"name": boss_display_name,
		"current_health": current_health,
		"max_health": max_health,
		"phase": boss_phase
	}

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

func _compute_velocity(delta: float) -> Vector2:
	return ENEMY_MOVEMENT.compute_velocity(self, delta)

func _apply_direct_motion(delta: float) -> void:
	if velocity.length_squared() <= 0.001:
		return
	global_position += velocity * delta

func _compute_separation_velocity() -> Vector2:
	if get_tree() == null:
		return Vector2.ZERO
	var neighbors: Array = []
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("get_runtime_enemies"):
		neighbors = scene.get_runtime_enemies()
	else:
		neighbors = get_tree().get_nodes_in_group("enemies")
	var push: Vector2 = Vector2.ZERO
	var processed: int = 0
	for other in neighbors:
		if other == null or other == self or not is_instance_valid(other) or not (other is Node2D):
			continue
		var offset: Vector2 = global_position - (other as Node2D).global_position
		var other_radius: float = contact_radius
		var other_contact_radius: Variant = other.get("contact_radius")
		if other_contact_radius != null:
			other_radius = float(other_contact_radius)
		var radius: float = max(16.0, (contact_radius + other_radius) * 0.58)
		var radius_sq: float = radius * radius
		var distance_sq: float = offset.length_squared()
		if distance_sq > radius_sq:
			continue
		if distance_sq <= 0.001:
			offset = Vector2.RIGHT.rotated(float(get_instance_id() % 360) * PI / 180.0)
			distance_sq = 1.0
		var distance: float = sqrt(distance_sq)
		var max_push: float = max(24.0, radius * 0.55)
		var strength: float = (radius - distance) / radius
		push += offset.normalized() * strength * max_push
		processed += 1
		if processed >= 8:
			break
	return push

func _update_behavior_state(delta: float) -> void:
	ENEMY_TRAIT_BEHAVIOR.update_behavior_state(self, delta)

func _update_boss_trait(delta: float) -> void:
	ENEMY_BOSS_STATE.update_boss_trait(self, delta)

func has_trait(trait_id: String) -> bool:
	match trait_id:
		"shooter": return _is_shooter
		"dash": return _is_dasher
		"accelerator": return _is_accelerator
		"turret": return _is_turret
		"glutton": return _is_glutton
		"swarm": return _is_swarm
		"boss": return _is_boss
		"rebirth": return _is_rebirth
		_: return behavior_id == trait_id or secondary_behavior_id == trait_id

func _sync_trait_flags() -> void:
	_is_shooter = (behavior_id == "shooter" or secondary_behavior_id == "shooter")
	_is_dasher = (behavior_id == "dash" or secondary_behavior_id == "dash")
	_is_accelerator = (behavior_id == "accelerator" or secondary_behavior_id == "accelerator")
	_is_turret = (behavior_id == "turret" or secondary_behavior_id == "turret")
	_is_glutton = (behavior_id == "glutton" or secondary_behavior_id == "glutton")
	_is_swarm = (behavior_id == "swarm" or secondary_behavior_id == "swarm")
	_is_boss = (behavior_id == "boss" or secondary_behavior_id == "boss")
	_is_rebirth = (behavior_id == "rebirth" or secondary_behavior_id == "rebirth")

func _spawn_projectile(origin: Vector2, shot_direction: Vector2, shot_speed: float, shot_damage: float, shot_lifetime: float, color: Color, mode: String, extra_config: Dictionary = {}) -> void:
	ENEMY_PROJECTILES.spawn_projectile(self, origin, shot_direction, shot_speed, shot_damage, shot_lifetime, color, mode, extra_config)

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

func take_damage(amount: float) -> bool:
	return ENEMY_DAMAGE.take_damage(self, amount)

func take_batched_damage(amount: float) -> bool:
	return ENEMY_DAMAGE.apply_damage(self, amount, false)

func apply_slow(multiplier: float, duration: float) -> void:
	ENEMY_STATUS_EFFECTS.apply_slow(self, multiplier, duration)

func apply_vulnerability(bonus: float, duration: float) -> void:
	ENEMY_STATUS_EFFECTS.apply_vulnerability(self, bonus, duration)

func apply_bleed(damage_per_second: float, duration: float) -> void:
	ENEMY_STATUS_EFFECTS.apply_bleed(self, damage_per_second, duration)

func _ensure_status_visuals() -> void:
	ENEMY_STATUS_VISUALS.ensure_status_visuals(self)

func _update_status_visuals() -> void:
	ENEMY_STATUS_VISUALS.update_status_visuals(self)

func _has_status_visual_pressure() -> bool:
	return slow_timer > 0.0 or vulnerability_timer > 0.0 or enemy_kind != "normal" or secondary_behavior_id != "" or _is_dasher or boss_visual_instance != null

func _has_timed_behavior_traits() -> bool:
	return _is_shooter or _is_accelerator or _is_dasher or _is_glutton or _is_turret or _is_boss or _is_rebirth

func _spawn_status_burst(color: Color, radius: float) -> void:
	ENEMY_STATUS_VISUALS.spawn_status_burst(self, color, radius)

func _spawn_dash_trail(direction_vector: Vector2, length: float) -> void:
	ENEMY_STATUS_VISUALS.spawn_dash_trail(self, direction_vector, length)

func _drop_experience_gem() -> void:
	ENEMY_DROPS.drop_experience_gem(self)

func _maybe_drop_heart() -> void:
	ENEMY_DROPS.maybe_drop_heart(self)

func get_save_data() -> Dictionary:
	return ENEMY_SAVE_DATA.get_save_data(self)

func apply_save_data(data: Dictionary, target_node: Node2D) -> void:
	ENEMY_SAVE_DATA.apply_save_data(self, data, target_node)

func _play_hit_feedback(damage_amount: float, killed: bool) -> void:
	ENEMY_HIT_FEEDBACK.play_hit_feedback(self, damage_amount, killed)

func _get_hit_flash_alpha() -> float:
	return ENEMY_HIT_FEEDBACK.get_hit_flash_alpha(hit_flash_remaining)

func _apply_hit_flash_alpha_to_node(node: Node, alpha: float) -> void:
	ENEMY_HIT_FEEDBACK.apply_hit_flash_alpha_to_node(node, alpha)

func _register_runtime_enemy() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("register_runtime_enemy"):
		scene.register_runtime_enemy(self)

func _unregister_runtime_enemy() -> void:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene != null and scene.has_method("unregister_runtime_enemy"):
		scene.unregister_runtime_enemy(self)
