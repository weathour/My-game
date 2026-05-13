extends RefCounted

const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

const ACTIVE_BOMBARD_META_KEY := "__enemy_turret_bombards"
const BOMBARD_FRAME_META_KEY := "__enemy_turret_bombard_frame"

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

	var warning := Line2D.new()
	warning.global_position = impact_center
	warning.width = 4.0
	warning.default_color = Color(1.0, 0.28, 0.18, 0.86)
	warning.closed = true
	warning.points = ENEMY_GEOMETRY.build_circle_points(enemy.turret_bombard_radius)
	warning.z_index = 15
	current_scene.add_child(warning)

	var warning_fill := Polygon2D.new()
	warning_fill.global_position = impact_center
	warning_fill.color = Color(1.0, 0.22, 0.14, 0.14)
	warning_fill.polygon = warning.points
	warning_fill.z_index = 14
	current_scene.add_child(warning_fill)

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
	if warning_node != null and is_instance_valid(warning_node) and warning_node is Node:
		(warning_node as Node).queue_free()
	var fill_node: Variant = data.get("fill", null)
	if fill_node != null and is_instance_valid(fill_node) and fill_node is Node:
		(fill_node as Node).queue_free()
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

static func _get_enemy_current_scene(enemy) -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null
	if enemy is Node and not (enemy as Node).is_inside_tree():
		return null
	var tree: SceneTree = enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene
