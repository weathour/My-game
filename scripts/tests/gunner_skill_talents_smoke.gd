extends SceneTree

const GunnerRole := preload("res://scripts/player/roles/gunner_role.gd")
const InfiniteReload := preload("res://scripts/abilities/gunner_infinite_reload_ability.gd")
const ShrapnelField := preload("res://scripts/abilities/gunner_shrapnel_field_ability.gd")
const GunnerEntryTalentFlow := preload("res://scripts/player/player_gunner_entry_talent_flow.gd")
const SwitchEntryFlow := preload("res://scripts/player/player_switch_entry_flow.gd")


func _init() -> void:
	var owner := TalentOwner.new()
	root.add_child(owner)
	var role := GunnerRole.new()

	owner.talents = {
		"gunner_basic_mark": true,
		"gunner_basic_penetration": true,
		"gunner_basic_mobile_fire": true
	}
	owner.velocity = Vector2.RIGHT * 10.0
	role._spawn_primary_batched_bullet(owner, Vector2.RIGHT, 10.0, Color.WHITE, {"id": "gunner"}, {"range_bonus": 0.0}, 0, Vector2.ZERO)
	assert(is_equal_approx(float(owner.last_projectile.get("vulnerability_bonus", 0.0)), 0.06))
	assert(int(owner.last_projectile.get("pierce_count", 0)) == 2)
	assert(is_equal_approx(float(owner.last_projectile.get("hit_radius", 0.0)), 16.8))
	assert(is_equal_approx(float(owner.last_projectile.get("speed", 0.0)), 950.0))

	owner.talents = {"gunner_entry_piercing": true}
	owner.projectiles.clear()
	SwitchEntryFlow.fire_gunner_entry_wave(owner, "gunner", 0)
	assert(owner.projectiles.size() == 8)
	assert(int(owner.projectiles[0].get("pierce_count", 0)) == 12)
	var entry_enemy := TalentEnemy.new()
	entry_enemy.global_position = Vector2(100.0, 0.0)
	root.add_child(entry_enemy)
	owner.runtime_enemies = [entry_enemy]
	owner.talents = {"gunner_entry_repulse": true}
	SwitchEntryFlow.fire_gunner_entry_wave(owner, "gunner", 0)
	assert(is_equal_approx(entry_enemy.global_position.x, 100.0))

	owner.talents = {"gunner_shrapnel_rend": true, "gunner_shrapnel_quick_throw": true}
	var shrapnel := ShrapnelField.new()
	assert(is_equal_approx(shrapnel._get_cooldown(owner), 10.92))
	assert(is_equal_approx(shrapnel._get_duration(owner), 3.2))
	shrapnel._damage_field(owner, {"center": Vector2.ZERO, "radius": 50.0, "effect_scale": 1.0})
	assert(is_equal_approx(float(owner.last_radius_damage.get("vulnerability_bonus", 0.0)), 0.05))
	owner.talents = {"gunner_shrapnel_snare": true}
	shrapnel._apply_snare_tail(owner, entry_enemy)
	assert(is_equal_approx(entry_enemy.slow_multiplier, 0.75))
	assert(is_equal_approx(entry_enemy.slow_timer, 0.65))
	var shrapnel_enemies: Array = []
	for shrapnel_enemy_position in [Vector2(0.0, 0.0), Vector2(420.0, 40.0), Vector2(840.0, -20.0)]:
		var shrapnel_enemy := TalentEnemy.new()
		shrapnel_enemy.global_position = shrapnel_enemy_position
		root.add_child(shrapnel_enemy)
		shrapnel_enemies.append(shrapnel_enemy)
	owner.runtime_enemies = shrapnel_enemies
	owner.forced_cluster_centers = [Vector2.ZERO]
	seed(240810)
	var shrapnel_centers: Array = shrapnel._get_field_centers(owner, 3)
	assert(shrapnel_centers.size() == 3)
	for center_value in shrapnel_centers:
		assert(center_value is Vector2)
		var center := center_value as Vector2
		var nearest_enemy_distance := INF
		for shrapnel_enemy_value in shrapnel_enemies:
			var shrapnel_enemy := shrapnel_enemy_value as Node2D
			nearest_enemy_distance = min(nearest_enemy_distance, center.distance_to(shrapnel_enemy.global_position))
		assert(nearest_enemy_distance <= 121.0)
	for first_index in range(shrapnel_centers.size()):
		for second_index in range(first_index + 1, shrapnel_centers.size()):
			assert((shrapnel_centers[first_index] as Vector2).distance_to(shrapnel_centers[second_index] as Vector2) > 150.0)
	for shrapnel_enemy_value in shrapnel_enemies:
		(shrapnel_enemy_value as Node).queue_free()
	owner.runtime_enemies = [entry_enemy]
	owner.forced_cluster_centers.clear()
	owner.level_talents = {
		"gunner_level_talent_shrapnel_1": true,
		"gunner_level_talent_shrapnel_2": true
	}
	assert(shrapnel._get_base_field_count(owner, false) == 4)
	assert(shrapnel._get_base_field_count(owner, true) == 4)
	assert(is_equal_approx(shrapnel._get_radius(owner), 150.0 * sqrt(1.2)))
	assert(is_equal_approx(shrapnel._get_uncompressed_duration(owner), 4.0))
	assert(is_equal_approx(shrapnel._get_duration(owner), 1.0))
	assert(is_equal_approx(shrapnel._get_field_tick_interval(owner), 0.15))
	assert(is_equal_approx(shrapnel._get_damage(owner), 4.5))
	shrapnel._damage_field(owner, {
		"center": Vector2.ZERO,
		"radius": 50.0,
		"effect_scale": 1.0,
		"damage": shrapnel._get_damage(owner),
		"slow_multiplier": 0.7,
		"talent_ids": ["gunner_level_talent_shrapnel_2"]
	})
	assert(is_equal_approx(float(owner.last_radius_damage.get("damage", 0.0)), 4.5))
	assert(is_equal_approx(float(owner.last_radius_damage.get("slow_duration", 0.0)), 3.0))
	owner.level_talents.clear()

	owner.talents = {"gunner_infinite_sear": true}
	var infinite := InfiniteReload.new()
	infinite._apply_piercing_beam_damage(owner, Vector2.ZERO, Vector2.RIGHT, 100.0, 20.0, 30.0)
	assert(is_equal_approx(float(owner.last_shapes[0].get("vulnerability_bonus", 0.0)), 0.06))
	assert(is_equal_approx(float(owner.last_shapes[0].get("vulnerability_duration", 0.0)), 0.45))
	owner.talents = {"gunner_infinite_recycle": true}
	infinite.cooldown_remaining = 10.0
	infinite.hit_during_cast = true
	infinite._finish_cast(owner)
	assert(is_equal_approx(infinite.cooldown_remaining, 8.5))
	infinite.last_tick_data = {"origin": Vector2(1.0, 2.0), "direction": Vector2.RIGHT, "length": 30.0, "width": 4.0, "damage": 5.0}
	var infinite_save := infinite.get_save_data()
	assert(JSON.stringify(infinite_save).contains("\"origin\":[1.0,2.0]"))
	var restored_infinite := InfiniteReload.new()
	restored_infinite.apply_save_data(infinite_save)
	assert((restored_infinite.last_tick_data.get("origin", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(1.0, 2.0)))
	restored_infinite.apply_save_data({"cooldown_remaining": 21.0})
	assert(is_equal_approx(restored_infinite.cooldown_remaining, 21.0))

	owner.talents = {}
	owner.level_talents = {"gunner_level_talent_infinite_reload_2": true}
	owner.last_shapes.clear()
	var infinite_two := InfiniteReload.new()
	assert(is_equal_approx(infinite_two._get_duration(owner), 4.0 + 1.0))
	assert(is_equal_approx(infinite_two._get_cooldown(owner), 32.0 + 1.0))
	infinite_two._start_cast(owner, false)
	infinite_two._trigger_tick(owner)
	infinite_two._update_pending_beam_hits(owner, 0.2)
	assert(owner.last_shapes.size() == 2)
	assert(is_equal_approx(float(owner.last_shapes[0].get("length", 0.0)), 450.0))
	infinite_two.stop(owner)
	owner.level_talents.clear()

	owner.last_shapes.clear()
	var sync_infinite := InfiniteReload.new()
	var sync_shapes: Array[Dictionary] = [{
		"type": "oriented_rect",
		"center": Vector2(50.0, 0.0),
		"axis": Vector2.RIGHT,
		"length": 100.0,
		"width": 20.0,
		"damage_amount": 30.0,
		"vulnerability_bonus": 0.0,
		"vulnerability_duration": 0.0,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"source_position": Vector2.ZERO,
		"source_role_id": "gunner"
	}]
	sync_infinite._queue_piercing_beam_shapes(owner, sync_shapes)
	sync_shapes[0]["axis"] = Vector2.DOWN
	assert(owner.last_shapes.is_empty())
	sync_infinite._update_pending_beam_hits(owner, 0.19)
	assert(owner.last_shapes.is_empty())
	sync_infinite._update_pending_beam_hits(owner, 0.02)
	assert(owner.last_shapes.size() == 1)
	assert((owner.last_shapes[0].get("axis", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.RIGHT))
	assert(sync_infinite.hit_during_cast)

	owner.talents = {"gunner_entry_hot_start": true, "gunner_entry_follow_fire": true}
	owner.gunner_shrapnel_field_ability.cooldown_remaining = 8.0
	owner.gunner_infinite_reload_ability.cooldown_remaining = 20.0
	role._complete_entry_talents(owner)
	assert(is_equal_approx(owner.gunner_shrapnel_field_ability.cooldown_remaining, 6.0))
	assert(is_equal_approx(owner.gunner_infinite_reload_ability.cooldown_remaining, 16.0))
	assert(is_equal_approx(role.get_basic_attack_interval_multiplier(owner), 0.75))

	var calibration := {"anchor": Vector2.RIGHT, "stable_elapsed": 0.0, "calibrated": false}
	role._update_ultimate_calibration(Vector2.RIGHT, 0.5, calibration)
	assert(bool(calibration.get("calibrated", false)))
	role._update_ultimate_calibration(Vector2.DOWN, 0.1, calibration)
	assert(not bool(calibration.get("calibrated", true)))

	owner.talents = {}
	owner.level_talents = {"gunner_level_talent_rocket_barrage_1": true}
	owner.projectiles.clear()
	owner.last_cone_damage.clear()
	owner.scheduled_counts.clear()
	owner.mouse_aim_direction = Vector2.RIGHT
	owner.mouse_direction_after_schedule = Vector2.DOWN
	role.perform_ultimate(owner, {})
	owner.mouse_direction_after_schedule = Vector2.ZERO
	assert(owner.scheduled_counts.has(21))
	assert((owner.last_cone_damage.get("direction", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.RIGHT))
	assert(is_equal_approx(rad_to_deg(float(owner.last_cone_damage.get("angle", 0.0))), 20.0))
	var locked_mid_index := int(owner.projectiles.size() / 2)
	var locked_visual_direction := owner.projectiles[locked_mid_index].get("direction", Vector2.ZERO) as Vector2
	assert(abs(Vector2.RIGHT.angle_to(locked_visual_direction)) <= deg_to_rad(10.1))
	assert(is_equal_approx(float(owner.last_cone_damage.get("damage_amount", 0.0)), 10.0 * (2.1 + 0.10) * (12.0 / 19.0) * 0.8))

	owner.level_talents = {"gunner_level_talent_rocket_barrage_2": true}
	owner.projectiles.clear()
	owner.last_cone_damage.clear()
	owner.scheduled_counts.clear()
	owner.mouse_aim_direction = Vector2.RIGHT
	owner.mouse_direction_after_schedule = Vector2.DOWN
	role.perform_ultimate(owner, {})
	owner.mouse_direction_after_schedule = Vector2.ZERO
	assert(owner.scheduled_counts.has(21))
	assert((owner.last_cone_damage.get("direction", Vector2.ZERO) as Vector2).is_equal_approx(Vector2.DOWN))
	assert(is_equal_approx(rad_to_deg(float(owner.last_cone_damage.get("angle", 0.0))), 60.0))
	assert(is_equal_approx(float(owner.last_cone_damage.get("damage_amount", 0.0)), 10.0 * (2.1 - 0.10) * (12.0 / 19.0) * 0.8))

	owner.level_talents = {"gunner_level_talent_gunfire_ceremony_1": true}
	owner.projectiles.clear()
	SwitchEntryFlow.fire_gunner_entry_wave(owner, "gunner", 0)
	assert(owner.projectiles.size() == 8)
	assert(is_equal_approx(float(owner.projectiles[0].get("damage", 0.0)), 25.0))
	GunnerEntryTalentFlow.on_enemy_killed(owner, "gunner", "gunner_entry:1")
	assert(is_equal_approx(GunnerEntryTalentFlow.get_gunner_damage_multiplier(owner, "gunner"), 1.01))
	GunnerEntryTalentFlow.tick(owner, 5.0)
	assert(is_equal_approx(GunnerEntryTalentFlow.get_gunner_damage_multiplier(owner, "gunner"), 1.0))

	owner.level_talents = {"gunner_level_talent_gunfire_ceremony_2": true}
	var shred_enemy := TalentEnemy.new()
	root.add_child(shred_enemy)
	GunnerEntryTalentFlow.on_entry_attack_hit(owner, shred_enemy, "gunner_entry:2")
	var shred_entries: Array = shred_enemy.get_meta("gunner_timed_armor_shred_entries", [])
	assert(shred_entries.size() == 1)
	assert(is_equal_approx(float((shred_entries[0] as Dictionary).get("value", 0.0)), 50.0))
	shred_enemy.queue_free()
	owner.level_talents.clear()

	owner.talents = {"gunner_trait_execution": true}
	owner.gunner_flash_stacks = 10
	var enemy := TalentEnemy.new()
	root.add_child(enemy)
	assert(is_equal_approx(role.consume_damage_event_multiplier(owner, "gunner"), 1.6))
	assert(owner.gunner_flash_stacks == 5)

	enemy.queue_free()
	owner.queue_free()
	print("GUNNER_SKILL_TALENTS_SMOKE_OK")
	quit(0)


class TalentAbility:
	extends RefCounted
	var cooldown_remaining := 0.0


class TalentEnemy:
	extends Node2D
	var enemy_kind := "normal"
	var vulnerability_bonus := 0.0
	var slow_multiplier := 1.0
	var slow_timer := 0.0
	func apply_vulnerability(value: float, _duration: float) -> void:
		vulnerability_bonus = value
	func apply_slow(value: float, duration: float) -> void:
		slow_multiplier = min(slow_multiplier, value)
		slow_timer = max(slow_timer, duration)


class TalentOwner:
	extends CharacterBody2D

	var talents: Dictionary = {}
	var role_special_states := {"gunner": {"build_levels": {}}}
	var last_projectile: Dictionary = {}
	var projectiles: Array[Dictionary] = []
	var last_radius_damage: Dictionary = {}
	var last_cone_damage: Dictionary = {}
	var last_shapes: Array[Dictionary] = []
	var scheduled_counts: Array[int] = []
	var mouse_direction_after_schedule := Vector2.ZERO
	var facing_direction := Vector2.RIGHT
	var mouse_aim_direction := Vector2.RIGHT
	var last_tag := ""
	var gunner_flash_stacks := 0
	var gunner_attack_chain := 0
	var gunner_shrapnel_field_ability := TalentAbility.new()
	var gunner_infinite_reload_ability = InfiniteReload.new()
	var runtime_enemies: Array = []
	var forced_cluster_centers: Array = []
	var level_talents: Dictionary = {}
	var blessing_skill_state: Dictionary = {}
	var active_role_id := "gunner"
	var level_up_active := false
	var is_dead := false
	var attack_count := 0
	var ultimate_haste_remaining := 0.0
	var ultimate_haste_move_speed_multiplier := 1.0
	var ultimate_haste_dodge_chance := 0.0
	var switch_invulnerability_remaining := 0.0
	const GUNNER_INTERSECT_VISUAL_SCALE := 1.0

	func _has_skill_talent(talent_id: String) -> bool:
		return bool(talents.get(talent_id, false))

	func _has_level_talent(talent_id: String) -> bool:
		return bool(level_talents.get(talent_id, false))

	func _is_blessing_skill_unlocked(skill_id: String) -> bool:
		return bool((blessing_skill_state.get("unlocked", {}) as Dictionary).get(skill_id, false))

	func _get_role_special_state(role_id: String) -> Dictionary:
		if not role_special_states.has(role_id):
			role_special_states[role_id] = {}
		return role_special_states[role_id]

	func _get_active_role() -> Dictionary:
		return {"id": active_role_id}

	func _get_role_damage(_role_id: String) -> float:
		return 10.0

	func _get_role_attribute_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_role_equipment_skill_range_multiplier(_role_id: String) -> float:
		return 1.0

	func _get_equipment_skill_range_multiplier() -> float:
		return 1.0

	func _get_infinite_reload_range_multiplier() -> float:
		return 1.0

	func _get_equipment_cooldown_multiplier() -> float:
		return 1.0

	func _get_blessing_skill_combo_scales(_skill_id: String) -> Array:
		return []

	func _get_blessing_skill_duration_multiplier(_skill_id: String) -> float:
		return 1.0

	func _get_blessing_skill_duration_flat_bonus(_skill_id: String) -> float:
		return 0.0

	func _get_live_mouse_aim_direction(fallback_direction: Vector2) -> Vector2:
		return mouse_aim_direction if mouse_aim_direction.length_squared() > 0.001 else fallback_direction

	func _get_downward_perpendicular(direction: Vector2) -> Vector2:
		return Vector2(-direction.y, direction.x)

	func _get_gunner_intersect_gather_duration() -> float:
		return 0.2

	func _get_gunner_safe_zone_radius() -> float:
		return 115.0

	func _get_live_enemies() -> Array:
		return runtime_enemies

	func _get_random_enemy_cluster_centers(count: int) -> Array:
		if forced_cluster_centers.is_empty():
			return []
		var result: Array = forced_cluster_centers.duplicate()
		while result.size() < count:
			result.append(forced_cluster_centers[0])
		return result

	func _get_blessing_skill_tier(_skill_id: String) -> int:
		return 1

	func _queue_camera_shake(_strength: float, _duration: float) -> void:
		pass

	func _spawn_combat_tag(_position: Vector2, text: String, _color: Color) -> void:
		last_tag = text

	func _apply_post_ultimate_bonuses(_role_id: String, _duration: float) -> void:
		pass

	func _delay_level_up_requests(_duration: float) -> void:
		pass

	func _register_attack_result(_role_id: String, _hits: int, _critical: bool) -> void:
		pass

	func _spawn_ring_effect(_position: Vector2, _radius: float, _color: Color, _segments: float, _duration: float) -> Node2D:
		return Node2D.new()

	func _spawn_burst_effect(_position: Vector2, _radius: float, _color: Color, _duration: float) -> Node2D:
		return Node2D.new()

	func _spawn_gunner_intersect_scene_effect(_center: Vector2, _direction: Vector2, _visual_length: float = 112.0, _visual_thickness: float = 18.0, _gather_visual_length: float = -1.0) -> Node2D:
		return Node2D.new()

	func _schedule_repeating_sequence(_interval: float, _count: int, callback: Callable, _initial_delay: float = 0.0) -> void:
		scheduled_counts.append(_count)
		if mouse_direction_after_schedule.length_squared() > 0.001:
			mouse_aim_direction = mouse_direction_after_schedule
		callback.call(0)

	func _damage_enemies_in_radius(center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
		last_radius_damage = {
			"center": center,
			"radius": radius,
			"damage": damage_amount,
			"vulnerability_bonus": vulnerability_bonus,
			"slow_multiplier": slow_multiplier,
			"slow_duration": slow_duration,
			"source_role_id": source_role_id
		}
		return 1

	func _damage_enemies_in_cone_batched(origin: Vector2, direction: Vector2, range_value: float, angle: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, source_role_id: String = "") -> int:
		last_cone_damage = {
			"origin": origin,
			"direction": direction,
			"range": range_value,
			"angle": angle,
			"damage_amount": damage_amount,
			"vulnerability_bonus": vulnerability_bonus,
			"slow_multiplier": slow_multiplier,
			"slow_duration": slow_duration,
			"source_role_id": source_role_id
		}
		return 1

	func _damage_enemies_in_shapes_batched(shapes: Array[Dictionary]) -> int:
		last_shapes = []
		for shape in shapes:
			last_shapes.append(shape.duplicate(true))
		return shapes.size()

	func _perform_gunner_attack() -> void:
		attack_count += 1

	func _spawn_batched_directional_bullet_values(
		direction: Vector2,
		damage_amount: float,
		_color: Color,
		role_id: String = "",
		origin: Variant = null,
		speed: float = 620.0,
		lifetime: float = 1.0,
		hit_radius: float = 10.0,
		_visual_radius: float = 4.2,
		_visual_min_diameter: float = 8.0,
		_visual_outline_color: Color = Color.TRANSPARENT,
		_visual_outline_width: float = 0.0,
		_enemy_hit_radius_scale: float = 0.2,
		_enemy_hit_radius_min: float = 4.0,
		_enemy_hit_radius_max: float = 12.0,
		vulnerability_bonus: float = 0.0,
		vulnerability_duration: float = 0.0,
		_slow_multiplier: float = 1.0,
		_slow_duration: float = 0.0,
		pierce_count: int = 0,
		_wave_amplitude: float = 0.0,
		_wave_frequency: float = 0.0,
		_wave_phase: float = 0.0
	) -> bool:
		last_projectile = {
			"direction": direction,
			"damage": damage_amount,
			"role_id": role_id,
			"origin": origin,
			"speed": speed,
			"lifetime": lifetime,
			"hit_radius": hit_radius,
			"vulnerability_bonus": vulnerability_bonus,
			"vulnerability_duration": vulnerability_duration,
			"pierce_count": pierce_count
		}
		projectiles.append(last_projectile)
		return true
