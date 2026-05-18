extends RefCounted


static func apply_body_collision_separation(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var self_body_radius: float = get_body_collision_radius(enemy)
	var push: Vector2 = Vector2.ZERO
	var processed: int = 0
	enemy.ENEMY_SPATIAL_GRID.for_each_neighbor(enemy, max(144.0, self_body_radius * 5.0), func(other: Variant) -> bool:
		if other == null or other == enemy or not is_instance_valid(other) or not (other is Node2D):
			return true
		var other_radius: float = self_body_radius
		var other_body_radius: Variant = other.get("body_collision_radius")
		if other_body_radius != null:
			other_radius = max(8.0, float(other_body_radius))
		var offset: Vector2 = enemy.global_position - (other as Node2D).global_position
		var distance_sq: float = offset.length_squared()
		var min_distance: float = self_body_radius + other_radius
		var min_distance_sq: float = min_distance * min_distance
		if distance_sq >= min_distance_sq:
			return true
		if distance_sq <= 0.001:
			offset = Vector2.RIGHT.rotated(float((enemy.get_instance_id() + processed * 37) % 360) * PI / 180.0)
			distance_sq = 1.0
		var distance: float = sqrt(distance_sq)
		var overlap: float = min_distance - distance
		push += offset / distance * min(overlap * 0.65, 18.0)
		processed += 1
		return processed < 24
	)
	if push.length_squared() > 0.001:
		enemy.global_position += push.limit_length(36.0)


static func get_separation_velocity(enemy) -> Vector2:
	var current_frame := Engine.get_physics_frames()
	if should_refresh_separation(enemy, current_frame):
		enemy.cached_separation_velocity = compute_separation_velocity(enemy)
		enemy.separation_refresh_frame = current_frame + get_separation_refresh_interval(enemy)
	return enemy.cached_separation_velocity


static func compute_separation_velocity(enemy) -> Vector2:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return Vector2.ZERO
	var push: Vector2 = Vector2.ZERO
	var processed: int = 0
	var self_body_radius: float = get_body_collision_radius(enemy)
	enemy.ENEMY_SPATIAL_GRID.for_each_neighbor(enemy, max(128.0, self_body_radius * 4.5), func(other: Variant) -> bool:
		if other == null or other == enemy or not is_instance_valid(other) or not (other is Node2D):
			return true
		var offset: Vector2 = enemy.global_position - (other as Node2D).global_position
		var other_radius: float = self_body_radius
		var other_body_radius: Variant = other.get("body_collision_radius")
		if other_body_radius != null:
			other_radius = max(6.0, float(other_body_radius))
		var radius: float = max(12.0, self_body_radius + other_radius)
		var radius_sq: float = radius * radius
		var distance_sq: float = offset.length_squared()
		if distance_sq > radius_sq:
			return true
		if distance_sq <= 0.001:
			offset = Vector2.RIGHT.rotated(float(enemy.get_instance_id() % 360) * PI / 180.0)
			distance_sq = 1.0
		var distance: float = sqrt(distance_sq)
		var max_push: float = max(170.0, radius * 5.2)
		var strength: float = (radius - distance) / radius
		push += offset.normalized() * strength * max_push
		processed += 1
		return processed < 20
	)
	return push


static func get_body_collision_radius(enemy) -> float:
	var visual_scale_multiplier: float = get_body_collision_visual_scale_multiplier(enemy)
	if float(enemy.body_collision_radius) > 0.0:
		return max(6.0, float(enemy.body_collision_radius) * visual_scale_multiplier)
	return clamp(float(enemy.contact_radius) * 0.82, 24.0, 42.0) * visual_scale_multiplier


static func get_body_collision_visual_scale_multiplier(enemy) -> float:
	var current_scale: float = max(abs(enemy.scale.x), abs(enemy.scale.y))
	var reference_scale: float = max(0.001, float(enemy.body_collision_reference_scale))
	return max(0.25, current_scale / reference_scale)


static func should_refresh_separation(enemy, current_frame: int) -> bool:
	if str(enemy.enemy_kind) != "normal" or str(enemy.secondary_behavior_id) != "" or bool(enemy._has_timed_behavior_traits()):
		return true
	if int(enemy.separation_refresh_frame) < 0:
		enemy.separation_refresh_frame = current_frame + int(enemy.get_instance_id() % get_separation_refresh_interval(enemy))
		return true
	return current_frame >= int(enemy.separation_refresh_frame)


static func get_separation_refresh_interval(enemy) -> int:
	if str(enemy.enemy_kind) == "normal" and str(enemy.secondary_behavior_id) == "" and not bool(enemy._has_timed_behavior_traits()) and bool(enemy._is_scene_under_enemy_pressure()):
		return 4
	return 2
