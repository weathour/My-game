extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
const PLAYER_EFFECT_SHAPE_PRIMITIVES := preload("res://scripts/player/player_effect_shape_primitives.gd")
const PLAYER_EFFECT_LINE_PRIMITIVES := preload("res://scripts/player/player_effect_line_primitives.gd")

static func _mark_temporary_effect(node: Node) -> void:
	if node != null:
		node.add_to_group("temporary_effects")
		PERFORMANCE_COUNTERS.add("temporary_effect_spawns", 1)

static func _can_spawn_temporary_effect(owner: Node) -> bool:
	if owner == null or owner.get_tree() == null:
		return false
	var root := owner.get_tree().current_scene
	if root != null and root.has_method("_can_spawn_runtime_group"):
		var limit: int = PERFORMANCE_GUARD.get_dynamic_limit(root, "temporary_effects", PERFORMANCE_GUARD.DEFAULT_TEMPORARY_EFFECT_LIMIT)
		return bool(root._can_spawn_runtime_group("temporary_effects", limit))
	return true

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

	var label := Label.new()
	_mark_temporary_effect(label)
	label.text = text
	label.modulate = color
	label.z_index = 24
	label.add_theme_font_size_override("font_size", 20)
	current_scene.add_child(label)
	label.global_position = position

	var tween := label.create_tween()
	tween.parallel().tween_property(label, "global_position", position + Vector2(0.0, -24.0), 0.34)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.34)
	tween.tween_callback(label.queue_free)

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

	var shield := Polygon2D.new()
	_mark_temporary_effect(shield)
	shield.global_position = center
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
	current_scene.add_child(shield)

	shield.scale = Vector2(0.36, 0.36)
	var tween := shield.create_tween()
	tween.parallel().tween_property(shield, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(shield, "modulate:a", 0.0, duration)
	tween.tween_callback(shield.queue_free)

static func spawn_burst_effect(owner: Node, center: Vector2, color: Color, duration: float, points: PackedVector2Array) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var polygon := Polygon2D.new()
	_mark_temporary_effect(polygon)
	polygon.global_position = center
	polygon.color = color
	polygon.z_index = 10
	polygon.polygon = points
	current_scene.add_child(polygon)

	polygon.scale = Vector2(0.2, 0.2)
	var tween := polygon.create_tween()
	tween.parallel().tween_property(polygon, "scale", Vector2.ONE, duration)
	tween.parallel().tween_property(polygon, "modulate:a", 0.0, duration)
	tween.tween_callback(polygon.queue_free)

static func spawn_frost_sigils_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float) -> void:
	if not _can_spawn_temporary_effect(owner):
		return
	var current_scene := owner.get_tree().current_scene
	if current_scene == null:
		return

	var effect := Node2D.new()
	_mark_temporary_effect(effect)
	effect.global_position = center
	effect.z_index = 12
	current_scene.add_child(effect)

	var shard_count := 6
	for index in range(shard_count):
		var angle: float = TAU * float(index) / float(shard_count)
		var outer: Vector2 = Vector2.RIGHT.rotated(angle) * radius
		var inner: Vector2 = Vector2.RIGHT.rotated(angle) * max(12.0, radius * 0.48)
		var side: Vector2 = Vector2.RIGHT.rotated(angle + PI * 0.5) * max(4.0, radius * 0.08)
		var shard := Polygon2D.new()
		shard.color = color
		shard.polygon = PackedVector2Array([
			inner - side * 0.7,
			outer,
			inner + side * 0.7
		])
		effect.add_child(shard)

	effect.scale = Vector2(0.45, 0.45)
	var tween := effect.create_tween()
	tween.parallel().tween_property(effect, "rotation", 0.32, duration)
	tween.parallel().tween_property(effect, "scale", Vector2.ONE, duration * 0.5)
	tween.parallel().tween_property(effect, "modulate:a", 0.0, duration)
	tween.tween_callback(effect.queue_free)

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

static func spawn_target_lock_effect(owner: Node, center: Vector2, radius: float, color: Color, duration: float, ring_points: PackedVector2Array) -> void:
	PLAYER_EFFECT_SHAPE_PRIMITIVES.spawn_target_lock_effect(owner, center, radius, color, duration, ring_points)

static func spawn_radial_rays_effect(owner: Node, center: Vector2, radius: float, ray_count: int, color: Color, width: float, duration: float, angle_offset: float = 0.0) -> void:
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

	var safe_ray_count: int = max(3, ray_count)
	var inner_radius: float = max(12.0, radius * 0.18)
	for ray_index in range(safe_ray_count):
		var angle: float = TAU * float(ray_index) / float(safe_ray_count) + angle_offset
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var ray := Line2D.new()
		ray.width = width
		ray.default_color = Color(color.r, color.g, color.b, min(1.0, color.a + (0.14 if ray_index % 2 == 0 else 0.0)))
		ray.points = PackedVector2Array([direction * inner_radius, direction * radius])
		root.add_child(ray)

	root.scale = Vector2(0.35, 0.35)
	var tween := root.create_tween()
	tween.parallel().tween_property(root, "scale", Vector2.ONE, duration * 0.45)
	tween.parallel().tween_property(root, "modulate:a", 0.0, duration)
	tween.tween_callback(root.queue_free)

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
