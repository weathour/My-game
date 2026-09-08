extends RefCounted

const PLAYER_RESOURCE_FLOW := preload("res://scripts/player/player_resource_flow.gd")

const DAMAGE_RATIO := 1.60
const HIT_TEMPORARY_HEALTH := 5.0
const TEMPORARY_HEALTH_DURATION := 5.0
const THRUST_LENGTH := 250.0
const THRUST_WIDTH := 58.0
const KNOCKBACK_DISTANCE := 100.0
const SOURCE_ROLE_ID := "swordsman"
const SIDE_ANGLE := deg_to_rad(15.0)
const SIDE_SCALE := 0.8


static func apply(owner, direction: Vector2, length_bonus: float = 0.0, damage_ratio_bonus: float = 0.0, thrust_count: int = 1, has_side_thrusts: bool = false, temporary_health_bonus: float = 0.0) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	var axis := direction.normalized()
	if axis.length_squared() <= 0.001:
		axis = Vector2.RIGHT
	var hit_registry: Dictionary = {}
	var total_new_hits := 0
	var base_length := THRUST_LENGTH + length_bonus
	var base_damage: float = float(owner._get_role_damage(SOURCE_ROLE_ID)) * (DAMAGE_RATIO + damage_ratio_bonus)
	var angles: Array[float] = [0.0]
	if has_side_thrusts:
		angles = [-SIDE_ANGLE, 0.0, SIDE_ANGLE]
	for angle in angles:
		var scale: float = SIDE_SCALE if not is_zero_approx(angle) else 1.0
		var thrust_axis: Vector2 = axis.rotated(angle)
		var thrust_length: float = base_length * scale
		var thrust_width: float = THRUST_WIDTH * scale
		var center: Vector2 = owner.global_position + thrust_axis * (thrust_length * 0.5)
		total_new_hits += int(owner._damage_enemies_in_oriented_rect_tracking(
			center,
			thrust_axis,
			thrust_length,
			thrust_width,
			base_damage,
			0.0,
			1.0,
			0.0,
			hit_registry,
			SOURCE_ROLE_ID,
			KNOCKBACK_DISTANCE
		))
	if total_new_hits > 0:
		PLAYER_RESOURCE_FLOW.add_temporary_health(
			owner,
			float(total_new_hits) * (HIT_TEMPORARY_HEALTH + temporary_health_bonus),
			SOURCE_ROLE_ID,
			TEMPORARY_HEALTH_DURATION
		)
	return total_new_hits
