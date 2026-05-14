extends RefCounted

const CIRCLE_POINTS_CACHE_LIMIT := 128

static var circle_points_cache: Dictionary = {}
static var circle_points_cache_order: Array[String] = []

static func build_circle_points(radius: float, segments: int = 20) -> PackedVector2Array:
	var safe_segments: int = max(3, segments)
	var radius_key: int = int(round(radius * 1000.0))
	var cache_key: String = "%d:%d" % [safe_segments, radius_key]
	if circle_points_cache.has(cache_key):
		return circle_points_cache[cache_key] as PackedVector2Array
	var points := PackedVector2Array()
	points.resize(safe_segments)
	for index in range(safe_segments):
		var angle: float = TAU * float(index) / float(safe_segments)
		points[index] = Vector2.RIGHT.rotated(angle) * radius
	_store_circle_points(cache_key, points)
	return points

static func _store_circle_points(cache_key: String, points: PackedVector2Array) -> void:
	if circle_points_cache.has(cache_key):
		return
	while circle_points_cache_order.size() >= CIRCLE_POINTS_CACHE_LIMIT:
		var oldest_key: String = circle_points_cache_order.pop_front()
		circle_points_cache.erase(oldest_key)
	circle_points_cache[cache_key] = points
	circle_points_cache_order.append(cache_key)
