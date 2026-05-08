extends RefCounted

const ENEMY_VISUAL_DATA := preload("res://scripts/enemies/enemy_visual_data.gd")
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")
const MUSHROOM_VISUAL_SCENE := preload("res://assets/enemies/Mushroom/mushroom.tscn")
const SLIME_VISUAL_SCENE := preload("res://assets/enemies/slime/Slime.tscn")
const FLYING_EYE_VISUAL_SCENE := preload("res://assets/enemies/flyingeye/flyingeye.tscn")

static func apply_visuals(enemy, color_override = null) -> void:
	var polygon := enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		return

	enemy.display_color = ENEMY_VISUAL_DATA.get_display_color(enemy.enemy_kind, enemy.archetype_id, color_override)

	if _should_use_mushroom_visual(enemy):
		polygon.visible = false
		_ensure_mushroom_visual(enemy)
	elif _should_use_slime_visual(enemy):
		polygon.visible = false
		_ensure_slime_visual(enemy)
	elif _should_use_flying_eye_visual(enemy):
		polygon.visible = false
		_ensure_flying_eye_visual(enemy)
	elif enemy.enemy_kind == "boss":
		polygon.visible = false
		_clear_mushroom_visual(enemy)
		_clear_slime_visual(enemy)
		_clear_flying_eye_visual(enemy)
		enemy._ensure_boss_visual()
	else:
		_clear_mushroom_visual(enemy)
		_clear_slime_visual(enemy)
		_clear_flying_eye_visual(enemy)
		polygon.visible = true
		polygon.color = enemy.display_color
		polygon.polygon = ENEMY_VISUAL_DATA.get_shape_points(enemy.behavior_id)
		polygon.rotation = 0.0

	if enemy.enemy_kind != "normal" or enemy.secondary_behavior_id != "" or enemy._is_dasher:
		enemy._ensure_status_visuals()

	if enemy.trait_ring != null:
		enemy.trait_ring.visible = (enemy.enemy_kind != "normal" or enemy.secondary_behavior_id != "") and enemy.enemy_kind != "boss"
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
	var visual: Node = enemy.get_node_or_null("MushroomVisual")
	if visual == null or not visual.has_method("set_moving"):
		visual = enemy.get_node_or_null("SlimeVisual")
	if visual == null or not visual.has_method("set_moving"):
		visual = enemy.get_node_or_null("FlyingEyeVisual")
	if visual == null or not visual.has_method("set_moving"):
		return
	visual.set_moving(enemy.velocity.length_squared() > 1.0, enemy.velocity)

static func _should_use_mushroom_visual(enemy) -> bool:
	return enemy.enemy_kind == "normal" and enemy.archetype_id == "chaser" and enemy.behavior_id == "chaser"

static func _should_use_slime_visual(enemy) -> bool:
	return enemy.enemy_kind == "normal" and enemy.archetype_id == "runner" and enemy.behavior_id == "chaser"

static func _should_use_flying_eye_visual(enemy) -> bool:
	return enemy.enemy_kind == "normal" and enemy.archetype_id == "swarm" and enemy.behavior_id == "swarm"

static func _ensure_mushroom_visual(enemy) -> void:
	if enemy.get_node_or_null("MushroomVisual") != null:
		return
	var visual := MUSHROOM_VISUAL_SCENE.instantiate() as Node2D
	if visual == null:
		return
	visual.name = "MushroomVisual"
	enemy.add_child(visual)
	visual.position = Vector2.ZERO
	if visual.has_method("set_moving"):
		visual.set_moving(false)

static func _ensure_slime_visual(enemy) -> void:
	if enemy.get_node_or_null("SlimeVisual") != null:
		return
	var visual := SLIME_VISUAL_SCENE.instantiate() as Node2D
	if visual == null:
		return
	visual.name = "SlimeVisual"
	enemy.add_child(visual)
	visual.position = Vector2.ZERO
	if visual.has_method("set_moving"):
		visual.set_moving(false)

static func _ensure_flying_eye_visual(enemy) -> void:
	if enemy.get_node_or_null("FlyingEyeVisual") != null:
		return
	var visual := FLYING_EYE_VISUAL_SCENE.instantiate() as Node2D
	if visual == null:
		return
	visual.name = "FlyingEyeVisual"
	enemy.add_child(visual)
	visual.position = Vector2.ZERO
	if visual.has_method("set_moving"):
		visual.set_moving(false)

static func _clear_mushroom_visual(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("MushroomVisual")
	if visual == null:
		return
	visual.queue_free()

static func _clear_slime_visual(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("SlimeVisual")
	if visual == null:
		return
	visual.queue_free()

static func _clear_flying_eye_visual(enemy) -> void:
	var visual: Node = enemy.get_node_or_null("FlyingEyeVisual")
	if visual == null:
		return
	visual.queue_free()
