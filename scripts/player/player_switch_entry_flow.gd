extends RefCounted

const PLAYER_GUNNER_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_gunner_entry_talent_flow.gd")

const GUNNER_ENTRY_WAVE_BULLET_COUNT := 8
const GUNNER_ENTRY_WAVE_BATCH_SIZE := 4
const GUNNER_ENTRY_WAVE_BATCH_INTERVAL := 0.012
const GUNNER_ENTRY_BULLET_DAMAGE_MULTIPLIER := 2.0
const GUNNER_ENTRY_BULLET_SPEED := 1000.0
const GUNNER_ENTRY_BULLET_LIFETIME := 0.9
const GUNNER_ENTRY_BULLET_HIT_RADIUS := 18.0
const GUNNER_ENTRY_BULLET_PIERCE_COUNT := 8
const GUNNER_ENTRY_DAMAGE_SOURCE_ID := "gunner_entry"
const MAGE_ATTACK_EFFECT_SCALE := 0.8
const MAGE_ENTRY_EFFECT_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const MAGE_ENTRY_HIT_RADIUS := 104.0 * MAGE_ATTACK_EFFECT_SCALE
const ENTRY_RESCUE_DURATION := 5.0


static func fire_gunner_entry_wave(owner, role_id: String, wave_index: int, damage_scale: float = 1.0) -> void:
	owner._queue_camera_shake(4.0, 0.08)
	if _has_talent(owner, "gunner_entry_focus"):
		_spawn_gunner_entry_focus(owner, role_id, damage_scale)
		return
	if _has_talent(owner, "gunner_entry_denial"):
		_spawn_gunner_entry_denial(owner, role_id, wave_index, damage_scale)
		return
	spawn_gunner_entry_wave_batch(owner, role_id, wave_index, 0, damage_scale)


static func _spawn_gunner_entry_focus(owner, role_id: String, damage_scale: float) -> void:
	var forward: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	for angle_degrees in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		_spawn_gunner_entry_bullet(owner, role_id, forward.rotated(deg_to_rad(angle_degrees)), damage_scale * 0.35)


static func _spawn_gunner_entry_denial(owner, role_id: String, wave_index: int, damage_scale: float) -> void:
	var angle_offset: float = PI / 12.0 * float(wave_index)
	for bullet_index in range(12):
		_spawn_gunner_entry_bullet(owner, role_id, Vector2.RIGHT.rotated(TAU * float(bullet_index) / 12.0 + angle_offset), damage_scale * 0.5, {
			"speed": 800.0,
			"lifetime": 0.65,
			"pierce": 4,
			"slow_multiplier": 0.6,
			"slow_duration": 1.5
		})


static func _spawn_gunner_entry_bullet(owner, role_id: String, direction: Vector2, damage_scale: float, overrides: Dictionary = {}) -> void:
	var pierce_count := int(overrides.get("pierce", GUNNER_ENTRY_BULLET_PIERCE_COUNT))
	if _has_talent(owner, "gunner_entry_piercing"):
		pierce_count += 4
	var speed := float(overrides.get("speed", GUNNER_ENTRY_BULLET_SPEED))
	var lifetime := float(overrides.get("lifetime", GUNNER_ENTRY_BULLET_LIFETIME))
	var damage_event_id := _create_gunner_damage_event_id(owner, "gunner_entry")
	if owner.has_method("_spawn_batched_directional_bullet"):
		owner._spawn_batched_directional_bullet(
			direction,
			_get_gunner_entry_bullet_damage(owner, role_id, damage_scale),
			Color(1.0, 0.55, 0.32, 1.0),
			GUNNER_ENTRY_DAMAGE_SOURCE_ID,
			owner.global_position,
			{
				"speed": speed,
				"lifetime": lifetime,
				"hit_radius": GUNNER_ENTRY_BULLET_HIT_RADIUS,
				"visual_radius": 3.4,
				"visual_min_diameter": 3.2,
				"enemy_hit_radius_scale": 0.42,
				"enemy_hit_radius_min": 10.0,
				"enemy_hit_radius_max": 28.0,
				"slow_multiplier": float(overrides.get("slow_multiplier", 1.0)),
				"slow_duration": float(overrides.get("slow_duration", 0.0)),
				"pierce_count": pierce_count,
				"damage_event_id": damage_event_id,
				"entry_repulse_on_first_hit": _has_talent(owner, "gunner_entry_repulse")
			}
		)
		return
	owner._spawn_batched_directional_bullet_values(
		direction,
		_get_gunner_entry_bullet_damage(owner, role_id, damage_scale),
		Color(1.0, 0.55, 0.32, 1.0),
		GUNNER_ENTRY_DAMAGE_SOURCE_ID,
		owner.global_position,
		speed,
		lifetime,
		GUNNER_ENTRY_BULLET_HIT_RADIUS,
		3.4,
		3.2,
		Color(1.0, 1.0, 1.0, 0.0),
		0.0,
		0.42,
		10.0,
		28.0,
		0.0,
		0.0,
		float(overrides.get("slow_multiplier", 1.0)),
		float(overrides.get("slow_duration", 0.0)),
		pierce_count
	)


static func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))


static func spawn_gunner_entry_wave_batch(owner, role_id: String, wave_index: int, start_index: int, damage_scale: float = 1.0) -> void:
	var bullet_count: int = GUNNER_ENTRY_WAVE_BULLET_COUNT
	var angle_offset: float = (TAU / float(bullet_count)) * 0.5 * float(wave_index)
	var end_index: int = min(start_index + GUNNER_ENTRY_WAVE_BATCH_SIZE, bullet_count)
	var pierce_count := GUNNER_ENTRY_BULLET_PIERCE_COUNT + (4 if _has_talent(owner, "gunner_entry_piercing") else 0)
	for bullet_index in range(start_index, end_index):
		var shot_angle: float = TAU * float(bullet_index) / float(bullet_count) + angle_offset
		var direction := Vector2.RIGHT.rotated(shot_angle)
		if owner.has_method("_spawn_batched_directional_bullet_values"):
			var damage_event_id := _create_gunner_damage_event_id(owner, "gunner_entry")
			if owner.has_method("_spawn_batched_directional_bullet"):
				owner._spawn_batched_directional_bullet(
					direction,
					_get_gunner_entry_bullet_damage(owner, role_id, damage_scale),
					Color(1.0, 0.55, 0.32, 1.0),
					GUNNER_ENTRY_DAMAGE_SOURCE_ID,
					owner.global_position,
					{
						"speed": GUNNER_ENTRY_BULLET_SPEED,
						"lifetime": GUNNER_ENTRY_BULLET_LIFETIME,
						"hit_radius": GUNNER_ENTRY_BULLET_HIT_RADIUS,
						"visual_radius": 3.4,
						"visual_min_diameter": 3.2,
						"enemy_hit_radius_scale": 0.42,
						"enemy_hit_radius_min": 10.0,
						"enemy_hit_radius_max": 28.0,
						"pierce_count": pierce_count,
						"damage_event_id": damage_event_id,
						"entry_repulse_on_first_hit": _has_talent(owner, "gunner_entry_repulse")
					}
				)
				continue
			owner._spawn_batched_directional_bullet_values(
				direction,
				_get_gunner_entry_bullet_damage(owner, role_id, damage_scale),
				Color(1.0, 0.55, 0.32, 1.0),
				GUNNER_ENTRY_DAMAGE_SOURCE_ID,
				owner.global_position,
				GUNNER_ENTRY_BULLET_SPEED,
				GUNNER_ENTRY_BULLET_LIFETIME,
				GUNNER_ENTRY_BULLET_HIT_RADIUS,
				3.4,
				3.2,
				Color(1.0, 1.0, 1.0, 0.0),
				0.0,
				0.42,
				10.0,
				28.0,
				0.0,
				0.0,
				1.0,
				0.0,
				pierce_count
			)
		else:
			var bullet = owner._spawn_directional_bullet(direction, _get_gunner_entry_bullet_damage(owner, role_id, damage_scale), Color(1.0, 0.55, 0.32, 1.0), GUNNER_ENTRY_DAMAGE_SOURCE_ID, owner.global_position)
			if bullet != null:
				bullet.speed = GUNNER_ENTRY_BULLET_SPEED
				bullet.lifetime = GUNNER_ENTRY_BULLET_LIFETIME
				bullet.hit_radius = GUNNER_ENTRY_BULLET_HIT_RADIUS
				bullet.enemy_hit_radius_scale = 0.42
				bullet.enemy_hit_radius_min = 10.0
				bullet.enemy_hit_radius_max = 28.0
				bullet.pierce_count = pierce_count
				bullet.damage_event_id = _create_gunner_damage_event_id(owner, "gunner_entry")
				bullet.entry_repulse_on_first_hit = _has_talent(owner, "gunner_entry_repulse")
				if bullet.has_method("_register_damage_event"):
					bullet._register_damage_event()
	if end_index >= bullet_count:
		return
	if not owner.has_method("_schedule_repeating_sequence"):
		return
	owner._schedule_repeating_sequence(GUNNER_ENTRY_WAVE_BATCH_INTERVAL, 1, func(_index: int) -> void:
		spawn_gunner_entry_wave_batch(owner, role_id, wave_index, end_index, damage_scale)
	, GUNNER_ENTRY_WAVE_BATCH_INTERVAL)


static func _get_gunner_entry_bullet_damage(owner, role_id: String, damage_scale: float = 1.0) -> float:
	if owner == null or not is_instance_valid(owner):
		return 0.0
	var entry_ratio: float = GUNNER_ENTRY_BULLET_DAMAGE_MULTIPLIER + PLAYER_GUNNER_ENTRY_TALENT_FLOW.get_entry_damage_ratio_bonus(owner)
	return owner._get_role_damage(role_id) * entry_ratio * max(0.0, damage_scale)


static func _create_gunner_damage_event_id(owner, prefix: String) -> String:
	var gunner_role = owner.get("gunner_role") if owner != null else null
	if gunner_role != null and gunner_role.has_method("create_damage_event_id"):
		return str(gunner_role.create_damage_event_id(owner, prefix))
	return ""


static func start_mage_entry_bombardment(owner, role_id: String, bombard_centers: Array, damage_scale: float = 1.0) -> void:
	if bombard_centers.is_empty():
		return

	if not owner.has_method("_schedule_repeating_sequence"):
		return

	var first_center: Vector2 = bombard_centers[0]
	var warning_duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	show_mage_entry_bombardment_warning(owner, first_center)
	var sequence_steps: Array[Dictionary] = []
	sequence_steps.append({
		"delay": warning_duration,
		"action": "impact",
		"center": first_center
	})
	for center_index in range(1, bombard_centers.size()):
		var next_center: Vector2 = bombard_centers[center_index]
		sequence_steps.append({
			"delay": 0.22,
			"action": "warning",
			"center": next_center
		})
		sequence_steps.append({
			"delay": warning_duration,
			"action": "impact",
			"center": next_center
		})
	_schedule_mage_entry_step(owner, role_id, sequence_steps, 0, damage_scale)


static func _schedule_mage_entry_step(owner, role_id: String, sequence_steps: Array[Dictionary], step_index: int, damage_scale: float) -> void:
	if step_index < 0 or step_index >= sequence_steps.size():
		return
	var step: Dictionary = sequence_steps[step_index]
	owner._schedule_repeating_sequence(float(step.get("delay", 0.0)), 1, func(_index: int) -> void:
		if not is_instance_valid(owner):
			return
		var center: Vector2 = step.get("center", Vector2.ZERO)
		if str(step.get("action", "")) == "warning":
			show_mage_entry_bombardment_warning(owner, center)
		else:
			trigger_mage_entry_bombardment_impact(owner, role_id, center, damage_scale)
		_schedule_mage_entry_step(owner, role_id, sequence_steps, step_index + 1, damage_scale)
	, float(step.get("delay", 0.0)))


static func show_mage_entry_bombardment_warning(owner, center: Vector2) -> void:
	var range_multiplier: float = _get_mage_entry_range_multiplier(owner)
	owner._spawn_mage_warning_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS * range_multiplier)


static func trigger_mage_entry_bombardment_impact(owner, role_id: String, center: Vector2, damage_scale: float = 1.0) -> void:
	var range_multiplier: float = _get_mage_entry_range_multiplier(owner)
	owner._queue_camera_shake(7.2, 0.14)
	owner._spawn_mage_boom_scene_effect(center, MAGE_ENTRY_EFFECT_RADIUS * range_multiplier)
	var hits: int = owner._damage_enemies_in_radius(center, MAGE_ENTRY_HIT_RADIUS * range_multiplier, owner._get_role_damage(role_id) * 0.82 * max(0.0, damage_scale), 0.0, 1.0, 0.0)
	if hits > 0:
		owner._register_attack_result(role_id, hits, false)


static func _get_mage_entry_range_multiplier(owner) -> float:
	var range_multiplier: float = 1.0
	if owner.has_method("_get_role_blessing_stat_bonus"):
		range_multiplier += float(owner._get_role_blessing_stat_bonus("mage", "skill_range"))
	return range_multiplier


static func queue_next_entry_blessing(owner, source_role_id: String) -> void:
	owner.pending_entry_blessing_source_role_id = source_role_id


static func apply_pending_entry_blessing(owner, _target_role_id: String) -> void:
	if owner.pending_entry_blessing_source_role_id == "":
		return
	owner.pending_entry_blessing_source_role_id = ""
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())


static func clear_entry_blessing(owner) -> void:
	owner.entry_blessing_role_id = ""
	owner.entry_blessing_label = ""
	owner.entry_blessing_remaining = 0.0
	owner.entry_lifesteal_ratio = 0.0
	owner.entry_haste_interval_bonus = 0.0
	owner.entry_haste_move_speed_multiplier = 1.0
	owner._update_fire_timer()
	owner.stats_changed.emit(owner.get_stat_summary())


static func apply_shared_entry_skills(owner, role_id: String) -> void:
	_apply_entry_rescue(owner)
	_apply_hero_entry(owner, role_id)


static func _apply_entry_rescue(owner) -> void:
	if owner == null or not owner.has_method("_get_entry_rescue_regen_per_second"):
		return
	var regen: float = float(owner._get_entry_rescue_regen_per_second())
	if regen <= 0.0:
		return
	owner.entry_rescue_remaining = ENTRY_RESCUE_DURATION
	owner.entry_rescue_regen_per_second = regen
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -54.0), "协同救援", Color(0.48, 1.0, 0.66, 1.0))


static func _apply_hero_entry(owner, role_id: String) -> void:
	if owner == null or not owner.has_method("_get_hero_entry_effect"):
		return
	var effect: Dictionary = owner._get_hero_entry_effect()
	var extra_count: int = max(0, int(effect.get("extra_count", 0)))
	var effect_scale: float = max(0.0, float(effect.get("effect_scale", 0.0)))
	if extra_count <= 0 or effect_scale <= 0.0:
		return
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -74.0), "英雄登场", Color(1.0, 0.9, 0.48, 1.0))
	match role_id:
		"swordsman":
			_spawn_swordsman_hero_entry_extras(owner, role_id, extra_count, effect_scale)
		"gunner":
			_spawn_gunner_hero_entry_extras(owner, role_id, extra_count, effect_scale)
		"mage":
			_spawn_mage_hero_entry_extras(owner, role_id, extra_count, effect_scale)


static func _spawn_swordsman_hero_entry_extras(owner, role_id: String, extra_count: int, effect_scale: float) -> void:
	if owner.get_tree() == null:
		return
	var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var origin: Vector2 = owner.global_position
	for index in range(extra_count):
		var extra_index: int = index
		owner._schedule_repeating_sequence(0.0, 1, func(_sequence_index: int) -> void:
			if owner == null or not is_instance_valid(owner):
				return
			var slash_direction: Vector2 = direction.rotated(deg_to_rad(14.0 * (float(extra_index) - float(extra_count - 1) * 0.5)))
			var start_position: Vector2 = origin - slash_direction * 42.0
			var end_position: Vector2 = origin + slash_direction * 128.0
			var width: float = 32.0 * effect_scale
			var center: Vector2 = start_position.lerp(end_position, 0.5)
			owner._spawn_sword_omnislash_scene_effect(center, slash_direction, start_position.distance_to(end_position) * effect_scale, width * 1.08)
			var hits: int = owner._damage_enemies_in_line(start_position, end_position, width, owner._get_role_damage(role_id) * 1.52 * effect_scale, 0.1, 1.0, 0.0, role_id)
			if hits > 0:
				owner._register_attack_result(role_id, hits, false)
		, 0.08 * float(index + 1))


static func _spawn_gunner_hero_entry_extras(owner, role_id: String, extra_count: int, effect_scale: float) -> void:
	if owner.get_tree() == null:
		return
	for index in range(extra_count):
		var extra_index: int = index
		owner._schedule_repeating_sequence(0.0, 1, func(_sequence_index: int) -> void:
			if is_instance_valid(owner):
				spawn_gunner_entry_wave_batch(owner, role_id, extra_index + 2, 0, effect_scale)
		, 0.08 * float(extra_index + 1))


static func _spawn_mage_hero_entry_extras(owner, role_id: String, _extra_count: int, effect_scale: float) -> void:
	var centers: Array = owner._get_random_enemy_cluster_centers(3)
	if centers.is_empty():
		return
	owner._start_mage_entry_bombardment(role_id, centers, effect_scale)
