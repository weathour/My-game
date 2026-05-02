extends RefCounted

static func reset(enemy, randomize_timers: bool) -> void:
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
		enemy.strafe_sign = 1.0
		enemy.boss_turning_sign = 1.0
		enemy.boss_orbit_sign = 1.0

	enemy.acceleration_remaining = 0.0
	enemy.dash_windup_remaining = 0.0
	enemy.dash_remaining = 0.0
	enemy.boss_sine_stream_remaining = 0.0
	enemy.boss_sine_stream_timer = 0.0
	enemy.boss_pattern_rotation = randf() * TAU if randomize_timers else 0.0
	enemy.boss_battle_elapsed = 0.0
	enemy.boss_phase = 1
	enemy.boss_phase_three_elapsed = 0.0
	enemy.boss_phase_three_intro_remaining = 0.0
	enemy.boss_laser_remaining = 0.0
	enemy.boss_laser_rotation = randf() * TAU if randomize_timers else 0.0
	enemy.boss_laser_start_rotation = enemy.boss_laser_rotation
	enemy.boss_laser_final_rotation = enemy.boss_laser_rotation
	enemy.boss_laser_hit_timer = 0.0
	enemy.boss_orbit_bomb_remaining = 0.0
	enemy.boss_orbit_bomb_angle = 0.0
	enemy.boss_orbit_bomb_shot_timer = 0.0
	enemy.boss_peacock_charge_remaining = 0.0
	enemy.rebirth_timer = 0.0
	enemy.glutton_absorb_elapsed = 0.0
