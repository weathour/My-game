extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const VORTEX_POOL_LIMIT := 24
const TARGET_LOCK_POOL_LIMIT := 24

static var vortex_pool: Array[Node2D] = []
static var target_lock_pool: Array[Node2D] = []
static var active_roots: Array[Dictionary] = []
static var shape_animation_frame: int = -1

static func update_effect_animations(delta: float) -> void:
	if delta <= 0.0:
		return
	var current_frame := Engine.get_process_frames()
	if shape_animation_frame == current_frame:
		return
	shape_animation_frame = current_frame
	for index in range(active_roots.size() - 1, -1, -1):
		var data: Dictionary = active_roots[index]
		var root_node: Variant = data.get("node", null)
		if root_node == null or not is_instance_valid(root_node) or not (root_node is Node2D):
			active_roots.remove_at(index)
			continue
		var root := root_node as Node2D
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.1)))
		var scale_duration: float = max(0.001, float(data.get("scale_duration", duration)))
		var alpha_progress: float = clamp(elapsed / duration, 0.0, 1.0)
		var scale_progress: float = clamp(elapsed / scale_duration, 0.0, 1.0)
		root.rotation = lerpf(float(data.get("start_rotation", 0.0)), float(data.get("target_rotation", 0.0)), alpha_progress)
		root.scale = (data.get("start_scale", Vector2.ONE) as Vector2).lerp(data.get("target_scale", Vector2.ONE) as Vector2, scale_progress)
		root.modulate.a = float(data.get("start_alpha", 1.0)) * (1.0 - alpha_progress)
		if elapsed >= duration:
			active_roots.remove_at(index)
			_release_root_by_kind(data.get("release_kind", &""), root)
			continue
		data["elapsed"] = elapsed
		active_roots[index] = data

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")
		PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func _can_spawn_temporary_effect(owner: Node) -> bool:
	return owner != null and owner.get_tree() != null

static func spawn_vortex_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, outer_points: PackedVector2Array, inner_points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var root := _acquire_vortex_root(current_scene)
	root.global_position = center
	root.rotation = 0.0
	root.modulate = Color.WHITE
	root.z_index = 12

	var outer_ring := root.get_node_or_null("OuterRing") as Line2D
	outer_ring.width = 5.0
	outer_ring.default_color = color
	outer_ring.closed = true
	outer_ring.points = outer_points

	var inner_ring := root.get_node_or_null("InnerRing") as Line2D
	inner_ring.width = 3.0
	inner_ring.default_color = Color(0.92, 0.98, 1.0, min(0.96, color.a + 0.18))
	inner_ring.closed = true
	inner_ring.points = inner_points

	for arm_index in range(3):
		var arm := root.get_node_or_null("Arm%d" % arm_index) as Polygon2D
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

	root.scale = Vector2(0.4, 0.4)
	_track_root_animation(root, duration, root.scale, Vector2.ONE, -0.42, &"vortex", duration * 0.45)


static func spawn_target_lock_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, ring_points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var root := _acquire_target_lock_root(current_scene)
	root.global_position = center
	root.rotation = 0.0
	root.modulate = Color.WHITE
	root.z_index = 13

	var ring := root.get_node_or_null("Ring") as Line2D
	ring.width = 4.0
	ring.default_color = color
	ring.closed = true
	ring.points = ring_points

	for index in range(2):
		var side: float = -1.0 if index == 0 else 1.0
		var line := root.get_node_or_null("HLine%d" % index) as Line2D
		line.width = 3.0
		line.default_color = color
		line.points = PackedVector2Array([
			Vector2(side * (radius + 10.0), 0.0),
			Vector2(side * (radius - 3.0), 0.0)
		])

		var vline := root.get_node_or_null("VLine%d" % index) as Line2D
		vline.width = 3.0
		vline.default_color = color
		vline.points = PackedVector2Array([
			Vector2(0.0, side * (radius + 10.0)),
			Vector2(0.0, side * (radius - 3.0))
		])

	root.scale = Vector2(1.2, 1.2)
	_track_root_animation(root, duration, root.scale, Vector2.ONE, 0.0, &"target_lock", duration * 0.5)

static func _track_root_animation(root: Node2D, duration: float, start_scale: Vector2, target_scale: Vector2, target_rotation: float, release_kind: StringName, scale_duration: float) -> void:
	active_roots.append({
		"node": root,
		"elapsed": 0.0,
		"duration": max(0.001, duration),
		"scale_duration": max(0.001, scale_duration),
		"start_scale": start_scale,
		"target_scale": target_scale,
		"start_rotation": root.rotation,
		"target_rotation": target_rotation,
		"start_alpha": root.modulate.a,
		"release_kind": release_kind
	})

static func _release_root_by_kind(release_kind: StringName, root: Node2D) -> void:
	match release_kind:
		&"vortex":
			_release_vortex_root(root)
		&"target_lock":
			_release_target_lock_root(root)
		_:
			if root != null and is_instance_valid(root):
				root.queue_free()

static func _acquire_vortex_root(current_scene: Node) -> Node2D:
	while not vortex_pool.is_empty():
		var pooled_root: Variant = vortex_pool.pop_back()
		if not is_instance_valid(pooled_root) or not (pooled_root is Node2D):
			continue
		var root := pooled_root as Node2D
		if root.is_queued_for_deletion():
			continue
		_prepare_root(root, current_scene)
		return root
	var root := Node2D.new()
	current_scene.add_child(root)
	_mark_temporary_effect(root)
	var outer_ring := Line2D.new()
	outer_ring.name = "OuterRing"
	root.add_child(outer_ring)
	var inner_ring := Line2D.new()
	inner_ring.name = "InnerRing"
	root.add_child(inner_ring)
	for arm_index in range(3):
		var arm := Polygon2D.new()
		arm.name = "Arm%d" % arm_index
		root.add_child(arm)
	return root

static func _release_vortex_root(root: Node2D) -> void:
	_release_root_to_pool(root, vortex_pool, VORTEX_POOL_LIMIT)

static func _acquire_target_lock_root(current_scene: Node) -> Node2D:
	while not target_lock_pool.is_empty():
		var pooled_root: Variant = target_lock_pool.pop_back()
		if not is_instance_valid(pooled_root) or not (pooled_root is Node2D):
			continue
		var root := pooled_root as Node2D
		if root.is_queued_for_deletion():
			continue
		_prepare_root(root, current_scene)
		return root
	var root := Node2D.new()
	current_scene.add_child(root)
	_mark_temporary_effect(root)
	var ring := Line2D.new()
	ring.name = "Ring"
	root.add_child(ring)
	for index in range(2):
		var line := Line2D.new()
		line.name = "HLine%d" % index
		root.add_child(line)
		var vline := Line2D.new()
		vline.name = "VLine%d" % index
		root.add_child(vline)
	return root

static func _release_target_lock_root(root: Node2D) -> void:
	_release_root_to_pool(root, target_lock_pool, TARGET_LOCK_POOL_LIMIT)

static func _prepare_root(root: Node2D, current_scene: Node) -> void:
	var parent := root.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(root)
		current_scene.add_child(root)
	root.show()
	root.add_to_group("temporary_effects")
	PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func _release_root_to_pool(root: Node2D, pool: Array[Node2D], pool_limit: int) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.hide()
	root.remove_from_group("temporary_effects")
	if pool.size() < pool_limit and not pool.has(root):
		pool.append(root)
	else:
		root.queue_free()
