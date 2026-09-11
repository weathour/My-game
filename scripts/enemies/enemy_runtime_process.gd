extends RefCounted


static func ready(enemy) -> void:
	enemy.current_health = enemy.max_health if enemy.current_health <= 0.0 else min(enemy.current_health, enemy.max_health)
	if not enemy.profile_initialized:
		enemy.base_scale = enemy.scale
	if enemy.enemy_kind == "":
		enemy.enemy_kind = "normal"
	enemy.add_to_group("enemies")
	enemy._register_runtime_enemy()
	if not enemy.profile_initialized:
		enemy._reset_runtime_state(true)
	enemy._apply_visuals()
	if enemy.enemy_kind == "boss":
		enemy._ensure_boss_visual()
		enemy._ensure_boss_helpers()


static func exit_tree(enemy) -> void:
	enemy._unregister_runtime_enemy()


static func physics_process(enemy, delta: float) -> void:
	enemy.ENEMY_HIT_FEEDBACK.update_feedback_animations(delta)
	enemy.ENEMY_STATUS_VISUALS.update_temporary_animations(delta)
	if enemy.pooled_inactive:
		return
	if bool(enemy._is_glutton) or enemy.behavior_id == "skulltomb" or enemy.secondary_behavior_id == "skulltomb":
		enemy.ENEMY_OCCLUSION_SORT.update_scene_from_occluder(enemy)
	if enemy.status_root != null or enemy.boss_visual_instance != null or enemy.hit_flash_remaining > 0.0 or enemy._has_status_visual_pressure():
		enemy.status_visual_time += delta
	var had_hit_flash: bool = enemy.hit_flash_remaining > 0.0
	if had_hit_flash:
		enemy.hit_flash_remaining = max(0.0, enemy.hit_flash_remaining - delta)
	var hit_flash_finished: bool = had_hit_flash and enemy.hit_flash_remaining <= 0.0
	if enemy.slow_timer > 0.0 or enemy.vulnerability_timer > 0.0 or enemy.bleed_timer > 0.0 or enemy.skull_soldier_speed_timer > 0.0 or enemy.skull_damage_immune_timer > 0.0 or enemy.skullshot_attack_frequency_timer > 0.0:
		enemy._update_status_timers(delta)
	if enemy.bleed_timer > 0.0 and enemy.bleed_damage_per_second > 0.0:
		enemy._update_bleed(delta)
	if (enemy.status_root != null or had_hit_flash or enemy.hit_flash_remaining > 0.0 or enemy._has_status_visual_pressure() or enemy.skull_damage_immune_timer > 0.0 or enemy.boss_phase_three_intro_remaining > 0.0) and (hit_flash_finished or enemy._should_update_status_visual_frame()):
		enemy._update_status_visuals()

	if enemy.target == null or not is_instance_valid(enemy.target):
		if enemy.rebirth_timer > 0.0:
			enemy.ENEMY_TRAIT_BEHAVIOR.update_rebirth_timer(enemy, delta)
		if enemy.behavior_id == "boss":
			enemy._update_boss_trait(delta)
		enemy.velocity = Vector2.ZERO
		enemy._update_motion_visual()
		return

	enemy._cached_to_target = enemy.target.global_position - enemy.global_position
	enemy._cached_distance_to_target = enemy._cached_to_target.length()
	enemy._cached_direction_to_target = enemy._cached_to_target.normalized() if enemy._cached_distance_to_target > 0.001 else Vector2.RIGHT
	if enemy._has_timed_behavior_traits():
		enemy._update_behavior_state(delta + enemy.throttled_motion_delta)
	if enemy._should_skip_motion_frame(delta):
		enemy.ENEMY_BODY_SEPARATION.apply_body_collision_separation(enemy)
		if bool(enemy._is_glutton):
			enemy.ENEMY_GLUTTON_SKILL_BEHAVIOR.enforce_cast_position_lock(enemy)
		enemy._update_motion_visual()
		return
	var motion_delta: float = delta + enemy.throttled_motion_delta
	enemy.throttled_motion_delta = 0.0
	if enemy.behavior_id == "rose" or enemy.secondary_behavior_id == "rose":
		enemy.velocity = Vector2.ZERO
		enemy._update_motion_visual()
		return
	enemy.velocity = enemy._compute_velocity(motion_delta)
	var skulltomb_charging: bool = enemy.behavior_id == "skulltomb" and enemy.dash_remaining > 0.0
	if not skulltomb_charging:
		enemy.velocity += enemy.ENEMY_BODY_SEPARATION.get_separation_velocity(enemy) * 2.6
	enemy._apply_direct_motion(motion_delta)
	if not skulltomb_charging:
		enemy.ENEMY_BODY_SEPARATION.apply_body_collision_separation(enemy)
	if bool(enemy._is_glutton):
		enemy.ENEMY_GLUTTON_SKILL_BEHAVIOR.enforce_cast_position_lock(enemy)
	enemy._update_motion_visual()
