extends RefCounted

const ENEMY_VISUAL_DATA := preload("res://scripts/enemies/enemy_visual_data.gd")
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

const PROFILE_VISUAL_NAME := "ProfileVisual"
const PROFILE_VISUAL_SOURCE_META := "profile_visual_source_path"

static func apply_visuals(enemy, color_override = null) -> void:
	var polygon := enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		return

	enemy.display_color = ENEMY_VISUAL_DATA.get_display_color(enemy.enemy_kind, enemy.archetype_id, color_override)

	if enemy.profile_visual_scene != null:
		polygon.visible = false
		_clear_all_visuals_except(enemy, PROFILE_VISUAL_NAME)
		_ensure_profile_visual(enemy)
	elif enemy.enemy_kind == "boss":
		polygon.visible = false
		_clear_all_visuals_except(enemy, "")
		enemy._ensure_boss_visual()
	else:
		_clear_all_visuals_except(enemy, "")
		polygon.visible = true
		polygon.color = enemy.display_color
		polygon.polygon = ENEMY_VISUAL_DATA.get_shape_points(enemy.behavior_id)
		polygon.rotation = 0.0

	if enemy.enemy_kind != "normal" or enemy.secondary_behavior_id != "" or enemy._is_dasher:
		enemy._ensure_status_visuals()

	if enemy.trait_ring != null:
		enemy.trait_ring.visible = (enemy.enemy_kind != "normal" or enemy.secondary_behavior_id != "") and enemy.enemy_kind != "boss" and not _should_hide_trait_ring(enemy)
		enemy.trait_ring.points = ENEMY_GEOMETRY.build_circle_points(18.0 + enemy.scale.x * 4.0)
		if enemy.enemy_kind == "boss":
			enemy.trait_ring.default_color = Color(1.0, 0.54, 0.4, 0.72)
			enemy.trait_ring.width = 5.0
		elif enemy.enemy_kind == "small_boss":
			enemy.trait_ring.default_color = Color(enemy.display_color.r, enemy.display_color.g, enemy.display_color.b, 0.78)
			enemy.trait_ring.width = 4.0
		elif enemy.enemy_kind == "elite":
			enemy.trait_ring.default_color = ENEMY_VISUAL_DATA.get_trait_ring_color(enemy.secondary_behavior_id)
			enemy.trait_ring.width = 4.0
		else:
			enemy.trait_ring.default_color = Color(enemy.display_color.r, enemy.display_color.g, enemy.display_color.b, 0.46)
			enemy.trait_ring.width = 3.0

	if enemy.dash_warning_ring != null:
		enemy.dash_warning_ring.points = ENEMY_GEOMETRY.build_circle_points(24.0 + enemy.scale.x * 10.0)

static func update_motion_visual(enemy) -> void:
	var visual: Node = enemy.cached_motion_visual
	if not _is_valid_motion_visual(enemy, visual):
		_clear_motion_visual_cache(enemy, visual)
		return
	var is_moving: bool = enemy.velocity.length_squared() > 1.0
	var facing_sign: int = _get_velocity_facing_sign(enemy.velocity.x, enemy.cached_motion_visual_facing_sign)
	if is_moving == enemy.cached_motion_visual_moving and facing_sign == enemy.cached_motion_visual_facing_sign:
		return
	enemy.cached_motion_visual_moving = is_moving
	enemy.cached_motion_visual_facing_sign = facing_sign
	visual.set_moving(is_moving, enemy.velocity)

static func _should_hide_trait_ring(enemy) -> bool:
	return enemy.enemy_kind == "small_boss" and enemy.archetype_id == "smallboss_glutton"

static func _ensure_profile_visual(enemy) -> void:
	var existing_visual: Node = enemy.get_node_or_null(PROFILE_VISUAL_NAME)
	if existing_visual != null:
		if _is_profile_visual_for_scene(enemy, existing_visual):
			_set_motion_visual_cache(enemy, existing_visual)
			if existing_visual.has_method("set_moving"):
				existing_visual.set_moving(false)
			return
		_clear_motion_visual_cache(enemy, existing_visual)
		enemy.remove_child(existing_visual)
		existing_visual.queue_free()
	if enemy.profile_visual_scene == null:
		return
	var visual := enemy.profile_visual_scene.instantiate() as Node2D
	if visual == null:
		return
	visual.name = PROFILE_VISUAL_NAME
	visual.set_meta(PROFILE_VISUAL_SOURCE_META, _get_profile_visual_source_path(enemy))
	enemy.add_child(visual)
	visual.position = Vector2.ZERO
	_set_motion_visual_cache(enemy, visual)
	if visual.has_method("set_moving"):
		visual.set_moving(false)

static func _is_profile_visual_for_scene(enemy, visual: Node) -> bool:
	if visual == null:
		return false
	return str(visual.get_meta(PROFILE_VISUAL_SOURCE_META, "")) == _get_profile_visual_source_path(enemy)

static func _get_profile_visual_source_path(enemy) -> String:
	if enemy == null or enemy.profile_visual_scene == null:
		return ""
	return str(enemy.profile_visual_scene.resource_path)

static func _set_motion_visual_cache(enemy, visual: Node) -> void:
	enemy.cached_motion_visual = visual
	enemy.cached_motion_visual_moving = false
	enemy.cached_motion_visual_facing_sign = 0

static func _clear_motion_visual_cache(enemy, visual: Node) -> void:
	if visual == null or enemy.cached_motion_visual == visual:
		enemy.cached_motion_visual = null
		enemy.cached_motion_visual_moving = false
	enemy.cached_motion_visual_facing_sign = 0

static func _is_valid_motion_visual(enemy, visual: Node) -> bool:
	if visual == null or not is_instance_valid(visual):
		return false
	if visual.is_queued_for_deletion():
		return false
	if not visual.is_inside_tree():
		return false
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	if not enemy.is_ancestor_of(visual):
		return false
	return visual.has_method("set_moving")

static func _get_velocity_facing_sign(velocity_x: float, fallback: int) -> int:
	if abs(velocity_x) <= 0.01:
		return fallback
	return 1 if velocity_x > 0.0 else -1

static func _clear_all_visuals_except(enemy, keep_name: String) -> void:
	for child in enemy.get_children():
		if not (child is Node):
			continue
		var node: Node = child as Node
		if node.name == keep_name:
			continue
		if not _is_enemy_visual_node(node):
			continue
		_clear_motion_visual_cache(enemy, node)
		_hide_and_free(node)

static func _is_enemy_visual_node(node: Node) -> bool:
	return node.name == PROFILE_VISUAL_NAME or String(node.name).ends_with("Visual")

static func _hide_and_free(visual: Node) -> void:
	if visual is CanvasItem:
		(visual as CanvasItem).hide()
	visual.queue_free()
