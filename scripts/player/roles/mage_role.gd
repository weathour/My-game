extends RefCounted

const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PLAYER_BUILD_SYSTEM := preload("res://scripts/player/player_build_system.gd")
const PLAYER_MAGE_BASIC_TALENT_FLOW := preload("res://scripts/player/player_mage_basic_talent_flow.gd")
const PLAYER_MAGE_ULTIMATE_TALENT_FLOW := preload("res://scripts/player/player_mage_ultimate_talent_flow.gd")
const PLAYER_MAGE_ENTRY_TALENT_FLOW := preload("res://scripts/player/player_mage_entry_talent_flow.gd")

const MAGE_ATTACK_EFFECT_SCALE := 0.8
const BASIC_COMBO_INTERVAL := 0.16
const ULTIMATE_SKILL_ID := "mage_ultimate"
const ULTIMATE_COMBO_INTERVAL := 0.18
const ULTIMATE_DURATION := 4.0
const ULTIMATE_BOMBARD_INTERVAL := 0.25
const ULTIMATE_BASE_DAMAGE_RATIO := 1.14
const ULTIMATE_GUNNER_ULTIMATE_OUTPUT_RATIO := 0.75
const ULTIMATE_BOSS_TARGET_WEIGHT := 0.35
const ULTIMATE_EXTRA_BOMBARDS := 8
const ULTIMATE_TIER_TWO_EXTRA_BOMBARDS := 6
const ULTIMATE_TIER_THREE_EXTRA_BOMBARDS := 3
const ENTRY_ARCANE_SURPLUS_DURATION := 5.0
const ENTRY_ARCANE_SURPLUS_STATUS_ID := "mage_arcane_surplus"
const ENTRY_LIGHTNING_COUNT := 5
const ENTRY_LIGHTNING_DISTANCE := 124.0
const ENTRY_LIGHTNING_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const ENTRY_LIGHTNING_DAMAGE_SCALE := 1.0
const BASIC_QUICKCAST_WARNING_MULTIPLIER := 0.75
const BASIC_FROST_SLOW_MULTIPLIER := 0.80
const BASIC_FROST_SLOW_DURATION := 0.8
var basic_damage_event_serial: int = 0

func perform_attack(owner) -> void:
	var basic_source_id := _create_basic_source_id(owner)
	var contexts: Array = _build_attack_contexts(owner, basic_source_id)
	if (contexts[0] as Array).is_empty():
		return
	var primary_context_count: int = min(PLAYER_MAGE_BASIC_TALENT_FLOW.get_primary_context_count(owner), (contexts[0] as Array).size())
	var base_contexts: Array = _get_attack_context_subset(contexts, 0, primary_context_count)
	if _has_talent(owner, "mage_basic_triangle"):
		base_contexts = _build_triangle_attack_contexts(base_contexts)
	var trick_context_count: int = max(0, (contexts[0] as Array).size() - primary_context_count)
	var trick_contexts: Array = _get_attack_context_subset(contexts, primary_context_count, trick_context_count)
	var combo_scales: Array[float] = [1.0]
	combo_scales.append_array(_get_skill_effect_scales(owner, "combo_skill_extra"))
	var cast_state := {"rift_triggered": false}
	_spawn_basic_attack_warning_group(owner, contexts)
	_start_basic_attack_combo_sequence(owner, base_contexts, combo_scales, false, cast_state)
	if not (trick_contexts[0] as Array).is_empty():
		_start_basic_attack_combo_sequence(owner, trick_contexts, [1.0], false, cast_state)
	if _has_talent(owner, "mage_basic_aftershock"):
		_schedule_basic_aftershock(owner, base_contexts)
	_schedule_level_basic_rehit(owner, base_contexts, cast_state)
	owner._spawn_attack_aftershock((base_contexts[0] as Array)[0], str((base_contexts[3] as Array)[0]))

func _create_basic_source_id(owner) -> String:
	if owner != null and owner.has_method("_create_basic_attack_source_id"):
		return str(owner._create_basic_attack_source_id("mage"))
	basic_damage_event_serial += 1
	return "mage_basic:%s:%s" % [owner.get_instance_id() if owner != null else 0, basic_damage_event_serial]

func _build_triangle_attack_contexts(contexts: Array) -> Array:
	var origin: Vector2 = (contexts[0] as Array)[0]
	var base_radius: float = float((contexts[1] as Array)[0])
	var base_damage: float = float((contexts[2] as Array)[0])
	var role_id: String = str((contexts[3] as Array)[0])
	var source_id: String = str((contexts[4] as Array)[0]) if contexts.size() > 4 else role_id
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	var damages: Array[float] = []
	var role_ids: Array[String] = []
	var source_ids: Array[String] = []
	for index in range(3):
		centers.append(origin + Vector2.RIGHT.rotated(-PI * 0.5 + TAU * float(index) / 3.0) * 48.0)
		radii.append(base_radius * 0.70)
		damages.append(base_damage * 0.40)
		role_ids.append(role_id)
		source_ids.append(source_id)
	return [centers, radii, damages, role_ids, source_ids]

func _schedule_basic_aftershock(owner, contexts: Array) -> void:
	var delay: float = _get_basic_warning_duration(owner)
	delay += owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3) + 0.35
	var callback := func(_index: int) -> void:
		if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
			return
		_spawn_basic_attack_boom_group(owner, contexts, 0.45)
		_resolve_basic_attack_group(owner, contexts, 0.45, false)
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		callback.call(0)
	else:
		owner._schedule_repeating_sequence(0.0, 1, callback, delay)

func _schedule_level_basic_rehit(owner, contexts: Array, cast_state: Dictionary = {}) -> void:
	var followup_scale := PLAYER_MAGE_BASIC_TALENT_FLOW.get_basic_followup_damage_multiplier(owner)
	if followup_scale <= 0.0 or (contexts[0] as Array).is_empty():
		return
	var callback := func(_index: int) -> void:
		if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
			return
		_spawn_basic_attack_boom_group(owner, contexts, followup_scale)
		_resolve_basic_attack_group(owner, contexts, followup_scale, false, cast_state)
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		callback.call(0)
	else:
		var delay: float = _get_basic_warning_duration(owner)
		delay += owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
		delay += PLAYER_MAGE_BASIC_TALENT_FLOW.get_basic_followup_delay(owner)
		owner._schedule_repeating_sequence(0.0, 1, callback, delay)

func _perform_combo_segment(owner, contexts: Array, combo_scale: float) -> void:
	var centers: Array = contexts[0]
	for index in range(centers.size()):
		_cast_attack_context(owner, contexts, index, combo_scale, index == 0)

func _start_basic_attack_combo_sequence(owner, contexts: Array, combo_scales: Array[float], spawn_warning: bool = true, cast_state: Dictionary = {}) -> void:
	if combo_scales.is_empty():
		return
	if owner.get_tree() == null:
		for combo_index in range(combo_scales.size()):
			_perform_combo_segment(owner, contexts, float(combo_scales[combo_index]))
		return

	var warning_duration: float = _get_basic_warning_duration(owner)
	var boom_duration: float = owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	if spawn_warning:
		_spawn_basic_attack_warning_group(owner, contexts)
	if not owner.has_method("_schedule_repeating_sequence"):
		for combo_index in range(combo_scales.size()):
			var combo_scale: float = float(combo_scales[combo_index])
			_spawn_basic_attack_boom_group(owner, contexts, combo_scale)
			_resolve_basic_attack_group(owner, contexts, combo_scale, true, cast_state)
		return
	for combo_index in range(combo_scales.size()):
		var combo_scale: float = float(combo_scales[combo_index])
		var boom_delay: float = warning_duration + float(combo_index) * boom_duration
		var resolve_delay: float = boom_delay + boom_duration
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				_spawn_basic_attack_boom_group(owner, contexts, combo_scale)
		, boom_delay)
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				_resolve_basic_attack_group(owner, contexts, combo_scale, true, cast_state)
		, resolve_delay)

func _perform_combo_segment_if_valid(owner, contexts: Array, combo_scale: float) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	_perform_combo_segment(owner, contexts, combo_scale)

func _spawn_basic_attack_warning_group(owner, contexts: Array) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	for index in range(centers.size()):
		owner._spawn_mage_warning_scene_effect(centers[index], float(radii[index]))

func _spawn_basic_attack_boom_group(owner, contexts: Array, combo_scale: float) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	for index in range(centers.size()):
		owner._spawn_mage_boom_scene_effect(centers[index], float(radii[index]))

func _resolve_basic_attack_group(owner, contexts: Array, combo_scale: float, allow_stage_three: bool = true, cast_state: Dictionary = {}) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	var centers: Array = contexts[0]
	for index in range(centers.size()):
		_resolve_basic_attack_context(owner, contexts, index, combo_scale, index == 0, allow_stage_three, cast_state)

func _resolve_basic_attack_context(owner, contexts: Array, index: int, combo_scale: float, advance_attack_chain: bool, allow_stage_three: bool = true, cast_state: Dictionary = {}) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	var damages: Array = contexts[2]
	var role_ids: Array = contexts[3]
	var source_ids: Array = contexts[4]
	var center: Vector2 = centers[index]
	var radius: float = float(radii[index])
	var damage_amount: float = float(damages[index]) * max(0.0, combo_scale)
	var rift_target: Node2D
	if allow_stage_three and _has_talent(owner, "mage_basic_rift") and not bool(cast_state.get("rift_triggered", false)):
		rift_target = _find_elite_or_boss_in_radius(owner, center, radius)
	if allow_stage_three and _has_talent(owner, "mage_basic_gravemark"):
		_pull_non_boss_enemies(owner, center, radius, 24.0)
	var slow_multiplier := BASIC_FROST_SLOW_MULTIPLIER if _has_talent(owner, "mage_basic_frostburst") else 1.0
	var slow_duration := BASIC_FROST_SLOW_DURATION if slow_multiplier < 1.0 else 0.0
	owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, 0.0, slow_multiplier, slow_duration, 0, 0, 0, str(source_ids[index]), true, advance_attack_chain)
	if rift_target != null and is_instance_valid(rift_target):
		cast_state["rift_triggered"] = true
		var rift_center: Vector2 = rift_target.global_position
		owner._spawn_burst_effect(rift_center, radius * 0.50, Color(0.62, 0.88, 1.0, 0.28), 0.18)
		owner._damage_enemies_in_radius(rift_center, radius * 0.50, damage_amount * 0.25, 0.0, 1.0, 0.0, str(role_ids[index]))

func _get_basic_warning_duration(owner) -> float:
	var duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	if _has_talent(owner, "mage_basic_quickcast"):
		duration *= BASIC_QUICKCAST_WARNING_MULTIPLIER
	return duration

func _find_elite_or_boss_in_radius(owner, center: Vector2, radius: float) -> Node2D:
	if owner == null or not owner.has_method("_get_live_enemies"):
		return null
	for enemy in owner._get_live_enemies():
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		var offset := enemy_node.global_position - center
		var ellipse_distance := pow(offset.x / max(1.0, radius * 2.04), 2.0) + pow(offset.y / max(1.0, radius * 2.45), 2.0)
		if ellipse_distance > 1.0:
			continue
		var enemy_kind := str(enemy_node.get("enemy_kind"))
		if enemy_kind == "elite" or enemy_kind == "small_boss" or enemy_kind == "boss":
			return enemy_node
	return null

func _pull_non_boss_enemies(owner, center: Vector2, radius: float, distance: float) -> void:
	if owner == null or not owner.has_method("_get_live_enemies"):
		return
	for enemy in owner._get_live_enemies():
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var enemy_node := enemy as Node2D
		if str(enemy_node.get("enemy_kind")) == "boss":
			continue
		var offset: Vector2 = center - enemy_node.global_position
		if offset.length_squared() <= 0.001 or offset.length() > radius:
			continue
		enemy_node.global_position += offset.normalized() * min(distance, offset.length())

func _get_attack_context_subset(contexts: Array, start_index: int, count: int) -> Array:
	var source_centers: Array = contexts[0]
	var source_radii: Array = contexts[1]
	var source_damages: Array = contexts[2]
	var source_role_ids: Array = contexts[3]
	var source_damage_ids: Array = contexts[4] if contexts.size() > 4 else source_role_ids
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	var damages: Array[float] = []
	var role_ids: Array[String] = []
	var damage_source_ids: Array[String] = []
	var first_index: int = max(0, start_index)
	var end_index: int = min(source_centers.size(), first_index + max(0, count))
	for index in range(first_index, end_index):
		centers.append(source_centers[index])
		radii.append(float(source_radii[index]))
		damages.append(float(source_damages[index]))
		role_ids.append(str(source_role_ids[index]))
		damage_source_ids.append(str(source_damage_ids[index]))
	return [centers, radii, damages, role_ids, damage_source_ids]

func _build_attack_contexts(owner, basic_source_id: String) -> Array:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var arcane_focus_level: float = 0.0
	var bombard_center: Vector2 = owner._get_mage_mouse_bombard_center(float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)))
	var centers: Array[Vector2] = [bombard_center]
	var center_scales: Array[float] = [1.0]
	var quantity_scales := _get_skill_effect_scales(owner, "quantity_skill_count")
	if PLAYER_MAGE_BASIC_TALENT_FLOW.has_level_talent(owner, PLAYER_MAGE_BASIC_TALENT_FLOW.TALENT_BASIC_ATTACK_2):
		centers.append(PLAYER_MAGE_BASIC_TALENT_FLOW.pick_secondary_lightning_center(owner, bombard_center))
		center_scales.append(1.0)
	var primary_context_count := centers.size()
	var targets: Array = owner._get_enemy_targets(quantity_scales.size(), false)
	for target_index in range(targets.size()):
		var target = targets[target_index]
		if target != null and is_instance_valid(target):
			var target_center: Vector2 = target.global_position
			if _is_context_center_far_enough(target_center, centers):
				centers.append(target_center)
				center_scales.append(float(quantity_scales[min(target_index, quantity_scales.size() - 1)]))
	var expected_context_count: int = primary_context_count + quantity_scales.size()
	while centers.size() < expected_context_count:
		var extra_index: int = max(0, centers.size() - primary_context_count)
		var angle: float = TAU * float(centers.size()) / float(max(2, expected_context_count))
		centers.append(bombard_center + Vector2.RIGHT.rotated(angle) * 72.0)
		center_scales.append(float(quantity_scales[min(extra_index, quantity_scales.size() - 1)]))
	var context_centers: Array[Vector2] = []
	var context_radii: Array[float] = []
	var context_damages: Array[float] = []
	var context_role_ids: Array[String] = []
	var context_source_ids: Array[String] = []
	for index in range(centers.size()):
		var center: Vector2 = centers[index]
		var effect_scale: float = float(center_scales[min(index, center_scales.size() - 1)])
		var context: Array = _build_attack_context(owner, role_data, upgrade_data, special_data, center, effect_scale, arcane_focus_level)
		context_centers.append(context[0])
		context_radii.append(float(context[1]))
		context_damages.append(float(context[2]))
		context_role_ids.append(str(context[3]))
		context_source_ids.append(basic_source_id)
	return [context_centers, context_radii, context_damages, context_role_ids, context_source_ids]

func _is_context_center_far_enough(center: Vector2, existing_centers: Array[Vector2]) -> bool:
	for existing_center in existing_centers:
		if center.distance_to(existing_center) < 32.0:
			return false
	return true

func _build_attack_context(owner, role_data: Dictionary, upgrade_data: Dictionary, _special_data: Dictionary, bombard_center: Vector2, effect_scale: float, arcane_focus_level: float) -> Array:
	var target_enemy: Node2D = owner._get_enemy_near_position(bombard_center, 56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.25)
	var role_range_multiplier: float = owner._get_role_attribute_range_multiplier(role_data["id"]) * owner._get_role_equipment_skill_range_multiplier(role_data["id"])
	var radius: float = (43.75 + float(upgrade_data["range_bonus"]) * 0.55) * role_range_multiplier
	radius *= owner._get_role_attribute_range_multiplier("mage")
	radius *= owner._get_mage_arcane_focus_range_multiplier(arcane_focus_level)
	radius *= _get_basic_attack_range_multiplier(owner)
	var damage_amount: float = owner._get_role_damage(role_data["id"]) * 1.0 * max(0.0, effect_scale) * PLAYER_BUILD_SYSTEM.get_basic_attack_damage_multiplier(owner, "mage")
	if target_enemy != null:
		damage_amount *= owner._get_priority_target_bonus(target_enemy)
	radius *= MAGE_ATTACK_EFFECT_SCALE
	return [bombard_center, radius, damage_amount, str(role_data["id"]), arcane_focus_level]

func _cast_attack_context(owner, contexts: Array, index: int, scale: float, advance_attack_chain: bool) -> void:
	var centers: Array = contexts[0]
	var radii: Array = contexts[1]
	var damages: Array = contexts[2]
	var source_ids: Array = contexts[4]
	var bombard_center: Vector2 = centers[index]
	var radius: float = float(radii[index])
	var damage_amount: float = float(damages[index]) * max(0.0, scale)
	owner._start_basic_mage_bombardment(bombard_center, radius, damage_amount, 0.0, 1.0, 0.0, 0, 0, 0, str(source_ids[index]), true, advance_attack_chain)

func _get_skill_effect_scales(owner, stat: String) -> Array[float]:
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales_for_skill"):
		return owner._get_skill_blessing_effect_scales_for_skill("mage_basic_attack", stat)
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales"):
		return owner._get_skill_blessing_effect_scales(stat)
	return []

func _get_basic_attack_range_multiplier(owner) -> float:
	var multiplier: float = 1.0
	if owner != null and owner.has_method("_get_basic_attack_range_multiplier"):
		multiplier *= float(owner._get_basic_attack_range_multiplier("mage_basic_attack"))
	multiplier *= PLAYER_BUILD_SYSTEM.get_basic_attack_range_multiplier(owner, "mage")
	return multiplier

func _get_arcane_surplus_duration(owner) -> float:
	return ENTRY_ARCANE_SURPLUS_DURATION + PLAYER_BUILD_SYSTEM.get_mage_arcane_surplus_duration_bonus(owner)

func _start_evolved_arcane_bombardment(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, third_tier: bool = false) -> void:
	owner._start_basic_mage_bombardment(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, false)
	var followup_count: int = 2 if third_tier else 1
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		for followup_index in range(followup_count):
			owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, followup_index == followup_count - 1)
		return
	var first_damage_delay: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2) + owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	var boom_duration: float = owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	for followup_index in range(followup_count):
		var boom_delay: float = first_damage_delay + 0.06 + float(followup_index) * (boom_duration + 0.06)
		var resolve_delay: float = boom_delay + boom_duration
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				owner._spawn_mage_boom_scene_effect(center, radius)
		, boom_delay)
		var advance_chain := followup_index == followup_count - 1
		owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
			if is_instance_valid(owner):
				owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, advance_chain)
		, resolve_delay)

func perform_background(owner) -> void:
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var support_level: int = int(special_data.get("support_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var echo_level: int = int(special_data.get("echo_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var cluster_position: Vector2 = owner._get_enemy_cluster_center()
	if cluster_position == Vector2.ZERO:
		var target_enemy: Node2D = owner._get_closest_enemy()
		if target_enemy == null:
			return
		cluster_position = owner._get_enemy_aim_point(target_enemy, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target_enemy.global_position

	var radius: float = (44.0 + support_level * 8.0 + echo_level * 4.0 + frost_level * 4.0) * MAGE_ATTACK_EFFECT_SCALE * owner._get_role_attribute_range_multiplier("mage")
	var damage_amount: float = owner._get_role_damage("mage") * (0.32 + support_level * 0.06)
	var vulnerability_bonus: float = 0.02 * frost_level
	var slow_multiplier: float = max(0.62, 0.84 - frost_level * 0.05)
	var slow_duration: float = 1.2 + support_level * 0.18
	owner._start_basic_mage_bombardment(cluster_position, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, "mage", true, false)

	if support_level > 0:
		var secondary_targets: Array = owner._get_enemy_targets(2, false)
		for secondary_target in secondary_targets:
			if secondary_target == null or not is_instance_valid(secondary_target):
				continue
			var secondary_center: Vector2 = owner._get_enemy_aim_point(secondary_target, cluster_position) if owner.has_method("_get_enemy_aim_point") else secondary_target.global_position
			if secondary_center.distance_to(cluster_position) < 40.0:
				continue
			owner._start_basic_mage_bombardment(
				secondary_center,
				(34.0 + support_level * 5.0) * MAGE_ATTACK_EFFECT_SCALE,
				owner._get_role_damage("mage") * (0.18 + support_level * 0.04),
				0.0,
				max(0.66, 0.86 - frost_level * 0.04),
				1.0,
				max(0, gravity_level - 1),
				min(echo_level, 1),
				frost_level,
				"mage",
				true,
				false
			)
			break

func perform_enter(owner, role_id: String, _assault_level: int, assault_multiplier: float) -> int:
	owner._show_switch_banner("\u8FDB\u573A", "\u5BC6\u96C6\u96F7\u7FA4", Color(0.34, 0.72, 1.0, 1.0))
	var hit_count: int = _cast_entry_lightning_ring(owner, role_id, assault_multiplier)
	var arcane_surplus_duration: float = _get_arcane_surplus_duration(owner) + consume_arcane_dawn_duration_bonus(owner) + PLAYER_MAGE_ENTRY_TALENT_FLOW.consume_pending_arcane_surplus_bonus(owner)
	owner.mage_arcane_surplus_remaining = arcane_surplus_duration
	owner._start_duration_status(ENTRY_ARCANE_SURPLUS_STATUS_ID, "\u5965\u6CD5\u76C8\u4F59", arcane_surplus_duration, 18, Color(0.34, 0.72, 1.0, 0.95))
	return hit_count

func _cast_entry_lightning_ring(owner, role_id: String, damage_scale: float = 1.0) -> int:
	var centers: Array[Vector2] = []
	var entry_source_id := PLAYER_MAGE_ENTRY_TALENT_FLOW.make_damage_source_id()
	var base_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	if _has_talent(owner, "mage_entry_mark"):
		for target in owner._get_enemy_targets(32, false):
			if target == null or not is_instance_valid(target):
				continue
			if owner.global_position.distance_to(target.global_position) > 248.0:
				continue
			centers.append(owner._get_enemy_aim_point(target, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target.global_position)
			if centers.size() >= ENTRY_LIGHTNING_COUNT:
				break
	for index in range(ENTRY_LIGHTNING_COUNT):
		if centers.size() >= ENTRY_LIGHTNING_COUNT:
			break
		var angle_offset: float = TAU * float(index) / float(ENTRY_LIGHTNING_COUNT)
		var direction: Vector2 = base_direction.rotated(angle_offset).normalized()
		centers.append(owner.global_position + direction * ENTRY_LIGHTNING_DISTANCE)
	PLAYER_MAGE_ENTRY_TALENT_FLOW.append_extra_ring_centers(owner, centers, base_direction, ENTRY_LIGHTNING_COUNT, ENTRY_LIGHTNING_DISTANCE)
	for center in centers:
		owner._spawn_mage_warning_scene_effect(center, ENTRY_LIGHTNING_RADIUS)
	var damage_amount: float = owner._get_role_damage(role_id) * ENTRY_LIGHTNING_DAMAGE_SCALE * max(0.0, damage_scale)
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		return _resolve_entry_lightning_ring(owner, role_id, centers, damage_amount, entry_source_id)
	var warning_duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
		if is_instance_valid(owner):
			_resolve_entry_lightning_ring(owner, role_id, centers, damage_amount, entry_source_id)
	, warning_duration)
	return 0

func _resolve_entry_lightning_ring(owner, role_id: String, centers: Array[Vector2], damage_amount: float, source_role_id: String = "") -> int:
	var damage_source_role_id := source_role_id if source_role_id != "" else role_id
	var total_hits: int = 0
	var best_center: Vector2 = owner.global_position
	var best_center_hits: int = -1
	var unique_targets: Dictionary = {}
	for center in centers:
		var center_hits := _collect_enemy_ids_in_radius(owner, center, ENTRY_LIGHTNING_RADIUS, unique_targets)
		if center_hits > best_center_hits:
			best_center_hits = center_hits
			best_center = center
		owner._spawn_mage_boom_scene_effect(center, ENTRY_LIGHTNING_RADIUS)
		var slow_multiplier := _get_entry_slow_multiplier(owner)
		var slow_duration := _get_entry_slow_duration(owner)
		total_hits += owner._damage_enemies_in_radius(center, ENTRY_LIGHTNING_RADIUS, damage_amount, 0.0, slow_multiplier, slow_duration, damage_source_role_id)
	if _has_talent(owner, "mage_entry_echo") and best_center_hits > 0:
		for echo_index in range(2):
			var echo_delay := 0.45 + float(echo_index) * 0.10
			var echo_callback := func(_index: int) -> void:
				if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
					return
				owner._spawn_mage_boom_scene_effect(best_center, ENTRY_LIGHTNING_RADIUS)
				owner._damage_enemies_in_radius(best_center, ENTRY_LIGHTNING_RADIUS, damage_amount * 0.35, 0.0, _get_entry_slow_multiplier(owner), _get_entry_slow_duration(owner), damage_source_role_id)
			if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
				echo_callback.call(0)
			else:
				owner._schedule_repeating_sequence(0.0, 1, echo_callback, echo_delay)
	if _has_talent(owner, "mage_entry_canopy"):
		_start_entry_lightning_canopy(owner, role_id, centers, damage_amount, damage_source_role_id)
	if _has_talent(owner, "mage_entry_surge") and unique_targets.size() >= 5 and owner.has_method("_add_mage_arcane_charge_stacks"):
		owner._add_mage_arcane_charge_stacks(2)
	if _has_talent(owner, "mage_entry_center"):
		var center_point: Vector2 = owner.global_position
		if not centers.is_empty():
			center_point = Vector2.ZERO
			for lightning_center in centers:
				center_point += lightning_center
			center_point /= float(centers.size())
		var center_callback := func(_index: int) -> void:
			if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
				return
			owner._spawn_mage_boom_scene_effect(center_point, ENTRY_LIGHTNING_RADIUS * 1.50)
			owner._damage_enemies_in_radius(center_point, ENTRY_LIGHTNING_RADIUS * 1.50, damage_amount * 0.60, 0.0, _get_entry_slow_multiplier(owner), _get_entry_slow_duration(owner), damage_source_role_id)
		if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
			center_callback.call(0)
		else:
			owner._schedule_repeating_sequence(0.0, 1, center_callback, 0.25)
	return total_hits

func _get_entry_slow_multiplier(owner) -> float:
	return 0.80 if _has_talent(owner, "mage_entry_static") else 1.0

func _get_entry_slow_duration(owner) -> float:
	return 1.25 if _has_talent(owner, "mage_entry_static") else 0.0

func _collect_enemy_ids_in_radius(owner, center: Vector2, radius: float, result: Dictionary) -> int:
	if owner == null or not owner.has_method("_get_live_enemies"):
		return 0
	var count := 0
	for enemy in owner._get_live_enemies():
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if (enemy as Node2D).global_position.distance_squared_to(center) > radius * radius:
			continue
		result[(enemy as Node).get_instance_id()] = true
		count += 1
	return count

func _start_entry_lightning_canopy(owner, role_id: String, centers: Array[Vector2], damage_amount: float, source_role_id: String = "") -> void:
	var damage_source_role_id := source_role_id if source_role_id != "" else role_id
	var hit_enemy_ids: Dictionary = {}
	for center in centers:
		owner._spawn_ring_effect(center, ENTRY_LIGHTNING_RADIUS, Color(0.38, 0.78, 1.0, 0.28), 5.0, 1.5)
	var callback := func(_index: int) -> void:
		if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")) or not owner.has_method("_get_live_enemies"):
			return
		for enemy in owner._get_live_enemies():
			if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
				continue
			var enemy_node := enemy as Node2D
			var enemy_id := enemy_node.get_instance_id()
			if hit_enemy_ids.has(enemy_id):
				continue
			for center in centers:
				if enemy_node.global_position.distance_squared_to(center) <= ENTRY_LIGHTNING_RADIUS * ENTRY_LIGHTNING_RADIUS:
					hit_enemy_ids[enemy_id] = true
					owner._damage_enemies_in_radius(enemy_node.global_position, 4.0, damage_amount * 0.30, 0.0, 0.85, 1.0, damage_source_role_id)
					break
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		callback.call(0)
	else:
		owner._schedule_repeating_sequence(0.25, 6, callback)

func perform_exit(owner, _role_id: String, _rearguard_level: int) -> int:
	record_arcane_dawn(owner, int(owner.get("mage_arcane_charge_stacks")))
	return 0

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var storm_level: int = int(special_data.get("storm_level", 0))
	var center: Vector2 = owner._get_enemy_cluster_center()
	if center == Vector2.ZERO:
		center = owner.global_position
	var ultimate_tier: int = _get_ultimate_skill_tier(owner)
	var total_duration: float = _get_ultimate_duration(owner, cast_payload)
	var bombard_count: int = max(1, int(floor(total_duration / ULTIMATE_BOMBARD_INTERVAL)) + PLAYER_BUILD_SYSTEM.get_mage_ultimate_bombard_count_bonus(owner) + PLAYER_MAGE_ULTIMATE_TALENT_FLOW.get_extra_bombard_count(owner))
	var combo_scales: Array[float] = _get_ultimate_combo_scales(owner)
	var bombard_scales: Array[float] = _build_ultimate_segment_scales(bombard_count, combo_scales)
	var target_state: Dictionary = _build_ultimate_talent_target_state(owner, center)
	var total_sequence_duration: float = 0.28 + float(bombard_scales.size() - 1) * ULTIMATE_BOMBARD_INTERVAL
	owner._queue_camera_shake(18.5, 0.58)
	owner._delay_level_up_requests(total_sequence_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "奥数轰炸", Color(0.82, 0.96, 1.0, 1.0))
	owner._spawn_ring_effect(center, 118.0 + storm_level * 10.0, Color(0.72, 0.96, 1.0, 0.82), 10.0, 0.22)
	_schedule_ultimate_bombardment_sequence(owner, bombard_scales, storm_level, _get_ultimate_damage_multiplier(owner, cast_payload), ultimate_tier, center, 0.0, total_sequence_duration, target_state)
	owner._apply_post_ultimate_bonuses("mage", total_sequence_duration)

func _schedule_ultimate_bombardment_sequence(owner, bombard_scales: Array[float], storm_level: int, cast_damage_multiplier: float, ultimate_tier: int, cast_center: Vector2, start_delay: float, surplus_delay: float = 0.0, target_state: Dictionary = {}) -> void:
	var bombard_count: int = bombard_scales.size()
	var sequence_callback := func(pulse_index: int) -> void:
		_trigger_ultimate_bombardment(owner, bombard_scales, storm_level, cast_damage_multiplier, pulse_index, ultimate_tier, cast_center, target_state)
	if start_delay <= 0.0:
		owner._schedule_repeating_sequence(ULTIMATE_BOMBARD_INTERVAL, bombard_count, sequence_callback)
	else:
		owner._schedule_repeating_sequence(ULTIMATE_BOMBARD_INTERVAL, bombard_count, sequence_callback, start_delay)
	if surplus_delay <= 0.0 or not owner.has_method("_schedule_repeating_sequence"):
		var arcane_surplus_duration: float = _get_arcane_surplus_duration(owner)
		owner.mage_arcane_surplus_remaining = max(owner.mage_arcane_surplus_remaining, arcane_surplus_duration)
		owner._start_duration_status(ENTRY_ARCANE_SURPLUS_STATUS_ID, "\u5965\u6CD5\u76C8\u4F59", arcane_surplus_duration, 18, Color(0.34, 0.72, 1.0, 0.95))
		return
	owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
		if not is_instance_valid(owner):
			return
		var arcane_surplus_duration: float = _get_arcane_surplus_duration(owner)
		owner.mage_arcane_surplus_remaining = max(owner.mage_arcane_surplus_remaining, arcane_surplus_duration)
		owner._start_duration_status(ENTRY_ARCANE_SURPLUS_STATUS_ID, "\u5965\u6CD5\u76C8\u4F59", arcane_surplus_duration, 18, Color(0.34, 0.72, 1.0, 0.95))
	, surplus_delay)

func _trigger_ultimate_bombardment(owner, bombard_scales: Array[float], storm_level: int, cast_damage_multiplier: float, pulse_index: int, ultimate_tier: int = 1, cast_center: Vector2 = Vector2.ZERO, target_state: Dictionary = {}) -> void:
	if owner.is_dead:
		return

	var pulse_count: int = bombard_scales.size()
	var effect_scale: float = 1.0
	if pulse_index >= 0 and pulse_index < pulse_count:
		effect_scale = float(bombard_scales[pulse_index])
	var cluster_center: Vector2 = _get_ultimate_talent_center(owner, cast_center, pulse_index, target_state)
	if cluster_center == Vector2.ZERO:
		cluster_center = owner.global_position
	var phase: float = float(pulse_index) / float(max(1, pulse_count - 1))
	var orbit_angle: float = phase * TAU * 1.6
	var main_center: Vector2 = cluster_center + Vector2.RIGHT.rotated(orbit_angle) * (12.0 + 8.0 * sin(orbit_angle * 1.4))
	if _cast_has_ultimate_talent(target_state, "mage_ultimate_lock") or _cast_has_ultimate_talent(target_state, "mage_ultimate_triangle"):
		main_center = cluster_center
	var tier_damage_multiplier: float = 1.16 if ultimate_tier >= 2 else 1.0
	var role_range_multiplier: float = owner._get_role_attribute_range_multiplier("mage") * owner._get_role_equipment_skill_range_multiplier("mage")
	var pulse_radius: float = 100.0 * role_range_multiplier * owner._get_role_attribute_range_multiplier("mage")
	var pulse_damage: float = owner._get_role_damage("mage") * (ULTIMATE_BASE_DAMAGE_RATIO + storm_level * 0.08) * cast_damage_multiplier * max(0.0, effect_scale) * tier_damage_multiplier * ULTIMATE_GUNNER_ULTIMATE_OUTPUT_RATIO * PLAYER_MAGE_ULTIMATE_TALENT_FLOW.get_pulse_damage_multiplier(owner)
	if _cast_has_ultimate_talent(target_state, "mage_ultimate_lock"):
		pulse_radius *= 0.70
		pulse_damage *= 1.25
	elif _cast_has_ultimate_talent(target_state, "mage_ultimate_triangle"):
		pulse_radius *= 0.80
	if _cast_has_ultimate_talent(target_state, "mage_ultimate_eclipse"):
		pulse_damage *= 1.0 + 0.04 * float(min(5, max(0, pulse_index)))
	if _cast_has_ultimate_talent(target_state, "mage_ultimate_canopy"):
		pulse_radius *= 1.15
		pulse_damage *= 0.92
	var ultimate_source_id := PLAYER_MAGE_ULTIMATE_TALENT_FLOW.make_damage_source_id(pulse_index)
	owner._queue_camera_shake(6.4 + float(storm_level) * 0.28, 0.12)
	if _should_spawn_ultimate_pulse_visual(pulse_index):
		owner._spawn_ring_effect(main_center, pulse_radius, Color(0.72, 0.96, 1.0, 0.76), 6.0, 0.18)
		owner._spawn_burst_effect(main_center, pulse_radius, Color(0.5, 0.92, 1.0, 0.24), 0.2)
	var shape_hits: int = owner._damage_enemies_in_radius(
		main_center,
		pulse_radius,
		pulse_damage,
		0.0,
		1.0,
		0.0,
		ultimate_source_id
	)
	if shape_hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result("mage", shape_hits, false)
	if pulse_index == pulse_count - 1 and _cast_has_ultimate_talent(target_state, "mage_ultimate_afterglow"):
		var afterglow_radius := pulse_radius * 1.25
		owner._spawn_ring_effect(main_center, afterglow_radius, Color(0.86, 0.96, 1.0, 0.84), 8.0, 0.2)
		owner._spawn_burst_effect(main_center, afterglow_radius, Color(0.64, 0.9, 1.0, 0.32), 0.24)
		owner._damage_enemies_in_radius(main_center, afterglow_radius, pulse_damage * 1.60, 0.0, 1.0, 0.0, ultimate_source_id)
	if pulse_index == pulse_count - 1 and _cast_has_ultimate_talent(target_state, "mage_ultimate_scorch"):
		_start_ultimate_scorch(owner, main_center, pulse_radius, pulse_damage, ultimate_source_id)

func _start_ultimate_scorch(owner, center: Vector2, radius: float, pulse_damage: float, source_role_id: String = "mage") -> void:
	owner._spawn_ring_effect(center, radius, Color(0.42, 0.74, 1.0, 0.30), 6.0, 2.0)
	var callback := func(_index: int) -> void:
		if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
			return
		owner._spawn_burst_effect(center, radius, Color(0.36, 0.72, 1.0, 0.16), 0.18)
		owner._damage_enemies_in_radius(center, radius, pulse_damage * 0.25, 0.0, 1.0, 0.0, source_role_id)
	if owner.get_tree() == null or not owner.has_method("_schedule_repeating_sequence"):
		for index in range(4):
			callback.call(index)
	else:
		owner._schedule_repeating_sequence(0.5, 4, callback)

func _build_ultimate_talent_target_state(owner, cast_center: Vector2) -> Dictionary:
	var state := {"talents": {}}
	for talent_id in [
		"mage_ultimate_lock",
		"mage_ultimate_triangle",
		"mage_ultimate_eclipse",
		"mage_ultimate_afterglow",
		"mage_ultimate_canopy",
		"mage_ultimate_scorch"
	]:
		state["talents"][talent_id] = _has_talent(owner, talent_id)
	if _cast_has_ultimate_talent(state, "mage_ultimate_lock"):
		var target: Node2D = null
		if owner.has_method("_get_priority_boss_target"):
			target = owner._get_priority_boss_target(owner.global_position)
		if target == null:
			var best_distance := INF
			for candidate in owner._get_enemy_targets(64, false):
				if candidate == null or not is_instance_valid(candidate):
					continue
				var distance: float = candidate.global_position.distance_squared_to(cast_center)
				if distance < best_distance:
					best_distance = distance
					target = candidate
		var last_position: Vector2 = cast_center
		if target != null and is_instance_valid(target):
			last_position = owner._get_enemy_aim_point(target, cast_center) if owner.has_method("_get_enemy_aim_point") else target.global_position
		state["target"] = target
		state["last_position"] = last_position
	elif _cast_has_ultimate_talent(state, "mage_ultimate_triangle"):
		var nodes: Array[Vector2] = []
		for index in range(3):
			nodes.append(cast_center + Vector2.RIGHT.rotated(-PI * 0.5 + TAU * float(index) / 3.0) * 96.0)
		state["triangle_nodes"] = nodes
	return state

func _get_ultimate_talent_center(owner, fallback_center: Vector2, pulse_index: int, target_state: Dictionary) -> Vector2:
	if _cast_has_ultimate_talent(target_state, "mage_ultimate_lock"):
		var target: Variant = target_state.get("target")
		if target != null and is_instance_valid(target) and not target.is_queued_for_deletion() and float(target.get("current_health")) > 0.0:
			var position: Vector2 = owner._get_enemy_aim_point(target, fallback_center) if owner.has_method("_get_enemy_aim_point") else target.global_position
			target_state["last_position"] = position
		return target_state.get("last_position", fallback_center)
	if _cast_has_ultimate_talent(target_state, "mage_ultimate_triangle"):
		var nodes: Array = target_state.get("triangle_nodes", [])
		if not nodes.is_empty():
			return nodes[posmod(pulse_index, nodes.size())]
	return _get_ultimate_bombard_lock_center(owner, fallback_center)

func _cast_has_ultimate_talent(target_state: Dictionary, talent_id: String) -> bool:
	var talents: Dictionary = target_state.get("talents", {})
	return bool(talents.get(talent_id, false))

func _get_ultimate_bombard_lock_center(owner, fallback_center: Vector2) -> Vector2:
	var priority_boss: Node2D = null
	if owner != null and owner.has_method("_get_priority_boss_target") and randf() <= ULTIMATE_BOSS_TARGET_WEIGHT:
		priority_boss = owner._get_priority_boss_target(owner.global_position)
	if priority_boss != null and is_instance_valid(priority_boss):
		return owner._get_enemy_aim_point(priority_boss, owner.global_position) if owner.has_method("_get_enemy_aim_point") else priority_boss.global_position
	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	if cluster_center != Vector2.ZERO:
		return cluster_center
	var target_enemy: Node2D = owner._get_closest_enemy()
	if target_enemy != null and is_instance_valid(target_enemy):
		return owner._get_enemy_aim_point(target_enemy, owner.global_position) if owner.has_method("_get_enemy_aim_point") else target_enemy.global_position
	return fallback_center

func _get_ultimate_skill_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return max(1, int(owner._get_blessing_skill_tier(ULTIMATE_SKILL_ID)))
	return 1

func _get_ultimate_combo_scales(owner) -> Array[float]:
	if owner != null and owner.has_method("_get_blessing_skill_combo_scales"):
		return owner._get_blessing_skill_combo_scales(ULTIMATE_SKILL_ID) as Array[float]
	return []

func _get_ultimate_duration(owner, cast_payload: Dictionary) -> float:
	var duration: float = ULTIMATE_DURATION * float(cast_payload.get("duration_multiplier", 1.0))
	if owner != null and owner.has_method("_get_blessing_skill_duration_multiplier"):
		duration *= float(owner._get_blessing_skill_duration_multiplier(ULTIMATE_SKILL_ID))
	if owner != null and owner.has_method("_get_blessing_skill_duration_flat_bonus"):
		duration += float(owner._get_blessing_skill_duration_flat_bonus(ULTIMATE_SKILL_ID))
	return max(ULTIMATE_BOMBARD_INTERVAL, duration)

func _get_ultimate_damage_multiplier(owner, cast_payload: Dictionary) -> float:
	var multiplier: float = float(cast_payload.get("damage_multiplier", 1.0))
	if owner != null and owner.has_method("_get_blessing_ultimate_damage_multiplier"):
		multiplier *= float(owner._get_blessing_ultimate_damage_multiplier(ULTIMATE_SKILL_ID))
	return multiplier

func _should_spawn_ultimate_pulse_visual(pulse_index: int) -> bool:
	var fps: int = PERFORMANCE_GUARD.get_fps()
	if fps > 0 and fps < PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return pulse_index % 3 == 0
	if fps > 0 and fps < PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return pulse_index % 2 == 0
	return true

func _build_ultimate_segment_scales(base_count: int, combo_scales: Array[float]) -> Array[float]:
	var result: Array[float] = []
	for _index in range(max(0, base_count)):
		result.append(1.0)
	for scale in combo_scales:
		result.append(max(0.05, float(scale)))
	return result

func _apply_damage_shapes(owner, shapes: Array[Dictionary]) -> int:
	if owner != null and owner.has_method("_damage_enemies_in_shapes_batched"):
		return int(owner._damage_enemies_in_shapes_batched(shapes))
	var hits := 0
	for shape in shapes:
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

func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_shapes_batched")

func _has_talent(owner, talent_id: String) -> bool:
	return owner != null and owner.has_method("_has_skill_talent") and bool(owner._has_skill_talent(talent_id))

func get_arcane_transfer_duration(owner, stacks: int, base_duration: float) -> float:
	if _has_talent(owner, "mage_trait_flow"):
		return base_duration + 0.4 * float(clampi(stacks, 0, 10))
	return base_duration

func get_arcane_surplus_expire_stacks(owner, base_stacks: int) -> int:
	return base_stacks + (2 if _has_talent(owner, "mage_trait_overflow") else 0)

func get_arcane_relay_limit(owner) -> int:
	var relay_limit := 0
	if _has_talent(owner, "mage_trait_relay_chain"):
		relay_limit += 1
	if _has_talent(owner, "mage_trait_relay"):
		relay_limit += 1
	return relay_limit

func get_arcane_relay_remaining(owner, remaining: float) -> float:
	return remaining * 0.70 if _has_talent(owner, "mage_trait_relay_chain") else remaining

func record_arcane_dawn(owner, transfer_stacks: int) -> void:
	if not _has_talent(owner, "mage_trait_dawn") or transfer_stacks < 8:
		return
	var state: Dictionary = owner._get_role_special_state("mage")
	state["arcane_dawn_armed"] = true
	owner.role_special_states["mage"] = state

func consume_arcane_dawn_duration_bonus(owner) -> float:
	var state: Dictionary = owner._get_role_special_state("mage")
	if not bool(state.get("arcane_dawn_armed", false)):
		return 0.0
	state["arcane_dawn_armed"] = false
	owner.role_special_states["mage"] = state
	return 2.0
