extends RefCounted

const SHAPE_CACHE_LIMIT := 96

static var circle_polygon_cache: Dictionary = {}
static var arc_points_cache: Dictionary = {}
static var arc_band_polygon_cache: Dictionary = {}

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
	var key := _shape_cache_key([radius])
	if circle_polygon_cache.has(key):
		return circle_polygon_cache[key]
	var points := PackedVector2Array()
	var segments := 18
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	_store_shape_cache(circle_polygon_cache, key, points)
	return points

static func build_arc_points(radius: float, arc_degrees: float) -> PackedVector2Array:
	var key := _shape_cache_key([radius, arc_degrees])
	if arc_points_cache.has(key):
		return arc_points_cache[key]
	var points := PackedVector2Array()
	var segments := 24
	var half_arc := deg_to_rad(arc_degrees) * 0.5
	var start_angle := -half_arc
	var end_angle := half_arc
	for index in range(segments + 1):
		var weight := float(index) / float(segments)
		var angle := lerpf(start_angle, end_angle, weight)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	_store_shape_cache(arc_points_cache, key, points)
	return points

static func build_arc_band_polygon(outer_radius: float, inner_radius: float, arc_degrees: float) -> PackedVector2Array:
	var key := _shape_cache_key([outer_radius, inner_radius, arc_degrees])
	if arc_band_polygon_cache.has(key):
		return arc_band_polygon_cache[key]
	var points := PackedVector2Array()
	var outer_points := build_arc_points(outer_radius, arc_degrees)
	var inner_points := build_arc_points(inner_radius, arc_degrees)
	for point in outer_points:
		points.append(point)
	for index in range(inner_points.size() - 1, -1, -1):
		points.append(inner_points[index])
	_store_shape_cache(arc_band_polygon_cache, key, points)
	return points

static func _shape_cache_key(values: Array) -> String:
	var parts: Array[String] = []
	for value in values:
		parts.append(str(roundf(float(value) * 10.0) / 10.0))
	return "|".join(parts)

static func _store_shape_cache(cache: Dictionary, key: String, points: PackedVector2Array) -> void:
	if cache.size() >= SHAPE_CACHE_LIMIT:
		cache.clear()
	cache[key] = points
