extends RefCounted

static func get_infinite_reload_range_multiplier() -> float:
	return 1.0

static func get_downward_perpendicular(direction: Vector2) -> Vector2:
	var normalized_direction: Vector2 = direction.normalized()
	if normalized_direction.length_squared() <= 0.001:
		return Vector2.DOWN
	var perpendicular: Vector2 = normalized_direction.orthogonal().normalized()
	var mirrored: Vector2 = -perpendicular
	if mirrored.dot(Vector2.DOWN) > perpendicular.dot(Vector2.DOWN):
		return mirrored
	return perpendicular

static func build_circle_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 18
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

static func build_arc_points(radius: float, arc_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 24
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	var start_angle := -half_arc
	var end_angle := half_arc
	for index in range(segments + 1):
		var weight := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points

static func build_arc_band_polygon(outer_radius: float, inner_radius: float, arc_degrees: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var outer_points := build_arc_points(outer_radius, arc_degrees)
	var inner_points := build_arc_points(inner_radius, arc_degrees)
	for point in outer_points:
		points.append(point)
	for index in range(inner_points.size() - 1, -1, -1):
		points.append(inner_points[index])
	return points
