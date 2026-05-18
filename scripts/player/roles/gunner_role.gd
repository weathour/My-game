extends RefCounted

const ULTIMATE_BULLET_HIT_SCAN_INTERVAL := 0.035
const BASIC_COMBO_INTERVAL := 0.12
const GUNNER_BULLET_VISUAL_SCALE := 0.4
const GUNNER_BATCHED_BULLET_VISUAL_MIN_DIAMETER := 3.2
const GUNNER_TRICK_ANGLE_STEP_DEGREES := 10.0
const ULTIMATE_SKILL_ID := "gunner_ultimate"
const ULTIMATE_DURATION := 4.0
const ULTIMATE_TIER_ONE_CONE_DEGREES := 45.0
const ULTIMATE_TIER_TWO_CONE_DEGREES := 60.0
const ULTIMATE_TIER_THREE_CONE_DEGREES := 90.0
const ULTIMATE_TIER_ONE_TICK_INTERVAL := 0.34
const ULTIMATE_TIER_TWO_TICK_INTERVAL := 0.24
const ULTIMATE_TIER_THREE_TICK_INTERVAL := 0.14
const ULTIMATE_TIER_ONE_DAMAGE_WAVES_PER_SECOND := 4.7
const ULTIMATE_TIER_TWO_DAMAGE_WAVES_PER_SECOND := 5.3
const ULTIMATE_TIER_THREE_DAMAGE_WAVES_PER_SECOND := 6.0
const ULTIMATE_VISUAL_INTERVAL := 0.07
const ULTIMATE_VISUAL_BULLETS_PER_PULSE := 7
const ULTIMATE_DAMAGE_BASE_RATIO := 2.1
const ULTIMATE_DAMAGE_BARRAGE_RATIO := 0.16
const ULTIMATE_DAMAGE_FOCUS_RATIO := 0.11
const ULTIMATE_TIER_TWO_DAMAGE_MULTIPLIER := 1.42
const ULTIMATE_TIER_THREE_DAMAGE_MULTIPLIER := 1.6
const ULTIMATE_VISUAL_BULLET_SPEED := 1880.0
const ULTIMATE_VISUAL_FOCUS_SPEED_BONUS := 128.0
const ULTIMATE_VISUAL_BARRAGE_SPEED_BONUS := 42.0
const ULTIMATE_VISUAL_BULLET_COLOR := Color(0.0, 0.0, 0.0, 0.96)
const ULTIMATE_VISUAL_BULLET_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.96)
const ULTIMATE_VISUAL_BULLET_OUTLINE_WIDTH := 2.0
const BASIC_BULLET_BASE_SPEED := 760.0
const BASIC_BULLET_FOCUS_SPEED_BONUS := 72.0
const BASIC_BULLET_LIFETIME := 1.65
const BASIC_BULLET_VISUAL_RADIUS := 3.4

var ultimate_attack_locked: bool = false
var ultimate_attack_lock_id: int = 0

func perform_attack(owner) -> void:
	if ultimate_attack_locked:
		return
	if owner.is_gunner_infinite_reload_active():
		return
	var base_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	_perform_combo_segment(owner, base_direction, 1.0)
	_schedule_reprise_segments(owner, base_direction)

func _perform_combo_segment(owner, base_direction: Vector2, combo_scale: float) -> void:
	_perform_attack_variant(owner, base_direction, combo_scale, true, true)
	_apply_trick_variants(owner, base_direction, combo_scale)

func _perform_attack_variant(owner, shot_direction: Vector2, effect_scale: float = 1.0, advance_chain: bool = true, spawn_aftershock: bool = true) -> void:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var focus_level: int = 0
	var barrage_attribute_level: float = 0.0
	shot_direction = shot_direction if shot_direction.length_squared() > 0.001 else Vector2.RIGHT
	shot_direction = shot_direction.normalized()
	var effective_range: float = (float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0))) * owner._get_story_style_range_multiplier(role_data["id"])
	var target_enemy: Node2D = owner._get_enemy_in_aim_cone(18.0, effective_range + 80.0)
	var main_damage: float = owner._get_role_damage(role_data["id"]) * max(0.0, effect_scale)
	if target_enemy != null:
		main_damage *= owner._get_priority_target_bonus(target_enemy)

	var bullet_color := Color(0.54, 0.94, 1.0, 1.0) if owner._get_story_style_id(role_data["id"]) == "star_pierce" else Color(1.0, 0.42, 0.34, 1.0)
	if owner._get_gunner_barrage_shotgun_wave_count(barrage_attribute_level) > 0:
		_spawn_barrage_shotgun(owner, shot_direction, main_damage, bullet_color, role_data, upgrade_data, focus_level, barrage_attribute_level)
	else:
		if not _spawn_primary_batched_bullet(owner, shot_direction, main_damage, bullet_color, role_data, upgrade_data, focus_level, owner.global_position + shot_direction * 18.0):
			return

	if advance_chain:
		owner.gunner_attack_chain = (owner.gunner_attack_chain + 1) % 4

	if spawn_aftershock:
		owner._spawn_attack_aftershock(owner.global_position + shot_direction * min(220.0, effective_range), role_data["id"])

func _schedule_reprise_segments(owner, base_direction: Vector2) -> void:
	var combo_scales := _get_skill_effect_scales(owner, "combo_skill_extra")
	if combo_scales.is_empty():
		return
	owner._schedule_repeating_sequence(BASIC_COMBO_INTERVAL, combo_scales.size(), func(index: int) -> void:
		if index >= 0 and index < combo_scales.size():
			_perform_combo_segment_if_valid(owner, base_direction, float(combo_scales[index]))
	, BASIC_COMBO_INTERVAL)

func _perform_combo_segment_if_valid(owner, base_direction: Vector2, combo_scale: float) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	if ultimate_attack_locked:
		return
	if owner.has_method("is_gunner_infinite_reload_active") and owner.is_gunner_infinite_reload_active():
		return
	_perform_combo_segment(owner, base_direction, combo_scale)

func _apply_trick_variants(owner, base_direction: Vector2, combo_scale: float) -> void:
	var scales := _get_skill_effect_scales(owner, "quantity_skill_count")
	var total_count := scales.size() + 1
	if total_count <= 1:
		return
	var center_offset := (float(total_count) - 1.0) * 0.5
	for index in range(total_count):
		if is_equal_approx(float(index), center_offset):
			continue
		var scale_index := index if float(index) < center_offset else index - 1
		var angle_offset := deg_to_rad((float(index) - center_offset) * GUNNER_TRICK_ANGLE_STEP_DEGREES)
		_perform_attack_variant(owner, base_direction.rotated(angle_offset), combo_scale * float(scales[scale_index]), false, false)

func _get_skill_effect_scales(owner, stat: String) -> Array[float]:
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales_for_skill"):
		return owner._get_skill_blessing_effect_scales_for_skill("gunner_basic_attack", stat)
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales"):
		return owner._get_skill_blessing_effect_scales(stat)
	return []

func _spawn_barrage_shotgun(owner, shot_direction: Vector2, main_damage: float, bullet_color: Color, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int, barrage_attribute_level: float) -> void:
	var wave_count: int = owner._get_gunner_barrage_shotgun_wave_count(barrage_attribute_level)
	var pellet_count: int = owner._get_gunner_barrage_shotgun_pellet_count(barrage_attribute_level)
	var base_arc := deg_to_rad(9.0)
	for wave_index in range(wave_count):
		var wave_arc: float = base_arc + deg_to_rad(3.5 * float(wave_index))
		for pellet_index in range(pellet_count):
			var centered_index := float(pellet_index) - float(pellet_count - 1) * 0.5
			var pellet_direction: Vector2 = shot_direction.rotated(centered_index * wave_arc)
			var origin: Vector2 = owner.global_position + shot_direction * (18.0 + float(wave_index) * 8.0)
			_spawn_primary_batched_bullet(owner, pellet_direction, main_damage * 0.58, bullet_color, role_data, upgrade_data, focus_level, origin, {
				"lifetime": 0.86 + float(wave_index) * 0.08,
				"hit_radius_bonus": 1.0
			})

func _spawn_primary_batched_bullet(owner, shot_direction: Vector2, damage_amount: float, bullet_color: Color, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int, origin: Vector2, overrides: Dictionary = {}) -> bool:
	var hit_radius: float = 14.0 + float(overrides.get("hit_radius_bonus", 0.0))
	if focus_level > 0:
		hit_radius += 1.5 * focus_level
	var lifetime: float = float(overrides.get("lifetime", BASIC_BULLET_LIFETIME))
	var pierce_count: int = int(round(float(upgrade_data["range_bonus"]) / 40.0)) + focus_level + owner._get_story_style_extra_pierce(role_data["id"])
	return owner._spawn_batched_directional_bullet_values(
		shot_direction,
		damage_amount,
		bullet_color,
		role_data["id"],
		origin,
		(BASIC_BULLET_BASE_SPEED + BASIC_BULLET_FOCUS_SPEED_BONUS * focus_level) * owner._get_story_style_bullet_speed_multiplier(role_data["id"]) * _get_basic_attack_projectile_speed_multiplier(owner),
		lifetime,
		hit_radius,
		_get_scaled_visual_radius(BASIC_BULLET_VISUAL_RADIUS),
		GUNNER_BATCHED_BULLET_VISUAL_MIN_DIAMETER,
		Color(1.0, 1.0, 1.0, 0.0),
		0.0,
		0.42,
		10.0,
		28.0,
		0.04 * focus_level if focus_level > 0 else 0.0,
		1.0 + 0.2 * focus_level if focus_level > 0 else 0.0,
		1.0,
		0.0,
		pierce_count
	)

func _configure_primary_bullet(owner, bullet, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int) -> void:
	bullet.speed = (BASIC_BULLET_BASE_SPEED + BASIC_BULLET_FOCUS_SPEED_BONUS * focus_level) * owner._get_story_style_bullet_speed_multiplier(role_data["id"]) * _get_basic_attack_projectile_speed_multiplier(owner)
	bullet.lifetime = BASIC_BULLET_LIFETIME
	bullet.visual_scale_multiplier *= GUNNER_BULLET_VISUAL_SCALE
	bullet.pierce_count = int(round(float(upgrade_data["range_bonus"]) / 40.0)) + focus_level + owner._get_story_style_extra_pierce(role_data["id"])
	if focus_level > 0:
		bullet.vulnerability_bonus = 0.04 * focus_level
		bullet.vulnerability_duration = 1.0 + 0.2 * focus_level
		bullet.hit_radius += 1.5 * focus_level

func _get_basic_attack_projectile_speed_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_basic_attack_projectile_speed_multiplier"):
		return float(owner._get_basic_attack_projectile_speed_multiplier("gunner_basic_attack"))
	return 1.0

func perform_background(owner) -> void:
	var special_data: Dictionary = owner._get_role_special_state("gunner")
	var support_level: int = int(special_data.get("support_level", 0))
	var focus_level: int = int(special_data.get("focus_level", 0))
	var scatter_level: int = int(special_data.get("scatter_level", 0))
	var lock_level: int = int(special_data.get("lock_level", 0))
	var targets: Array = owner._get_enemy_targets(min(1 + support_level, 3), true)
	if targets.is_empty():
		var fallback: Node2D = owner._get_closest_enemy()
		if fallback != null:
			targets.append(fallback)

	for target_enemy in targets:
		if target_enemy == null or not is_instance_valid(target_enemy):
			continue
		var bullet = owner._spawn_bullet(target_enemy, owner._get_role_damage("gunner") * (0.34 + support_level * 0.06), Color(1.0, 0.58, 0.38, 0.9), "gunner", owner.global_position + owner._get_support_offset("gunner", false))
		if bullet != null:
			bullet.speed = 500.0 + 24.0 * support_level
			bullet.lifetime = 1.35
			bullet.visual_scale_multiplier *= GUNNER_BULLET_VISUAL_SCALE
			if focus_level > 0:
				bullet.vulnerability_bonus = 0.02 * focus_level
				bullet.vulnerability_duration = 0.9 + 0.16 * focus_level
		if lock_level > 0 and owner.global_position.distance_to(target_enemy.global_position) >= 180.0:
			owner._spawn_target_lock_effect(target_enemy.global_position, 16.0 + lock_level * 3.0, Color(1.0, 0.8, 0.42, 0.9), 0.18)
		if scatter_level >= 2:
			for angle_sign in [-1.0, 1.0]:
				var fire_direction: Vector2 = owner.global_position.direction_to(target_enemy.global_position).rotated(0.16 * angle_sign)
				var spread_bullet = owner._spawn_directional_bullet(fire_direction, owner._get_role_damage("gunner") * 0.18, Color(1.0, 0.66, 0.42, 0.86), "gunner", owner.global_position + owner._get_support_offset("gunner", false))
				if spread_bullet != null:
					spread_bullet.speed = 460.0
					spread_bullet.lifetime = 0.5
					spread_bullet.hit_radius = 10.0
					spread_bullet.visual_scale_multiplier *= GUNNER_BULLET_VISUAL_SCALE

func perform_enter(owner, role_id: String, _assault_level: int, _assault_multiplier: float) -> int:
	owner._show_switch_banner("\u8FDB\u573A", "\u5FEB\u62D4\u538B\u5236", Color(1.0, 0.58, 0.36, 1.0))
	owner._fire_gunner_entry_wave(role_id, 0)
	var wave_count := 2
	if owner.has_method("_schedule_repeating_sequence") and wave_count > 1:
		owner._schedule_repeating_sequence(0.08, wave_count - 1, func(index: int) -> void:
			owner._fire_gunner_entry_wave(role_id, index + 1)
		, 0.08)
	return 8

func perform_exit(owner, role_id: String, rearguard_level: int) -> int:
	owner._queue_next_entry_blessing(role_id)
	owner._show_switch_banner("\u9000\u573A", "\u6218\u672F\u88C5\u586B", Color(1.0, 0.58, 0.38, 0.96))
	owner._spawn_ring_effect(owner.global_position, 92.0, Color(1.0, 0.58, 0.38, 0.54), 6.0, 0.18)
	owner._spawn_burst_effect(owner.global_position, 72.0, Color(1.0, 0.58, 0.38, 0.16), 0.16)
	if rearguard_level >= 3:
		owner._activate_guard_cover()
	return owner._trigger_rearguard_attack(role_id, owner.global_position, rearguard_level)

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var barrage_level: int = 0
	var focus_level: int = 0
	var scatter_level: int = 0
	var ultimate_tier: int = _get_ultimate_skill_tier(owner)
	var cone_degrees: float = _get_ultimate_cone_degrees(ultimate_tier)
	var total_duration: float = ULTIMATE_DURATION
	if owner.has_method("_get_blessing_skill_duration_multiplier"):
		total_duration *= float(owner._get_blessing_skill_duration_multiplier(ULTIMATE_SKILL_ID))
	total_duration *= float(cast_payload.get("duration_multiplier", 1.0))
	_lock_basic_attack_during_ultimate(owner, total_duration)
	var old_tick_interval: float = _get_ultimate_tick_interval(ultimate_tier)
	var old_tick_count: int = max(1, int(ceil(total_duration / old_tick_interval)))
	var tick_count: int = _get_ultimate_damage_wave_count(total_duration, ultimate_tier)
	var tick_interval: float = total_duration / float(max(1, tick_count))
	var damage_wave_multiplier: float = float(old_tick_count) / float(max(1, tick_count))
	var visual_count: int = max(1, int(ceil(total_duration / ULTIMATE_VISUAL_INTERVAL)))
	owner._queue_camera_shake(17.5, 0.54)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.5)
	owner._delay_level_up_requests(total_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "火箭弹幕", Color(1.0, 0.86, 0.5, 1.0))
	owner._schedule_repeating_sequence(tick_interval, tick_count, func(tick_index: int) -> void:
		_apply_ultimate_cone_damage(owner, barrage_level, focus_level, cone_degrees, float(cast_payload.get("damage_multiplier", 1.0)) * damage_wave_multiplier, ultimate_tier, tick_index)
	)
	owner._schedule_repeating_sequence(ULTIMATE_VISUAL_INTERVAL, visual_count, func(visual_index: int) -> void:
		_spawn_ultimate_cone_visuals(owner, barrage_level, focus_level, scatter_level, cone_degrees, visual_index)
	)
	owner._apply_post_ultimate_bonuses("gunner", total_duration)

func _lock_basic_attack_during_ultimate(owner, total_duration: float) -> void:
	ultimate_attack_lock_id += 1
	var lock_id: int = ultimate_attack_lock_id
	ultimate_attack_locked = true
	if owner == null or not owner.has_method("_schedule_repeating_sequence"):
		ultimate_attack_locked = false
		return
	var lock_duration: float = max(0.0, total_duration)
	owner._schedule_repeating_sequence(lock_duration, 1, func(_index: int) -> void:
		if ultimate_attack_lock_id == lock_id:
			ultimate_attack_locked = false
	, lock_duration)

func _apply_ultimate_cone_damage(owner, barrage_level: int, focus_level: int, cone_degrees: float, cast_damage_multiplier: float, ultimate_tier: int, tick_index: int) -> void:
	if owner.is_dead:
		return
	var origin: Vector2 = owner.global_position
	var direction: Vector2 = owner._get_attack_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	owner.facing_direction = direction
	var range_value: float = _get_ultimate_cone_range(owner)
	var damage_multiplier: float = (ULTIMATE_DAMAGE_BASE_RATIO + float(barrage_level) * ULTIMATE_DAMAGE_BARRAGE_RATIO + float(focus_level) * ULTIMATE_DAMAGE_FOCUS_RATIO) * cast_damage_multiplier
	if ultimate_tier >= 3:
		damage_multiplier *= ULTIMATE_TIER_TWO_DAMAGE_MULTIPLIER * ULTIMATE_TIER_THREE_DAMAGE_MULTIPLIER
	elif ultimate_tier >= 2:
		damage_multiplier *= ULTIMATE_TIER_TWO_DAMAGE_MULTIPLIER
	var hits: int = owner._damage_enemies_in_cone_batched(
		origin,
		direction,
		range_value,
		deg_to_rad(cone_degrees),
		owner._get_role_damage("gunner") * damage_multiplier,
		0.035 * float(focus_level),
		1.0,
		0.0,
		"gunner"
	)
	if hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("gunner", hits, false)
	if tick_index % 3 == 0:
		owner._queue_camera_shake(3.8 + float(barrage_level) * 0.18, 0.08)

func _spawn_ultimate_cone_visuals(owner, barrage_level: int, focus_level: int, scatter_level: int, cone_degrees: float, visual_index: int) -> void:
	if owner.is_dead:
		return
	var direction: Vector2 = owner._get_attack_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	direction = direction.normalized()
	var range_value: float = _get_ultimate_cone_range(owner)
	var bullet_speed: float = ULTIMATE_VISUAL_BULLET_SPEED + focus_level * ULTIMATE_VISUAL_FOCUS_SPEED_BONUS + barrage_level * ULTIMATE_VISUAL_BARRAGE_SPEED_BONUS
	var bullet_lifetime: float = max(0.20, range_value / bullet_speed)
	var bullet_count: int = ULTIMATE_VISUAL_BULLETS_PER_PULSE + min(3, barrage_level) + min(2, scatter_level)
	var phase: float = float(visual_index) * 0.37
	for bullet_index in range(bullet_count):
		var ratio: float = 0.5 if bullet_count <= 1 else float(bullet_index) / float(bullet_count - 1)
		var centered_ratio: float = ratio * 2.0 - 1.0
		var jitter: float = sin(phase + float(bullet_index) * 1.7) * 0.08
		var shot_direction: Vector2 = direction.rotated(deg_to_rad(cone_degrees) * 0.5 * centered_ratio + jitter)
		var origin_offset: Vector2 = direction * 18.0 + direction.orthogonal() * (centered_ratio * 10.0)
		owner._spawn_batched_directional_bullet_values(
			shot_direction,
			0.0,
			ULTIMATE_VISUAL_BULLET_COLOR,
			"gunner",
			owner.global_position + origin_offset,
			bullet_speed,
			bullet_lifetime,
			0.0,
			_get_scaled_visual_radius(3.8),
			GUNNER_BATCHED_BULLET_VISUAL_MIN_DIAMETER,
			ULTIMATE_VISUAL_BULLET_OUTLINE_COLOR,
			ULTIMATE_VISUAL_BULLET_OUTLINE_WIDTH,
			0.0,
			0.0,
			0.0
		)

func _apply_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		hits += int(owner._damage_enemies_in_cone(
			shape.get("origin", Vector2.ZERO),
			shape.get("direction", Vector2.RIGHT),
			float(shape.get("range", 1.0)),
			float(shape.get("angle", 0.0)),
			float(shape.get("damage_amount", 0.0)),
			float(shape.get("vulnerability_bonus", 0.0)),
			float(shape.get("slow_multiplier", 1.0)),
			float(shape.get("slow_duration", 0.0)),
			str(shape.get("source_role_id", ""))
		))
	return hits

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")

func _get_ultimate_cone_range(owner) -> float:
	var role_data: Dictionary = owner.roles[1] if owner.roles.size() > 1 else {"range": 300.0, "id": "gunner"}
	var upgrade_data: Dictionary = owner.role_upgrade_levels.get("gunner", {})
	var base_range: float = (float(role_data.get("range", 300.0)) + float(upgrade_data.get("range_bonus", 0.0))) * 2.0
	base_range *= owner._get_story_style_range_multiplier("gunner")
	base_range *= owner._get_role_attribute_range_multiplier("gunner")
	base_range *= owner._get_role_equipment_skill_range_multiplier("gunner")
	return max(220.0, base_range)

func _get_ultimate_skill_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return max(1, int(owner._get_blessing_skill_tier(ULTIMATE_SKILL_ID)))
	return 1

func _get_ultimate_cone_degrees(ultimate_tier: int) -> float:
	if ultimate_tier >= 3:
		return ULTIMATE_TIER_THREE_CONE_DEGREES
	if ultimate_tier >= 2:
		return ULTIMATE_TIER_TWO_CONE_DEGREES
	return ULTIMATE_TIER_ONE_CONE_DEGREES

func _get_ultimate_tick_interval(ultimate_tier: int) -> float:
	if ultimate_tier >= 3:
		return ULTIMATE_TIER_THREE_TICK_INTERVAL
	if ultimate_tier >= 2:
		return ULTIMATE_TIER_TWO_TICK_INTERVAL
	return ULTIMATE_TIER_ONE_TICK_INTERVAL

func _get_ultimate_damage_wave_count(total_duration: float, ultimate_tier: int) -> int:
	var waves_per_second: float = ULTIMATE_TIER_ONE_DAMAGE_WAVES_PER_SECOND
	if ultimate_tier >= 3:
		waves_per_second = ULTIMATE_TIER_THREE_DAMAGE_WAVES_PER_SECOND
	elif ultimate_tier >= 2:
		waves_per_second = ULTIMATE_TIER_TWO_DAMAGE_WAVES_PER_SECOND
	return max(1, int(round(total_duration * waves_per_second)))

func _fire_ultimate_wave(owner, wave_count: int, barrage_level: int, focus_level: int, scatter_level: int, lock_level: int, cast_damage_multiplier: float, wave_index: int) -> void:
	if owner.is_dead:
		return

	var upgrade_data: Dictionary = owner.role_upgrade_levels["gunner"]
	var base_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var phase: float = float(wave_index) / float(max(1, wave_count - 1))
	var spin: float = phase * TAU * (2.8 + float(barrage_level) * 0.24)
	var wave_shift: float = sin(spin * 1.2) * (16.0 + scatter_level * 4.0)
	var wave_origin: Vector2 = owner.global_position + base_direction.orthogonal() * wave_shift
	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	var target_direction: Vector2 = base_direction
	if cluster_center != Vector2.ZERO and wave_origin.distance_to(cluster_center) > 8.0:
		target_direction = wave_origin.direction_to(cluster_center)
	var fan_arc_degrees: float = 92.0 + scatter_level * 8.0 + min(10.0, float(barrage_level) * 3.0)
	var fan_arc_radians: float = deg_to_rad(fan_arc_degrees)
	var bullet_count: int = 16 + scatter_level * 3 + barrage_level * 3
	var normal_pierce_count: int = int(round(float(upgrade_data.get("range_bonus", 0.0)) / 40.0)) + focus_level + owner._get_story_style_extra_pierce("gunner")
	var damage_scale: float = (0.44 + float(barrage_level) * 0.03 + float(focus_level) * 0.04) * cast_damage_multiplier
	var angle_offset: float = sin(spin * 0.9) * 0.18
	owner._queue_camera_shake(4.6 + float(barrage_level) * 0.24, 0.1)

	for bullet_index in range(bullet_count):
		var ratio: float = 0.0 if bullet_count <= 1 else float(bullet_index) / float(bullet_count - 1)
		var centered_ratio: float = ratio * 2.0 - 1.0
		var angle: float = target_direction.angle() + centered_ratio * fan_arc_radians * 0.5 + angle_offset
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var muzzle_offset: Vector2 = shot_direction * (12.0 + 4.0 * sin(spin + float(bullet_index) * 0.8))
		var wave_amplitude: float = 0.0
		var wave_frequency: float = 0.0
		var wave_phase: float = 0.0
		if abs(centered_ratio) >= 0.34:
			wave_phase = ratio * PI + spin * 0.45
			wave_amplitude = max(0.0, abs(centered_ratio) * (10.0 + scatter_level * 4.0))
			wave_frequency = 6.4 + focus_level * 0.9 + barrage_level * 0.25
		owner._spawn_batched_directional_bullet_values(
			shot_direction,
			owner._get_role_damage("gunner") * damage_scale,
			Color(1.0, 0.72, 0.38, 0.94),
			"gunner",
			wave_origin + muzzle_offset,
			620.0 + focus_level * 54.0 + barrage_level * 18.0,
			1.08 + barrage_level * 0.06,
			10.0 + scatter_level * 0.8,
			_get_scaled_visual_radius(3.8),
			GUNNER_BATCHED_BULLET_VISUAL_MIN_DIAMETER,
			Color(1.0, 1.0, 1.0, 0.0),
			0.0,
			0.2,
			4.0,
			12.0,
			0.04 * focus_level if focus_level > 0 else 0.0,
			1.0 + focus_level * 0.2 if focus_level > 0 else 0.0,
			1.0,
			0.0,
			normal_pierce_count,
			wave_amplitude,
			wave_frequency,
			wave_phase
		)

	if lock_level > 0 and wave_index % max(2, 4 - lock_level) == 0:
		for enemy in owner._get_enemy_targets(min(1 + lock_level, 3), false):
			if enemy == null or not is_instance_valid(enemy):
				continue
			var lock_bullet = owner._spawn_bullet(enemy, owner._get_role_damage("gunner") * (0.38 + lock_level * 0.06) * cast_damage_multiplier, Color(1.0, 0.86, 0.5, 1.0), "gunner", wave_origin)
			if lock_bullet != null:
				lock_bullet.speed = 760.0 + focus_level * 55.0
				lock_bullet.lifetime = 1.38 + barrage_level * 0.07
				lock_bullet.hit_radius = 8.0 + lock_level * 0.8
				lock_bullet.visual_scale_multiplier = 0.68 * GUNNER_BULLET_VISUAL_SCALE
				lock_bullet.enemy_hit_radius_scale = 0.18
				lock_bullet.enemy_hit_radius_min = 4.0
				lock_bullet.enemy_hit_radius_max = 10.0
				lock_bullet.pierce_count = min(1, normal_pierce_count)
				lock_bullet.min_hit_travel_distance = 22.0
				lock_bullet.hit_scan_interval = ULTIMATE_BULLET_HIT_SCAN_INTERVAL
				lock_bullet.vulnerability_bonus = 0.04 + lock_level * 0.01
				lock_bullet.vulnerability_duration = 1.4 + lock_level * 0.22

func _get_scaled_visual_radius(base_radius: float) -> float:
	return base_radius * GUNNER_BULLET_VISUAL_SCALE


func apply_lock(owner, target_enemy: Node2D, lock_level: int) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		owner.gunner_lock_target = null
		owner.gunner_lock_stacks = 0
		return

	if owner.gunner_lock_target == null or not is_instance_valid(owner.gunner_lock_target) or owner.gunner_lock_target != target_enemy:
		owner.gunner_lock_target = target_enemy
		owner.gunner_lock_stacks = 0

	owner.gunner_lock_stacks += 1
	if target_enemy.has_method("apply_vulnerability"):
		target_enemy.apply_vulnerability(0.04 * lock_level, 1.4 + 0.2 * lock_level)

	var required_stacks: int = max(1, 3 - lock_level)
	if owner.gunner_lock_stacks < required_stacks:
		return

	owner.gunner_lock_stacks = 0
	owner.gunner_lock_target = null
	var bonus_damage: float = owner._get_role_damage("gunner") * (0.36 + lock_level * 0.14)
	var locked_kill := false
	locked_kill = owner._deal_damage_to_enemy(target_enemy, bonus_damage, "gunner")
	if lock_level >= 2:
		var splash_hits: int = owner._damage_enemies_in_radius(target_enemy.global_position, 26.0 + lock_level * 5.0, owner._get_role_damage("gunner") * (0.12 + lock_level * 0.03), 0.02, 1.0, 0.0)
		if splash_hits > 0:
			owner._register_attack_result("gunner", splash_hits, false)
	owner._register_attack_result("gunner", 1, locked_kill)
