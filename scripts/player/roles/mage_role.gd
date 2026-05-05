extends RefCounted

const MAGE_ATTACK_EFFECT_SCALE := 0.8
const BASIC_COMBO_INTERVAL := 0.16
const ULTIMATE_SKILL_ID := "mage_ultimate"
const ULTIMATE_COMBO_INTERVAL := 0.18
const ULTIMATE_EXTRA_BOMBARDS := 8
const ULTIMATE_TIER_TWO_EXTRA_BOMBARDS := 6
const ULTIMATE_TIER_THREE_EXTRA_BOMBARDS := 3
const ULTIMATE_TIER_THREE_KILL_ENERGY := 0.45

func perform_attack(owner) -> void:
	var contexts: Array[Dictionary] = _build_attack_contexts(owner)
	if contexts.is_empty():
		return
	var combo_scales: Array[float] = [1.0]
	combo_scales.append_array(_get_skill_effect_scales(owner, "combo_skill_extra"))
	_start_basic_attack_combo_sequence(owner, contexts, combo_scales)
	owner._spawn_attack_aftershock(contexts[0].get("center", owner.global_position), str((contexts[0].get("role_data", {}) as Dictionary).get("id", "mage")))

func _perform_combo_segment(owner, contexts: Array[Dictionary], combo_scale: float) -> void:
	for index in range(contexts.size()):
		_cast_attack_context(owner, contexts[index], combo_scale, index == 0)

func _start_basic_attack_combo_sequence(owner, contexts: Array[Dictionary], combo_scales: Array[float]) -> void:
	if combo_scales.is_empty():
		return
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		for combo_index in range(combo_scales.size()):
			_perform_combo_segment(owner, contexts, float(combo_scales[combo_index]))
		return

	var controller := Node2D.new()
	controller.name = "MageBasicAttackComboSequence"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	var warning_duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
	var boom_duration: float = owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	tween.tween_callback(func() -> void:
		if is_instance_valid(owner):
			_spawn_basic_attack_warning_group(owner, contexts)
	)
	tween.tween_interval(warning_duration)
	for combo_index in range(combo_scales.size()):
		var combo_scale: float = float(combo_scales[combo_index])
		tween.tween_callback(func() -> void:
			if is_instance_valid(owner):
				_spawn_basic_attack_boom_group(owner, contexts, combo_scale)
		)
		tween.tween_interval(boom_duration)
		tween.tween_callback(func() -> void:
			if is_instance_valid(owner):
				_resolve_basic_attack_group(owner, contexts, combo_scale)
		)
	tween.tween_callback(controller.queue_free)

func _perform_combo_segment_if_valid(owner, contexts: Array[Dictionary], combo_scale: float) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	_perform_combo_segment(owner, contexts, combo_scale)

func _spawn_basic_attack_warning_group(owner, contexts: Array[Dictionary]) -> void:
	for context in contexts:
		var center: Vector2 = context.get("center", owner.global_position)
		var radius: float = float(context.get("radius", 44.0))
		owner._spawn_mage_warning_scene_effect(center, radius)

func _spawn_basic_attack_boom_group(owner, contexts: Array[Dictionary], combo_scale: float) -> void:
	for context in contexts:
		var center: Vector2 = context.get("center", owner.global_position)
		var radius: float = float(context.get("radius", 44.0)) * max(0.05, combo_scale)
		owner._spawn_mage_boom_scene_effect(center, radius)

func _resolve_basic_attack_group(owner, contexts: Array[Dictionary], combo_scale: float) -> void:
	if owner == null or not is_instance_valid(owner) or bool(owner.get("is_dead")):
		return
	for index in range(contexts.size()):
		_resolve_basic_attack_context(owner, contexts[index], combo_scale, index == 0)

func _resolve_basic_attack_context(owner, context: Dictionary, combo_scale: float, advance_attack_chain: bool) -> void:
	var role_data: Dictionary = context.get("role_data", {})
	var center: Vector2 = context.get("center", owner.global_position)
	var radius: float = float(context.get("radius", 44.0)) * max(0.05, combo_scale)
	var damage_amount: float = float(context.get("damage_amount", 0.0)) * max(0.0, combo_scale)
	owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, 0.0, 1.0, 0.0, 0, 0, 0, role_data["id"], true, advance_attack_chain)

func _build_attack_contexts(owner) -> Array[Dictionary]:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var arcane_focus_level: float = 0.0
	var bombard_center: Vector2 = owner._get_mage_mouse_bombard_center(float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)))
	var centers: Array[Vector2] = [bombard_center]
	for target in owner._get_enemy_targets(_get_skill_effect_scales(owner, "quantity_skill_count").size(), false):
		if target != null and is_instance_valid(target):
			var target_center: Vector2 = target.global_position
			if target_center.distance_to(bombard_center) >= 32.0:
				centers.append(target_center)
	while centers.size() < 1 + _get_skill_effect_scales(owner, "quantity_skill_count").size():
		var angle: float = TAU * float(centers.size()) / float(max(2, 1 + _get_skill_effect_scales(owner, "quantity_skill_count").size()))
		centers.append(bombard_center + Vector2.RIGHT.rotated(angle) * 72.0)
	var contexts: Array[Dictionary] = []
	var quantity_scales: Array[float] = [1.0]
	quantity_scales.append_array(_get_skill_effect_scales(owner, "quantity_skill_count"))
	for index in range(centers.size()):
		var center: Vector2 = centers[index]
		var effect_scale: float = float(quantity_scales[min(index, quantity_scales.size() - 1)])
		contexts.append(_build_attack_context(owner, role_data, upgrade_data, special_data, center, effect_scale, arcane_focus_level))
	return contexts

func _build_attack_context(owner, role_data: Dictionary, upgrade_data: Dictionary, _special_data: Dictionary, bombard_center: Vector2, effect_scale: float, arcane_focus_level: float) -> Dictionary:
	var target_enemy: Node2D = owner._get_enemy_near_position(bombard_center, 56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.25)
	var radius: float = (44.0 + float(upgrade_data["range_bonus"]) * 0.55) * owner._get_story_style_range_multiplier(role_data["id"])
	radius *= owner._get_role_attribute_range_multiplier("mage")
	radius *= owner._get_mage_arcane_focus_range_multiplier(arcane_focus_level)
	radius *= _get_basic_attack_range_multiplier(owner)
	var damage_amount: float = owner._get_role_damage(role_data["id"]) * 0.96 * max(0.0, effect_scale)
	if target_enemy != null:
		damage_amount *= owner._get_priority_target_bonus(target_enemy)
	radius *= MAGE_ATTACK_EFFECT_SCALE
	return {
		"role_data": role_data,
		"center": bombard_center,
		"radius": radius,
		"damage_amount": damage_amount,
		"arcane_focus_level": arcane_focus_level
	}

func _cast_attack_context(owner, context: Dictionary, scale: float, advance_attack_chain: bool) -> void:
	var role_data: Dictionary = context.get("role_data", {})
	var arcane_focus_level: float = float(context.get("arcane_focus_level", 0.0))
	var bombard_center: Vector2 = context.get("center", owner.global_position)
	var radius: float = float(context.get("radius", 44.0)) * max(0.05, scale)
	var damage_amount: float = float(context.get("damage_amount", 0.0)) * max(0.0, scale)
	if arcane_focus_level > 6:
		_start_evolved_arcane_bombardment(owner, bombard_center, radius, damage_amount, 0.0, 1.0, 0.0, 0, 0, 0, role_data["id"], arcane_focus_level > 12)
	else:
		owner._start_basic_mage_bombardment(bombard_center, radius, damage_amount, 0.0, 1.0, 0.0, 0, 0, 0, role_data["id"], true, advance_attack_chain)

func _get_skill_effect_scales(owner, stat: String) -> Array[float]:
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales_for_skill"):
		return owner._get_skill_blessing_effect_scales_for_skill("mage_basic_attack", stat)
	if owner != null and owner.has_method("_get_skill_blessing_effect_scales"):
		return owner._get_skill_blessing_effect_scales(stat)
	return []

func _get_basic_attack_range_multiplier(owner) -> float:
	if owner != null and owner.has_method("_get_basic_attack_range_multiplier"):
		return float(owner._get_basic_attack_range_multiplier("mage_basic_attack"))
	return 1.0

func _start_evolved_arcane_bombardment(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, third_tier: bool = false) -> void:
	owner._start_basic_mage_bombardment(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, false)
	var followup_count: int = 2 if third_tier else 1
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene == null:
		for followup_index in range(followup_count):
			owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, followup_index == followup_count - 1)
		return
	var controller := Node2D.new()
	controller.name = "MageArcaneBurstSecondBombardment"
	current_scene.add_child(controller)
	var tween := controller.create_tween()
	var first_damage_delay: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2) + owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	var boom_duration: float = owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
	tween.tween_interval(first_damage_delay + 0.06)
	for followup_index in range(followup_count):
		tween.tween_callback(Callable(owner, "_spawn_mage_boom_scene_effect").bind(center, radius))
		tween.tween_interval(boom_duration)
		tween.tween_callback(Callable(owner, "_resolve_basic_mage_bombardment_damage").bind(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, followup_index == followup_count - 1))
		if followup_index < followup_count - 1:
			tween.tween_interval(0.06)
	tween.tween_callback(controller.queue_free)

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
		cluster_position = target_enemy.global_position

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
			if secondary_target.global_position.distance_to(cluster_position) < 40.0:
				continue
			owner._start_basic_mage_bombardment(
				secondary_target.global_position,
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

func perform_enter(owner, role_id: String, _assault_level: int, _assault_multiplier: float) -> int:
	owner._show_switch_banner("\u8FDB\u573A", "\u971C\u73AF\u548F\u5531", Color(0.54, 0.9, 1.0, 1.0))
	var bombard_count := 3
	var radius_multiplier: float = float(owner._get_role_blessing_stat_bonus(role_id, "skill_range")) + 1.0
	var bombard_centers: Array = owner._get_random_enemy_cluster_centers(bombard_count)
	var total_hits: int = 0
	for bombard_center in bombard_centers:
		total_hits += owner._count_enemies_in_radius(bombard_center, owner.MAGE_ENTRY_HIT_RADIUS * radius_multiplier)
	owner._start_mage_entry_bombardment(role_id, bombard_centers)
	return total_hits

func perform_exit(_owner, _role_id: String, _rearguard_level: int) -> int:
	return 0

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var storm_level: int = int(special_data.get("storm_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var echo_level: int = int(special_data.get("echo_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var center: Vector2 = owner._get_enemy_cluster_center()
	if center == Vector2.ZERO:
		center = owner.global_position
	var bombard_count: int = 11 + storm_level * 2
	bombard_count = int(ceil(float(bombard_count) * float(cast_payload.get("duration_multiplier", 1.0))))
	bombard_count += ULTIMATE_EXTRA_BOMBARDS
	var ultimate_tier: int = _get_ultimate_skill_tier(owner)
	if ultimate_tier >= 2:
		bombard_count += ULTIMATE_TIER_TWO_EXTRA_BOMBARDS
	if ultimate_tier >= 3:
		bombard_count += ULTIMATE_TIER_THREE_EXTRA_BOMBARDS
	var combo_scales: Array[float] = _get_ultimate_combo_scales(owner)
	var total_duration: float = 0.28 + float(bombard_count - 1) * owner.MAGE_ULTIMATE_BOMBARD_INTERVAL
	if not combo_scales.is_empty():
		total_duration += ULTIMATE_COMBO_INTERVAL * float(combo_scales.size())
	owner._queue_camera_shake(18.5, 0.58)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.45)
	owner._delay_level_up_requests(total_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "奥数轰炸", Color(0.82, 0.96, 1.0, 1.0))
	owner._spawn_vortex_effect(center, 58.0 + gravity_level * 12.0, Color(0.76, 0.84, 1.0, 0.54), 0.32)
	owner._spawn_ring_effect(center, 118.0 + storm_level * 10.0, Color(0.72, 0.96, 1.0, 0.82), 10.0, 0.22)
	_schedule_ultimate_bombardment_sequence(owner, bombard_count, storm_level, frost_level, echo_level, gravity_level, float(cast_payload.get("damage_multiplier", 1.0)), ultimate_tier, 1.0, 0.0)
	for combo_index in range(combo_scales.size()):
		_schedule_ultimate_bombardment_sequence(owner, bombard_count, storm_level, frost_level, echo_level, gravity_level, float(cast_payload.get("damage_multiplier", 1.0)), ultimate_tier, float(combo_scales[combo_index]), ULTIMATE_COMBO_INTERVAL * float(combo_index + 1))
	owner._apply_post_ultimate_bonuses("mage", total_duration)

func _schedule_ultimate_bombardment_sequence(owner, bombard_count: int, storm_level: int, frost_level: int, echo_level: int, gravity_level: int, cast_damage_multiplier: float, ultimate_tier: int, effect_scale: float, start_delay: float) -> void:
	var sequence_callback := func(pulse_index: int) -> void:
		_trigger_ultimate_bombardment(owner, bombard_count, storm_level, frost_level, echo_level, gravity_level, cast_damage_multiplier, pulse_index, ultimate_tier, effect_scale)
	if start_delay <= 0.0:
		owner._schedule_repeating_sequence(owner.MAGE_ULTIMATE_BOMBARD_INTERVAL, bombard_count, sequence_callback)
		return
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(start_delay)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(owner):
			owner._schedule_repeating_sequence(owner.MAGE_ULTIMATE_BOMBARD_INTERVAL, bombard_count, sequence_callback)
	)

func _trigger_ultimate_bombardment(owner, pulse_count: int, storm_level: int, frost_level: int, echo_level: int, gravity_level: int, cast_damage_multiplier: float, pulse_index: int, ultimate_tier: int = 1, effect_scale: float = 1.0) -> void:
	if owner.is_dead:
		return

	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	if cluster_center == Vector2.ZERO:
		cluster_center = owner.global_position
	var phase: float = float(pulse_index) / float(max(1, pulse_count - 1))
	var orbit_angle: float = phase * TAU * (1.6 + float(echo_level) * 0.18)
	var main_center: Vector2 = cluster_center + Vector2.RIGHT.rotated(orbit_angle) * (12.0 + 8.0 * sin(orbit_angle * 1.4))
	var tier_damage_multiplier: float = 1.16 if ultimate_tier >= 2 else 1.0
	var scale: float = max(0.05, effect_scale)
	var pulse_radius: float = (72.0 + storm_level * 9.0 + frost_level * 4.0) * owner._get_story_style_range_multiplier("mage") * owner._get_role_attribute_range_multiplier("mage") * scale
	var pulse_damage: float = owner._get_role_damage("mage") * (0.72 + storm_level * 0.08 + echo_level * 0.04) * cast_damage_multiplier * max(0.0, effect_scale) * tier_damage_multiplier
	owner._queue_camera_shake(6.4 + float(storm_level) * 0.28, 0.12)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.08)
	if gravity_level > 0:
		owner._pull_enemies_toward(cluster_center, 132.0 + gravity_level * 18.0, 20.0 + gravity_level * 10.0)
		owner._spawn_vortex_effect(cluster_center, 40.0 + gravity_level * 14.0, Color(0.76, 0.82, 1.0, 0.42), 0.18)
	owner._spawn_ring_effect(main_center, pulse_radius, Color(0.72, 0.96, 1.0, 0.76), 6.0, 0.18)
	owner._spawn_burst_effect(main_center, pulse_radius, Color(0.5, 0.92, 1.0, 0.24), 0.2)
	owner._spawn_frost_sigils_effect(main_center, 34.0 + frost_level * 8.0, Color(0.86, 0.98, 1.0, 0.82), 0.18)
	var main_kills: int = 0
	var main_hits: int = 0
	if ultimate_tier >= 3 and owner.has_method("_damage_enemies_in_radius_count_kills"):
		var main_result: Dictionary = owner._damage_enemies_in_radius_count_kills(main_center, pulse_radius, pulse_damage, 0.08 + frost_level * 0.025, max(0.24, 0.46 - frost_level * 0.03), 2.2 + storm_level * 0.22, "mage")
		main_hits = int(main_result.get("hits", 0))
		main_kills = int(main_result.get("kills", 0))
	else:
		main_hits = owner._damage_enemies_in_radius(main_center, pulse_radius, pulse_damage, 0.08 + frost_level * 0.025, max(0.24, 0.46 - frost_level * 0.03), 2.2 + storm_level * 0.22)
	if main_hits > 0:
		owner._register_attack_result("mage", main_hits, false)
	if main_kills > 0:
		owner._add_kill_energy(float(main_kills) * ULTIMATE_TIER_THREE_KILL_ENERGY)

	if frost_level >= 2 and pulse_index % 3 == 0:
		owner._spawn_pulsing_field(main_center, 44.0 + frost_level * 10.0, Color(0.56, 0.92, 1.0, 0.16), 2, 0.1, owner._get_role_damage("mage") * (0.18 + frost_level * 0.04), 0.05, max(0.24, 0.4 - frost_level * 0.03), 1.8 + frost_level * 0.2)

	if echo_level > 0:
		var secondary_enemy: Node2D = owner._get_enemy_nearest_to_position(cluster_center + Vector2.RIGHT.rotated(orbit_angle + 1.8) * 84.0)
		if secondary_enemy != null and is_instance_valid(secondary_enemy):
			var echo_center: Vector2 = secondary_enemy.global_position
			if echo_center.distance_to(main_center) > 28.0:
				owner._spawn_burst_effect(echo_center, (46.0 + echo_level * 8.0) * scale, Color(0.68, 0.96, 1.0, 0.18), 0.18)
				var echo_hits: int = owner._damage_enemies_in_radius(echo_center, (46.0 + echo_level * 8.0) * scale, owner._get_role_damage("mage") * (0.3 + echo_level * 0.05) * max(0.0, effect_scale) * tier_damage_multiplier, 0.04, max(0.3, 0.52 - frost_level * 0.03), 1.8)
				if echo_hits > 0:
					owner._register_attack_result("mage", echo_hits, false)

func _get_ultimate_skill_tier(owner) -> int:
	if owner != null and owner.has_method("_get_blessing_skill_tier"):
		return max(1, int(owner._get_blessing_skill_tier(ULTIMATE_SKILL_ID)))
	return 1

func _get_ultimate_combo_scales(owner) -> Array[float]:
	if owner != null and owner.has_method("_get_blessing_skill_combo_scales"):
		return owner._get_blessing_skill_combo_scales(ULTIMATE_SKILL_ID) as Array[float]
	return []
