extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_GUNNER_FLASH_TALENT_FLOW := preload("res://scripts/player/player_gunner_flash_talent_flow.gd")
const PLAYER_GUNNER_BASIC_TALENT_FLOW := preload("res://scripts/player/player_gunner_basic_talent_flow.gd")

const ULTIMATE_BULLET_HIT_SCAN_INTERVAL := 0.035
const BASIC_COMBO_INTERVAL := 0.12
const GUNNER_BULLET_VISUAL_SCALE := 0.4
const GUNNER_BATCHED_BULLET_VISUAL_MIN_DIAMETER := 3.2
const GUNNER_TRICK_ANGLE_STEP_DEGREES := 10.0
const ULTIMATE_SKILL_ID := "gunner_ultimate"
const ULTIMATE_DURATION := 4.0
const ULTIMATE_RANGE := 600.0
const ULTIMATE_HASTE_MOVE_SPEED_MULTIPLIER := 1.3
const ULTIMATE_HASTE_DODGE_CHANCE := 0.45
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
const ULTIMATE_LOW_FPS_VISUAL_INTERVAL := 0.11
const ULTIMATE_CRITICAL_FPS_VISUAL_INTERVAL := 0.16
const ULTIMATE_VISUAL_BULLETS_PER_PULSE := 7
const ULTIMATE_DAMAGE_OUTPUT_MULTIPLIER := 0.8
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
const BASIC_BULLET_TRAVEL_DISTANCE := 350.0
const BASIC_BULLET_VISUAL_RADIUS := 3.4
const GUNNER_REPRISE_BULLET_SIDE_OFFSET := 4.0
const GUNNER_FOLLOW_FIRE_DURATION := 1.4
const GUNNER_STEADY_AIM_DELAY := 0.45
const GUNNER_MOBILE_FIRE_RANGE_BONUS := 70.0
const GUNNER_MOBILE_FIRE_SPEED_MULTIPLIER := 1.25
const GUNNER_EXECUTION_COOLDOWN := 2.5
const GUNNER_REPULSE_COOLDOWN := 1.2
const GUNNER_DAMAGE_EVENT_TIMEOUT := 6.0
const ULTIMATE_ROCKET_BARRAGE_1 := "gunner_level_talent_rocket_barrage_1"
const ULTIMATE_ROCKET_BARRAGE_2 := "gunner_level_talent_rocket_barrage_2"

var ultimate_attack_locked: bool = false
var ultimate_attack_lock_id: int = 0
var damage_event_serial: int = 0

func perform_attack(owner) -> void:
	if ultimate_attack_locked:
		return
	if owner.is_gunner_infinite_reload_active():
		return
	var base_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var combo_scales := _get_skill_effect_scales(owner, "combo_skill_extra")
	var damage_event_id := create_damage_event_id(owner, "gunner_basic")
	if _has_talent(owner, "gunner_basic_burst"):
		register_damage_event(owner, damage_event_id, 0.5)
		_perform_combo_segment(owner, base_direction, 0.42, true, true, combo_scales, damage_event_id)
		owner._schedule_repeating_sequence(0.07, 2, func(index: int) -> void:
			if owner != null and is_instance_valid(owner) and not bool(owner.get("is_dead")):
				_perform_attack_variant(owner, base_direction, 0.42, false, false, [], damage_event_id)
			if index >= 1 and owner != null and is_instance_valid(owner):
				release_damage_event(owner, damage_event_id)
		, 0.07)
		return
	if owner.gunner_attack_chain == 3 and _has_talent(owner, "gunner_basic_armor"):
		_perform_attack_variant(owner, base_direction, 1.0, true, true, [], damage_event_id)
		return
	_perform_combo_segment(owner, base_direction, 1.0, true, true, combo_scales, damage_event_id)

func _perform_combo_segment(owner, base_direction: Vector2, combo_scale: float, allow_trick_variants: bool = true, spawn_aftershock: bool = true, reprise_scales: Array[float] = [], damage_event_id: String = "") -> void:
	_perform_attack_variant(owner, base_direction, combo_scale, true, spawn_aftershock, reprise_scales, damage_event_id)
	if allow_trick_variants:
		_apply_trick_variants(owner, base_direction, damage_event_id)

func _perform_attack_variant(owner, shot_direction: Vector2, effect_scale: float = 1.0, advance_chain: bool = true, spawn_aftershock: bool = true, reprise_scales: Array[float] = [], damage_event_id: String = "") -> void:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var focus_level: int = 0
	var barrage_attribute_level: float = 0.0
	shot_direction = shot_direction if shot_direction.length_squared() > 0.001 else Vector2.RIGHT
	shot_direction = shot_direction.normalized()
	var build_range_bonus: float = PLAYER_BUILD_SYSTEM.get_basic_attack_range_flat_bonus(owner, "gunner")
	var effective_range: float = (float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)) + build_range_bonus) * owner._get_role_attribute_range_multiplier(role_data["id"]) * owner._get_role_equipment_skill_range_multiplier(role_data["id"])
	var target_enemy: Node2D = owner._get_enemy_in_aim_cone(18.0, effective_range)
	var main_damage: float = owner._get_role_damage(role_data["id"]) * max(0.0, effect_scale) * PLAYER_BUILD_SYSTEM.get_basic_attack_damage_multiplier(owner, "gunner")
	if _has_talent(owner, "gunner_basic_steady_aim") and _get_talent_state_float(owner, "steady_aim_elapsed") >= GUNNER_STEADY_AIM_DELAY:
		main_damage *= 1.18
	if target_enemy != null:
		main_damage *= owner._get_priority_target_bonus(target_enemy)

	var bullet_color: Color = Color(1.0, 0.42, 0.34, 1.0)
	if owner._get_gunner_barrage_shotgun_wave_count(barrage_attribute_level) > 0:
		_spawn_barrage_shotgun(owner, shot_direction, main_damage, bullet_color, role_data, upgrade_data, focus_level, barrage_attribute_level, damage_event_id)
	else:
		var main_overrides: Dictionary = {}
		if advance_chain and owner.gunner_attack_chain == 3 and _has_talent(owner, "gunner_basic_armor"):
			main_overrides = {
				"damage_multiplier": 2.0,
				"hit_radius_multiplier": 1.4,
				"speed_multiplier": 0.85,
				"pierce_bonus": 4
			}
		if not _spawn_primary_batched_bullet_group(owner, shot_direction, main_damage, bullet_color, role_data, upgrade_data, focus_level, owner.global_position + shot_direction * 18.0, reprise_scales, main_overrides, damage_event_id):
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
	_perform_combo_segment(owner, base_direction, combo_scale, false, false)

func _apply_trick_variants(owner, base_direction: Vector2, damage_event_id: String = "") -> void:
	var scales: Array[float] = _get_skill_effect_scales(owner, "quantity_skill_count")
	var extra_count: int = scales.size()
	if extra_count <= 0:
		return
	var center_offset: float = (float(extra_count) - 1.0) * 0.5
	for index in range(extra_count):
		var relative_index: float = float(index) - center_offset
		if extra_count == 1:
			relative_index = 1.0
		var angle_offset: float = deg_to_rad(relative_index * GUNNER_TRICK_ANGLE_STEP_DEGREES)
		_perform_attack_variant(owner, base_direction.rotated(angle_offset), float(scales[index]), false, false, [], damage_event_id)

func _get_skill_effect_scales(owner, stat: String) -> Array[float]:
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales_for_skill"):
		return owner._get_skill_blessing_effect_scales_for_skill("gunner_basic_attack", stat)
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales"):
		return owner._get_skill_blessing_effect_scales(stat)
	return []

func _spawn_barrage_shotgun(owner, shot_direction: Vector2, main_damage: float, bullet_color: Color, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int, barrage_attribute_level: float, damage_event_id: String = "") -> void:
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
				"hit_radius_bonus": 1.0,
				"damage_event_id": damage_event_id
			})

func _spawn_primary_batched_bullet(owner, shot_direction: Vector2, damage_amount: float, bullet_color: Color, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int, origin: Vector2, overrides: Dictionary = {}) -> bool:
	damage_amount *= float(overrides.get("damage_multiplier", 1.0))
	var base_damage_amount := damage_amount
	damage_amount = PLAYER_GUNNER_BASIC_TALENT_FLOW.get_modified_basic_damage(owner, damage_amount)
	var hit_radius: float = (14.0 + float(overrides.get("hit_radius_bonus", 0.0))) * float(overrides.get("hit_radius_multiplier", 1.0))
	if _has_talent(owner, "gunner_basic_penetration"):
		hit_radius *= 1.2
	if focus_level > 0:
		hit_radius += 1.5 * focus_level
	var bullet_speed: float = _get_basic_bullet_speed(owner, role_data, focus_level) * float(overrides.get("speed_multiplier", 1.0))
	var lifetime: float = float(overrides.get("lifetime", _get_basic_bullet_lifetime(owner, bullet_speed)))
	var pierce_count: int = int(round(float(upgrade_data["range_bonus"]) / 40.0)) + focus_level + int(overrides.get("pierce_bonus", 0))
	if _has_talent(owner, "gunner_basic_penetration"):
		pierce_count += 2
	if _get_talent_state_float(owner, "follow_fire_remaining") > 0.0:
		pierce_count += 1
	var vulnerability_bonus: float = 0.06 if _has_talent(owner, "gunner_basic_mark") else 0.0
	var vulnerability_duration: float = 1.0 if vulnerability_bonus > 0.0 else 0.0
	var damage_event_id := str(overrides.get("damage_event_id", ""))
	var damage_source_id := "gunner_basic:%s" % damage_event_id if damage_event_id != "" else str(role_data["id"])
	var projectile_config := PLAYER_GUNNER_BASIC_TALENT_FLOW.build_projectile_config(owner, {
		"speed": bullet_speed,
		"lifetime": lifetime,
		"hit_radius": hit_radius,
		"visual_radius": _get_scaled_visual_radius(BASIC_BULLET_VISUAL_RADIUS),
		"visual_min_diameter": GUNNER_BATCHED_BULLET_VISUAL_MIN_DIAMETER,
		"enemy_hit_radius_scale": 0.42,
		"enemy_hit_radius_min": 10.0,
		"enemy_hit_radius_max": 28.0,
		"vulnerability_bonus": max(vulnerability_bonus, 0.04 * focus_level if focus_level > 0 else 0.0),
		"vulnerability_duration": max(vulnerability_duration, 1.0 + 0.2 * focus_level if focus_level > 0 else 0.0),
		"pierce_count": pierce_count,
		"damage_event_id": damage_event_id
	}, base_damage_amount)
	if owner.has_method("_spawn_batched_directional_bullet"):
		return bool(owner._spawn_batched_directional_bullet(
			shot_direction,
			damage_amount,
			bullet_color,
			damage_source_id,
			origin,
			projectile_config
		))
	return owner._spawn_batched_directional_bullet_values(
		shot_direction,
		damage_amount,
		bullet_color,
		damage_source_id,
		origin,
		bullet_speed,
		lifetime,
		hit_radius,
		_get_scaled_visual_radius(BASIC_BULLET_VISUAL_RADIUS),
		GUNNER_BATCHED_BULLET_VISUAL_MIN_DIAMETER,
		Color(1.0, 1.0, 1.0, 0.0),
		0.0,
		0.42,
		10.0,
		28.0,
		max(vulnerability_bonus, 0.04 * focus_level if focus_level > 0 else 0.0),
		max(vulnerability_duration, 1.0 + 0.2 * focus_level if focus_level > 0 else 0.0),
		1.0,
		0.0,
		pierce_count
	)

func _spawn_primary_batched_bullet_group(owner, shot_direction: Vector2, damage_amount: float, bullet_color: Color, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int, origin: Vector2, reprise_scales: Array[float], main_overrides: Dictionary = {}, damage_event_id: String = "") -> bool:
	var side_axis := Vector2(-shot_direction.y, shot_direction.x)
	var total_count := 1 + reprise_scales.size()
	var center_offset := (float(total_count) - 1.0) * 0.5
	var spawned := false
	for index in range(total_count):
		var scale := 1.0
		if index > 0:
			scale = float(reprise_scales[index - 1])
		var bullet_origin := origin + side_axis * ((float(index) - center_offset) * GUNNER_REPRISE_BULLET_SIDE_OFFSET)
		var overrides: Dictionary = main_overrides.duplicate() if index == 0 else {}
		overrides["damage_event_id"] = damage_event_id
		spawned = _spawn_primary_batched_bullet(owner, shot_direction, damage_amount * max(0.0, scale), bullet_color, role_data, upgrade_data, focus_level, bullet_origin, overrides) or spawned
	return spawned

func _configure_primary_bullet(owner, bullet, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int) -> void:
	bullet.speed = _get_basic_bullet_speed(owner, role_data, focus_level)
	bullet.lifetime = _get_basic_bullet_lifetime(owner, bullet.speed)
	bullet.visual_scale_multiplier *= GUNNER_BULLET_VISUAL_SCALE
	bullet.pierce_count = int(round(float(upgrade_data["range_bonus"]) / 40.0)) + focus_level
	if focus_level > 0:
		bullet.vulnerability_bonus = 0.04 * focus_level
		bullet.vulnerability_duration = 1.0 + 0.2 * focus_level
		bullet.hit_radius += 1.5 * focus_level

func _get_basic_attack_projectile_speed_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_basic_attack_projectile_speed_multiplier"):
		return float(owner._get_basic_attack_projectile_speed_multiplier("gunner_basic_attack"))
	return 1.0

func _get_basic_bullet_speed(owner, role_data: Dictionary, focus_level: int) -> float:
	var speed := (BASIC_BULLET_BASE_SPEED + BASIC_BULLET_FOCUS_SPEED_BONUS * focus_level) * _get_basic_attack_projectile_speed_multiplier(owner)
	speed += PLAYER_GUNNER_BASIC_TALENT_FLOW.get_basic_speed_bonus(owner)
	if _has_talent(owner, "gunner_basic_mobile_fire") and _is_owner_moving(owner):
		speed *= GUNNER_MOBILE_FIRE_SPEED_MULTIPLIER
	return speed

func _get_basic_bullet_lifetime(owner, bullet_speed: float) -> float:
	var travel_distance: float = BASIC_BULLET_TRAVEL_DISTANCE + PLAYER_BUILD_SYSTEM.get_basic_attack_range_flat_bonus(owner, "gunner")
	if _has_talent(owner, "gunner_basic_mobile_fire") and _is_owner_moving(owner):
		travel_distance += GUNNER_MOBILE_FIRE_RANGE_BONUS
	return travel_distance / max(1.0, bullet_speed)

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
		var target_center: Vector2 = owner._get_enemy_aim_point(target_enemy, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target_enemy.global_position
		var bullet = owner._spawn_bullet(target_enemy, owner._get_role_damage("gunner") * (0.34 + support_level * 0.06), Color(1.0, 0.58, 0.38, 0.9), "gunner", owner.global_position + owner._get_support_offset("gunner", false))
		if bullet != null:
			bullet.speed = 500.0 + 24.0 * support_level
			bullet.lifetime = 1.35
			bullet.visual_scale_multiplier *= GUNNER_BULLET_VISUAL_SCALE
			if focus_level > 0:
				bullet.vulnerability_bonus = 0.02 * focus_level
				bullet.vulnerability_duration = 0.9 + 0.16 * focus_level
		if lock_level > 0 and owner.global_position.distance_to(target_center) >= 180.0:
			owner._spawn_target_lock_effect(target_center, 16.0 + lock_level * 3.0, Color(1.0, 0.8, 0.42, 0.9), 0.18)
		if scatter_level >= 2:
			for angle_sign in [-1.0, 1.0]:
				var fire_direction: Vector2 = owner.global_position.direction_to(target_center).rotated(0.16 * angle_sign)
				var spread_bullet = owner._spawn_directional_bullet(fire_direction, owner._get_role_damage("gunner") * 0.18, Color(1.0, 0.66, 0.42, 0.86), "gunner", owner.global_position + owner._get_support_offset("gunner", false))
				if spread_bullet != null:
					spread_bullet.speed = 460.0
					spread_bullet.lifetime = 0.5
					spread_bullet.hit_radius = 10.0
					spread_bullet.visual_scale_multiplier *= GUNNER_BULLET_VISUAL_SCALE

func perform_enter(owner, role_id: String, _assault_level: int, assault_multiplier: float) -> int:
	owner._show_switch_banner("\u8FDB\u573A", "\u67AA\u706B\u5178\u793C", Color(1.0, 0.58, 0.36, 1.0))
	owner._fire_gunner_entry_wave(role_id, 0, assault_multiplier)
	var denial_talent: bool = _has_talent(owner, "gunner_entry_denial")
	var wave_count := 2 if denial_talent else 3
	var wave_interval := 0.12 if denial_talent else 0.08
	if owner.has_method("_schedule_repeating_sequence") and wave_count > 1:
		owner._schedule_repeating_sequence(wave_interval, wave_count - 1, func(index: int) -> void:
			owner._fire_gunner_entry_wave(role_id, index + 1, assault_multiplier)
		, wave_interval)
	if owner.has_method("_schedule_repeating_sequence"):
		var completion_delay := wave_interval * float(max(0, wave_count - 1)) + 0.02
		owner._schedule_repeating_sequence(completion_delay, 1, func(_index: int) -> void:
			_complete_entry_talents(owner)
		, completion_delay)
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
	var talent_snapshot := {}
	for talent_id in [
		"gunner_ultimate_line",
		"gunner_ultimate_fan",
		"gunner_ultimate_delayed_fire",
		"gunner_ultimate_calibration",
		"gunner_ultimate_sweep_suppression",
		"gunner_ultimate_terminal_guidance"
	]:
		talent_snapshot[talent_id] = _has_talent(owner, talent_id)
	var rocket_barrage_1 := _has_level_talent(owner, ULTIMATE_ROCKET_BARRAGE_1)
	var rocket_barrage_2 := _has_level_talent(owner, ULTIMATE_ROCKET_BARRAGE_2)
	talent_snapshot[ULTIMATE_ROCKET_BARRAGE_1] = rocket_barrage_1
	talent_snapshot[ULTIMATE_ROCKET_BARRAGE_2] = rocket_barrage_2
	if rocket_barrage_1:
		talent_snapshot["rocket_barrage_locked_direction"] = _get_current_ultimate_direction(owner)
	var ultimate_tier: int = _get_ultimate_skill_tier(owner)
	var cone_degrees: float = _get_ultimate_cone_degrees(ultimate_tier)
	if bool(talent_snapshot["gunner_ultimate_line"]):
		cone_degrees *= 0.4
	elif bool(talent_snapshot["gunner_ultimate_fan"]):
		cone_degrees = min(140.0, cone_degrees * 2.4)
	if rocket_barrage_1:
		cone_degrees = 20.0
	elif rocket_barrage_2:
		cone_degrees = 60.0
	var total_duration: float = ULTIMATE_DURATION
	if owner.has_method("_get_blessing_skill_duration_multiplier"):
		total_duration *= float(owner._get_blessing_skill_duration_multiplier(ULTIMATE_SKILL_ID))
	total_duration *= float(cast_payload.get("duration_multiplier", 1.0))
	if owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		total_duration += float(owner._get_blessing_skill_duration_flat_bonus(ULTIMATE_SKILL_ID))
	var base_duration := total_duration
	if bool(talent_snapshot["gunner_ultimate_delayed_fire"]):
		total_duration += 1.0
	_lock_basic_attack_during_ultimate(owner, total_duration)
	_apply_ultimate_haste(owner, total_duration)
	var old_tick_interval: float = _get_ultimate_tick_interval(ultimate_tier)
	var old_tick_count: int = max(1, int(ceil(total_duration / old_tick_interval)))
	var base_tick_count: int = _get_ultimate_damage_wave_count(total_duration, ultimate_tier)
	var tick_count: int = max(1, base_tick_count + PLAYER_BUILD_SYSTEM.get_gunner_ultimate_wave_bonus(owner))
	if rocket_barrage_1 or rocket_barrage_2:
		tick_count += 2
	var tick_interval: float = total_duration / float(max(1, tick_count))
	var damage_wave_multiplier: float = float(old_tick_count) / float(max(1, base_tick_count))
	var cast_damage_multiplier: float = float(cast_payload.get("damage_multiplier", 1.0)) * _get_ultimate_damage_multiplier(owner)
	if bool(talent_snapshot["gunner_ultimate_line"]):
		cast_damage_multiplier *= 1.55
	elif bool(talent_snapshot["gunner_ultimate_fan"]):
		cast_damage_multiplier *= 0.70
	var visual_interval: float = _get_ultimate_visual_interval()
	var visual_count: int = max(1, int(ceil(total_duration / visual_interval)))
	owner._queue_camera_shake(17.5, 0.54)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.5)
	owner._delay_level_up_requests(total_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "火箭弹幕", Color(1.0, 0.86, 0.5, 1.0))
	var calibration_state := {
		"anchor": owner._get_live_mouse_aim_direction(owner.facing_direction).normalized(),
		"stable_elapsed": 0.0,
		"calibrated": false
	}
	owner._schedule_repeating_sequence(tick_interval, tick_count, func(tick_index: int) -> void:
		var elapsed := tick_interval * float(tick_index + 1)
		var delayed_multiplier := 0.70 if elapsed > base_duration else 1.0
		_apply_ultimate_cone_damage(owner, barrage_level, focus_level, cone_degrees, cast_damage_multiplier * damage_wave_multiplier * delayed_multiplier, ultimate_tier, tick_index, tick_interval, calibration_state, talent_snapshot)
	)
	owner._schedule_repeating_sequence(visual_interval, visual_count, func(visual_index: int) -> void:
		_spawn_ultimate_cone_visuals(owner, barrage_level, focus_level, scatter_level, cone_degrees, visual_index, talent_snapshot)
	)
	owner._apply_post_ultimate_bonuses("gunner", total_duration)

func _apply_ultimate_haste(owner, total_duration: float) -> void:
	var special_multiplier: float = _get_ultimate_special_effect_multiplier(owner)
	owner.ultimate_haste_remaining = max(owner.ultimate_haste_remaining, total_duration)
	owner.ultimate_haste_move_speed_multiplier = 1.0 + (ULTIMATE_HASTE_MOVE_SPEED_MULTIPLIER - 1.0) * special_multiplier
	owner.ultimate_haste_dodge_chance = ULTIMATE_HASTE_DODGE_CHANCE * special_multiplier

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

func _apply_ultimate_cone_damage(owner, barrage_level: int, focus_level: int, cone_degrees: float, cast_damage_multiplier: float, ultimate_tier: int, tick_index: int, tick_interval: float = 0.0, calibration_state: Dictionary = {}, talent_snapshot: Dictionary = {}) -> void:
	if owner.is_dead:
		return
	var origin: Vector2 = owner.global_position
	var direction: Vector2 = _get_ultimate_wave_direction(owner, talent_snapshot)
	owner.facing_direction = direction
	if _talent_enabled(owner, talent_snapshot, "gunner_ultimate_calibration"):
		_update_ultimate_calibration(direction, max(0.0, tick_interval), calibration_state)
		if bool(calibration_state.get("calibrated", false)):
			cast_damage_multiplier *= 1.18
	var range_value: float = _get_ultimate_cone_range(owner, talent_snapshot)
	var rocket_ratio_bonus := 0.0
	if bool(talent_snapshot.get(ULTIMATE_ROCKET_BARRAGE_1, false)):
		rocket_ratio_bonus = 0.10
	elif bool(talent_snapshot.get(ULTIMATE_ROCKET_BARRAGE_2, false)):
		rocket_ratio_bonus = -0.10
	var damage_multiplier: float = (ULTIMATE_DAMAGE_BASE_RATIO + float(barrage_level) * ULTIMATE_DAMAGE_BARRAGE_RATIO + float(focus_level) * ULTIMATE_DAMAGE_FOCUS_RATIO + rocket_ratio_bonus) * cast_damage_multiplier * ULTIMATE_DAMAGE_OUTPUT_MULTIPLIER
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
	if hits > 0 and _talent_enabled(owner, talent_snapshot, "gunner_ultimate_sweep_suppression"):
		_repulse_first_ordinary_enemy_in_cone(owner, origin, direction, range_value, cone_degrees, 24.0)
	if (tick_index + 1) % 4 == 0 and _talent_enabled(owner, talent_snapshot, "gunner_ultimate_terminal_guidance"):
		_apply_terminal_guidance(owner, origin, direction, range_value, cone_degrees, owner._get_role_damage("gunner") * damage_multiplier * 0.55)
	if tick_index % 3 == 0:
		owner._queue_camera_shake(3.8 + float(barrage_level) * 0.18, 0.08)

func _update_ultimate_calibration(direction: Vector2, delta: float, state: Dictionary) -> void:
	var anchor: Vector2 = state.get("anchor", direction)
	if anchor.length_squared() <= 0.001:
		anchor = direction
	if abs(anchor.angle_to(direction)) > deg_to_rad(6.0):
		state["anchor"] = direction
		state["stable_elapsed"] = 0.0
		state["calibrated"] = false
		return
	var stable_elapsed := float(state.get("stable_elapsed", 0.0)) + delta
	state["stable_elapsed"] = stable_elapsed
	state["calibrated"] = stable_elapsed >= 0.5

func _repulse_first_ordinary_enemy_in_cone(owner, origin: Vector2, direction: Vector2, range_value: float, cone_degrees: float, distance: float) -> void:
	for enemy in _get_enemies_in_cone(owner, origin, direction, range_value, cone_degrees):
		if str(enemy.get("enemy_kind")) != "normal":
			continue
		var push_direction := direction
		if enemy.global_position.distance_squared_to(origin) > 0.001:
			push_direction = origin.direction_to(enemy.global_position)
		enemy.global_position += push_direction * distance
		return

func _apply_terminal_guidance(owner, origin: Vector2, direction: Vector2, range_value: float, cone_degrees: float, damage_amount: float) -> void:
	var target: Node2D = null
	var nearest_distance := INF
	for enemy in _get_enemies_in_cone(owner, origin, direction, range_value, cone_degrees):
		if str(enemy.get("enemy_kind")) not in ["elite", "boss", "small_boss"]:
			continue
		var distance_squared := origin.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance:
			nearest_distance = distance_squared
			target = enemy
	if target != null:
		owner._deal_damage_to_enemy(target, damage_amount, "gunner")

func _get_enemies_in_cone(owner, origin: Vector2, direction: Vector2, range_value: float, cone_degrees: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if owner == null or not owner.has_method("_get_live_enemies"):
		return result
	var max_angle := deg_to_rad(cone_degrees) * 0.5
	for enemy_value in owner._get_live_enemies():
		var enemy := enemy_value as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		var offset := enemy.global_position - origin
		if offset.length() > range_value or (offset.length_squared() > 0.001 and abs(direction.angle_to(offset.normalized())) > max_angle):
			continue
		result.append(enemy)
	return result

func _spawn_ultimate_cone_visuals(owner, barrage_level: int, focus_level: int, scatter_level: int, cone_degrees: float, visual_index: int, talent_snapshot: Dictionary = {}) -> void:
	if owner.is_dead:
		return
	var direction: Vector2 = _get_ultimate_wave_direction(owner, talent_snapshot)
	var range_value: float = _get_ultimate_cone_range(owner, talent_snapshot)
	var bullet_speed: float = ULTIMATE_VISUAL_BULLET_SPEED + focus_level * ULTIMATE_VISUAL_FOCUS_SPEED_BONUS + barrage_level * ULTIMATE_VISUAL_BARRAGE_SPEED_BONUS
	var bullet_lifetime: float = max(0.20, range_value / bullet_speed)
	var bullet_count: int = _get_ultimate_visual_bullets_per_pulse() + min(3, barrage_level) + min(2, scatter_level)
	for bullet_index in range(bullet_count):
		var ratio: float = 0.5 if bullet_count <= 1 else float(bullet_index) / float(bullet_count - 1)
		var centered_ratio: float = ratio * 2.0 - 1.0
		var shot_direction: Vector2 = direction.rotated(deg_to_rad(cone_degrees) * 0.5 * centered_ratio)
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

func _get_ultimate_cone_range(owner, talent_snapshot: Dictionary = {}) -> float:
	var base_range: float = ULTIMATE_RANGE
	var role_range_multiplier: float = owner._get_role_attribute_range_multiplier("gunner") * owner._get_role_equipment_skill_range_multiplier("gunner")
	base_range *= role_range_multiplier
	base_range *= role_range_multiplier
	if _talent_enabled(owner, talent_snapshot, "gunner_ultimate_line"):
		base_range *= 1.3
	elif _talent_enabled(owner, talent_snapshot, "gunner_ultimate_fan"):
		base_range *= 0.85
	return max(220.0, base_range)

func _talent_enabled(owner, talent_snapshot: Dictionary, talent_id: String) -> bool:
	return bool(talent_snapshot.get(talent_id, _has_talent(owner, talent_id)))

func _has_level_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_level_talent") and bool(owner._has_level_talent(talent_id))

func _get_current_ultimate_direction(owner) -> Vector2:
	var direction: Vector2 = owner._get_live_mouse_aim_direction(owner.facing_direction)
	if direction.length_squared() <= 0.001:
		direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	return direction.normalized()

func _get_ultimate_wave_direction(owner, talent_snapshot: Dictionary) -> Vector2:
	if bool(talent_snapshot.get(ULTIMATE_ROCKET_BARRAGE_1, false)):
		var locked_direction: Vector2 = talent_snapshot.get("rocket_barrage_locked_direction", Vector2.ZERO)
		if locked_direction.length_squared() > 0.001:
			return locked_direction.normalized()
	return _get_current_ultimate_direction(owner)

func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))

func _get_ultimate_skill_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return max(1, int(owner._get_blessing_skill_tier(ULTIMATE_SKILL_ID)))
	return 1

func _get_ultimate_cone_degrees(ultimate_tier: int) -> float:
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

func _get_ultimate_visual_interval() -> float:
	var fps: int = Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return ULTIMATE_CRITICAL_FPS_VISUAL_INTERVAL
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return ULTIMATE_LOW_FPS_VISUAL_INTERVAL
	return ULTIMATE_VISUAL_INTERVAL

func _get_ultimate_visual_bullets_per_pulse() -> int:
	var fps: int = Engine.get_frames_per_second()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return max(3, int(ceil(float(ULTIMATE_VISUAL_BULLETS_PER_PULSE) * 0.5)))
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return max(4, int(ceil(float(ULTIMATE_VISUAL_BULLETS_PER_PULSE) * 0.7)))
	return ULTIMATE_VISUAL_BULLETS_PER_PULSE

func _get_ultimate_damage_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_blessing_ultimate_damage_multiplier"):
		return float(owner._get_blessing_ultimate_damage_multiplier(ULTIMATE_SKILL_ID))
	return 1.0

func _get_ultimate_special_effect_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_blessing_ultimate_special_effect_multiplier"):
		return max(0.0, float(owner._get_blessing_ultimate_special_effect_multiplier(ULTIMATE_SKILL_ID)))
	return 1.0

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
	var normal_pierce_count: int = int(round(float(upgrade_data.get("range_bonus", 0.0)) / 40.0)) + focus_level
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
		var splash_center: Vector2 = owner._get_enemy_aim_point(target_enemy, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target_enemy.global_position
		var splash_hits: int = owner._damage_enemies_in_radius(splash_center, 26.0 + lock_level * 5.0, owner._get_role_damage("gunner") * (0.12 + lock_level * 0.03), 0.02, 1.0, 0.0, "gunner")
		if splash_hits > 0:
			owner._register_attack_result("gunner", splash_hits, false)
	owner._register_attack_result("gunner", 1, locked_kill)

func update_talent_states(owner, delta: float) -> void:
	if owner == null or delta <= 0.0:
		return
	var state := _get_talent_state(owner)
	state["follow_fire_remaining"] = max(0.0, float(state.get("follow_fire_remaining", 0.0)) - delta)
	state["escape_step_remaining"] = max(0.0, float(state.get("escape_step_remaining", 0.0)) - delta)
	state["execution_cooldown_remaining"] = max(0.0, float(state.get("execution_cooldown_remaining", 0.0)) - delta)
	var damage_events: Dictionary = state.get("damage_events", {})
	for event_id_value in damage_events.keys():
		var event_id := str(event_id_value)
		var event_state: Dictionary = damage_events[event_id]
		event_state["remaining"] = max(0.0, float(event_state.get("remaining", 0.0)) - delta)
		if float(event_state["remaining"]) <= 0.0:
			damage_events.erase(event_id)
	state["damage_events"] = damage_events
	if str(owner._get_active_role().get("id", "")) == "gunner" and not _is_owner_moving(owner):
		state["steady_aim_elapsed"] = min(GUNNER_STEADY_AIM_DELAY, float(state.get("steady_aim_elapsed", 0.0)) + delta)
	else:
		state["steady_aim_elapsed"] = 0.0

func get_basic_attack_interval_multiplier(owner) -> float:
	return 0.75 if _get_talent_state_float(owner, "follow_fire_remaining") > 0.0 else 1.0

func get_talent_move_speed_multiplier(owner) -> float:
	return 1.35 if _get_talent_state_float(owner, "escape_step_remaining") > 0.0 else 1.0

func handle_damage_taken(owner) -> void:
	if not _has_talent(owner, "gunner_trait_escape_step") or int(owner.get("gunner_flash_stacks")) < 5:
		return
	_get_talent_state(owner)["escape_step_remaining"] = 1.5

func consume_damage_event_multiplier(owner, source_role_id: String) -> float:
	if owner == null or source_role_id != "gunner":
		return 1.0
	var state := _get_talent_state(owner)
	if _has_talent(owner, "gunner_trait_execution") and PLAYER_GUNNER_FLASH_TALENT_FLOW.get_active_flash_stacks(owner) >= 10 and float(state.get("execution_cooldown_remaining", 0.0)) <= 0.0:
		if not PLAYER_GUNNER_FLASH_TALENT_FLOW.consume_flash_stacks(owner, 5):
			return 1.0
		state["execution_cooldown_remaining"] = GUNNER_EXECUTION_COOLDOWN
		return 1.6
	return 1.0

func create_damage_event_id(owner, prefix: String = "gunner") -> String:
	damage_event_serial += 1
	var owner_id: int = owner.get_instance_id() if owner != null and is_instance_valid(owner) else 0
	return "%s:%s:%s" % [prefix, owner_id, damage_event_serial]

func register_damage_event(owner, event_id: String, lifetime: float) -> void:
	if owner == null or event_id == "":
		return
	var state := _get_talent_state(owner)
	var damage_events: Dictionary = state.get("damage_events", {})
	var event_state: Dictionary = damage_events.get(event_id, {})
	event_state["refs"] = int(event_state.get("refs", 0)) + 1
	event_state["remaining"] = max(float(event_state.get("remaining", 0.0)), max(lifetime, GUNNER_DAMAGE_EVENT_TIMEOUT))
	damage_events[event_id] = event_state
	state["damage_events"] = damage_events

func release_damage_event(owner, event_id: String) -> void:
	if owner == null or event_id == "":
		return
	var state := _get_talent_state(owner)
	var damage_events: Dictionary = state.get("damage_events", {})
	if not damage_events.has(event_id):
		return
	var event_state: Dictionary = damage_events[event_id]
	var refs: int = max(0, int(event_state.get("refs", 1)) - 1)
	if refs <= 0:
		damage_events.erase(event_id)
	else:
		event_state["refs"] = refs
		damage_events[event_id] = event_state
	state["damage_events"] = damage_events

func get_or_lock_damage_event_multiplier(owner, source_role_id: String, event_id: String) -> float:
	if event_id == "":
		return consume_damage_event_multiplier(owner, source_role_id)
	var state := _get_talent_state(owner)
	var damage_events: Dictionary = state.get("damage_events", {})
	var event_state: Dictionary = damage_events.get(event_id, {
		"refs": 0,
		"remaining": GUNNER_DAMAGE_EVENT_TIMEOUT
	})
	if event_state.has("multiplier"):
		return float(event_state["multiplier"])
	var multiplier := consume_damage_event_multiplier(owner, source_role_id)
	event_state["multiplier"] = multiplier
	event_state["remaining"] = max(float(event_state.get("remaining", 0.0)), GUNNER_DAMAGE_EVENT_TIMEOUT)
	damage_events[event_id] = event_state
	state["damage_events"] = damage_events
	return multiplier

func apply_damage_target_talents(owner, enemy: Node2D, source_role_id: String, _source_position: Variant = null) -> void:
	if owner == null or enemy == null or not is_instance_valid(enemy) or source_role_id != "gunner":
		return
	var origin: Vector2 = owner.global_position
	var safe_radius: float = float(owner._get_gunner_safe_zone_radius()) if owner.has_method("_get_gunner_safe_zone_radius") else 0.0
	var distance := origin.distance_to(enemy.global_position)
	if _has_talent(owner, "gunner_trait_far_calibration") and distance > safe_radius and enemy.has_method("apply_vulnerability"):
		enemy.apply_vulnerability(0.06, 0.8)
	if _has_talent(owner, "gunner_trait_repulse") and distance <= safe_radius:
		_try_repulse_trait_enemy(owner, enemy)

func _try_repulse_trait_enemy(owner, enemy: Node2D) -> void:
	if str(enemy.get("enemy_kind")) in ["boss", "small_boss"]:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < float(enemy.get_meta("gunner_trait_repulse_ready", 0.0)):
		return
	enemy.set_meta("gunner_trait_repulse_ready", now + GUNNER_REPULSE_COOLDOWN)
	var push_direction: Vector2 = (owner as Node2D).global_position.direction_to(enemy.global_position)
	if push_direction.length_squared() <= 0.001:
		push_direction = Vector2.RIGHT
	enemy.global_position += push_direction * 42.0

func _complete_entry_talents(owner) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	if _has_talent(owner, "gunner_entry_follow_fire"):
		_get_talent_state(owner)["follow_fire_remaining"] = GUNNER_FOLLOW_FIRE_DURATION
	if _has_talent(owner, "gunner_entry_hot_start"):
		for ability_name in ["gunner_shrapnel_field_ability", "gunner_infinite_reload_ability"]:
			var ability = owner.get(ability_name)
			if ability == null:
				continue
			var remaining: float = max(0.0, float(ability.get("cooldown_remaining")))
			ability.set("cooldown_remaining", max(0.0, remaining - min(4.0, remaining * 0.25)))

func _get_talent_state(owner) -> Dictionary:
	if owner == null or not owner.has_method("_get_role_special_state"):
		return {}
	var role_state: Dictionary = owner._get_role_special_state("gunner")
	if not role_state.has("talent_runtime"):
		role_state["talent_runtime"] = {}
	return role_state["talent_runtime"]

func _get_talent_state_float(owner, key: String) -> float:
	return float(_get_talent_state(owner).get(key, 0.0))

func _is_owner_moving(owner) -> bool:
	return owner != null and owner is CharacterBody2D and (owner as CharacterBody2D).velocity.length_squared() > 1.0
