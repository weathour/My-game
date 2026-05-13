extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PLAYER_EFFECT_SHAPE_PRIMITIVES := preload("res://scripts/player/player_effect_shape_primitives.gd")
const PLAYER_EFFECT_LINE_PRIMITIVES := preload("res://scripts/player/player_effect_line_primitives.gd")
const COMBAT_TAG_POOL_LIMIT := 32
const BURST_POLYGON_POOL_LIMIT := 48
const FROST_SIGIL_POOL_LIMIT := 32
const RADIAL_RAYS_POOL_LIMIT := 24
const GUARD_SHIELD_POOL_LIMIT := 16

static var combat_tag_pool: Array = []
static var burst_polygon_pool: Array = []
static var frost_sigil_pool: Array = []
static var radial_rays_pool: Array = []
static var guard_shield_pool: Array = []
static var active_simple_effects: Array[Dictionary] = []
static var simple_effect_animation_frame: int = -1

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")
		PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func _can_spawn_temporary_effect(owner: Node) -> bool:
	return owner != null and owner.get_tree() != null

static func update_effect_animations(delta: float) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.update_effect_animations(delta)
	PLAYER_EFFECT_SHAPE_PRIMITIVES.update_effect_animations(delta)
	_update_simple_effect_animations(delta)

static func spawn_dash_line_effect(owner: Node, start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_dash_line_effect(owner, start_position, end_position, color, width, duration)

static func spawn_combat_tag(owner: Node, position: Vector2, text: String, color: Color, show_gameplay_text_hints: bool) -> void:
	if not show_gameplay_text_hints:
		return
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var label := _acquire_combat_tag(current_scene)
	label.text = text
	label.modulate = color
	label.z_index = 24
	label.scale = Vector2.ONE
	label.add_theme_font_size_override("font_size", 20)
	label.global_position = position

	_track_text_effect(label, position, position + Vector2(0.0, -24.0), 0.34, &"combat_tag")

static func spawn_ring_effect(owner: Node, center: Vector2, radius: float, color: Color, width: float, duration: float, points: PackedVector2Array) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_ring_effect(owner, center, radius, color, width, duration, points)

static func spawn_slash_effect(owner: Node, center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_slash_effect(owner, center, direction, length, width, color, duration)

static func spawn_line_corridor_effect(owner: Node, start_position: Vector2, end_position: Vector2, hit_width: float, color: Color, duration: float) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_line_corridor_effect(owner, start_position, end_position, hit_width, color, duration)

static func spawn_crescent_wave_effect(owner: Node, center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_band_points: PackedVector2Array, edge_points: PackedVector2Array) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_crescent_wave_effect(owner, center, direction, radius, color, duration, arc_band_points, edge_points)


static func spawn_owner_crescent_wave_effect(owner, center: Vector2, direction: Vector2, radius: float, color: Color, duration: float, arc_degrees: float = 270.0, thickness: float = 26.0) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_owner_crescent_wave_effect(owner, center, direction, radius, color, duration, arc_degrees, thickness)

static func spawn_thrust_effect(owner: Node, start_position: Vector2, end_position: Vector2, color: Color, width: float, duration: float, show_arrow: bool = true) -> void:
	PLAYER_EFFECT_LINE_PRIMITIVES.spawn_thrust_effect(owner, start_position, end_position, color, width, duration, show_arrow)

static func spawn_guard_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, ring_points: PackedVector2Array) -> void:
	spawn_ring_effect(owner, center, radius, Color(color.r, color.g, color.b, min(0.9, color.a + 0.2)), 6.0, duration, ring_points)
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var shield := _acquire_guard_shield(current_scene)
	shield.global_position = center
	shield.rotation = 0.0
	shield.modulate = Color.WHITE
	shield.z_index = 11
	shield.color = color
	shield.polygon = PackedVector2Array([
		Vector2(0.0, -radius * 0.6),
		Vector2(radius * 0.52, -radius * 0.18),
		Vector2(radius * 0.38, radius * 0.5),
		Vector2(0.0, radius * 0.72),
		Vector2(-radius * 0.38, radius * 0.5),
		Vector2(-radius * 0.52, -radius * 0.18)
	])

	shield.scale = Vector2(0.36, 0.36)
	_track_simple_effect(shield, duration, shield.scale, Vector2.ONE, 0.0, &"guard_shield")

static func spawn_burst_effect(owner: Node, center: Vector2, color: Color, duration: float, points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var polygon := _acquire_burst_polygon(current_scene)
	polygon.global_position = center
	polygon.rotation = 0.0
	polygon.color = color
	polygon.modulate = Color.WHITE
	polygon.z_index = 10
	polygon.polygon = points

	polygon.scale = Vector2(0.2, 0.2)
	_track_simple_effect(polygon, duration, polygon.scale, Vector2.ONE, 0.0, &"burst_polygon")

static func _acquire_combat_tag(current_scene: Node) -> Label:
	while not combat_tag_pool.is_empty():
		var pooled = combat_tag_pool.pop_back()
		if not is_instance_valid(pooled):
			continue
		var label := pooled as Label
		if _is_pool_node_valid(label):
			_prepare_pooled_node(label, current_scene)
			return label
	var label := Label.new()
	current_scene.add_child(label)
	_mark_temporary_effect(label)
	return label

static func _release_combat_tag(label: Label) -> void:
	if label == null or not is_instance_valid(label):
		return
	label.hide()
	label.remove_from_group("temporary_effects")
	if combat_tag_pool.size() < COMBAT_TAG_POOL_LIMIT and not combat_tag_pool.has(label):
		combat_tag_pool.append(label)
	else:
		label.queue_free()

static func _acquire_burst_polygon(current_scene: Node) -> Polygon2D:
	while not burst_polygon_pool.is_empty():
		var pooled = burst_polygon_pool.pop_back()
		if not is_instance_valid(pooled):
			continue
		var polygon := pooled as Polygon2D
		if _is_pool_node_valid(polygon):
			_prepare_pooled_node(polygon, current_scene)
			return polygon
	var polygon := Polygon2D.new()
	current_scene.add_child(polygon)
	_mark_temporary_effect(polygon)
	return polygon

static func _release_burst_polygon(polygon: Polygon2D) -> void:
	if polygon == null or not is_instance_valid(polygon):
		return
	polygon.hide()
	polygon.remove_from_group("temporary_effects")
	if burst_polygon_pool.size() < BURST_POLYGON_POOL_LIMIT and not burst_polygon_pool.has(polygon):
		burst_polygon_pool.append(polygon)
	else:
		polygon.queue_free()

static func _prepare_pooled_node(node: Node, current_scene: Node) -> void:
	var parent := node.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(node)
		current_scene.add_child(node)
	node.show()
	node.add_to_group("temporary_effects")
	PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func spawn_frost_sigils_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var effect := _acquire_frost_sigil(current_scene)
	effect.global_position = center
	effect.rotation = 0.0
	effect.modulate = Color.WHITE
	effect.z_index = 12

	var shard_count := 6
	for index in range(shard_count):
		var angle: float = TAU * float(index) / float(shard_count)
		var outer: Vector2 = Vector2.RIGHT.rotated(angle) * radius
		var inner: Vector2 = Vector2.RIGHT.rotated(angle) * max(12.0, radius * 0.48)
		var side: Vector2 = Vector2.RIGHT.rotated(angle + PI * 0.5) * max(4.0, radius * 0.08)
		var shard := effect.get_node_or_null("Shard%d" % index) as Polygon2D
		shard.color = color
		shard.polygon = PackedVector2Array([
			inner - side * 0.7,
			outer,
			inner + side * 0.7
		])

	effect.scale = Vector2(0.45, 0.45)
	_track_simple_effect(effect, duration, effect.scale, Vector2.ONE, 0.32, &"frost_sigil", duration * 0.5)

static func _acquire_frost_sigil(current_scene: Node) -> Node2D:
	while not frost_sigil_pool.is_empty():
		var pooled = frost_sigil_pool.pop_back()
		if not is_instance_valid(pooled):
			continue
		var effect := pooled as Node2D
		if _is_pool_node_valid(effect):
			_prepare_pooled_node(effect, current_scene)
			return effect
	var effect := Node2D.new()
	current_scene.add_child(effect)
	_mark_temporary_effect(effect)
	for index in range(6):
		var shard := Polygon2D.new()
		shard.name = "Shard%d" % index
		effect.add_child(shard)
	return effect

static func _release_frost_sigil(effect: Node2D) -> void:
	if effect == null or not is_instance_valid(effect):
		return
	effect.hide()
	effect.remove_from_group("temporary_effects")
	if frost_sigil_pool.size() < FROST_SIGIL_POOL_LIMIT and not frost_sigil_pool.has(effect):
		frost_sigil_pool.append(effect)
	else:
		effect.queue_free()

static func spawn_vortex_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, outer_points: PackedVector2Array, inner_points: PackedVector2Array) -> void:
	PLAYER_EFFECT_SHAPE_PRIMITIVES.spawn_vortex_effect(owner, center, radius, color, duration, outer_points, inner_points)


static func spawn_owner_vortex_effect(owner, center: Vector2, radius: float, color: Color, duration: float) -> void:
	spawn_vortex_effect(
		owner,
		center,
		radius,
		color,
		duration,
		owner._build_circle_polygon(radius),
		owner._build_circle_polygon(max(8.0, radius * 0.55))
	)

static func spawn_cross_slash_effect(owner: Node, center: Vector2, direction: Vector2, length: float, width: float, color: Color, duration: float) -> void:
	spawn_slash_effect(owner, center, direction.rotated(0.78), length, width, color, duration)
	spawn_slash_effect(owner, center, direction.rotated(-0.78), length, width, color, duration)

static func spawn_owner_guard_effect(owner, center: Vector2, radius: float, color: Color, duration: float) -> void:
	spawn_guard_effect(owner, center, radius, color, duration, owner._build_circle_polygon(radius))

static func spawn_owner_ring_effect(owner, center: Vector2, radius: float, color: Color, width: float, duration: float) -> void:
	spawn_ring_effect(owner, center, radius, color, width, duration, owner._build_circle_polygon(radius))

static func spawn_owner_mage_bombardment_warning_effect(owner, center: Vector2, radius: float) -> void:
	spawn_mage_bombardment_warning_effect(owner, center, radius, owner._build_circle_polygon(radius * 0.82))

static func spawn_owner_mage_bombardment_fall_effect(owner, center: Vector2, radius: float) -> void:
	spawn_mage_bombardment_fall_effect(owner, center, radius, owner._build_circle_polygon(radius * 0.28))

static func spawn_owner_burst_effect(owner, center: Vector2, radius: float, color: Color, duration: float) -> void:
	spawn_burst_effect(owner, center, color, duration, owner._build_circle_polygon(radius))

static func spawn_owner_target_lock_effect(owner, center: Vector2, radius: float, color: Color, duration: float) -> void:
	spawn_target_lock_effect(owner, center, radius, color, duration, owner._build_circle_polygon(radius))

static func spawn_target_lock_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, ring_points: PackedVector2Array) -> void:
	PLAYER_EFFECT_SHAPE_PRIMITIVES.spawn_target_lock_effect(owner, center, radius, color, duration, ring_points)

static func spawn_radial_rays_effect(owner: Node, center: Vector2, radius: float, ray_count: int, color: Color, width: float, duration: float, angle_offset: float = 0.0) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var root := _acquire_radial_rays(current_scene, max(3, ray_count))
	root.global_position = center
	root.rotation = 0.0
	root.modulate = Color.WHITE
	root.z_index = 12

	var safe_ray_count: int = max(3, ray_count)
	var inner_radius: float = max(12.0, radius * 0.18)
	for ray_index in range(safe_ray_count):
		var angle: float = TAU * float(ray_index) / float(safe_ray_count) + angle_offset
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var ray := root.get_node_or_null("Ray%d" % ray_index) as Line2D
		ray.visible = true
		ray.width = width
		ray.default_color = Color(color.r, color.g, color.b, min(1.0, color.a + (0.14 if ray_index % 2 == 0 else 0.0)))
		ray.points = PackedVector2Array([direction * inner_radius, direction * radius])
	for child_index in range(safe_ray_count, root.get_child_count()):
		var extra_ray := root.get_child(child_index) as Line2D
		if extra_ray != null:
			extra_ray.visible = false

	root.scale = Vector2(0.35, 0.35)
	_track_simple_effect(root, duration, root.scale, Vector2.ONE, 0.0, &"radial_rays", duration * 0.45)

static func _track_simple_effect(node: CanvasItem, duration: float, start_scale: Vector2, target_scale: Vector2, target_rotation: float, release_kind: StringName, scale_duration: float = -1.0) -> void:
	active_simple_effects.append({
		"node": node,
		"elapsed": 0.0,
		"duration": max(0.001, duration),
		"scale_duration": max(0.001, duration if scale_duration < 0.0 else scale_duration),
		"start_scale": start_scale,
		"target_scale": target_scale,
		"start_rotation": node.rotation,
		"target_rotation": target_rotation,
		"start_alpha": node.modulate.a,
		"release_kind": release_kind
	})

static func _track_text_effect(label: Label, start_position: Vector2, target_position: Vector2, duration: float, release_kind: StringName) -> void:
	active_simple_effects.append({
		"node": label,
		"elapsed": 0.0,
		"duration": max(0.001, duration),
		"scale_duration": max(0.001, duration),
		"start_scale": label.scale,
		"target_scale": label.scale,
		"start_rotation": label.rotation,
		"target_rotation": label.rotation,
		"start_alpha": label.modulate.a,
		"start_position": start_position,
		"target_position": target_position,
		"release_kind": release_kind
	})

static func _update_simple_effect_animations(delta: float) -> void:
	if delta <= 0.0:
		return
	var current_frame := Engine.get_process_frames()
	if simple_effect_animation_frame == current_frame:
		return
	simple_effect_animation_frame = current_frame
	for index in range(active_simple_effects.size() - 1, -1, -1):
		var data: Dictionary = active_simple_effects[index]
		var effect_node: Variant = data.get("node", null)
		if effect_node == null or not is_instance_valid(effect_node) or not (effect_node is CanvasItem):
			active_simple_effects.remove_at(index)
			continue
		var node := effect_node as CanvasItem
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.1)))
		var scale_duration: float = max(0.001, float(data.get("scale_duration", duration)))
		var alpha_progress: float = clamp(elapsed / duration, 0.0, 1.0)
		var scale_progress: float = clamp(elapsed / scale_duration, 0.0, 1.0)
		node.scale = (data.get("start_scale", Vector2.ONE) as Vector2).lerp(data.get("target_scale", Vector2.ONE) as Vector2, scale_progress)
		node.rotation = lerpf(float(data.get("start_rotation", 0.0)), float(data.get("target_rotation", 0.0)), alpha_progress)
		if data.has("start_position") and data.has("target_position"):
			node.set("global_position", (data.get("start_position", Vector2.ZERO) as Vector2).lerp(data.get("target_position", Vector2.ZERO) as Vector2, alpha_progress))
		node.modulate.a = float(data.get("start_alpha", 1.0)) * (1.0 - alpha_progress)
		if elapsed >= duration:
			active_simple_effects.remove_at(index)
			_release_simple_effect(data.get("release_kind", &""), node)
			continue
		data["elapsed"] = elapsed
		active_simple_effects[index] = data

static func _release_simple_effect(release_kind: StringName, node: CanvasItem) -> void:
	match release_kind:
		&"combat_tag":
			_release_combat_tag(node as Label)
		&"guard_shield":
			_release_guard_shield(node as Polygon2D)
		&"burst_polygon":
			_release_burst_polygon(node as Polygon2D)
		&"frost_sigil":
			_release_frost_sigil(node as Node2D)
		&"radial_rays":
			_release_radial_rays(node as Node2D)
		_:
			if node != null and is_instance_valid(node):
				node.queue_free()

static func _acquire_guard_shield(current_scene: Node) -> Polygon2D:
	while not guard_shield_pool.is_empty():
		var pooled = guard_shield_pool.pop_back()
		if not is_instance_valid(pooled):
			continue
		var shield := pooled as Polygon2D
		if _is_pool_node_valid(shield):
			_prepare_pooled_node(shield, current_scene)
			return shield
	var shield := Polygon2D.new()
	current_scene.add_child(shield)
	_mark_temporary_effect(shield)
	return shield

static func _release_guard_shield(shield: Polygon2D) -> void:
	if shield == null or not is_instance_valid(shield):
		return
	shield.hide()
	shield.remove_from_group("temporary_effects")
	if guard_shield_pool.size() < GUARD_SHIELD_POOL_LIMIT and not guard_shield_pool.has(shield):
		guard_shield_pool.append(shield)
	else:
		shield.queue_free()

static func _acquire_radial_rays(current_scene: Node, ray_count: int) -> Node2D:
	while not radial_rays_pool.is_empty():
		var pooled = radial_rays_pool.pop_back()
		if not is_instance_valid(pooled):
			continue
		var root := pooled as Node2D
		if _is_pool_node_valid(root):
			_prepare_pooled_node(root, current_scene)
			_ensure_radial_ray_children(root, ray_count)
			return root
	var root := Node2D.new()
	current_scene.add_child(root)
	_mark_temporary_effect(root)
	_ensure_radial_ray_children(root, ray_count)
	return root

static func _release_radial_rays(root: Node2D) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.hide()
	root.remove_from_group("temporary_effects")
	if radial_rays_pool.size() < RADIAL_RAYS_POOL_LIMIT and not radial_rays_pool.has(root):
		radial_rays_pool.append(root)
	else:
		root.queue_free()

static func _is_pool_node_valid(node: Node) -> bool:
	return node != null and is_instance_valid(node) and not node.is_queued_for_deletion()

static func _ensure_radial_ray_children(root: Node2D, ray_count: int) -> void:
	while root.get_child_count() < ray_count:
		var ray := Line2D.new()
		ray.name = "Ray%d" % root.get_child_count()
		root.add_child(ray)

static func spawn_mage_bombardment_warning_effect(owner: Node, center: Vector2, radius: float, warning_ring_points: PackedVector2Array) -> void:
	spawn_ring_effect(owner, center, radius * 0.82, Color(0.72, 0.96, 1.0, 0.56), 4.0, 0.22, warning_ring_points)
	spawn_frost_sigils_effect(owner, center, max(18.0, radius * 0.5), Color(0.84, 0.98, 1.0, 0.64), 0.22)
	for offset_ratio in [-0.52, -0.24, 0.0, 0.24, 0.52]:
		var lateral: float = radius * offset_ratio
		var start := center + Vector2(lateral, -108.0 + abs(offset_ratio) * 18.0)
		var end := center + Vector2(lateral * 0.22, -18.0)
		var width: float = 3.0 if abs(offset_ratio) > 0.01 else 5.0
		var color := Color(0.62, 0.9, 1.0, 0.36) if abs(offset_ratio) > 0.01 else Color(0.78, 0.96, 1.0, 0.58)
		spawn_dash_line_effect(owner, start, end, color, width, 0.18)

static func spawn_mage_bombardment_fall_effect(owner: Node, center: Vector2, radius: float, burst_points: PackedVector2Array) -> void:
	for offset_ratio in [-0.58, -0.3, 0.0, 0.3, 0.58]:
		var lateral: float = radius * offset_ratio
		var start := center + Vector2(lateral, -132.0 + abs(offset_ratio) * 18.0)
		var end := center + Vector2(lateral * 0.18, radius * 0.18)
		var width: float = 4.0 if abs(offset_ratio) > 0.01 else 8.0
		var color := Color(0.7, 0.94, 1.0, 0.72) if abs(offset_ratio) > 0.01 else Color(0.92, 0.98, 1.0, 0.96)
		spawn_dash_line_effect(owner, start, end, color, width, 0.12)
	spawn_burst_effect(owner, center, Color(0.88, 0.98, 1.0, 0.24), 0.1, burst_points)
