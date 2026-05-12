extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const LINE_POOL_LIMIT := 96
const COMPOSITE_POOL_LIMIT_PER_KIND := 32

static var line_pool: Array[Line2D] = []
static var composite_pools: Dictionary = {}

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")
		PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func _can_spawn_temporary_effect(owner: Node) -> bool:
	return owner != null and owner.get_tree() != null

static func spawn_dash_line_effect(owner: Node, start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var line := _acquire_line(current_scene)
	line.global_position = Vector2.ZERO
	line.rotation = 0.0
	line.z_index = 11
	line.width = width
	line.default_color = color
	line.closed = false
	line.points = PackedVector2Array([start_position, end_position])
	line.scale = Vector2.ONE
	line.modulate = Color.WHITE

	var tween := line.create_tween()
	tween.parallel().tween_property(line, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(line, "width", 2.0, duration)
	tween.tween_callback(_release_line.bind(line))


static func spawn_ring_effect(owner: Node, center: Vector2, radius: float, color: Color, width: float, duration: float, points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var ring := _acquire_line(current_scene)
	ring.global_position = center
	ring.rotation = 0.0
	ring.z_index = 11
	ring.width = width
	ring.default_color = color
	ring.closed = true
	ring.points = points
	ring.scale = Vector2.ONE
	ring.modulate = Color.WHITE

	var tween := ring.create_tween()
	tween.parallel().tween_property(ring, "width", 2.0, duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(_release_line.bind(ring))

static func _acquire_line(current_scene: Node) -> Line2D:
	while not line_pool.is_empty():
		var pooled_line: Variant = line_pool.pop_back()
		if not is_instance_valid(pooled_line) or not (pooled_line is Line2D):
			continue
		var line := pooled_line as Line2D
		if line.is_queued_for_deletion():
			continue
		_prepare_pooled_line(line, current_scene)
		return line
	var line := Line2D.new()
	current_scene.add_child(line)
	_mark_temporary_effect(line)
	return line

static func _release_line(line: Line2D) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.hide()
	line.remove_from_group("temporary_effects")
	if line_pool.size() < LINE_POOL_LIMIT and not line_pool.has(line):
		line_pool.append(line)
	else:
		line.queue_free()

static func _prepare_pooled_line(line: Line2D, current_scene: Node) -> void:
	var parent := line.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(line)
		current_scene.add_child(line)
	line.show()
	line.add_to_group("temporary_effects")
	PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)


static func spawn_slash_effect(owner: Node, center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var effect := _acquire_composite(current_scene, "slash", ["polygon"])
	effect.global_position = center
	effect.rotation = direction.angle()
	effect.scale = Vector2.ONE
	effect.modulate = Color.WHITE
	effect.z_index = 12

	var polygon := effect.get_node_or_null("polygon") as Polygon2D
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		Vector2(-18.0, -width * 0.7),
		Vector2(length * 0.2, -width),
		Vector2(length, -width * 0.12),
		Vector2(length * 0.72, width * 0.48),
		Vector2(-12.0, width * 0.7)
	])

	effect.scale = Vector2(0.32, 0.74)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2(1.0, 1.0), duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(_release_composite.bind(effect, "slash"))


static func spawn_line_corridor_effect(owner: Node, start_position: Vector2, end_position: Vector2, hit_width: float, color: Color, duration: float) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var direction := start_position.direction_to(end_position)
	var length := start_position.distance_to(end_position)
	if length <= 1.0:
		return

	var effect := _acquire_composite(current_scene, "corridor", ["polygon"])
	effect.global_position = start_position
	effect.rotation = direction.angle()
	effect.scale = Vector2.ONE
	effect.modulate = Color.WHITE
	effect.z_index = 10

	var polygon := effect.get_node_or_null("polygon") as Polygon2D
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		Vector2(0.0, -hit_width),
		Vector2(length, -hit_width),
		Vector2(length, hit_width),
		Vector2(0.0, hit_width)
	])

	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(effect, "scale:y", 0.65, duration)
	tween.tween_callback(_release_composite.bind(effect, "corridor"))


static func spawn_crescent_wave_effect(owner: Node, center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_band_points: PackedVector2Array, edge_points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var effect := _acquire_composite(current_scene, "crescent", ["polygon", "edge"])
	effect.global_position = center
	effect.rotation = direction.angle()
	effect.scale = Vector2.ONE
	effect.modulate = Color.WHITE
	effect.z_index = 13

	var polygon := effect.get_node_or_null("polygon") as Polygon2D
	polygon.color = Color(color.r, color.g, color.b, min(0.05, color.a * 0.08))
	polygon.polygon = arc_band_points

	var edge := effect.get_node_or_null("edge") as Line2D
	edge.width = 4.0
	edge.default_color = Color(0.9, 0.98, 1.0, min(0.1, color.a * 0.16))
	edge.points = edge_points

	effect.scale = Vector2(0.42, 0.42)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(_release_composite.bind(effect, "crescent"))


static func spawn_owner_crescent_wave_effect(owner, center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_degrees: float = 270.0, thickness: float = 26.0) -> void:
	var outer_radius: float = radius
	var inner_radius: float = max(8.0, radius - thickness)
	spawn_crescent_wave_effect(
		owner,
		center,
		direction,
		radius,
		color,
		duration,
		owner._build_arc_band_polygon(outer_radius, inner_radius, arc_degrees),
		owner._build_arc_points(outer_radius - 2.0, arc_degrees)
	)


static func spawn_thrust_effect(owner: Node, start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float, show_arrow: bool = true) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var direction := start_position.direction_to(end_position)
	var length := start_position.distance_to(end_position)

	spawn_line_corridor_effect(owner, start_position, end_position, width, Color(color.r, color.g, color.b, min(0.34, color.a * 0.35)), duration)
	if not show_arrow:
		return

	var effect := _acquire_composite(current_scene, "thrust", ["shaft", "tip"])
	effect.global_position = start_position
	effect.rotation = direction.angle()
	effect.scale = Vector2.ONE
	effect.modulate = Color.WHITE
	effect.z_index = 13

	var shaft := effect.get_node_or_null("shaft") as Polygon2D
	shaft.color = color
	shaft.polygon = PackedVector2Array([
		Vector2(0.0, -width * 0.22),
		Vector2(length * 0.8, -width * 0.16),
		Vector2(length * 0.8, width * 0.16),
		Vector2(0.0, width * 0.22)
	])

	var tip := effect.get_node_or_null("tip") as Polygon2D
	tip.color = Color(1.0, 0.92, 0.72, min(1.0, color.a + 0.08))
	tip.polygon = PackedVector2Array([
		Vector2(length * 0.72, -width * 0.46),
		Vector2(length, 0.0),
		Vector2(length * 0.72, width * 0.46)
	])

	effect.scale = Vector2(0.3, 0.8)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(_release_composite.bind(effect, "thrust"))

static func _acquire_composite(current_scene: Node, kind: String, child_names: Array[String]) -> Node2D:
	var pool: Array = composite_pools.get(kind, [])
	while not pool.is_empty():
		var pooled_root: Variant = pool.pop_back()
		if not is_instance_valid(pooled_root) or not (pooled_root is Node2D):
			continue
		var root := pooled_root as Node2D
		if root.is_queued_for_deletion():
			continue
		composite_pools[kind] = pool
		_prepare_composite(root, current_scene)
		return root
	composite_pools[kind] = pool
	var root := Node2D.new()
	current_scene.add_child(root)
	_mark_temporary_effect(root)
	for child_name in child_names:
		if child_name == "edge":
			var line := Line2D.new()
			line.name = child_name
			root.add_child(line)
		else:
			var polygon := Polygon2D.new()
			polygon.name = child_name
			root.add_child(polygon)
	return root

static func _release_composite(root: Node2D, kind: String) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.hide()
	root.remove_from_group("temporary_effects")
	var pool: Array = composite_pools.get(kind, [])
	if pool.size() < COMPOSITE_POOL_LIMIT_PER_KIND and not pool.has(root):
		pool.append(root)
		composite_pools[kind] = pool
	else:
		root.queue_free()

static func _prepare_composite(root: Node2D, current_scene: Node) -> void:
	var parent := root.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(root)
		current_scene.add_child(root)
	root.show()
	root.add_to_group("temporary_effects")
	PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)
