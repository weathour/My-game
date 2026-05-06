extends RefCounted

static func tick_timers(enemy, delta: float) -> void:
	if enemy.slow_timer > 0.0:
		enemy.slow_timer = max(0.0, enemy.slow_timer - delta)
		if enemy.slow_timer == 0.0:
			enemy.slow_multiplier = 1.0

	if enemy.vulnerability_timer > 0.0:
		enemy.vulnerability_timer = max(0.0, enemy.vulnerability_timer - delta)
		if enemy.vulnerability_timer == 0.0:
			enemy.vulnerability_bonus = 0.0

	if enemy.bleed_timer > 0.0:
		enemy.bleed_timer = max(0.0, enemy.bleed_timer - delta)
		if enemy.bleed_timer == 0.0:
			enemy.bleed_damage_per_second = 0.0

static func tick_bleed(enemy, delta: float) -> void:
	if enemy.bleed_timer <= 0.0 or enemy.bleed_damage_per_second <= 0.0:
		return

	var bleed_damage: float = enemy.bleed_damage_per_second * delta
	if bleed_damage > 0.0:
		enemy.take_damage(bleed_damage)

static func apply_slow(enemy, multiplier: float, duration: float) -> void:
	enemy.slow_multiplier = min(enemy.slow_multiplier, clamp(multiplier, 0.2, 1.0))
	enemy.slow_timer = max(enemy.slow_timer, duration)
	enemy._ensure_status_visuals()
	enemy._spawn_status_burst(Color(0.56, 0.92, 1.0, 0.28), 22.0)

static func apply_vulnerability(enemy, bonus: float, duration: float) -> void:
	enemy.vulnerability_bonus = max(enemy.vulnerability_bonus, bonus)
	enemy.vulnerability_timer = max(enemy.vulnerability_timer, duration)
	enemy._ensure_status_visuals()
	enemy._spawn_status_burst(Color(1.0, 0.46, 0.36, 0.24), 18.0)

static func apply_bleed(enemy, damage_per_second: float, duration: float) -> void:
	enemy.bleed_damage_per_second = max(enemy.bleed_damage_per_second, damage_per_second)
	enemy.bleed_timer = max(enemy.bleed_timer, duration)
