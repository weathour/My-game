extends RefCounted

const ULTIMATE_BULLET_HIT_SCAN_INTERVAL := 0.025

func perform_attack(owner) -> void:
	if owner.is_gunner_infinite_reload_active():
		return
	var role_data: Dictionary = owner._get_active_role()
	var upgrade_data: Dictionary = owner.role_upgrade_levels[role_data["id"]]
	var special_data: Dictionary = owner._get_role_special_state("gunner")
	var scatter_level: int = int(special_data.get("scatter_level", 0))
	var focus_level: int = int(special_data.get("focus_level", 0))
	var lock_level: int = int(special_data.get("lock_level", 0))
	var barrage_attribute_level: float = 0.0
	var overload_level: int = owner._get_card_level("battle_overload")
	var shot_direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var effective_range: float = (float(role_data["range"]) + float(upgrade_data.get("range_bonus", 0.0))) * owner._get_story_style_range_multiplier(role_data["id"])
	var target_enemy: Node2D = owner._get_enemy_in_aim_cone(18.0, effective_range + 80.0)
	var target_distance: float = owner.global_position.distance_to(target_enemy.global_position) if target_enemy != null else effective_range
	var main_damage: float = owner._get_role_damage(role_data["id"])
	if target_enemy != null:
		main_damage *= owner._get_priority_target_bonus(target_enemy)
	var overload_ready: bool = overload_level > 0 and owner.gunner_attack_chain == 3
	if overload_ready:
		main_damage *= 1.16 + overload_level * 0.08

	var bullet_color := Color(0.54, 0.94, 1.0, 1.0) if owner._get_story_style_id(role_data["id"]) == "star_pierce" else Color(1.0, 0.42, 0.34, 1.0)
	if owner._get_gunner_barrage_shotgun_wave_count(barrage_attribute_level) > 0:
		_spawn_barrage_shotgun(owner, shot_direction, main_damage, bullet_color, role_data, upgrade_data, focus_level, barrage_attribute_level)
	else:
		var bullet = owner._spawn_directional_bullet(shot_direction, main_damage, bullet_color, role_data["id"], owner.global_position + shot_direction * 18.0)
		if bullet == null:
			return
		_configure_primary_bullet(owner, bullet, role_data, upgrade_data, focus_level)
	if lock_level > 0 and target_enemy != null and target_distance >= 175.0:
		owner._apply_gunner_lock(target_enemy, lock_level)

	if scatter_level > 0 and target_distance >= 160.0:
		var side_shots: int = min(2, scatter_level)
		var angle_step: float = deg_to_rad(7.0 + scatter_level * 2.0)
		for shot_index in range(side_shots):
			var angle_offset: float = angle_step * float(shot_index + 1)
			for direction_sign in [-1.0, 1.0]:
				var spread_direction: Vector2 = owner.facing_direction.rotated(angle_offset * direction_sign)
				var spread_bullet = owner._spawn_directional_bullet(spread_direction, owner._get_role_damage(role_data["id"]) * (0.42 + scatter_level * 0.06), Color(1.0, 0.55, 0.36, 0.92), role_data["id"], owner.global_position + owner.facing_direction * 14.0)
				if spread_bullet != null:
					spread_bullet.speed = 510.0 + 18.0 * scatter_level
					spread_bullet.lifetime = 1.0
					spread_bullet.hit_radius = 11.0

	if scatter_level >= 2 and target_distance >= 220.0:
		for angle_offset in [-0.2, 0.2]:
			var lock_bullet = owner._spawn_directional_bullet(owner.facing_direction.rotated(angle_offset), owner._get_role_damage(role_data["id"]) * (0.32 + scatter_level * 0.04), Color(1.0, 0.66, 0.4, 0.94), role_data["id"], owner.global_position + owner.facing_direction * 18.0)
			if lock_bullet != null:
				lock_bullet.speed = 600.0
				lock_bullet.lifetime = 1.2
				lock_bullet.hit_radius = 11.0

	if focus_level >= 2 and target_distance >= 170.0:
		var rail_width: float = 16.0 + focus_level * 2.0
		var rail_bullet = owner._spawn_directional_bullet(owner.facing_direction, owner._get_role_damage(role_data["id"]) * (0.34 + focus_level * 0.08), Color(1.0, 0.82, 0.44, 0.96), role_data["id"], owner.global_position + owner.facing_direction * 16.0)
		if rail_bullet != null:
			rail_bullet.speed = 980.0 + focus_level * 80.0
			rail_bullet.lifetime = 0.72 + focus_level * 0.04
			rail_bullet.hit_radius = rail_width
			rail_bullet.pierce_count = 3 + focus_level
			rail_bullet.vulnerability_bonus = max(rail_bullet.vulnerability_bonus, 0.05 * focus_level)
			rail_bullet.vulnerability_duration = max(rail_bullet.vulnerability_duration, 1.0)

	owner.gunner_attack_chain = (owner.gunner_attack_chain + 1) % 4
	if owner.gunner_attack_chain == 0 and focus_level > 0:
		var tracer_width: float = 18.0 + focus_level * 2.0
		var tracer_bullet = owner._spawn_directional_bullet(owner.facing_direction, owner._get_role_damage(role_data["id"]) * (0.52 + focus_level * 0.08), Color(1.0, 0.9, 0.5, 0.98), role_data["id"], owner.global_position + owner.facing_direction * 14.0)
		if tracer_bullet != null:
			tracer_bullet.speed = 860.0 + focus_level * 65.0
			tracer_bullet.lifetime = 0.68 + focus_level * 0.05
			tracer_bullet.hit_radius = tracer_width
			tracer_bullet.pierce_count = 2 + focus_level
			tracer_bullet.vulnerability_bonus = max(tracer_bullet.vulnerability_bonus, 0.08 + focus_level * 0.02)
			tracer_bullet.vulnerability_duration = max(tracer_bullet.vulnerability_duration, 1.0)

	if overload_ready:
		var overdrive_bullet = owner._spawn_directional_bullet(shot_direction, owner._get_role_damage(role_data["id"]) * (0.72 + overload_level * 0.1), Color(1.0, 0.88, 0.54, 0.98), role_data["id"], owner.global_position + shot_direction * 22.0)
		if overdrive_bullet != null:
			overdrive_bullet.speed = 680.0
			overdrive_bullet.lifetime = 1.0
			overdrive_bullet.hit_radius = 14.0
			overdrive_bullet.pierce_count = 1 + min(1, overload_level)

	owner._spawn_attack_aftershock(owner.global_position + shot_direction * min(220.0 + focus_level * 20.0, effective_range), role_data["id"])

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
			var pellet = owner._spawn_directional_bullet(pellet_direction, main_damage * 0.58, bullet_color, role_data["id"], origin)
			if pellet != null:
				_configure_primary_bullet(owner, pellet, role_data, upgrade_data, focus_level)
				pellet.lifetime = max(pellet.lifetime, 0.86 + float(wave_index) * 0.08)
				pellet.hit_radius += 1.0

func _configure_primary_bullet(owner, bullet, role_data: Dictionary, upgrade_data: Dictionary, focus_level: int) -> void:
	bullet.speed = (560.0 + 62.0 * focus_level) * owner._get_story_style_bullet_speed_multiplier(role_data["id"])
	bullet.pierce_count = int(round(float(upgrade_data["range_bonus"]) / 40.0)) + focus_level + owner._get_story_style_extra_pierce(role_data["id"])
	if focus_level > 0:
		bullet.vulnerability_bonus = 0.04 * focus_level
		bullet.vulnerability_duration = 1.0 + 0.2 * focus_level
		bullet.hit_radius += 1.5 * focus_level

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

func perform_enter(owner, role_id: String, assault_level: int, _assault_multiplier: float) -> int:
	owner._show_switch_banner("\u8FDB\u573A", "\u5FEB\u62D4\u538B\u5236", Color(1.0, 0.58, 0.36, 1.0))
	owner._fire_gunner_entry_wave(role_id, 0)
	var current_scene: Node = owner.get_tree().current_scene
	if current_scene != null:
		var controller := Node2D.new()
		controller.name = "GunnerEntryWaveController"
		current_scene.add_child(controller)
		var tween := controller.create_tween()
		tween.tween_interval(0.08)
		tween.tween_callback(Callable(owner, "_fire_gunner_entry_wave").bind(role_id, 1))
		tween.tween_callback(controller.queue_free)
	owner._activate_switch_power(role_id, "\u5F39\u9053\u8D85\u8F7D", 2.0, 1.22, 0.11)
	owner._apply_switch_payoff(8 + assault_level * 2, 5.0 + assault_level, 1.0 + assault_level * 0.15)
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
	var special_data: Dictionary = owner._get_role_special_state("gunner")
	var barrage_level: int = int(special_data.get("barrage_level", 0))
	var focus_level: int = int(special_data.get("focus_level", 0))
	var scatter_level: int = int(special_data.get("scatter_level", 0))
	var lock_level: int = int(special_data.get("lock_level", 0))
	var extend_level: int = owner._get_card_level("skill_extend")
	var wave_count: int = 11 + barrage_level * 2
	wave_count = int(ceil(float(wave_count) * (1.0 + extend_level * 0.12) * float(cast_payload.get("duration_multiplier", 1.0))))
	wave_count += int(ceil(2.0 / owner.GUNNER_ULTIMATE_WAVE_INTERVAL))
	var total_duration: float = 0.24 + float(wave_count - 1) * owner.GUNNER_ULTIMATE_WAVE_INTERVAL
	total_duration *= 1.0 + extend_level * 0.04
	owner._queue_camera_shake(17.5, 0.54)
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, 0.5)
	if extend_level >= 2:
		owner.ultimate_guard_remaining = max(owner.ultimate_guard_remaining, total_duration)
		owner.ultimate_guard_damage_multiplier = min(owner.ultimate_guard_damage_multiplier, 0.9)
	owner._delay_level_up_requests(total_duration)
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -34.0), "\u5F39\u5E55", Color(1.0, 0.86, 0.5, 1.0))
	owner._schedule_repeating_sequence(owner.GUNNER_ULTIMATE_WAVE_INTERVAL, wave_count, func(wave_index: int) -> void:
		_fire_ultimate_wave(owner, wave_count, barrage_level, focus_level, scatter_level, lock_level, float(cast_payload.get("damage_multiplier", 1.0)), wave_index)
	)
	owner._apply_post_ultimate_bonuses("gunner", total_duration)

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
	var finale_level: int = owner._get_card_level("skill_finale")
	if wave_index == wave_count - 1 and finale_level > 0:
		bullet_count += 6 + finale_level * 3
		damage_scale *= [1.08, 1.14, 1.2][finale_level - 1]
	var angle_offset: float = sin(spin * 0.9) * 0.18
	owner._queue_camera_shake(4.6 + float(barrage_level) * 0.24, 0.1)

	for bullet_index in range(bullet_count):
		var ratio: float = 0.0 if bullet_count <= 1 else float(bullet_index) / float(bullet_count - 1)
		var centered_ratio: float = ratio * 2.0 - 1.0
		var angle: float = target_direction.angle() + centered_ratio * fan_arc_radians * 0.5 + angle_offset
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var muzzle_offset: Vector2 = shot_direction * (12.0 + 4.0 * sin(spin + float(bullet_index) * 0.8))
		var spray_bullet = owner._spawn_directional_bullet(shot_direction, owner._get_role_damage("gunner") * damage_scale, Color(1.0, 0.72, 0.38, 0.94), "gunner", wave_origin + muzzle_offset)
		if spray_bullet != null:
			spray_bullet.speed = 620.0 + focus_level * 54.0 + barrage_level * 18.0
			spray_bullet.lifetime = 1.08 + barrage_level * 0.06
			spray_bullet.hit_radius = 10.0 + scatter_level * 0.8
			spray_bullet.visual_scale_multiplier = 0.68
			spray_bullet.enemy_hit_radius_scale = 0.2
			spray_bullet.enemy_hit_radius_min = 4.0
			spray_bullet.enemy_hit_radius_max = 12.0
			spray_bullet.pierce_count = normal_pierce_count
			spray_bullet.min_hit_travel_distance = 22.0
			spray_bullet.hit_scan_interval = ULTIMATE_BULLET_HIT_SCAN_INTERVAL
			if spray_bullet.has_method("configure_wave_motion") and abs(centered_ratio) >= 0.34:
				var wave_phase: float = ratio * PI + spin * 0.45
				var wave_amplitude: float = max(0.0, abs(centered_ratio) * (10.0 + scatter_level * 4.0))
				var wave_frequency: float = 6.4 + focus_level * 0.9 + barrage_level * 0.25
				spray_bullet.configure_wave_motion(wave_amplitude, wave_frequency, wave_phase)
			if focus_level > 0:
				spray_bullet.vulnerability_bonus = 0.04 * focus_level
				spray_bullet.vulnerability_duration = 1.0 + focus_level * 0.2

	if lock_level > 0 and wave_index % max(2, 4 - lock_level) == 0:
		for enemy in owner._get_enemy_targets(min(1 + lock_level, 3), false):
			if enemy == null or not is_instance_valid(enemy):
				continue
			var lock_bullet = owner._spawn_bullet(enemy, owner._get_role_damage("gunner") * (0.38 + lock_level * 0.06) * cast_damage_multiplier, Color(1.0, 0.86, 0.5, 1.0), "gunner", wave_origin)
			if lock_bullet != null:
				lock_bullet.speed = 760.0 + focus_level * 55.0
				lock_bullet.lifetime = 1.38 + barrage_level * 0.07
				lock_bullet.hit_radius = 8.0 + lock_level * 0.8
				lock_bullet.visual_scale_multiplier = 0.68
				lock_bullet.enemy_hit_radius_scale = 0.18
				lock_bullet.enemy_hit_radius_min = 4.0
				lock_bullet.enemy_hit_radius_max = 10.0
				lock_bullet.pierce_count = min(1, normal_pierce_count)
				lock_bullet.min_hit_travel_distance = 22.0
				lock_bullet.hit_scan_interval = ULTIMATE_BULLET_HIT_SCAN_INTERVAL
				lock_bullet.vulnerability_bonus = 0.04 + lock_level * 0.01
				lock_bullet.vulnerability_duration = 1.4 + lock_level * 0.22
