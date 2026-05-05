extends RefCounted

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")

static func _can_spawn_temporary_effect(owner: Node) -> bool:
	if owner == null or owner.get_tree() == null:
		return false
	var root := owner.get_tree().current_scene
	if root != null and root.has_method("_can_spawn_runtime_group"):
		return bool(root._can_spawn_runtime_group("temporary_effects", 160))
	return true

static func spawn_dash_line_effect(owner: Node, start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var line := Line2D.new()
	_mark_temporary_effect(line)
	line.z_index = 11
	line.width = width
	line.default_color = color
	line.points = PackedVector2Array([start_position, end_position])
	current_scene.add_child(line)

	var tween := line.create_tween()
	tween.parallel().tween_property(line, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(line, "width", 2.0, duration)
	tween.tween_callback(line.queue_free)


static func spawn_ring_effect(owner: Node, center: Vector2, radius: float, color: Color, width: float, duration: float, points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var ring := Line2D.new()
	_mark_temporary_effect(ring)
	ring.global_position = center
	ring.z_index = 11
	ring.width = width
	ring.default_color = color
	ring.closed = true
	ring.points = points
	current_scene.add_child(ring)

	var tween := ring.create_tween()
	tween.parallel().tween_property(ring, "width", 2.0, duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)


static func spawn_slash_effect(owner: Node, center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var effect := Node2D.new()
	_mark_temporary_effect(effect)
	effect.global_position = center
	effect.rotation = direction.angle()
	effect.z_index = 12

	var polygon := Polygon2D.new()
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		Vector2(-18.0, -width * 0.7),
		Vector2(length * 0.2, -width),
		Vector2(length, -width * 0.12),
		Vector2(length * 0.72, width * 0.48),
		Vector2(-12.0, width * 0.7)
	])
	effect.add_child(polygon)
	current_scene.add_child(effect)

	effect.scale = Vector2(0.32, 0.74)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2(1.0, 1.0), duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)


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

	var effect := Node2D.new()
	_mark_temporary_effect(effect)
	effect.global_position = start_position
	effect.rotation = direction.angle()
	effect.z_index = 10

	var polygon := Polygon2D.new()
	polygon.color = color
	polygon.polygon = PackedVector2Array([
		Vector2(0.0, -hit_width),
		Vector2(length, -hit_width),
		Vector2(length, hit_width),
		Vector2(0.0, hit_width)
	])
	effect.add_child(polygon)
	current_scene.add_child(effect)

	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.parallel().tween_property(effect, "scale:y", 0.65, duration)
	tween.tween_callback(effect.queue_free)


static func spawn_crescent_wave_effect(owner: Node, center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_band_points: PackedVector2Array, edge_points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var effect := Node2D.new()
	_mark_temporary_effect(effect)
	effect.global_position = center
	effect.rotation = direction.angle()
	effect.z_index = 13

	var polygon := Polygon2D.new()
	polygon.color = Color(color.r, color.g, color.b, min(0.05, color.a * 0.08))
	polygon.polygon = arc_band_points
	effect.add_child(polygon)

	var edge := Line2D.new()
	edge.width = 4.0
	edge.default_color = Color(0.9, 0.98, 1.0, min(0.1, color.a * 0.16))
	edge.points = edge_points
	effect.add_child(edge)
	current_scene.add_child(effect)

	effect.scale = Vector2(0.42, 0.42)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)


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

	var effect := Node2D.new()
	_mark_temporary_effect(effect)
	effect.global_position = start_position
	effect.rotation = direction.angle()
	effect.z_index = 13

	var shaft := Polygon2D.new()
	shaft.color = color
	shaft.polygon = PackedVector2Array([
		Vector2(0.0, -width * 0.22),
		Vector2(length * 0.8, -width * 0.16),
		Vector2(length * 0.8, width * 0.16),
		Vector2(0.0, width * 0.22)
	])
	effect.add_child(shaft)

	var tip := Polygon2D.new()
	tip.color = Color(1.0, 0.92, 0.72, min(1.0, color.a + 0.08))
	tip.polygon = PackedVector2Array([
		Vector2(length * 0.72, -width * 0.46),
		Vector2(length, 0.0),
		Vector2(length * 0.72, width * 0.46)
	])
	effect.add_child(tip)
	current_scene.add_child(effect)

	effect.scale = Vector2(0.3, 0.8)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)
