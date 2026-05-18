extends RefCounted

const MAP_SPAWN_MARGIN := 36.0
const MAP_SPAWN_EDGE_EPSILON := 0.5
const SPAWN_POSITION_RETRY_COUNT := 18


static func get_spawn_position(main: Node, angle: float, distance: float) -> Vector2:
	var target_distance: float = max(180.0, distance)
	var base_angle: float = angle
	for index in range(SPAWN_POSITION_RETRY_COUNT):
		var offset_angle: float = 0.0
		if index > 0:
			var side: float = -1.0 if index % 2 == 0 else 1.0
			offset_angle = side * float(index + 1) * 0.18
		var candidate: Vector2 = main.player.global_position + Vector2.RIGHT.rotated(base_angle + offset_angle) * target_distance
		if is_position_inside_spawn_bounds(main, candidate):
			return candidate
	return clamp_position_to_spawn_bounds(main, main.player.global_position + Vector2.RIGHT.rotated(base_angle) * target_distance)


static func get_spawn_bounds(main: Node) -> Rect2:
	if main != null and main.get("map_bounds") != null:
		var bounds: Variant = main.get("map_bounds")
		if bounds is Rect2:
			return (bounds as Rect2).grow(-MAP_SPAWN_MARGIN)
	return Rect2(Vector2(-1600.0, -900.0), Vector2(3200.0, 1800.0)).grow(-MAP_SPAWN_MARGIN)


static func is_position_inside_spawn_bounds(main: Node, position: Vector2) -> bool:
	return get_spawn_bounds(main).has_point(position)


static func clamp_position_to_spawn_bounds(main: Node, position: Vector2) -> Vector2:
	var bounds: Rect2 = get_spawn_bounds(main)
	return Vector2(
		clamp(position.x, bounds.position.x, bounds.position.x + bounds.size.x - MAP_SPAWN_EDGE_EPSILON),
		clamp(position.y, bounds.position.y, bounds.position.y + bounds.size.y - MAP_SPAWN_EDGE_EPSILON)
	)
