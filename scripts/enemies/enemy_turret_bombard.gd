extends RefCounted

const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

const ACTIVE_BOMBARD_META_KEY := "__enemy_turret_bombards"
const BOMBARD_FRAME_META_KEY := "__enemy_turret_bombard_frame"
const WARNING_LINE_POOL_LIMIT := 48
const WARNING_FILL_POOL_LIMIT := 48

static var warning_line_pool: Array[Line2D] = []
static var warning_fill_pool: Array[Polygon2D] = []

static func start_bombard(enemy) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		return
	var current_scene: Node = _get_enemy_current_scene(enemy)
	if current_scene == null:
		return
	var aim_center: Vector2 = enemy.target.global_position
	if enemy.target.has_method("get_hurtbox_center"):
		aim_center = enemy.target.get_hurtbox_center()
	var impact_center: Vector2 = aim_center + Vector2(randf_range(-42.0, 42.0), randf_range(-42.0, 42.0))
	var warning_points: PackedVector2Array = ENEMY_GEOMETRY.build_circle_points(enemy.turret_bombard_radius)

	var warning := _acquire_warning_line(current_scene)
	warning.global_position = impact_center
	warning.width = 4.0
	warning.default_color = Color(1.0, 0.28, 0.18, 0.86)
	warning.closed = true
	warning.points = warning_points
	warning.z_index = 15
	warning.scale = Vector2.ONE
	warning.modulate = Color.WHITE

	var warning_fill := _acquire_warning_fill(current_scene)
	warning_fill.global_position = impact_center
	warning_fill.color = Color(1.0, 0.22, 0.14, 0.14)
	warning_fill.polygon = warning_points
	warning_fill.z_index = 14
	warning_fill.scale = Vector2.ONE
	warning_fill.modulate = Color.WHITE

	_track_bombard(current_scene, enemy, warning, warning_fill, impact_center, 0.7)

static func update_bombards(scene: Node, delta: float) -> void:
	if scene == null or delta <= 0.0:
		return
	var current_frame: int = Engine.get_process_frames()
	if int(scene.get_meta(BOMBARD_FRAME_META_KEY, -1)) == current_frame:
		return
	scene.set_meta(BOMBARD_FRAME_META_KEY, current_frame)
	var active_bombards: Array = scene.get_meta(ACTIVE_BOMBARD_META_KEY, [])
	if active_bombards.is_empty():
		return
	for index in range(active_bombards.size() - 1, -1, -1):
		var data: Dictionary = active_bombards[index]
		var elapsed: float = float(data.get("elapsed", 0.0)) + delta
		var duration: float = max(0.001, float(data.get("duration", 0.7)))
		var progress: float = clamp(elapsed / duration, 0.0, 1.0)
		var scale: Vector2 = Vector2.ONE.lerp(Vector2(1.08, 1.08), progress)
		var warning_node: Variant = data.get("warning", null)
		if warning_node != null and is_instance_valid(warning_node) and warning_node is Node2D:
			(warning_node as Node2D).scale = scale
		var fill_node: Variant = data.get("fill", null)
		if fill_node != null and is_instance_valid(fill_node) and fill_node is Node2D:
			(fill_node as Node2D).scale = scale
		if elapsed >= duration:
			active_bombards.remove_at(index)
			_finish_bombard(data)
			continue
		data["elapsed"] = elapsed
		active_bombards[index] = data
	scene.set_meta(ACTIVE_BOMBARD_META_KEY, active_bombards)

static func _track_bombard(scene: Node, enemy, warning: Line2D, warning_fill: Polygon2D, impact_center: Vector2, duration: float) -> void:
	var active_bombards: Array = scene.get_meta(ACTIVE_BOMBARD_META_KEY, [])
	active_bombards.append({
		"enemy_ref": weakref(enemy),
		"warning": warning,
		"fill": warning_fill,
		"impact_center": impact_center,
		"elapsed": 0.0,
		"duration": max(0.001, duration)
	})
	scene.set_meta(ACTIVE_BOMBARD_META_KEY, active_bombards)

static func _finish_bombard(data: Dictionary) -> void:
	var warning_node: Variant = data.get("warning", null)
	if warning_node != null and is_instance_valid(warning_node) and warning_node is Line2D:
		_release_warning_line(warning_node as Line2D)
	var fill_node: Variant = data.get("fill", null)
	if fill_node != null and is_instance_valid(fill_node) and fill_node is Polygon2D:
		_release_warning_fill(fill_node as Polygon2D)
	var enemy_ref: WeakRef = data.get("enemy_ref", null) as WeakRef
	var enemy = enemy_ref.get_ref() if enemy_ref != null else null
	if enemy == null or not is_instance_valid(enemy):
		return
	var impact_center: Vector2 = data.get("impact_center", Vector2.ZERO)
	enemy._spawn_status_burst(Color(1.0, 0.42, 0.18, 0.24), 34.0 + enemy.scale.x * 8.0)
	if enemy.target != null and is_instance_valid(enemy.target):
		var target_center: Vector2 = enemy.target.global_position
		var target_radius: float = 0.0
		if enemy.target.has_method("get_hurtbox_center"):
			target_center = enemy.target.get_hurtbox_center()
		if enemy.target.has_method("get_hurtbox_radius"):
			target_radius = float(enemy.target.get_hurtbox_radius())
		if impact_center.distance_to(target_center) <= enemy.turret_bombard_radius + target_radius and enemy.target.has_method("take_damage"):
			enemy.target.take_damage(enemy.projectile_damage * 1.25)
	for index in range(max(6, enemy.turret_bombard_projectiles)):
		var angle: float = TAU * float(index) / float(max(1, enemy.turret_bombard_projectiles))
		var shot_direction: Vector2 = Vector2.RIGHT.rotated(angle)
		enemy._spawn_projectile(
			impact_center + shot_direction * 12.0,
			shot_direction,
			max(280.0, enemy.projectile_speed * 1.05),
			enemy.projectile_damage,
			3.8,
			Color(1.0, 0.4, 0.16, 1.0),
			"straight",
			{"size_scale": 1.1}
		)

static func _acquire_warning_line(current_scene: Node) -> Line2D:
	while not warning_line_pool.is_empty():
		var pooled_line = warning_line_pool.pop_back()
		if not is_instance_valid(pooled_line) or not (pooled_line is Line2D):
			continue
		var line := pooled_line as Line2D
		if line != null and not line.is_queued_for_deletion():
			_prepare_pooled_node(line, current_scene)
			return line
	var line := Line2D.new()
	current_scene.add_child(line)
	return line

static func _release_warning_line(line: Line2D) -> void:
	if line == null or not is_instance_valid(line):
		return
	line.hide()
	line.scale = Vector2.ONE
	line.modulate = Color.WHITE
	if warning_line_pool.size() < WARNING_LINE_POOL_LIMIT and not warning_line_pool.has(line):
		warning_line_pool.append(line)
	else:
		line.queue_free()

static func _acquire_warning_fill(current_scene: Node) -> Polygon2D:
	while not warning_fill_pool.is_empty():
		var pooled_fill = warning_fill_pool.pop_back()
		if not is_instance_valid(pooled_fill) or not (pooled_fill is Polygon2D):
			continue
		var fill := pooled_fill as Polygon2D
		if fill != null and not fill.is_queued_for_deletion():
			_prepare_pooled_node(fill, current_scene)
			return fill
	var fill := Polygon2D.new()
	current_scene.add_child(fill)
	return fill

static func _release_warning_fill(fill: Polygon2D) -> void:
	if fill == null or not is_instance_valid(fill):
		return
	fill.hide()
	fill.scale = Vector2.ONE
	fill.modulate = Color.WHITE
	if warning_fill_pool.size() < WARNING_FILL_POOL_LIMIT and not warning_fill_pool.has(fill):
		warning_fill_pool.append(fill)
	else:
		fill.queue_free()

static func _prepare_pooled_node(node: Node2D, current_scene: Node) -> void:
	var parent := node.get_parent()
	if parent != current_scene:
		if parent != null:
			parent.remove_child(node)
		current_scene.add_child(node)
	node.show()

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene
