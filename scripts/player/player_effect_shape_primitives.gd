extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")
		PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func _can_spawn_temporary_effect(owner: Node) -> bool:
	if owner == null or owner.get_tree() == null:
		return false
	var root := owner.get_tree().current_scene
	if root != null and root.has_method("_can_spawn_runtime_group"):
		return bool(root._can_spawn_runtime_group("temporary_effects", 160))
	return true

static func spawn_vortex_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, outer_points: PackedVector2Array, inner_points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var root := Node2D.new()
	_mark_temporary_effect(root)
	root.global_position = center
	root.z_index = 12
	current_scene.add_child(root)

	var outer_ring := Line2D.new()
	outer_ring.width = 5.0
	outer_ring.default_color = color
	outer_ring.closed = true
	outer_ring.points = outer_points
	root.add_child(outer_ring)

	var inner_ring := Line2D.new()
	inner_ring.width = 3.0
	inner_ring.default_color = Color(0.92, 0.98, 1.0, min(0.96, color.a + 0.18))
	inner_ring.closed = true
	inner_ring.points = inner_points
	root.add_child(inner_ring)

	for arm_index in range(3):
		var arm := Polygon2D.new()
		var angle := TAU * float(arm_index) / 3.0
		arm.rotation = angle
		arm.color = Color(color.r, color.g, color.b, min(0.86, color.a + 0.08))
		arm.polygon = PackedVector2Array([
			Vector2(6.0, -4.0),
			Vector2(radius * 0.7, -8.0),
			Vector2(radius, 0.0),
			Vector2(radius * 0.7, 8.0),
			Vector2(6.0, 4.0)
		])
		root.add_child(arm)

	root.scale = Vector2(0.4, 0.4)
	var tween := root.create_tween()
	tween.parallel().tween_property(root, "rotation", -0.42, duration)
	tween.parallel().tween_property(root, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(root, "modulate:a", 0.0, duration)
	tween.tween_callback(root.queue_free)


static func spawn_target_lock_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, ring_points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var root := Node2D.new()
	_mark_temporary_effect(root)
	root.global_position = center
	root.z_index = 13
	current_scene.add_child(root)

	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = color
	ring.closed = true
	ring.points = ring_points
	root.add_child(ring)

	for side in [-1.0, 1.0]:
		var line := Line2D.new()
		line.width = 3.0
		line.default_color = color
		line.points = PackedVector2Array([
			Vector2(side * (radius + 10.0), 0.0),
			Vector2(side * (radius - 3.0), 0.0)
		])
		root.add_child(line)

		var vline := Line2D.new()
		vline.width = 3.0
		vline.default_color = color
		vline.points = PackedVector2Array([
			Vector2(0.0, side * (radius + 10.0)),
			Vector2(0.0, side * (radius - 3.0))
		])
		root.add_child(vline)

	root.scale = Vector2(1.2, 1.2)
	var tween := root.create_tween()
	tween.parallel().tween_property(root, "scale", Vector2.ONE, duration * 0.5)
	tween.parallel().tween_property(root, "modulate:a", 0.0, duration)
	tween.tween_callback(root.queue_free)
