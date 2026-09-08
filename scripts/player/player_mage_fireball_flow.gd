extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")
const PLAYER_TARGETING := preload("res://scripts/player/player_targeting.gd")


static func resolve_target_position(owner, facing: Vector2, max_range: float) -> Vector2:
	return PLAYER_TARGETING.get_aim_target_position(owner, facing, max_range)


static func apply_impact(owner, center: Vector2, radius: float, damage: float) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	return int(owner._damage_enemies_in_radius(center, radius, damage, 0.0, 1.0, 0.0, "mage"))


static func apply_burn_tick(owner, center: Vector2, radius: float, current_health_ratio: float) -> int:
	if owner == null or not is_instance_valid(owner):
		return 0
	var candidates: Array = PLAYER_DAMAGE_RESOLVER._get_candidate_enemies_for_bounds(
		owner,
		Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	)
	var radius_squared: float = radius * radius
	var hit_count := 0
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		if not bool(PLAYER_DAMAGE_RESOLVER._is_live_enemy(enemy)):
			continue
		var enemy_node := enemy as Node2D
		if center.distance_squared_to(enemy_node.global_position) > radius_squared:
			continue
		var current_health_value: Variant = enemy.get("current_health")
		var burn_damage: float = max(0.0, float(current_health_value) if current_health_value != null else 0.0) * current_health_ratio
		if burn_damage <= 0.0:
			continue
		owner._deal_damage_to_enemy(enemy_node, burn_damage, "mage", 0.0, 2.0, 1.0, 0.0, center)
		hit_count += 1
	return hit_count
