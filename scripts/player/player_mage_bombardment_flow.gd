extends RefCounted

const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")


static func start_basic_mage_bombardment(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	if not use_boom_effect:
		owner._spawn_mage_bombardment_warning_effect(center, radius)
	if gravity_level > 0:
		owner._spawn_vortex_effect(center, 18.0 + gravity_level * 7.0, Color(0.74, 0.82, 1.0, 0.26), 0.18)

	if owner.get_tree() == null:
		return

	if use_boom_effect:
		var warning_duration: float = owner._get_scene_animation_duration(owner.MAGE_WARNING_EFFECT_SCENE, 0.2)
		var boom_duration: float = owner._get_scene_animation_duration(owner.MAGE_BOOM_EFFECT_SCENE, 0.3)
		owner._spawn_mage_warning_scene_effect(center, radius)
		if owner.has_method("_schedule_repeating_sequence"):
			owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
				if is_instance_valid(owner):
					owner._spawn_mage_boom_scene_effect(center, radius)
			, warning_duration)
			owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
				if is_instance_valid(owner):
					owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)
			, warning_duration + boom_duration)
		else:
			owner._spawn_mage_boom_scene_effect(center, radius)
			owner._resolve_basic_mage_bombardment_damage(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)
	else:
		if owner.has_method("_schedule_repeating_sequence"):
			owner._schedule_repeating_sequence(0.0, 1, func(_index: int) -> void:
				if is_instance_valid(owner):
					owner._trigger_basic_mage_bombardment_impact(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)
			, 0.22)
		else:
			trigger_basic_mage_bombardment_impact(owner, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, use_boom_effect, advance_attack_chain)


static func trigger_basic_mage_bombardment_impact(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool = false, advance_attack_chain: bool = true) -> void:
	if not use_boom_effect:
		owner._spawn_mage_bombardment_fall_effect(center, radius)
	if use_boom_effect:
		resolve_basic_mage_bombardment_damage(owner, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, true, advance_attack_chain)
	else:
		owner._spawn_sketch_sprite_effect(
			center,
			0.0,
			owner.MAGE_BOMBARD_TEXTURE_RELATIVE_PATH,
			owner.MAGE_BOMBARD_TEXTURE_SIZE,
			owner.MAGE_BOMBARD_VISIBLE_BOUNDS,
			Vector2(radius * 2.0, radius * 2.0),
			0.22,
			Color.WHITE,
			14,
			true,
			true
		)
		resolve_basic_mage_bombardment_damage(owner, center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, gravity_level, echo_level, frost_level, role_id, false, advance_attack_chain)


static func resolve_basic_mage_bombardment_damage(owner, center: Vector2, radius: float, damage_amount: float, vulnerability_bonus: float, slow_multiplier: float, slow_duration: float, gravity_level: int, echo_level: int, frost_level: int, role_id: String, use_boom_effect: bool, advance_attack_chain: bool = true) -> void:
	owner._queue_camera_shake(5.8, 0.12)
	if gravity_level > 0:
		owner._pull_enemies_toward(center, radius + gravity_level * 10.0, 16.0 + gravity_level * 10.0)
		owner._spawn_vortex_effect(center, 24.0 + gravity_level * 8.0, Color(0.76, 0.84, 1.0, 0.42), 0.2)
	if not use_boom_effect:
		owner._spawn_ring_effect(center, radius, Color(0.72, 0.96, 1.0, 0.78), 6.0, 0.18)
	owner._spawn_burst_effect(center, radius, Color(0.52, 0.9, 1.0, 0.22), 0.2)
	if frost_level > 0:
		owner._spawn_frost_sigils_effect(center, max(20.0, radius * 0.58), Color(0.86, 0.98, 1.0, 0.76), 0.18)
	var hits: int = 0
	if use_boom_effect:
		var ellipse_horizontal_radius: float = radius * 2.04
		var ellipse_vertical_radius: float = max(32.0, radius * 0.84)
		hits += owner._damage_enemies_in_ellipse(center, ellipse_horizontal_radius, ellipse_vertical_radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, role_id)
	else:
		hits += owner._damage_enemies_in_radius(center, radius, damage_amount, vulnerability_bonus, slow_multiplier, slow_duration, role_id)

	if echo_level > 0:
		var echo_target: Node2D = get_enemy_nearest_to_position(owner, center + owner.facing_direction * (36.0 + echo_level * 10.0))
		if echo_target != null and is_instance_valid(echo_target) and center.distance_to(echo_target.global_position) <= 132.0 + echo_level * 16.0:
			var echo_center: Vector2 = echo_target.global_position
			owner._spawn_burst_effect(echo_center, 24.0 + echo_level * 6.0, Color(0.64, 0.94, 1.0, 0.16), 0.14)
			hits += owner._damage_enemies_in_radius(echo_center, 24.0 + echo_level * 6.0, damage_amount * (0.24 + echo_level * 0.05), 0.0, max(0.62, slow_multiplier + 0.08), 0.8 + echo_level * 0.15, role_id)
	if hits > 0 and not _uses_batched_damage(owner):
		owner._register_attack_result(role_id, hits, false)

	if frost_level >= 2:
		owner._spawn_pulsing_field(center, 28.0 + frost_level * 5.0, Color(0.56, 0.9, 1.0, 0.14), 2, 0.12, damage_amount * (0.12 + frost_level * 0.02), 0.02 * frost_level, max(0.4, slow_multiplier - 0.08), 0.9 + frost_level * 0.18)
	if gravity_level >= 2:
		owner._spawn_pulsing_field(center, 24.0 + gravity_level * 6.0, Color(0.74, 0.84, 1.0, 0.12), 2, 0.1, damage_amount * (0.1 + gravity_level * 0.03), 0.0, max(0.46, slow_multiplier - 0.08), 0.9 + gravity_level * 0.15)

	if advance_attack_chain:
		owner.mage_attack_chain = (owner.mage_attack_chain + 1) % 3
		if owner.mage_attack_chain == 0 and (echo_level > 0 or frost_level > 0 or gravity_level > 0):
			owner._spawn_pulsing_field(center, 34.0 + echo_level * 5.0, Color(0.62, 0.95, 1.0, 0.16), 2, 0.1, damage_amount * (0.16 + echo_level * 0.03), 0.02 + frost_level * 0.01, max(0.46, slow_multiplier - 0.06), 0.8 + frost_level * 0.15)


static func get_enemy_nearest_to_position(owner, position: Vector2) -> Node2D:
	if position == Vector2.ZERO:
		return owner._get_closest_enemy()
	return PLAYER_TARGETING.get_enemy_nearest_to_position(owner._get_live_enemies(), position)


static func get_enemy_near_position(owner, position: Vector2, max_distance: float) -> Node2D:
	return PLAYER_TARGETING.get_enemy_near_position(owner._get_live_enemies(), position, max_distance)


static func _uses_batched_damage(owner) -> bool:
	return owner != null and owner.has_method("_damage_enemies_in_radius")


static func get_mage_mouse_bombard_center(owner, base_range: float) -> Vector2:
	var viewport_rect: Rect2 = owner.get_viewport_rect()
	var min_view_size: float = min(viewport_rect.size.x, viewport_rect.size.y)
	var max_distance: float = max(base_range + 36.0, clamp(min_view_size * 0.46, 220.0, 420.0))
	if bool(owner.get("auto_attack_enabled")):
		var target_enemy: Node2D = owner._get_closest_enemy()
		if target_enemy != null and is_instance_valid(target_enemy):
			var target_offset: Vector2 = target_enemy.global_position - owner.global_position
			if target_offset.length() > max_distance:
				target_offset = target_offset.normalized() * max_distance
			return owner.global_position + target_offset
		return owner.global_position + owner.facing_direction * min(max_distance * 0.55, 180.0)

	var mouse_offset: Vector2 = owner.get_global_mouse_position() - owner.global_position
	if mouse_offset.length_squared() <= 1.0:
		return owner.global_position + owner.facing_direction * min(max_distance * 0.55, 180.0)
	if mouse_offset.length() > max_distance:
		mouse_offset = mouse_offset.normalized() * max_distance
	return owner.global_position + mouse_offset
