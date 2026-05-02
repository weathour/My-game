extends RefCounted

const ENEMY_BOSS_ATTACKS := preload("res://scripts/enemies/enemy_boss_attacks.gd")
const ENEMY_BOSS_VISUALS := preload("res://scripts/enemies/enemy_boss_visuals.gd")
const BOSS_ATTACK_INTERVAL_SCALE := 0.6666667
const BOSS_PHASE_THREE_CHARGE_DURATION := 5.0
const BOSS_PHASE_THREE_FULL_PRESSURE_DURATION := 10.0
const BOSS_PHASE_THREE_LATE_INTERVAL_MULTIPLIER := 2.2222223
const BOSS_PHASE_THREE_SHAKE_STRENGTH := 60.0
const BOSS_PHASE_THREE_SHAKE_DURATION := 2.0

static func get_boss_phase(enemy) -> int:
	var health_ratio: float = enemy.current_health / max(enemy.max_health, 1.0)
	if health_ratio <= 0.11:
		return 3
	if health_ratio <= 0.67:
		return 2
	return 1

static func update_boss_trait(enemy, delta: float) -> void:
	enemy._ensure_boss_helpers()
	enemy.boss_battle_elapsed += delta
	var next_phase: int = get_boss_phase(enemy)
	if next_phase != enemy.boss_phase:
		enemy.boss_phase = next_phase
		if enemy.boss_phase == 3:
			enemy.boss_phase_three_elapsed = 0.0
			enemy.boss_phase_three_intro_remaining = BOSS_PHASE_THREE_CHARGE_DURATION
			enemy.boss_laser_remaining = 0.0
			enemy.boss_laser_hit_timer = 0.0
			enemy._clear_boss_orbit_ball()
			enemy._clear_boss_peacock_markers()
			ENEMY_BOSS_ATTACKS.update_lasers(enemy, 0.0)
		enemy._spawn_status_burst(Color(1.0, 0.84, 0.42, 0.24), 54.0 + enemy.scale.x * 12.0)

	if enemy.boss_phase >= 3 and enemy.boss_phase_three_intro_remaining > 0.0:
		update_boss_phase_three_intro(enemy, delta)
		return

	if enemy.boss_phase >= 3:
		enemy.boss_phase_three_elapsed += delta

	var pressure_scale: float = max(0.6, float(enemy.get("boss_attack_pressure_scale")))
	var interval_pressure_multiplier: float = 1.0 / sqrt(pressure_scale)
	var count_pressure_multiplier: float = sqrt(pressure_scale)
	var radial_interval: float = 0.74
	var radial_count: int = 16
	var sine_interval: float = 2.9
	var sine_count: int = 12
	var phase_three_interval_multiplier: float = 1.0
	if enemy.boss_phase == 1:
		radial_interval *= 4.0
		sine_interval *= 4.0
	elif enemy.boss_phase == 2:
		radial_interval = 0.6
		radial_count = 18
		sine_interval = 2.15
		sine_count = 18
	elif enemy.boss_phase >= 3:
		radial_interval = 0.48
		radial_count = 20
		sine_interval = 1.95
		sine_count = 16
		if enemy.boss_phase_three_elapsed > BOSS_PHASE_THREE_FULL_PRESSURE_DURATION:
			phase_three_interval_multiplier = BOSS_PHASE_THREE_LATE_INTERVAL_MULTIPLIER
	if enemy.boss_phase == 2:
		radial_interval *= 2.2222223
		sine_interval *= 2.2222223
	if enemy.boss_phase >= 3:
		radial_interval *= phase_three_interval_multiplier
		sine_interval *= phase_three_interval_multiplier
	radial_interval *= BOSS_ATTACK_INTERVAL_SCALE
	sine_interval *= BOSS_ATTACK_INTERVAL_SCALE
	radial_interval *= interval_pressure_multiplier
	sine_interval *= interval_pressure_multiplier
	radial_count = max(8, int(round(float(radial_count) * count_pressure_multiplier)))
	sine_count = max(8, int(round(float(sine_count) * count_pressure_multiplier)))

	enemy.boss_radial_timer -= delta
	if enemy.boss_radial_timer <= 0.0:
		enemy.boss_radial_timer += radial_interval
		ENEMY_BOSS_ATTACKS.fire_radial_burst(enemy, radial_count)

	enemy.boss_sine_cooldown -= delta
	if enemy.boss_sine_cooldown <= 0.0:
		enemy.boss_sine_cooldown += sine_interval
		ENEMY_BOSS_ATTACKS.fire_quarter_sine_ring(enemy, sine_count)

	if enemy.boss_phase >= 2:
		enemy.boss_split_timer -= delta
		if enemy.boss_split_timer <= 0.0:
			var split_interval: float = (5.4 if enemy.boss_phase == 2 else 4.2) * interval_pressure_multiplier
			if enemy.boss_phase == 2:
				split_interval *= 2.2222223
			elif enemy.boss_phase >= 3:
				split_interval *= phase_three_interval_multiplier
			enemy.boss_split_timer += split_interval * BOSS_ATTACK_INTERVAL_SCALE
			ENEMY_BOSS_ATTACKS.fire_recall_split(enemy)

		enemy.boss_laser_timer -= delta
		if enemy.boss_laser_timer <= 0.0 and enemy.boss_laser_remaining <= 0.0:
			var laser_interval: float = ((8.0 if enemy.boss_phase == 2 else 6.4) + 3.0) * interval_pressure_multiplier
			if enemy.boss_phase == 2:
				laser_interval *= 2.2222223
			elif enemy.boss_phase >= 3:
				laser_interval *= phase_three_interval_multiplier
			enemy.boss_laser_timer += laser_interval * BOSS_ATTACK_INTERVAL_SCALE
			ENEMY_BOSS_ATTACKS.start_laser_sweep(enemy)

	ENEMY_BOSS_ATTACKS.update_lasers(enemy, delta)

	if enemy.boss_phase >= 3:
		enemy.boss_orbit_bomb_timer -= delta
		if enemy.boss_orbit_bomb_timer <= 0.0 and enemy.boss_orbit_bomb_remaining <= 0.0:
			enemy.boss_orbit_bomb_timer += 9.8 * BOSS_ATTACK_INTERVAL_SCALE * phase_three_interval_multiplier * interval_pressure_multiplier
			ENEMY_BOSS_ATTACKS.start_orbit_bomb(enemy)

		enemy.boss_peacock_timer -= delta
		if enemy.boss_peacock_timer <= 0.0 and enemy.boss_peacock_charge_remaining <= 0.0:
			enemy.boss_peacock_timer += 8.2 * BOSS_ATTACK_INTERVAL_SCALE * phase_three_interval_multiplier * interval_pressure_multiplier
			ENEMY_BOSS_ATTACKS.start_peacock_attack(enemy)

	ENEMY_BOSS_ATTACKS.update_orbit_bomb(enemy, delta)
	ENEMY_BOSS_ATTACKS.update_peacock_attack(enemy, delta)

static func update_boss_phase_three_intro(enemy, delta: float) -> void:
	enemy.boss_phase_three_intro_remaining = max(0.0, enemy.boss_phase_three_intro_remaining - delta)
	ENEMY_BOSS_VISUALS.update_boss_phase_three_charge_visuals(enemy)
	if enemy.boss_phase_three_intro_remaining > 0.0:
		return
	ENEMY_BOSS_VISUALS.clear_boss_phase_three_charge_visuals(enemy)
	enemy.boss_phase_three_elapsed = 0.0
	enemy.boss_radial_timer = 0.18
	enemy.boss_sine_cooldown = 0.75
	enemy.boss_split_timer = 1.6
	enemy.boss_laser_timer = 2.9
	enemy.boss_orbit_bomb_timer = 3.8
	enemy.boss_peacock_timer = 4.6
	enemy._spawn_status_burst(Color(0.2, 0.42, 1.0, 0.34), 84.0 + enemy.scale.x * 12.0)
	if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("queue_external_camera_shake"):
		enemy.target.queue_external_camera_shake(BOSS_PHASE_THREE_SHAKE_STRENGTH, BOSS_PHASE_THREE_SHAKE_DURATION)
