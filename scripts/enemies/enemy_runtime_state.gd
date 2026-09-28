extends RefCounted

const ENEMY_GLUTTON_SKILL_BEHAVIOR := preload("res://scripts/enemies/enemy_glutton_skill_behavior.gd")
const ENEMY_BOSS_STATE := preload("res://scripts/enemies/enemy_boss_state.gd")

static func reset(enemy, randomize_timers: bool) -> void:
	preload("res://scripts/enemies/enemy_runner_haste.gd").reset(enemy)
	enemy.fury_armor_shred = 0.0
	enemy.fury_armor_shred_remaining = 0.0
	if randomize_timers:
		enemy.shot_timer = randf_range(0.15, max(0.16, enemy.shot_interval))
		enemy.acceleration_timer = randf_range(0.2, max(0.22, enemy.acceleration_interval)) if enemy.acceleration_interval > 0.0 else 0.0
		enemy.dash_timer = randf_range(0.35, max(0.4, enemy.dash_interval)) if enemy.dash_interval > 0.0 else 0.0
		enemy.boss_radial_timer = randf_range(0.18, max(0.2, enemy.boss_radial_interval))
		enemy.boss_sine_cooldown = randf_range(1.0, max(1.1, enemy.boss_sine_interval))
		enemy.boss_turning_timer = randf_range(1.4, max(1.5, enemy.boss_turning_interval))
		enemy.boss_split_timer = randf_range(2.0, max(2.2, enemy.boss_split_interval))
		enemy.boss_laser_timer = randf_range(3.0, max(3.2, enemy.boss_laser_interval))
		enemy.boss_orbit_bomb_timer = randf_range(4.0, max(4.2, enemy.boss_orbit_bomb_interval))
		enemy.boss_peacock_timer = randf_range(4.0, max(4.2, enemy.boss_peacock_interval))
		enemy.turret_bombard_timer = randf_range(1.2, max(1.3, enemy.turret_bombard_interval)) if enemy.turret_bombard_interval > 0.0 else 0.0
		enemy.rose_split_timer = randf_range(6.0, 15.0)
		enemy.strafe_sign = -1.0 if randi() % 2 == 0 else 1.0
		enemy.boss_turning_sign = -1.0 if randi() % 2 == 0 else 1.0
		enemy.boss_orbit_sign = -1.0 if randi() % 2 == 0 else 1.0
	else:
		enemy.shot_timer = enemy.shot_interval
		enemy.acceleration_timer = enemy.acceleration_interval
		enemy.dash_timer = enemy.dash_interval
		enemy.boss_radial_timer = enemy.boss_radial_interval
		enemy.boss_sine_cooldown = enemy.boss_sine_interval
		enemy.boss_turning_timer = enemy.boss_turning_interval
		enemy.boss_split_timer = enemy.boss_split_interval
		enemy.boss_laser_timer = enemy.boss_laser_interval
		enemy.boss_orbit_bomb_timer = enemy.boss_orbit_bomb_interval
		enemy.boss_peacock_timer = enemy.boss_peacock_interval
		enemy.turret_bombard_timer = enemy.turret_bombard_interval
		enemy.rose_split_timer = 15.0
		enemy.strafe_sign = 1.0
		enemy.boss_turning_sign = 1.0
		enemy.boss_orbit_sign = 1.0

	enemy.acceleration_remaining = 0.0
	enemy.basic_shot_timer = 0.0
	if str(enemy.archetype_id) == "shotgunner":
		var basic_interval: float = preload("res://scripts/enemies/enemy_shotgunner_attacks.gd").get_basic_interval()
		enemy.basic_shot_timer = randf_range(0.15, basic_interval) if randomize_timers else basic_interval
		enemy.shot_timer = enemy.shot_interval
	enemy.dash_windup_remaining = 0.0
	enemy.dash_remaining = 0.0
	enemy.dash_distance_remaining = 0.0
	enemy.elite_charge_haste_remaining = 0.0
	if preload("res://scripts/enemies/enemy_dasher_charge.gd").uses_fixed_charge(enemy):
		enemy.dash_timer = enemy.dash_interval
	enemy.boss_sine_stream_remaining = 0.0
	enemy.boss_sine_stream_timer = 0.0
	enemy.boss_danmaku_pattern = -1
	enemy.boss_danmaku_wave = 6
	enemy.boss_danmaku_count = 0
	enemy.boss_danmaku_rotation = 0.0
	enemy.boss_danmaku_spin = 1.0
	ENEMY_BOSS_STATE.ROUTINE.reset(enemy)
	enemy.boss_aimed_shots_remaining = 0
	enemy.boss_aimed_shot_timer = 0.0
	enemy.boss_pattern_rotation = randf() * TAU if randomize_timers else 0.0
	enemy.boss_battle_elapsed = 0.0
	enemy.boss_phase = 1
	enemy.boss_phase_three_elapsed = 0.0
	enemy.boss_phase_three_intro_remaining = 0.0
	enemy.boss_phase_transition_target = 0
	enemy.boss_shield_break_intro_played = false
	enemy.boss_shield_break_visual_intro_active = false
	if str(enemy.enemy_kind) == "boss":
		enemy.current_health = ENEMY_BOSS_STATE.get_boss_spawn_health(enemy)
	enemy.boss_laser_remaining = 0.0
	enemy.boss_laser_rotation = randf() * TAU if randomize_timers else 0.0
	enemy.boss_laser_start_rotation = enemy.boss_laser_rotation
	enemy.boss_laser_final_rotation = enemy.boss_laser_rotation
	enemy.boss_laser_hit_timer = 0.0
	enemy.boss_orbit_bomb_remaining = 0.0
	enemy.boss_orbit_bomb_angle = 0.0
	enemy.boss_orbit_bomb_shot_timer = 0.0
	enemy.boss_orbit_pull_remaining = 0.0
	enemy.boss_peacock_charge_remaining = 0.0
	enemy.rebirth_timer = 0.0
	enemy.glutton_absorb_elapsed = 0.0
	enemy.glutton_aura_hits_by_enemy_id.clear()
	ENEMY_GLUTTON_SKILL_BEHAVIOR.reset(enemy)
	enemy.skulltomb_summon_timer = enemy.skulltomb_summon_interval
	enemy.skulltomb_summon_windup_remaining = 0.0
	enemy.skulltomb_charge_timer = enemy.skulltomb_charge_interval
	enemy.skulltomb_charge_decision_timer = 0.0
	enemy.skulltomb_charge_active = false
	enemy.skulltomb_charge_windup_remaining = 0.0
	enemy.skulltomb_charge_target_position = Vector2.ZERO
	enemy.skulltomb_aging_aura_elapsed = 0.0
	enemy.skull_soldier_speed_multiplier = 1.0
	enemy.skull_soldier_speed_timer = 0.0
	enemy.skull_damage_immune_timer = 0.0
	enemy.skullshot_attack_frequency_multiplier = 1.0
	enemy.skullshot_attack_frequency_timer = 0.0
	if enemy.skulltomb_tomb_instance != null and is_instance_valid(enemy.skulltomb_tomb_instance):
		enemy.skulltomb_tomb_instance.queue_free()
	enemy.skulltomb_tomb_instance = null
	if enemy.skulltomb_channel_ring != null and is_instance_valid(enemy.skulltomb_channel_ring):
		enemy.skulltomb_channel_ring.queue_free()
	enemy.skulltomb_channel_ring = null
	if enemy.skulltomb_channel_fill != null and is_instance_valid(enemy.skulltomb_channel_fill):
		enemy.skulltomb_channel_fill.queue_free()
	enemy.skulltomb_channel_fill = null
	if enemy.skulltomb_death_ring != null and is_instance_valid(enemy.skulltomb_death_ring):
		enemy.skulltomb_death_ring.queue_free()
	enemy.skulltomb_death_ring = null
	if enemy.skulltomb_area_instance != null and is_instance_valid(enemy.skulltomb_area_instance):
		enemy.skulltomb_area_instance.queue_free()
	enemy.skulltomb_area_instance = null
	enemy.skulltomb_area_remaining = 0.0
	enemy.skulltomb_area_damage_elapsed = 0.0
	enemy.skulltomb_area_center = Vector2.ZERO
	enemy.skulltomb_area_radius = 0.0
	enemy.skulltomb_pending_spawns.clear()
	enemy.skulltomb_spawn_elapsed = 0.0
	enemy.skulltomb_spawn_vertex_index = 0
