extends RefCounted

static func take_damage(enemy, amount: float) -> bool:
	return apply_damage(enemy, amount, true)

static func apply_damage(enemy, amount: float, show_feedback: bool = true) -> bool:
	if enemy.enemy_kind == "boss" and enemy.boss_phase >= 3 and enemy.boss_phase_three_intro_remaining > 0.0:
		return false
	if enemy.rebirth_timer > 0.0:
		return false
	var adjusted_damage: float = amount * (1.0 + enemy.vulnerability_bonus)
	enemy.current_health -= adjusted_damage
	var killed: bool = enemy.current_health <= 0.0
	if show_feedback:
		enemy._play_hit_feedback(adjusted_damage, killed)
	if enemy.enemy_kind == "small_boss" and enemy.behavior_id == "rebirth" and killed and enemy.rebirth_lives_remaining > 0:
		enemy.rebirth_lives_remaining -= 1
		enemy.current_health = enemy.max_health
		enemy.rebirth_timer = enemy.rebirth_delay
		if enemy.target != null and is_instance_valid(enemy.target) and enemy.target.has_method("apply_enemy_slow"):
			enemy.target.apply_enemy_slow(enemy.rebirth_slow_multiplier, enemy.rebirth_slow_duration)
		enemy._spawn_status_burst(Color(0.8, 0.64, 1.0, 0.32), 40.0 + enemy.scale.x * 10.0)
		return false
	if enemy.current_health <= 0.0:
		enemy.defeated.emit(enemy.enemy_kind)
		enemy._drop_experience_gem()
		enemy._maybe_drop_heart()
		enemy.queue_free()
		return true

	return false
