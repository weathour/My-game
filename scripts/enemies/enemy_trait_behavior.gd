extends RefCounted

const ENEMY_PROJECTILES := preload("res://scripts/enemies/enemy_projectiles.gd")
const ENEMY_TURRET_BOMBARD := preload("res://scripts/enemies/enemy_turret_bombard.gd")
const NON_BOSS_RANGED_ATTACK_FREQUENCY_MULTIPLIER := 0.4
const GLUTTON_ABSORB_INTERVAL := 0.18

static func update_behavior_state(enemy, delta: float) -> void:
	_tick_trait(enemy, enemy.behavior_id, delta)
	if enemy.secondary_behavior_id != "" and enemy.secondary_behavior_id != enemy.behavior_id:
		_tick_trait(enemy, enemy.secondary_behavior_id, delta)

static func _tick_trait(enemy, trait_id: String, delta: float) -> void:
	match trait_id:
		"shooter":
			_update_shooter_trait(enemy, delta)
		"accelerator":
			_update_accelerator_trait(enemy, delta)
		"dash":
			_update_dash_trait(enemy, delta)
		"glutton":
			_update_glutton_trait(enemy, delta)
		"rebirth":
			_update_rebirth_trait(enemy, delta)
		"turret":
			_update_turret_trait(enemy, delta)
		"boss":
			enemy._update_boss_trait(delta)

static func _update_shooter_trait(enemy, delta: float) -> void:
	if enemy.shot_interval <= 0.0:
		return
	var shot_interval: float = _get_non_boss_ranged_interval(enemy, enemy.shot_interval)
	enemy.shot_timer -= delta
	if enemy.shot_timer > 0.0:
		return
	enemy.shot_timer += max(0.18, shot_interval)
	ENEMY_PROJECTILES.fire_shooter_pattern(enemy)

static func _update_accelerator_trait(enemy, delta: float) -> void:
	if enemy.acceleration_remaining > 0.0:
		enemy.acceleration_remaining = max(0.0, enemy.acceleration_remaining - delta)
	if enemy.acceleration_interval <= 0.0:
		return
	enemy.acceleration_timer -= delta
	if enemy.acceleration_timer > 0.0:
		return
	enemy.acceleration_timer += max(0.2, enemy.acceleration_interval)
	enemy.acceleration_remaining = max(enemy.acceleration_remaining, enemy.acceleration_duration)
	enemy._spawn_status_burst(Color(1.0, 0.74, 0.34, 0.26), 22.0 + enemy.scale.x * 6.0)

static func _update_dash_trait(enemy, delta: float) -> void:
	if enemy.dash_remaining > 0.0:
		enemy.dash_remaining = max(0.0, enemy.dash_remaining - delta)
		return
	if enemy.dash_windup_remaining > 0.0:
		enemy.dash_windup_remaining = max(0.0, enemy.dash_windup_remaining - delta)
		if enemy.dash_windup_remaining <= 0.0:
			enemy.dash_remaining = max(enemy.dash_remaining, enemy.dash_duration)
			enemy._spawn_dash_trail(enemy.dash_direction, 42.0 + enemy.scale.x * 8.0)
		return
	if enemy.dash_interval <= 0.0:
		return
	enemy.dash_timer -= delta
	if enemy.dash_timer > 0.0:
		return
	enemy.dash_timer += max(0.3, enemy.dash_interval)
	var direction_to_target: Vector2 = enemy.global_position.direction_to(enemy.target.global_position)
	enemy.dash_direction = direction_to_target if direction_to_target != Vector2.ZERO else Vector2.RIGHT
	enemy.dash_windup_remaining = max(enemy.dash_windup_duration, 0.18)
	enemy._spawn_status_burst(Color(1.0, 0.88, 0.32, 0.24), 28.0 + enemy.scale.x * 6.0)

static func _update_glutton_trait(enemy, delta: float) -> void:
	if enemy.glutton_absorb_radius <= 0.0:
		return
	enemy.glutton_absorb_elapsed += delta
	if enemy.glutton_absorb_elapsed < GLUTTON_ABSORB_INTERVAL:
		return
	enemy.glutton_absorb_elapsed = 0.0
	for gem in enemy.get_tree().get_nodes_in_group("exp_gems"):
		if not is_instance_valid(gem):
			continue
		if enemy.global_position.distance_to(gem.global_position) > enemy.glutton_absorb_radius:
			continue
		if gem.has_method("collect"):
			gem.collect()
		enemy.glutton_bonus_speed = min(enemy.glutton_max_bonus_speed, enemy.glutton_bonus_speed + enemy.glutton_speed_gain_per_gem)
		enemy.scale += Vector2.ONE * enemy.glutton_scale_gain_per_gem
		enemy._spawn_status_burst(Color(0.42, 0.88, 1.0, 0.18), 26.0 + enemy.scale.x * 6.0)

static func _update_rebirth_trait(enemy, delta: float) -> void:
	if enemy.rebirth_timer <= 0.0:
		return
	enemy.rebirth_timer = max(0.0, enemy.rebirth_timer - delta)
	if enemy.rebirth_timer <= 0.0:
		enemy._spawn_status_burst(Color(0.82, 0.66, 1.0, 0.3), 32.0 + enemy.scale.x * 8.0)

static func _update_turret_trait(enemy, delta: float) -> void:
	if enemy.turret_bombard_interval <= 0.0 or enemy.target == null or not is_instance_valid(enemy.target):
		return
	var turret_bombard_interval: float = _get_non_boss_ranged_interval(enemy, enemy.turret_bombard_interval)
	enemy.turret_bombard_timer -= delta
	if enemy.turret_bombard_timer > 0.0:
		return
	enemy.turret_bombard_timer += max(0.5, turret_bombard_interval)
	ENEMY_TURRET_BOMBARD.start_bombard(enemy)

static func _get_non_boss_ranged_interval(enemy, base_interval: float) -> float:
	if str(enemy.enemy_kind) == "boss":
		return base_interval
	return base_interval / max(NON_BOSS_RANGED_ATTACK_FREQUENCY_MULTIPLIER, 0.001)
