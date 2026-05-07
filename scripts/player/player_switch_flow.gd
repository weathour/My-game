extends RefCounted

const DEVELOPER_MODE := preload("res://scripts/developer_mode.gd")
const PLAYER_SWITCH_BANNER_FLOW := preload("res://scripts/player/player_switch_banner_flow.gd")
const PLAYER_SWITCH_ENTRY_FLOW := preload("res://scripts/player/player_switch_entry_flow.gd")
const PLAYER_SWITCH_JOB_QUEUE := preload("res://scripts/player/player_switch_job_queue.gd")

const ROLE_SWITCH_COOLDOWN := 7.0
const SWITCH_INVULNERABILITY := 0.2
const GUNNER_ENTRY_WAVE_BULLET_COUNT := 16
const GUNNER_ENTRY_WAVE_BATCH_SIZE := 4
const GUNNER_ENTRY_WAVE_BATCH_INTERVAL := 0.012
const GUNNER_REARGUARD_BULLET_BATCH_SIZE := 3
const GUNNER_REARGUARD_BULLET_BATCH_INTERVAL := 0.012
const EXIT_SWORD_LIFESTEAL_DURATION := 4.5
const EXIT_SWORD_LIFESTEAL_RATIO := 0.14
const EXIT_GUNNER_HASTE_DURATION := 4.0
const EXIT_GUNNER_ATTACK_INTERVAL_BONUS := 0.08
const EXIT_GUNNER_MOVE_SPEED_MULTIPLIER := 1.18
const MAGE_ATTACK_EFFECT_SCALE := 0.8
const MAGE_ENTRY_EFFECT_RADIUS := 52.0 * MAGE_ATTACK_EFFECT_SCALE
const MAGE_ENTRY_HIT_RADIUS := 104.0 * MAGE_ATTACK_EFFECT_SCALE
const EXIT_SKILLS_ENABLED := false


static func activate_switch_power(owner, role_id: String, label: String, duration: float, damage_multiplier: float, interval_bonus: float) -> void:
	owner.switch_power_role_id = role_id
	owner.switch_power_label = label
	owner.switch_power_remaining = duration
	owner.switch_power_damage_multiplier = damage_multiplier
	owner.switch_power_interval_bonus = interval_bonus
	owner._update_fire_timer()


static func clear_standby_entry_buff(owner) -> void:
	owner.standby_entry_role_id = ""
	owner.standby_entry_label = "寰呮満钃勫娍"
	owner.standby_entry_remaining = 0.0
	owner.standby_entry_damage_multiplier = 1.0
	owner.standby_entry_interval_bonus = 0.0
	owner._update_fire_timer()



static func apply_rotation_entry_bonus(owner, role_id: String) -> void:
	var rotation_level: int = 0
	if rotation_level <= 0:
		return
	var standby_time: float = float(owner.role_standby_elapsed.get(role_id, 0.0))
	var stacks: int = clamp(int(floor(standby_time / 2.5)), 0, 3)
	if stacks <= 0:
		return
	var damage_step: float = [0.10, 0.14, 0.18][rotation_level - 1]
	var interval_step: float = [0.035, 0.045, 0.055][rotation_level - 1]
	owner.standby_entry_role_id = role_id
	owner.standby_entry_label = "寰呮満钃勫娍"
	owner.standby_entry_remaining = [2.5, 3.5, 4.5][rotation_level - 1]
	owner.standby_entry_damage_multiplier = 1.0 + damage_step * stacks
	owner.standby_entry_interval_bonus = interval_step * stacks
	owner.role_standby_elapsed[role_id] = 0.0
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -48.0), "寰呮満钃勫娍 x%d" % stacks, Color(1.0, 0.86, 0.56, 1.0))
	owner._spawn_ring_effect(owner.global_position, 54.0 + stacks * 10.0, Color(0.64, 0.92, 1.0, 0.62), 5.0, 0.18)
	if rotation_level >= 2:
		owner._add_energy(4.0)
	owner._update_fire_timer()


static func apply_swap_guard(owner, direction: Vector2) -> void:
	var swap_level: int = 0
	if swap_level <= 0:
		return
	var dash_direction: Vector2 = direction.normalized()
	if dash_direction.length_squared() <= 0.001:
		dash_direction = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
	var dash_distance: float = [50.0, 70.0, 90.0][swap_level - 1]
	var invulnerability: float = [0.35, 0.45, 0.55][swap_level - 1]
	owner.global_position += dash_direction * dash_distance
	owner.switch_invulnerability_remaining = max(owner.switch_invulnerability_remaining, invulnerability)
	owner._spawn_dash_line_effect(owner.global_position - dash_direction * dash_distance, owner.global_position, Color(1.0, 0.42, 0.34, 0.96), 12.0, 0.12)
	owner._spawn_ring_effect(owner.global_position, 30.0 + dash_distance * 0.2, Color(1.0, 0.62, 0.38, 0.62), 5.0, 0.14)
	owner._add_energy([3.0, 5.0, 7.0][swap_level - 1])
	if swap_level >= 2:
		owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - 0.4)


static func activate_guard_cover(owner) -> void:
	owner.guard_cover_remaining = 2.0
	owner.guard_cover_damage_multiplier = 0.92
	owner._spawn_combat_tag(owner.global_position + Vector2(0.0, -42.0), "鎺╂姢鏋跺娍", Color(0.88, 0.96, 1.0, 1.0))


static func trigger_rearguard_attack(owner, role_id: String, origin: Vector2, level: int) -> int:
	if level <= 0:
		return 0
	var hit_count: int = 0
	var repeat_count: int = 1 if level == 1 else 2
	var damage_scale: float = 0.4 if level == 1 else (0.45 if level == 2 else 0.55)
	var accent: Color = owner._get_role_theme_color(role_id)
	owner._spawn_combat_tag(origin + Vector2(0.0, -40.0), "鍚庡崼鎺╂姢", Color(min(1.0, accent.r + 0.18), min(1.0, accent.g + 0.18), min(1.0, accent.b + 0.18), 1.0))
	owner._spawn_ring_effect(origin, 62.0 + level * 12.0, Color(accent.r, accent.g, accent.b, 0.68), 8.0, 0.24)
	if owner.get_tree() == null:
		return 0
	var tween: Tween = owner.create_tween()
	for attack_index in range(repeat_count):
		var delay: float = 0.18 * attack_index
		var queued_attack_index: int = attack_index
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			match role_id:
				"swordsman":
					var direction: Vector2 = owner.facing_direction if owner.facing_direction.length_squared() > 0.001 else Vector2.RIGHT
					var slash_direction: Vector2 = direction.rotated(0.18 if queued_attack_index % 2 == 0 else -0.18)
					owner._spawn_crescent_wave_effect(origin + direction * 10.0, slash_direction, 110.0 + level * 10.0, Color(0.26, 0.94, 1.0, 0.72), 0.2, 170.0, 28.0 + level * 3.0)
					owner._spawn_cross_slash_effect(origin, slash_direction, 126.0 + level * 10.0, 24.0 + level * 2.0, Color(1.0, 0.84, 0.48, 0.92), 0.2)
					owner._spawn_ring_effect(origin + direction * 14.0, 60.0 + level * 8.0, Color(1.0, 0.26, 0.18, 0.48), 6.0, 0.18)
					owner._damage_enemies_in_radius(origin + direction * 16.0, 64.0 + level * 8.0, owner._get_role_damage(role_id) * damage_scale, 0.03, 1.0, 0.0)
				"gunner":
					owner._spawn_radial_rays_effect(origin, 86.0 + level * 10.0, 10 + level * 2, Color(1.0, 0.66, 0.34, 0.7), 4.0 + level, 0.22, queued_attack_index * 0.16)
					_spawn_gunner_rearguard_bullet_batch(owner, role_id, origin, level, damage_scale, queued_attack_index, 0)
				"mage":
					owner._spawn_ring_effect(origin, 62.0 + level * 10.0, Color(0.68, 0.94, 1.0, 0.82), 7.0, 0.22)
					owner._spawn_frost_sigils_effect(origin, 40.0 + level * 10.0, Color(0.9, 0.98, 1.0, 0.88), 0.22)
					owner._spawn_vortex_effect(origin, 30.0 + level * 8.0, Color(0.7, 0.78, 1.0, 0.42), 0.22)
					owner._spawn_burst_effect(origin, 68.0 + level * 12.0, Color(0.52, 0.9, 1.0, 0.28), 0.22)
					owner._damage_enemies_in_radius(origin, 68.0 + level * 12.0, owner._get_role_damage(role_id) * damage_scale, 0.02, 0.74, 1.0)
		)
		hit_count += 1
	return hit_count


static func _spawn_gunner_rearguard_bullet_batch(owner, role_id: String, origin: Vector2, level: int, damage_scale: float, attack_index: int, start_index: int) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var bullet_count: int = 6 + level * 2
	var end_index: int = min(start_index + GUNNER_REARGUARD_BULLET_BATCH_SIZE, bullet_count)
	for bullet_index in range(start_index, end_index):
		var angle: float = TAU * float(bullet_index) / float(bullet_count) + float(attack_index) * 0.14
		var bullet = owner._spawn_directional_bullet(Vector2.RIGHT.rotated(angle), owner._get_role_damage(role_id) * damage_scale, Color(1.0, 0.68, 0.42, 0.92), role_id, origin)
		if bullet != null:
			bullet.speed = 460.0
			bullet.lifetime = 0.7
			bullet.hit_radius = 10.0
			bullet.scale = Vector2(1.18, 1.18)
	if end_index >= bullet_count:
		return
	if owner.get_tree() == null:
		return
	var tween: Tween = owner.create_tween()
	tween.tween_interval(GUNNER_REARGUARD_BULLET_BATCH_INTERVAL)
	tween.tween_callback(func() -> void:
		_spawn_gunner_rearguard_bullet_batch(owner, role_id, origin, level, damage_scale, attack_index, end_index)
	)


static func try_switch_role(owner, new_role_index: int) -> void:
	if new_role_index == owner.active_role_index:
		return
	if new_role_index < 0 or new_role_index >= owner.roles.size():
		return
	if owner.switch_cooldown_remaining > 0.0 and not DEVELOPER_MODE.should_ignore_cooldowns():
		return

	var previous_role_index: int = owner.active_role_index
	var previous_position: Vector2 = owner.global_position
	if owner.has_method("_save_active_role_health"):
		owner._save_active_role_health()
	apply_exit_skill(owner, previous_role_index)
	owner.active_role_index = new_role_index
	owner.switch_cooldown_remaining = 0.0 if DEVELOPER_MODE.should_ignore_cooldowns() else _get_switch_cooldown_duration(owner)
	owner.switch_invulnerability_remaining = SWITCH_INVULNERABILITY
	var active_role_index: int = owner.active_role_index
	var active_role_id: String = str(owner.roles[active_role_index]["id"])
	var switch_direction: Vector2 = owner.velocity if owner.velocity.length_squared() > 0.001 else owner.facing_direction
	owner._update_active_role_state()
	PLAYER_SWITCH_JOB_QUEUE.run_jobs(owner, [
		func() -> void:
			apply_enter_skill(owner, active_role_index),
		func() -> void:
			PLAYER_SWITCH_ENTRY_FLOW.apply_shared_entry_skills(owner, active_role_id),
		func() -> void:
			apply_pending_entry_blessing(owner, active_role_id),
		func() -> void:
			apply_rotation_entry_bonus(owner, active_role_id),
		func() -> void:
			apply_swap_guard(owner, switch_direction)
	])
	var symbol_level: int = 0
	if symbol_level > 0:
		owner._add_energy((4.0 + symbol_level * 1.8) * owner.energy_gain_multiplier)
	if owner._has_elite_relic("elite_reactor"):
		owner._add_energy(12.0)
	if previous_position != owner.global_position:
		owner._spawn_dash_line_effect(previous_position, owner.global_position, Color(0.94, 0.92, 0.66, 0.7), 8.0, 0.12)


static func get_switch_cooldown_duration(owner) -> float:
	return _get_switch_cooldown_duration(owner)


static func _get_switch_cooldown_duration(owner) -> float:
	var common_prosperity_multiplier := 1.0
	if owner.has_method("_get_common_prosperity_switch_cooldown_multiplier"):
		common_prosperity_multiplier = float(owner._get_common_prosperity_switch_cooldown_multiplier())
	var support_multiplier := 1.0
	if owner.has_method("_get_role_blessing_stat_bonus"):
		var role_id := str(owner._get_active_role().get("id", ""))
		support_multiplier = max(0.2, 1.0 - float(owner._get_role_blessing_stat_bonus(role_id, "switch_cooldown_reduction")))
	return max(2.5, (ROLE_SWITCH_COOLDOWN - owner.role_switch_cooldown_bonus) * owner._get_equipment_cooldown_multiplier() * common_prosperity_multiplier * support_multiplier)


static func apply_enter_skill(owner, role_index: int) -> int:
	var role_id: String = owner.roles[role_index]["id"]
	var assault_level: int = 0
	var assault_multiplier: float = 1.0 + float(assault_level) * 0.16
	owner._queue_camera_shake(5.0, 0.12)
	owner._pulse_player_visual(1.14, 0.14)
	match role_id:
		"swordsman":
			if owner.swordsman_role != null:
				return owner.swordsman_role.perform_enter(owner, role_id, assault_level, assault_multiplier)
		"gunner":
			if owner.gunner_role != null:
				return owner.gunner_role.perform_enter(owner, role_id, assault_level, assault_multiplier)
		"mage":
			if owner.mage_role != null:
				return owner.mage_role.perform_enter(owner, role_id, assault_level, assault_multiplier)
	return 0


static func apply_exit_skill(owner, role_index: int) -> int:
	if not EXIT_SKILLS_ENABLED:
		return 0
	var role_id: String = owner.roles[role_index]["id"]
	var rearguard_level: int = 0
	owner._queue_camera_shake(3.2, 0.1)
	match role_id:
		"swordsman":
			if owner.swordsman_role != null:
				return owner.swordsman_role.perform_exit(owner, role_id, rearguard_level)
		"gunner":
			if owner.gunner_role != null:
				return owner.gunner_role.perform_exit(owner, role_id, rearguard_level)
		"mage":
			if owner.mage_role != null:
				return owner.mage_role.perform_exit(owner, role_id, rearguard_level)
	return 0


static func fire_gunner_entry_wave(owner, role_id: String, wave_index: int, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.fire_gunner_entry_wave(owner, role_id, wave_index, damage_scale)


static func spawn_gunner_entry_wave_batch(owner, role_id: String, wave_index: int, start_index: int, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.spawn_gunner_entry_wave_batch(owner, role_id, wave_index, start_index, damage_scale)


static func start_mage_entry_bombardment(owner, role_id: String, bombard_centers: Array, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.start_mage_entry_bombardment(owner, role_id, bombard_centers, damage_scale)


static func show_mage_entry_bombardment_warning(owner, center: Vector2) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.show_mage_entry_bombardment_warning(owner, center)


static func trigger_mage_entry_bombardment_impact(owner, role_id: String, center: Vector2, damage_scale: float = 1.0) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.trigger_mage_entry_bombardment_impact(owner, role_id, center, damage_scale)


static func queue_next_entry_blessing(owner, source_role_id: String) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.queue_next_entry_blessing(owner, source_role_id)


static func apply_pending_entry_blessing(owner, target_role_id: String) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.apply_pending_entry_blessing(owner, target_role_id)


static func clear_entry_blessing(owner) -> void:
	PLAYER_SWITCH_ENTRY_FLOW.clear_entry_blessing(owner)



static func apply_switch_payoff(owner, hit_count: int, energy_gain: float, cooldown_refund: float) -> void:
	if hit_count > 0 and energy_gain > 0.0:
		owner._add_energy(energy_gain * owner.energy_gain_multiplier)
	if cooldown_refund > 0.0:
		owner.switch_cooldown_remaining = max(0.0, owner.switch_cooldown_remaining - cooldown_refund)


static func show_switch_banner(owner, prefix: String, title: String, color: Color) -> void:
	PLAYER_SWITCH_BANNER_FLOW.show_switch_banner(owner, prefix, title, color)
