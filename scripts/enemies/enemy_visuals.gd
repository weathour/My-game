extends RefCounted

const ENEMY_VISUAL_DATA := preload("res://scripts/enemies/enemy_visual_data.gd")
const ENEMY_GEOMETRY := preload("res://scripts/enemies/enemy_geometry.gd")

static func apply_visuals(enemy, color_override = null) -> void:
	var polygon := enemy.get_node_or_null("Polygon2D") as Polygon2D
	if polygon == null:
		return

	enemy.display_color = ENEMY_VISUAL_DATA.get_display_color(enemy.enemy_kind, enemy.archetype_id, color_override)

	if enemy.enemy_kind == "boss":
		polygon.visible = false
		enemy._ensure_boss_visual()
	else:
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
