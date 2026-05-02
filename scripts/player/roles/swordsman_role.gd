extends RefCounted

func perform_attack(owner) -> void:
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = owner._get_role_special_state("swordsman")
	var attack_direction: Vector2 = owner._get_attack_aim_direction(owner.facing_direction)
	var heart_level: float = 0.0
	var normal_attack_scale: float = owner._get_swordsman_normal_attack_scale(heart_level)
	var normal_attack_width_scale: float = owner._get_swordsman_normal_attack_width_scale(heart_level)
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var blood_level: int = int(special_data.get("blood_level", 0))
	var stance_level: int = int(special_data.get("stance_level", 0))
	var overload_level: int = owner._get_card_level("battle_overload")
	var attack_range: float = (float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0)) + crescent_level * 6.0 + thrust_level * 4.0) * owner._get_story_style_range_multiplier(role_data["id"])
	var attack_damage: float = owner._get_role_damage(role_data["id"]) * 1.5
	var slash_axis: Vector2 = owner._get_downward_perpendicular(attack_direction)
	var slash_mirror: bool = attack_direction.x > 0.0
	var slash_length: float = (56.0 + float(upgrade_data.get("range_bonus", 0.0)) * 0.19 + crescent_level * 4.0 + thrust_level * 2.0) * owner._get_story_style_range_multiplier(role_data["id"])
	var slash_width: float = (8.0 + crescent_level * 1.05 + thrust_level * 0.7) * normal_attack_width_scale
	var slash_forward_distance: float = 42.0 + thrust_level * 3.0
	var style_color := Color(0.48, 0.86, 1.0, 0.95) if owner._get_story_style_id(role_data["id"]) == "moon_edge" else Color(1.0, 0.74, 0.34, 0.95)
	var enemies_hit: int = 0
	var any_kill: bool = false
	var overload_ready: bool = overload_level > 0 and owner.swordsman_attack_chain == 2
	if overload_ready:
		attack_damage *= 1.18 + 0.08 * overload_level
		slash_length += 5.0 + overload_level * 3.0
		slash_width += 1.0 + overload_level * 0.6

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
	enemies_hit += owner._damage_enemies_in_oriented_rect_unique(slash_center, slash_axis, slash_length, slash_rect_width, attack_damage, 0.0, 1.0, 0.0, slash_hit_registry, role_data["id"])
	owner._schedule_swordsman_slash_followthrough(slash_center, slash_axis, slash_length, slash_rect_width, attack_damage, 0.0, 1.0, 0.0, slash_animation_duration, role_data["id"], slash_hit_registry)
	if thrust_level > 0:
		var pierce_start: Vector2 = slash_center + attack_direction * 10.0
		var pierce_end: Vector2 = pierce_start + attack_direction * (34.0 + thrust_level * 12.0)
		enemies_hit += owner._damage_enemies_in_line(pierce_start, pierce_end, max(8.0, slash_width * 0.34), attack_damage * 0.14 * thrust_level, 0.06 * thrust_level, 1.0, 0.0, role_data["id"])

	if crescent_level >= 2:
		var follow_arc_direction := attack_direction.rotated(0.24 if owner.swordsman_attack_chain % 2 == 0 else -0.24)
		owner._spawn_crescent_wave_effect(owner.global_position + follow_arc_direction * 14.0, follow_arc_direction, attack_range + 28.0, Color(0.36, 0.82, 1.0, 0.92), 0.14, 110.0, 20.0 + crescent_level * 2.0)
		enemies_hit += owner._damage_enemies_in_line(owner.global_position, owner.global_position + follow_arc_direction * (attack_range + 30.0), 24.0 + crescent_level * 2.0, attack_damage * (0.22 + crescent_level * 0.05), 0.02 * crescent_level, 1.0, 0.0, role_data["id"])

	if thrust_level >= 2:
		var thrust_end: Vector2 = owner.global_position + attack_direction * (attack_range + 38.0 + thrust_level * 12.0)
		var thrust_width: float = 18.0 + thrust_level * 2.0
		owner._spawn_thrust_effect(owner.global_position + attack_direction * 8.0, thrust_end, Color(1.0, 0.18, 0.1, 0.98), thrust_width, 0.16, false)
		var thrust_hits: int = owner._damage_enemies_in_line(owner.global_position, thrust_end, thrust_width, attack_damage * (0.34 + thrust_level * 0.08), 0.06 * thrust_level, 1.0, 0.0, role_data["id"])
		enemies_hit += thrust_hits

	if blood_level >= 2 and enemies_hit >= 3:
		owner._heal(1.2 + blood_level * 0.8)
		owner._spawn_burst_effect(owner.global_position, 34.0 + blood_level * 4.0, Color(1.0, 0.3, 0.28, 0.18), 0.12)

	owner.swordsman_attack_chain = (owner.swordsman_attack_chain + 1) % 3
	if owner.swordsman_attack_chain == 0 and (crescent_level > 0 or thrust_level > 0 or stance_level > 0):
		var core_center: Vector2 = owner.global_position + attack_direction * 26.0
		owner._spawn_cross_slash_effect(core_center, attack_direction, 88.0, 17.0, Color(1.0, 0.94, 0.62, 0.82), 0.14)
		var chain_hits: int = owner._damage_enemies_in_radius(core_center, 44.0 + crescent_level * 5.0, attack_damage * (0.48 + thrust_level * 0.05), 0.04 + thrust_level * 0.02, 1.0, 0.0)
		enemies_hit += chain_hits
		if chain_hits > 0 and blood_level > 0:
			owner._heal(1.4 + blood_level * 0.6)
		if stance_level > 0:
			owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -26.0), "\u5B88\u52BF", Color(1.0, 0.88, 0.54, 1.0))
			owner._spawn_guard_effect(owner.global_position, 46.0 + stance_level * 10.0, Color(1.0, 0.88, 0.5, 0.24), 0.2 + stance_level * 0.03)
			owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.08 + stance_level * 0.05)
			if chain_hits > 0:
				owner._heal(0.8 + stance_level * 0.8)
			if stance_level >= 2:
				var guard_hits: int = owner._damage_enemies_in_radius(owner.global_position + owner.facing_direction * 14.0, 34.0 + stance_level * 8.0, attack_damage * (0.18 + stance_level * 0.07), 0.0, 1.0, 0.0)
				enemies_hit += guard_hits
				if guard_hits > 0:
					owner._spawn_burst_effect(owner.global_position + owner.facing_direction * 12.0, 30.0 + stance_level * 7.0, Color(1.0, 0.84, 0.42, 0.18), 0.12)

	owner._spawn_attack_aftershock(owner.global_position + owner.facing_direction * max(26.0, attack_range * 0.55), role_data["id"])

	if enemies_hit > 0:
		owner._register_attack_result(role_data["id"], enemies_hit, any_kill)

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

func perform_enter(owner, role_id: String, assault_level: int, assault_multiplier: float) -> int:
	var special_data: Dictionary = owner._get_role_special_state(role_id)
	var pursuit_level: int = int(special_data.get("pursuit_level", 0))
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var previous_position: Vector2 = owner.global_position
	var cluster_center: Vector2 = owner._get_enemy_cluster_center()
	var target_enemy: Node2D = owner._get_enemy_nearest_to_position(cluster_center) if cluster_center != Vector2.ZERO else owner._get_closest_enemy()
	var travel_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var trait_distance_multiplier := float(owner._get_swordsman_entry_distance_multiplier()) if owner.has_method("_get_swordsman_entry_distance_multiplier") else 1.0
	var trait_damage_multiplier := float(owner._get_role_entry_damage_multiplier(role_id)) if owner.has_method("_get_role_entry_damage_multiplier") else 1.0
	var trait_invulnerability_bonus := float(owner._get_swordsman_entry_invulnerability_bonus()) if owner.has_method("_get_swordsman_entry_invulnerability_bonus") else 0.0
	var dash_distance: float = (160.0 + thrust_level * 14.0 + pursuit_level * 10.0) * assault_multiplier * trait_distance_multiplier
	if target_enemy != null and is_instance_valid(target_enemy):
		travel_direction = previous_position.direction_to(target_enemy.global_position)
		dash_distance = (600.0 + thrust_level * 48.0 + pursuit_level * 28.0) * assault_multiplier * trait_distance_multiplier
	elif cluster_center != Vector2.ZERO:
		travel_direction = previous_position.direction_to(cluster_center)
		dash_distance = (600.0 + thrust_level * 48.0 + pursuit_level * 28.0) * assault_multiplier * trait_distance_multiplier
	owner.global_position += travel_direction * dash_distance
	owner.facing_direction = travel_direction
	owner._show_switch_banner("\u8FDB\u573A", "\u7A81\u8FDB\u7834\u9635", Color(1.0, 0.84, 0.46, 1.0))
	var scar_width: float = 32.0 + thrust_level * 4.0
	var scar_end: Vector2 = owner.global_position + travel_direction * (84.0 + thrust_level * 18.0)
	var scar_center: Vector2 = previous_position.lerp(scar_end, 0.5)
	var scar_length: float = previous_position.distance_to(scar_end)
	owner._spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.08)
	owner._spawn_ring_effect(owner.global_position, 78.0 + crescent_level * 8.0, Color(1.0, 0.86, 0.5, 0.78), 9.0, 0.18)
	owner._spawn_burst_effect(owner.global_position, 72.0 + crescent_level * 8.0, Color(1.0, 0.78, 0.38, 0.18), 0.16)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.5 + trait_invulnerability_bonus)
	var line_hits: int = owner._damage_enemies_in_line(previous_position, scar_end, scar_width, owner._get_role_damage(role_id) * (1.52 + pursuit_level * 0.12) * assault_multiplier * trait_damage_multiplier, 0.1, 1.0, 0.0, role_id)
	var burst_hits: int = owner._damage_enemies_in_radius(owner.global_position, (78.0 + crescent_level * 8.0) * (1.0 + assault_level * 0.06), owner._get_role_damage(role_id) * (0.72 + crescent_level * 0.08) * assault_multiplier * trait_damage_multiplier, 0.08, 1.0, 0.0)
	var entry_hits: int = line_hits + burst_hits
	owner._activate_switch_power(role_id, "\u7834\u9635\u8FFD\u51FB", 2.2, 1.28, 0.08)
	owner._apply_switch_payoff(entry_hits, 6.0 + assault_level, 1.4 + assault_level * 0.2)
	return entry_hits

func perform_exit(owner, role_id: String, rearguard_level: int) -> int:
	owner._queue_next_entry_blessing(role_id)
	owner._show_switch_banner("\u9000\u573A", "\u8840\u5203\u4F20\u627F", Color(1.0, 0.8, 0.42, 0.96))
	owner._spawn_ring_effect(owner.global_position, 82.0, Color(1.0, 0.42, 0.34, 0.52), 6.0, 0.18)
	owner._spawn_guard_effect(owner.global_position, 54.0, Color(1.0, 0.38, 0.32, 0.18), 0.18)
	if rearguard_level >= 3:
		owner._activate_guard_cover()
	return owner._trigger_rearguard_attack(role_id, owner.global_position, rearguard_level)

func perform_ultimate(owner, cast_payload: Dictionary) -> void:
	var special_data: Dictionary = owner._get_role_special_state("swordsman")
	var pursuit_level: int = int(special_data.get("pursuit_level", 0))
	var crescent_level: int = int(special_data.get("crescent_level", 0))
	var thrust_level: int = int(special_data.get("thrust_level", 0))
	var extend_level: int = owner._get_card_level("skill_extend")
	var slash_count: int = 7 + min(2, max(pursuit_level, max(crescent_level, thrust_level)))
	slash_count = int(ceil(float(slash_count) * (1.0 + extend_level * 0.12) * float(cast_payload.get("duration_multiplier", 1.0))))
	slash_count += 2
	var total_duration: float = 0.22 + float(slash_count - 1) * owner.SWORD_ULTIMATE_SLASH_INTERVAL + 0.18
	total_duration *= 1.0 + extend_level * 0.04
	owner._queue_camera_shake(20.0, 0.62)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, total_duration)
	if extend_level >= 2:
		owner.ultimate_guard_remaining = max(owner.ultimate_guard_remaining, total_duration)
		owner.ultimate_guard_damage_multiplier = min(owner.ultimate_guard_damage_multiplier, 0.9)
	owner._delay_level_up_requests(total_duration)
	owner._set_active_role_visual_hidden(true)
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene != null:
		var restore_controller := Node2D.new()
		restore_controller.name = "SwordsmanUltimateVisualRestore"
		current_scene.add_child(restore_controller)
		var restore_tween := restore_controller.create_tween()
		restore_tween.tween_interval(total_duration)
		restore_tween.tween_callback(func() -> void:
			owner._set_active_role_visual_hidden(false)
		)
		restore_tween.tween_callback(restore_controller.queue_free)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "\u7EDD\u65A9", Color(1.0, 0.92, 0.6, 1.0))
	owner._spawn_ring_effect(owner.global_position, 68.0, Color(1.0, 0.88, 0.52, 0.84), 8.0, 0.18)
	owner._schedule_repeating_sequence(owner.SWORD_ULTIMATE_SLASH_INTERVAL, slash_count, func(slash_index: int) -> void:
		_execute_ultimate_slash(owner, slash_count, pursuit_level, crescent_level, thrust_level, float(cast_payload.get("damage_multiplier", 1.0)), slash_index)
	)
	owner._apply_post_ultimate_bonuses("swordsman", total_duration)

func _execute_ultimate_slash(owner, slash_count: int, pursuit_level: int, crescent_level: int, thrust_level: int, cast_damage_multiplier: float, slash_index: int) -> void:
	if owner.is_dead:
		return

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
	var scar_width: float = 40.0 + thrust_level * 5.0
	var scar_length_end: Vector2 = end_position + travel_direction * (84.0 + thrust_level * 18.0)
	var scar_center: Vector2 = start_position.lerp(scar_length_end, 0.5)
	var scar_length: float = start_position.distance_to(scar_length_end)
	owner._spawn_sword_omnislash_scene_effect(scar_center, travel_direction, scar_length, scar_width * 1.12)

	var damage_scale: float = (1.15 + float(pursuit_level) * 0.12 + float(crescent_level + thrust_level) * 0.06 + float(slash_index) * 0.08) * cast_damage_multiplier
	var line_hits: int = owner._damage_enemies_in_line(start_position, scar_length_end, scar_width, owner._get_role_damage("swordsman") * damage_scale, 0.08 + pursuit_level * 0.02, 1.0, 0.0, "swordsman")
	var blast_hits: int = owner._damage_enemies_in_radius(end_position, 48.0 + crescent_level * 12.0, owner._get_role_damage("swordsman") * (0.52 + float(crescent_level) * 0.08) * cast_damage_multiplier, 0.03 + pursuit_level * 0.02, 1.0, 0.0)
	if line_hits > 0:
		owner._register_attack_result("swordsman", line_hits, false)
	if blast_hits > 0:
		owner._register_attack_result("swordsman", blast_hits, false)
	if target_enemy != null and is_instance_valid(target_enemy):
		var direct_cut_kill: bool = owner._deal_damage_to_enemy(target_enemy, owner._get_role_damage("swordsman") * (0.68 + pursuit_level * 0.08) * cast_damage_multiplier, "swordsman", 0.06 + pursuit_level * 0.02, 2.0, 1.0, 0.0)
		owner._register_attack_result("swordsman", 1, direct_cut_kill)

	owner._spawn_ring_effect(end_position, 34.0 + crescent_level * 8.0, Color(1.0, 0.84, 0.44, 0.76), 5.0, 0.12)

	if target_enemy != null and is_instance_valid(target_enemy) and target_enemy.has_method("apply_bleed"):
		target_enemy.apply_bleed(owner._get_role_damage("swordsman") * (0.68 + pursuit_level * 0.1), 2.8 + float(crescent_level) * 0.35)

	if slash_index == slash_count - 1:
		var finale_level: int = owner._get_card_level("skill_finale")
		var finale_damage_multiplier: float = [1.12, 1.2, 1.3][max(0, finale_level - 1)] if finale_level > 0 else 1.0
		var finale_radius_multiplier: float = 1.2 if finale_level > 0 else 1.0
		owner._queue_camera_shake(15.0, 0.22)
		owner._spawn_burst_effect(end_position, (94.0 + crescent_level * 10.0) * finale_radius_multiplier, Color(1.0, 0.78, 0.35, 0.28), 0.2)
		owner._spawn_ring_effect(end_position, (108.0 + thrust_level * 10.0) * finale_radius_multiplier, Color(1.0, 0.92, 0.58, 0.9), 10.0, 0.18)
		var finisher_hits: int = owner._damage_enemies_in_line(start_position, end_position + travel_direction * (168.0 * finale_radius_multiplier), scar_width + 18.0, owner._get_role_damage("swordsman") * (1.55 + pursuit_level * 0.14) * cast_damage_multiplier * finale_damage_multiplier, 0.1, 1.0, 0.0, "swordsman")
		if finisher_hits > 0:
			owner._register_attack_result("swordsman", finisher_hits, false)
		if target_enemy != null and is_instance_valid(target_enemy):
			var finisher_kill: bool = owner._deal_damage_to_enemy(target_enemy, owner._get_role_damage("swordsman") * (0.92 + pursuit_level * 0.1) * cast_damage_multiplier * finale_damage_multiplier, "swordsman", 0.12, 2.4, 1.0, 0.0)
			owner._register_attack_result("swordsman", 1, finisher_kill)

func _get_slash_visual_width(slash_width: float) -> float:
	return max(18.0, slash_width * 2.0)

func _get_slash_mirror_forward_offset(owner, visual_width: float) -> float:
	var visible_bounds: Rect2 = owner.SWORD_SLASH_SCENE_VISIBLE_BOUNDS
	var visible_center_x: float = visible_bounds.position.x + visible_bounds.size.x * 0.5
	var mirrored_center_offset_px: float = owner.SWORD_SLASH_SCENE_SIZE.x - visible_center_x * 2.0
	if mirrored_center_offset_px <= 0.0:
		return 0.0
	return mirrored_center_offset_px * visual_width / max(1.0, visible_bounds.size.x)
