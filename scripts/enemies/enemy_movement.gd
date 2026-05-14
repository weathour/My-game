extends RefCounted

const GLOBAL_UNIT_MOVE_SPEED_SCALE := 0.7
const BOSS_MOVE_SPEED_SCALE := 0.7

static func compute_velocity(enemy, delta: float) -> Vector2:
	var to_target: Vector2 = enemy._cached_to_target
	var distance_to_target: float = enemy._cached_distance_to_target
	var direction_to_target: Vector2 = enemy._cached_direction_to_target
	var move_direction := direction_to_target
	var move_speed: float = enemy.speed * enemy.slow_multiplier

	if enemy._is_boss:
		return compute_boss_velocity(enemy, direction_to_target, distance_to_target, delta)
	if enemy._is_turret or enemy.rebirth_timer > 0.0:
		return Vector2.ZERO

	if enemy._is_shooter:
		if distance_to_target < enemy.preferred_distance - 34.0:
			move_direction = -direction_to_target
		elif distance_to_target > enemy.preferred_distance + 44.0:
			move_direction = direction_to_target
		else:
			move_direction = (direction_to_target.orthogonal() * enemy.strafe_sign + direction_to_target * 0.18).normalized()

	if enemy._is_dasher and enemy.dash_windup_remaining > 0.0:
		return Vector2.ZERO

	if enemy._is_dasher and enemy.dash_remaining > 0.0:
		move_direction = enemy.dash_direction
		move_speed *= enemy.dash_speed_multiplier

	if enemy._is_accelerator and enemy.acceleration_remaining > 0.0:
		move_speed *= enemy.acceleration_boost

	if enemy._is_glutton:
		move_speed += enemy.glutton_bonus_speed
	if enemy._is_swarm:
		move_speed *= 1.1

	return move_direction * move_speed * GLOBAL_UNIT_MOVE_SPEED_SCALE

static func compute_boss_velocity(enemy, direction_to_target: Vector2, distance_to_target: float, delta: float) -> Vector2:
	if enemy.boss_phase >= 3 and enemy.boss_phase_three_intro_remaining > 0.0:
		return Vector2.ZERO
	var radial := Vector2.ZERO
	if distance_to_target > enemy.preferred_distance + 42.0:
		radial = direction_to_target
	elif distance_to_target < enemy.preferred_distance - 36.0:
		radial = -direction_to_target * 0.88
	else:
		radial = direction_to_target * 0.18

	var tangential: Vector2 = direction_to_target.orthogonal() * enemy.boss_orbit_sign
	enemy.boss_pattern_rotation = wrapf(enemy.boss_pattern_rotation + delta * 0.45, 0.0, TAU)
	var drift := Vector2.RIGHT.rotated(enemy.boss_pattern_rotation) * 0.16
	var move_direction := (tangential * 0.92 + radial * 0.58 + drift).normalized()
	return move_direction * enemy.speed * enemy.slow_multiplier * BOSS_MOVE_SPEED_SCALE * GLOBAL_UNIT_MOVE_SPEED_SCALE
