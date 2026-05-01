extends RefCounted

const MAGE_ATTACK_EFFECT_SCALE := 0.8

func perform_attack(owner) -> void:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var echo_level: int = int(special_data.get("echo_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var arcane_focus_level: float = 0.0
	var overload_level: int = owner._get_card_level("battle_overload")
	var bombard_center: Vector2 = owner._get_mage_mouse_bombard_center(float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)))
	var target_enemy: Node2D = owner._get_enemy_near_position(bombard_center, 56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.25)
	var radius: float = (44.0 + float(upgrade_data["range_bonus"]) * 0.55 + echo_level * 5.0 + frost_level * 5.0) * owner._get_story_style_range_multiplier(role_data["id"])
	radius *= owner._get_mage_arcane_focus_range_multiplier(arcane_focus_level)
	var damage_amount: float = owner._get_role_damage(role_data["id"]) * (0.96 + echo_level * 0.04)
	if target_enemy != null:
		damage_amount *= owner._get_priority_target_bonus(target_enemy)
	if overload_level > 0 and owner.mage_attack_chain == 2:
		radius += 10.0 + overload_level * 6.0
		damage_amount *= 1.16 + overload_level * 0.08
	radius *= MAGE_ATTACK_EFFECT_SCALE
	var vulnerability_bonus: float = 0.03 * frost_level
	var slow_multiplier: float = max(0.38, max(0.56, 0.76 - frost_level * 0.07) - owner._get_story_style_slow_bonus(role_data["id"]))
	var slow_duration: float = 1.0 + frost_level * 0.3 + overload_level * 0.15 if overload_level > 0 and owner.mage_attack_chain == 2 else 1.0 + frost_level * 0.3
	if arcane_focus_level > 6:
		_start_evolved_arcane_bombardment(owner, bombard_center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_data["id"], arcane_focus_level > 12)
	else:
		owner._start_basic_mage_bombardment(bombard_center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_data["id"], true)
	owner._spawn_attack_aftershock(bombard_center, role_data["id"])

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

	var radius: float = (44.0 + support_level * 8.0 + echo_level * 4.0 + frost_level * 4.0) * MAGE_ATTACK_EFFECT_SCALE
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

func perform_enter(owner, role_id: String, assault_level: int, _assault_multiplier: float) -> int:
	owner._show_switch_banner("\u8FDB\u573A", "\u971C\u73AF\u548F\u5531", Color(0.54, 0.9, 1.0, 1.0))
	var bombard_centers: Array = owner._get_random_enemy_cluster_centers(2)
	var total_hits: int = 0
	for bombard_center in bombard_centers:
		total_hits += owner._count_enemies_in_radius(bombard_center, owner.MAGE_ENTRY_HIT_RADIUS)
	owner._start_mage_entry_bombardment(role_id, bombard_centers)
	owner._activate_switch_power(role_id, "\u5171\u9E23\u8FC7\u8F7D", 2.4, 1.18, 0.07)
	owner._apply_switch_payoff(total_hits, 7.0 + assault_level, 1.2 + assault_level * 0.18)
	return total_hits

func perform_exit(owner, role_id: String, rearguard_level: int) -> int:
	owner._queue_next_entry_blessing(role_id)
	owner._show_switch_banner("\u9000\u573A", "\u7B26\u5370\u4F20\u5BFC", Color(0.56, 0.92, 1.0, 0.96))
	owner._spawn_ring_effect(owner.global_position, 96.0, Color(0.52, 0.88, 1.0, 0.58), 6.0, 0.18)
	owner._spawn_frost_sigils_effect(owner.global_position, 58.0, Color(0.82, 0.98, 1.0, 0.72), 0.2)
	if rearguard_level >= 3:
		owner._activate_guard_cover()
	return owner._trigger_rearguard_attack(role_id, owner.global_position, rearguard_level)

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var special_data: Dictionary = owner._get_role_special_state("mage")
	var storm_level: int = int(special_data.get("storm_level", 0))
	var frost_level: int = int(special_data.get("frost_level", 0))
	var echo_level: int = int(special_data.get("echo_level", 0))
	var gravity_level: int = int(special_data.get("gravity_level", 0))
	var extend_level: int = owner._get_card_level("skill_extend")
	var center: Vector2 = owner._get_enemy_cluster_center()
	if center == Vector2.ZERO:
		center = owner.global_position
	var bombard_count: int = 11 + storm_level * 2
	bombard_count = int(ceil(float(bombard_count) * (1.0 + extend_level * 0.12) * float(cast_payload.get("duration_multiplier", 1.0))))
	var total_duration: float = 0.28 + float(bombard_count - 1) * owner.MAGE_ULTIMATE_BOMBARD_INTERVAL
	total_duration *= 1.0 + extend_level * 0.04
	owner._queue_camera_shake(18.5, 0.58)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.45)
	if extend_level >= 2:
		owner.ultimate_guard_remaining = max(owner.ultimate_guard_remaining, total_duration)
		owner.ultimate_guard_damage_multiplier = min(owner.ultimate_guard_damage_multiplier, 0.9)
	owner._delay_level_up_requests(total_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "\u661F\u707E", Color(0.82, 0.96, 1.0, 1.0))
	owner._spawn_vortex_effect(center, 58.0 + gravity_level * 12.0, Color(0.76, 0.84, 1.0, 0.54), 0.32)
	owner._spawn_ring_effect(center, 118.0 + storm_level * 10.0, Color(0.72, 0.96, 1.0, 0.82), 10.0, 0.22)
	owner._schedule_repeating_sequence(owner.MAGE_ULTIMATE_BOMBARD_INTERVAL, bombard_count, func(pulse_index: int) -> void:
		_trigger_ultimate_bombardment(owner, bombard_count, storm_level, frost_level, echo_level, gravity_level, float(cast_payload.get("damage_multiplier", 1.0)), pulse_index)
	)
	owner._apply_post_ultimate_bonuses("mage", total_duration)

func _trigger_ultimate_bombardment(owner, pulse_count: int, storm_level: int, frost_level: int, echo_level: int, gravity_level: int, cast_damage_multiplier: float, pulse_index: int) -> void:
	if owner.is_dead:
		return

	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	if cluster_center == Vector2.ZERO:
		cluster_center = owner.global_position
	var phase: float = float(pulse_index) / float(max(1, pulse_count - 1))
	var orbit_angle: float = phase * TAU * (1.6 + float(echo_level) * 0.18)
	var main_center: Vector2 = cluster_center + Vector2.RIGHT.rotated(orbit_angle) * (12.0 + 8.0 * sin(orbit_angle * 1.4))
	var pulse_radius: float = (72.0 + storm_level * 9.0 + frost_level * 4.0) * owner._get_story_style_range_multiplier("mage")
	var pulse_damage: float = owner._get_role_damage("mage") * (0.72 + storm_level * 0.08 + echo_level * 0.04) * cast_damage_multiplier
	var finale_level: int = owner._get_card_level("skill_finale")
	if pulse_index == pulse_count - 1 and finale_level > 0:
		pulse_radius *= 1.2
		pulse_damage *= [1.45, 1.60, 1.75][finale_level - 1]
	owner._queue_camera_shake(6.4 + float(storm_level) * 0.28, 0.12)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.08)
	if gravity_level > 0:
		owner._pull_enemies_toward(cluster_center, 132.0 + gravity_level * 18.0, 20.0 + gravity_level * 10.0)
		owner._spawn_vortex_effect(cluster_center, 40.0 + gravity_level * 14.0, Color(0.76, 0.82, 1.0, 0.42), 0.18)
	owner._spawn_ring_effect(main_center, pulse_radius, Color(0.72, 0.96, 1.0, 0.76), 6.0, 0.18)
	owner._spawn_burst_effect(main_center, pulse_radius, Color(0.5, 0.92, 1.0, 0.24), 0.2)
	owner._spawn_frost_sigils_effect(main_center, 34.0 + frost_level * 8.0, Color(0.86, 0.98, 1.0, 0.82), 0.18)
	var main_hits: int = owner._damage_enemies_in_radius(main_center, pulse_radius, pulse_damage, 0.08 + frost_level * 0.025, max(0.24, 0.46 - frost_level * 0.03), 2.2 + storm_level * 0.22)
	if main_hits > 0:
		owner._register_attack_result("mage", main_hits, false)

	if frost_level >= 2 and pulse_index % 3 == 0:
		owner._spawn_pulsing_field(main_center, 44.0 + frost_level * 10.0, Color(0.56, 0.92, 1.0, 0.16), 2, 0.1, owner._get_role_damage("mage") * (0.18 + frost_level * 0.04), 0.05, max(0.24, 0.4 - frost_level * 0.03), 1.8 + frost_level * 0.2)

	if echo_level > 0:
		var secondary_enemy: Node2D = owner._get_enemy_nearest_to_position(cluster_center + Vector2.RIGHT.rotated(orbit_angle + 1.8) * 84.0)
		if secondary_enemy != null and is_instance_valid(secondary_enemy):
			var echo_center: Vector2 = secondary_enemy.global_position
			if echo_center.distance_to(main_center) > 28.0:
				owner._spawn_burst_effect(echo_center, 46.0 + echo_level * 8.0, Color(0.68, 0.96, 1.0, 0.18), 0.18)
				var echo_hits: int = owner._damage_enemies_in_radius(echo_center, 46.0 + echo_level * 8.0, owner._get_role_damage("mage") * (0.3 + echo_level * 0.05), 0.04, max(0.3, 0.52 - frost_level * 0.03), 1.8)
				if echo_hits > 0:
					owner._register_attack_result("mage", echo_hits, false)
