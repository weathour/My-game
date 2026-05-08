extends RefCounted

const BASIC_COMBO_INTERVAL := 0.14
const ULTIMATE_SKILL_ID := "swordsman_ultimate"
const ULTIMATE_EXTRA_SLASHES := 3
const ULTIMATE_TIER_TWO_EXTRA_SLASHES := 3
const ULTIMATE_TIER_TWO_VISUAL_HIT_SCALE := 1.18
const ULTIMATE_TIER_TWO_DAMAGE_MULTIPLIER := 1.22
const ULTIMATE_TIER_THREE_EXTRA_SLASHES := 3
const ULTIMATE_TIER_THREE_VISUAL_HIT_SCALE := 1.38
const ULTIMATE_TIER_THREE_DAMAGE_MULTIPLIER := 1.42
const ENTRY_INVULNERABILITY_DURATION := 1.5
const POST_ULTIMATE_INVULNERABILITY_DURATION := 1.5

func perform_attack(owner) -> void:
	var base_direction: Vector2 = owner._get_attack_aim_direction(owner.facing_direction)
	_perform_combo_segment(owner, base_direction, 1.0)
	_schedule_reprise_segments(owner, base_direction)

func _perform_combo_segment(owner, base_direction: Vector2, combo_scale: float, allow_followthrough: bool = true) -> void:
	var damage_shapes: Array[Dictionary] = []
	var total_hits: int = 0
	total_hits += _perform_attack_variant(owner, base_direction, combo_scale, true, true, allow_followthrough, damage_shapes)
	_apply_trick_variants(owner, base_direction, combo_scale, damage_shapes)
	var shape_hits: int = _apply_basic_attack_damage_shapes(owner, damage_shapes)
	total_hits += shape_hits
	if total_hits > 0 and not _uses_batched_basic_attack_damage(owner):
		var role_data: Dictionary = owner._get_active_role()
		owner._register_attack_result(role_data["id"], total_hits, false)

func _perform_attack_variant(owner, attack_direction: Vector2, effect_scale: float = 1.0, advance_chain: bool = true, spawn_aftershock: bool = true, allow_followthrough: bool = false, damage_shapes: Array[Dictionary] = []) -> int:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	if attack_direction.length_squared() <= 0.001:
		attack_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	attack_direction = attack_direction.normalized()
	var heart_level: float = 0.0
	var normal_attack_scale: float = owner._get_swordsman_normal_attack_scale(heart_level)
	var normal_attack_width_scale: float = owner._get_swordsman_normal_attack_width_scale(heart_level)
	var basic_range_multiplier: float = _get_basic_attack_range_multiplier(owner)
	var attack_range: float = (float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0))) * owner._get_story_style_range_multiplier(role_data["id"]) * basic_range_multiplier
	var attack_damage: float = owner._get_role_damage(role_data["id"]) * 1.5 * max(0.0, effect_scale)
	var slash_axis: Vector2 = owner._get_downward_perpendicular(attack_direction)
	var slash_mirror: bool = attack_direction.x > 0.0
	var slash_length: float = (56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.19) * owner._get_story_style_range_multiplier(role_data["id"]) * basic_range_multiplier
	var slash_width: float = 8.0 * normal_attack_width_scale
	var slash_forward_distance: float = 42.0
	var style_color := Color(0.48, 0.86, 1.0, 0.95) if owner._get_story_style_id(role_data["id"]) == "moon_edge" else Color(1.0, 0.74, 0.34, 0.95)
	var enemies_hit: int = 0

	slash_length *= normal_attack_scale
	var slash_visual_width: float = _get_slash_visual_width(slash_width)
	var slash_mirror_forward_offset: float = _get_slash_mirror_forward_offset(owner, slash_visual_width)
	var slash_center: Vector2 = owner.global_position + attack_direction * (slash_forward_distance + slash_mirror_forward_offset)
	var slash_effect_center: Vector2 = slash_center - attack_direction * slash_mirror_forward_offset if slash_mirror else slash_center

	owner._spawn_sword_slash_scene_effect(
		slash_effect_center,
		slash_axis,
		slash_length * 0.5,
		style_color,
		0.16,
		slash_width,
		slash_mirror
	)
	var slash_hit_registry: Dictionary = {}
	var slash_rect_width: float = max(slash_visual_width, slash_center.distance_to(owner.global_position) * 2.0 + 12.0)
	var slash_animation_duration: float = owner._get_sword_slash_scene_animation_duration()
	damage_shapes.append({
		"type": "oriented_rect",
		"center": slash_center,
		"axis": slash_axis,
		"length": slash_length,
		"width": slash_rect_width,
		"damage_amount": attack_damage,
		"vulnerability_bonus": 0.0,
		"slow_multiplier": 1.0,
		"slow_duration": 0.0,
		"source_role_id": role_data["id"],
		"source_position": slash_center,
		"hit_registry": slash_hit_registry
	})
	if allow_followthrough:
		owner._schedule_swordsman_slash_followthrough(slash_center, slash_axis, slash_length, slash_rect_width, attack_damage, 0.0, 1.0, 0.0, slash_animation_duration, role_data["id"], slash_hit_registry)

	if advance_chain:
		owner.swordsman_attack_chain = (owner.swordsman_attack_chain + 1) % 3

	if spawn_aftershock:
		owner._spawn_attack_aftershock(owner.global_position + attack_direction * max(26.0, attack_range * 0.55), role_data["id"])

	return enemies_hit

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
	_perform_combo_segment(owner, base_direction, combo_scale, false)

func _apply_trick_variants(owner, base_direction: Vector2, combo_scale: float, damage_shapes: Array[Dictionary]) -> void:
	var index := 1
	for scale in _get_skill_effect_scales(owner, "quantity_skill_count"):
		var direction := base_direction.rotated(deg_to_rad(30.0 * float(index)))
		_perform_attack_variant(owner, direction, combo_scale * float(scale), false, false, false, damage_shapes)
		index += 1

func _get_skill_effect_scales(owner, stat: String) -> Array[float]:
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales_for_skill"):
		return owner._get_skill_blessing_effect_scales_for_skill("swordsman_basic_attack", stat)
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales"):
		return owner._get_skill_blessing_effect_scales(stat)
	return []

func _get_basic_attack_range_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_basic_attack_range_multiplier"):
		return float(owner._get_basic_attack_range_multiplier("swordsman_basic_attack"))
	return 1.0

func _apply_basic_attack_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if shapes.is_empty():
		return 0
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		hits += int(owner._damage_enemies_in_oriented_rect_unique(
			shape.get("center", Vector2.ZERO),
			shape.get("axis", Vector2.RIGHT),
			float(shape.get("length", 1.0)),
			float(shape.get("width", 1.0)),
			float(shape.get("damage_amount", 0.0)),
			float(shape.get("vulnerability_bonus", 0.0)),
			float(shape.get("slow_multiplier", 1.0)),
			float(shape.get("slow_duration", 0.0)),
			shape.get("hit_registry", {}),
			str(shape.get("source_role_id", ""))
		))
	return hits

func _uses_batched_basic_attack_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")

func perform_background(owner) -> void:
	var target_enemy: Node2D = owner._get_low_health_enemy()
	if target_enemy == null:
		target_enemy = owner._get_closest_enemy()
	if target_enemy == null:
		return

	var special_data: Dictionary = owner._get_role_special_state("swordsman")
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var damage_amount: float = owner._get_role_damage("swordsman") * 0.44
	var hit_direction: Vector2 = owner.global_position.direction_to(target_enemy.global_position)
	var killed: bool = false
	owner._spawn_slash_effect(target_enemy.global_position - hit_direction * 10.0, hit_direction, 46.0, 12.0, Color(1.0, 0.74, 0.36, 0.65), 0.1)
	killed = owner._deal_damage_to_enemy(target_enemy, damage_amount, "swordsman")
	if target_enemy.has_method("apply_bleed"):
		target_enemy.apply_bleed(damage_amount * 0.22, 1.8)
	if crescent_level >= 2:
		owner._spawn_slash_effect(target_enemy.global_position, hit_direction.rotated(0.9), 42.0, 10.0, Color(1.0, 0.86, 0.48, 0.55), 0.1)
		owner._spawn_ring_effect(target_enemy.global_position, 34.0 + crescent_level * 5.0, Color(0.42, 0.84, 1.0, 0.32), 4.0, 0.12)
		owner._damage_enemies_in_radius(target_enemy.global_position, 34.0 + crescent_level * 5.0, damage_amount * 0.45, 0.0, 1.0, 0.0)
	if thrust_level >= 2:
		var bg_thrust_width: float = 14.0 + thrust_level * 2.0
		owner._spawn_thrust_effect(owner.global_position, target_enemy.global_position, Color(1.0, 0.24, 0.12, 0.82), bg_thrust_width, 0.12)
		owner._damage_enemies_in_line(owner.global_position, target_enemy.global_position, bg_thrust_width, damage_amount * 0.5, 0.04 * thrust_level, 1.0, 0.0, "swordsman")
	owner._register_attack_result("swordsman", 1, killed)

func perform_enter(owner, role_id: String, _assault_level: int, _assault_multiplier: float) -> int:
	var previous_position: Vector2 = owner.global_position
	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	var target_enemy: Node2D = owner._get_enemy_nearest_to_position(cluster_center) if cluster_center != Vector2.ZERO else owner._get_closest_enemy()
	var travel_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var dash_distance: float = 160.0
	if target_enemy != null and is_instance_valid(target_enemy):
		travel_direction = previous_position.direction_to(target_enemy.global_position)
		dash_distance = 600.0
	elif cluster_center != Vector2.ZERO:
		travel_direction = previous_position.direction_to(cluster_center)
		dash_distance = 600.0
	owner.global_position += travel_direction * dash_distance
	owner.facing_direction = travel_direction
	owner._show_switch_banner("\u8FDB\u573A", "\u7A81\u8FDB\u7834\u9635", Color(1.0, 0.84, 0.46, 1.0))
	var scar_width: float = 32.0
	var scar_end: Vector2 = owner.global_position + travel_direction * 84.0
	var scar_center: Vector2 = previous_position.lerp(scar_end, 0.5)
	var scar_length: float = previous_position.distance_to(scar_end)
	owner._spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.08)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, ENTRY_INVULNERABILITY_DURATION)
	return owner._damage_enemies_in_line(previous_position, scar_end, scar_width, owner._get_role_damage(role_id) * 1.52, 0.1, 1.0, 0.0, role_id)

func perform_exit(_owner, _role_id: String, _rearguard_level: int) -> int:
	return 0

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var pursuit_level: int = 0
	var crescent_level: int = 0
	var thrust_level: int = 0
	var slash_count: int = 7
	slash_count = int(ceil(float(slash_count) * float(cast_payload.get("duration_multiplier", 1.0))))
	slash_count += 2 + ULTIMATE_EXTRA_SLASHES
	var ultimate_tier: int = _get_ultimate_skill_tier(owner)
	if ultimate_tier >= 2:
		slash_count += ULTIMATE_TIER_TWO_EXTRA_SLASHES
	if ultimate_tier >= 3:
		slash_count += ULTIMATE_TIER_THREE_EXTRA_SLASHES
	var combo_scales: Array[float] = _get_ultimate_combo_scales(owner)
	var slash_scales: Array[float] = _build_ultimate_segment_scales(slash_count, combo_scales)
	var total_duration: float = 0.22 + float(slash_scales.size() - 1) * owner.SWORD_ULTIMATE_SLASH_INTERVAL + 0.18
	if ultimate_tier >= 3:
		var special_data: Dictionary = owner._get_role_special_state("swordsman")
		special_data["ultimate_lifesteal_multiplier_remaining"] = total_duration
		owner.role_special_states["swordsman"] = special_data
	var combo_start_index: int = max(0, slash_count - 1)
	var combo_end_index: int = combo_start_index + combo_scales.size()
	owner._queue_camera_shake(20.0, 0.62)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, total_duration + POST_ULTIMATE_INVULNERABILITY_DURATION)
	owner._delay_level_up_requests(total_duration)
	owner._set_active_role_visual_hidden(true)
	if owner.get_tree() != null:
		var restore_tween: Tween = owner.create_tween()
		restore_tween.tween_interval(total_duration)
		restore_tween.tween_callback(func() -> void:
			owner._set_active_role_visual_hidden(false)
		)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "无敌斩", Color(1.0, 0.92, 0.6, 1.0))
	owner._spawn_ring_effect(owner.global_position, 68.0, Color(1.0, 0.88, 0.52, 0.84), 8.0, 0.18)
	_schedule_ultimate_sequence(owner, slash_scales, pursuit_level, crescent_level, thrust_level, float(cast_payload.get("damage_multiplier", 1.0)), ultimate_tier, 0.0, combo_start_index, combo_end_index)
	owner._apply_post_ultimate_bonuses("swordsman", total_duration)

func _schedule_ultimate_sequence(owner, slash_scales: Array[float], pursuit_level: int, crescent_level: int, thrust_level: int, cast_damage_multiplier: float, ultimate_tier: int, start_delay: float, combo_start_index: int = -1, combo_end_index: int = -1) -> void:
	var slash_count: int = slash_scales.size()
	var sequence_callback := func(slash_index: int) -> void:
		var is_combo_segment := combo_start_index >= 0 and slash_index >= combo_start_index and slash_index < combo_end_index
		_execute_ultimate_slash(owner, slash_scales, pursuit_level, crescent_level, thrust_level, cast_damage_multiplier, slash_index, ultimate_tier, is_combo_segment)
	if start_delay <= 0.0:
		owner._schedule_repeating_sequence(owner.SWORD_ULTIMATE_SLASH_INTERVAL, slash_count, sequence_callback)
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(start_delay)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(owner):
			owner._schedule_repeating_sequence(owner.SWORD_ULTIMATE_SLASH_INTERVAL, slash_count, sequence_callback)
	)

func _execute_ultimate_slash(owner, slash_scales: Array[float], pursuit_level: int, crescent_level: int, thrust_level: int, cast_damage_multiplier: float, slash_index: int, ultimate_tier: int = 1, is_combo_segment: bool = false) -> void:
	if owner.is_dead:
		return

	var slash_count: int = slash_scales.size()
	var effect_scale: float = 1.0
	if slash_index >= 0 and slash_index < slash_count:
		effect_scale = float(slash_scales[slash_index])
	var start_position: Vector2 = owner.global_position
	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	var target_enemy: Node2D = null
	if slash_index == slash_count - 1:
		target_enemy = owner._get_low_health_enemy()
	elif slash_index % 2 == 0:
		target_enemy = owner._get_enemy_nearest_to_position(cluster_center if cluster_center != Vector2.ZERO else start_position + owner.facing_direction * 240.0)
	else:
		target_enemy = owner._get_farthest_enemy()

	var travel_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	if target_enemy != null and is_instance_valid(target_enemy):
		travel_direction = start_position.direction_to(target_enemy.global_position)
	elif cluster_center != Vector2.ZERO:
		travel_direction = start_position.direction_to(cluster_center)
	if travel_direction.length_squared() <= 0.001:
		travel_direction = Vector2.RIGHT.rotated(float(slash_index) * TAU / float(max(1, slash_count)))

	var dash_distance: float = 96.0 + thrust_level * 10.0 + pursuit_level * 8.0
	if target_enemy != null and is_instance_valid(target_enemy):
		dash_distance = 600.0 + thrust_level * 48.0 + pursuit_level * 28.0
	elif cluster_center != Vector2.ZERO:
		dash_distance = 600.0 + thrust_level * 48.0 + pursuit_level * 28.0
	var end_position: Vector2 = start_position + travel_direction * dash_distance
	owner.global_position = end_position
	owner.facing_direction = travel_direction
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.24)
	owner._queue_camera_shake(8.6 + float(slash_index) * 0.7, 0.15)
	var tier_visual_hit_scale: float = 1.0
	if ultimate_tier >= 3:
		tier_visual_hit_scale = ULTIMATE_TIER_THREE_VISUAL_HIT_SCALE
	elif ultimate_tier >= 2:
		tier_visual_hit_scale = ULTIMATE_TIER_TWO_VISUAL_HIT_SCALE
	var visual_hit_scale: float = max(0.05, effect_scale) * tier_visual_hit_scale
	var tier_damage_multiplier: float = 1.0
	if ultimate_tier >= 3:
		tier_damage_multiplier = ULTIMATE_TIER_THREE_DAMAGE_MULTIPLIER
	elif ultimate_tier >= 2:
		tier_damage_multiplier = ULTIMATE_TIER_TWO_DAMAGE_MULTIPLIER
	var damage_multiplier: float = cast_damage_multiplier * max(0.0, effect_scale) * tier_damage_multiplier
	var scar_width: float = (40.0 + thrust_level * 5.0) * visual_hit_scale
	var scar_length_end: Vector2 = end_position + travel_direction * ((84.0 + thrust_level * 18.0) * visual_hit_scale)
	var scar_center: Vector2 = start_position.lerp(scar_length_end, 0.5)
	var scar_length: float = start_position.distance_to(scar_length_end)
	owner._spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.12)

	var damage_scale: float = (1.15 + float(pursuit_level) * 0.12 + float(crescent_level + thrust_level) * 0.06 + float(slash_index) * 0.08) * damage_multiplier
	var line_damage: float = owner._get_role_damage("swordsman") * damage_scale
	if is_combo_segment:
		var combo_hits: int = _apply_ultimate_damage_shapes(owner, [{
			"type": "line",
			"start": start_position,
			"end": scar_length_end,
			"width": scar_width,
			"damage_amount": line_damage,
			"vulnerability_bonus": 0.08 + pursuit_level * 0.02,
			"slow_multiplier": 1.0,
			"slow_duration": 0.0,
			"source_role_id": "swordsman",
			"source_position": start_position
		}])
		if combo_hits > 0 and not _uses_batched_ultimate_damage(owner):
			owner._register_attack_result("swordsman", combo_hits, false)
		return
	var shape_hits: int = _apply_ultimate_damage_shapes(owner, [
		{
			"type": "line",
			"start": start_position,
			"end": scar_length_end,
			"width": scar_width,
			"damage_amount": line_damage,
			"vulnerability_bonus": 0.08 + pursuit_level * 0.02,
			"slow_multiplier": 1.0,
			"slow_duration": 0.0,
			"source_role_id": "swordsman",
			"source_position": start_position
		},
		{
			"type": "circle",
			"center": end_position,
			"radius": (48.0 + crescent_level * 12.0) * visual_hit_scale,
			"damage_amount": owner._get_role_damage("swordsman") * (0.52 + float(crescent_level) * 0.08) * damage_multiplier,
			"vulnerability_bonus": 0.03 + pursuit_level * 0.02,
			"slow_multiplier": 1.0,
			"slow_duration": 0.0,
			"source_role_id": "swordsman",
			"source_position": end_position
		}
	])
	if shape_hits > 0 and not _uses_batched_ultimate_damage(owner):
		owner._register_attack_result("swordsman", shape_hits, false)
	if target_enemy != null and is_instance_valid(target_enemy):
		var direct_cut_kill: bool = owner._deal_damage_to_enemy(target_enemy, owner._get_role_damage("swordsman") * (0.68 + pursuit_level * 0.08) * damage_multiplier, "swordsman", 0.06 + pursuit_level * 0.02, 2.0, 1.0, 0.0)
		owner._register_attack_result("swordsman", 1, direct_cut_kill)

	owner._spawn_ring_effect(end_position, (34.0 + crescent_level * 8.0) * visual_hit_scale, Color(1.0, 0.84, 0.44, 0.76), 5.0, 0.12)

	if target_enemy != null and is_instance_valid(target_enemy) and target_enemy.has_method("apply_bleed"):
		target_enemy.apply_bleed(owner._get_role_damage("swordsman") * (0.68 + pursuit_level * 0.1), 2.8 + float(crescent_level) * 0.35)

	if slash_index == slash_count - 1:
		owner._queue_camera_shake(15.0, 0.22)
		owner._spawn_burst_effect(end_position, (94.0 + crescent_level * 10.0) * visual_hit_scale, Color(1.0, 0.78, 0.35, 0.28), 0.2)
		owner._spawn_ring_effect(end_position, (108.0 + thrust_level * 10.0) * visual_hit_scale, Color(1.0, 0.92, 0.58, 0.9), 10.0, 0.18)
		var finisher_hits: int = _apply_ultimate_damage_shapes(owner, [{
			"type": "line",
			"start": start_position,
			"end": end_position + travel_direction * (168.0 * visual_hit_scale),
			"width": scar_width + 18.0 * visual_hit_scale,
			"damage_amount": owner._get_role_damage("swordsman") * (1.55 + pursuit_level * 0.14) * damage_multiplier,
			"vulnerability_bonus": 0.1,
			"slow_multiplier": 1.0,
			"slow_duration": 0.0,
			"source_role_id": "swordsman",
			"source_position": start_position
		}])
		if finisher_hits > 0 and not _uses_batched_ultimate_damage(owner):
			owner._register_attack_result("swordsman", finisher_hits, false)
		if target_enemy != null and is_instance_valid(target_enemy):
			var finisher_kill: bool = owner._deal_damage_to_enemy(target_enemy, owner._get_role_damage("swordsman") * (0.92 + pursuit_level * 0.1) * damage_multiplier, "swordsman", 0.12, 2.4, 1.0, 0.0)
			owner._register_attack_result("swordsman", 1, finisher_kill)

func _get_ultimate_skill_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return max(1, int(owner._get_blessing_skill_tier(ULTIMATE_SKILL_ID)))
	return 1

func _get_ultimate_combo_scales(owner) -> Array[float]:
	if owner != null and owner.has_method("_get_blessing_skill_combo_scales"):
		return owner._get_blessing_skill_combo_scales(ULTIMATE_SKILL_ID) as Array[float]
	return []

func _build_ultimate_segment_scales(base_count: int, combo_scales: Array[float]) -> Array[float]:
	var result: Array[float] = []
	var normal_count: int = max(0, base_count - 1)
	for _index in range(normal_count):
		result.append(1.0)
	for scale in combo_scales:
		result.append(max(0.05, float(scale)))
	result.append(1.0)
	return result

func _apply_ultimate_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
		if str(shape.get("type", "")) == "line":
			hits += int(owner._damage_enemies_in_line(
				shape.get("start", Vector2.ZERO),
				shape.get("end", Vector2.ZERO),
				float(shape.get("width", 1.0)),
				float(shape.get("damage_amount", 0.0)),
				float(shape.get("vulnerability_bonus", 0.0)),
				float(shape.get("slow_multiplier", 1.0)),
				float(shape.get("slow_duration", 0.0)),
				str(shape.get("source_role_id", ""))
			))
		elif str(shape.get("type", "")) == "circle":
			hits += int(owner._damage_enemies_in_radius(
				shape.get("center", Vector2.ZERO),
				float(shape.get("radius", 1.0)),
				float(shape.get("damage_amount", 0.0)),
				float(shape.get("vulnerability_bonus", 0.0)),
				float(shape.get("slow_multiplier", 1.0)),
				float(shape.get("slow_duration", 0.0)),
				str(shape.get("source_role_id", ""))
			))
	return hits

func _uses_batched_ultimate_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")

func _get_slash_visual_width(slash_width: float) -> float:
	return max(18.0, slash_width * 2.0)

func _get_slash_mirror_forward_offset(owner, visual_width: float) -> float:
	var visible_bounds: Rect2 = owner.SWORD_SLASH_SCENE_VISIBLE_BOUNDS
	var visible_center_x: float = visible_bounds.position.x + visible_bounds.size.x * 0.5
	var mirrored_center_offset_px: float = owner.SWORD_SLASH_SCENE_SIZE.x - visible_center_x * 2.0
	if mirrored_center_offset_px <= 0.0:
		return 0.0
	return mirrored_center_offset_px * visual_width / max(1.0, visible_bounds.size.x)
