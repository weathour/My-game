extends RefCounted

const MAP_BOUNDARY_VIEW := preload("res://scripts/map/map_boundary_view.gd")
const BATTLE_MAP_SCENE := preload("res://assets/tile/map.tscn")
const EDITOR_ONLY_MAP_NODES := {
	"BorderGuide_3200x1800": true
}
const TILE_MAP_LAYER_NAMES := {
	"GroundLayer": true,
	"RoadLayer": true,
	"WaterLayer": true,
	"DecorLayer": true,
	"ground": true,
	"stone": true
}
const MAP_BOUNDS_PADDING := 0.0

# Handoff note:
# Map-scale presentation lives here. Keep gameplay rules separate:
# - player movement clamping is owned by player/player_map_bounds_flow.gd
# - HUD minimap drawing is owned by scripts/hud.gd
# - this flow only creates/updates map boundary and minimap presentation.

static func setup_map_features(main: Node) -> void:
	_setup_boundary_view(main)
	if main.hud != null and main.hud.has_method("configure_minimap"):
		main.hud.configure_minimap(main.map_bounds)

static func update_minimap(main: Node) -> void:
	if main.hud == null or not main.hud.has_method("update_minimap"):
		return
	main.hud.update_minimap(_build_minimap_payload(main))

static func _setup_boundary_view(main: Node) -> void:
	if main.map_boundary_node != null and is_instance_valid(main.map_boundary_node):
		if main.map_boundary_node.has_method("configure"):
			main.map_boundary_node.configure(main.map_bounds)
		_apply_camera_limits(main)
		return
	var boundary := _create_battle_map_view()
	boundary.name = "MapBoundary"
	boundary.z_index = -20
	main.add_child(boundary)
	main.map_boundary_node = boundary
	_apply_tile_map_bounds_to_main(main, boundary)
	if boundary.has_method("configure"):
		boundary.configure(main.map_bounds)
	_apply_camera_limits(main)

static func _create_battle_map_view() -> Node2D:
	var map_scene := BATTLE_MAP_SCENE.instantiate()
	if map_scene is Node2D:
		_prepare_battle_map_scene(map_scene)
		return map_scene
	return MAP_BOUNDARY_VIEW.new()

static func _prepare_battle_map_scene(map_scene: Node) -> void:
	for child in map_scene.get_children():
		if child.name in EDITOR_ONLY_MAP_NODES and child is CanvasItem:
			(child as CanvasItem).visible = false
		elif child.name == "ReferenceImage" and child is CanvasItem:
			var reference := child as CanvasItem
			reference.visible = false

static func _apply_tile_map_bounds_to_main(main: Node, map_scene: Node2D) -> void:
	var tile_bounds := _calculate_tile_map_bounds(map_scene)
	if tile_bounds.size.x <= 0.0 or tile_bounds.size.y <= 0.0:
		return
	main.map_bounds = tile_bounds.grow(MAP_BOUNDS_PADDING)

static func _calculate_tile_map_bounds(map_scene: Node2D) -> Rect2:
	var merged := Rect2()
	var has_bounds := false
	for child in map_scene.get_children():
		if not (child is TileMapLayer) or not (child.name in TILE_MAP_LAYER_NAMES):
			continue
		var layer_bounds := _calculate_layer_bounds(child as TileMapLayer)
		if layer_bounds.size.x <= 0.0 or layer_bounds.size.y <= 0.0:
			continue
		if has_bounds:
			merged = merged.merge(layer_bounds)
		else:
			merged = layer_bounds
			has_bounds = true
	return merged if has_bounds else Rect2()

static func _calculate_layer_bounds(layer: TileMapLayer) -> Rect2:
	var used_rect := layer.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return Rect2()
	var tile_size := Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(32.0, 32.0)
	var top_left := layer.to_global(layer.map_to_local(used_rect.position) - tile_size * 0.5)
	var bottom_right_cell := used_rect.position + used_rect.size - Vector2i.ONE
	var bottom_right := layer.to_global(layer.map_to_local(bottom_right_cell) + tile_size * 0.5)
	return Rect2(top_left, bottom_right - top_left).abs()

static func _apply_camera_limits(main: Node) -> void:
	var bounds: Rect2 = main.map_bounds
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var camera := _get_player_camera(main)
	if camera == null:
		return
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.position.x + bounds.size.x)
	camera.limit_bottom = ceili(bounds.position.y + bounds.size.y)

static func _get_player_camera(main: Node) -> Camera2D:
	var player = main.get("player")
	if player == null or not is_instance_valid(player):
		return null
	if player.get("camera_node") is Camera2D:
		return player.get("camera_node") as Camera2D
	if player is Node:
		return (player as Node).get_node_or_null("Camera2D") as Camera2D
	return null

static func _build_minimap_payload(main: Node) -> Dictionary:
	return {
		"bounds": main.map_bounds,
		"player_position": _get_node_position(main.player),
		"enemies": _collect_group_points(main, "enemies"),
		"boss_position": _get_node_position(main.boss_enemy) if main.boss_enemy != null and is_instance_valid(main.boss_enemy) else null,
		"gems": _collect_group_points(main, "exp_gems", 18),
		"hearts": _collect_group_points(main, "heart_pickups", 8)
	}

static func _collect_group_points(main: Node, group_name: String, limit: int = 48) -> Array:
	var points: Array = []
	for node in _get_runtime_group_nodes(main, group_name):
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var entry := {
			"position": (node as Node2D).global_position
		}
		if node.has_method("get_minimap_kind"):
			entry["kind"] = str(node.get_minimap_kind())
		elif node.get("enemy_kind") != null:
			entry["kind"] = str(node.get("enemy_kind"))
		points.append(entry)
		if points.size() >= limit:
			break
	return points

static func _get_runtime_group_nodes(main: Node, group_name: String) -> Array:
	if main == null:
		return []
	if group_name == "enemies" and main.has_method("get_runtime_enemies"):
		return main.get_runtime_enemies()
	if (group_name == "exp_gems" or group_name == "heart_pickups") and main.has_method("get_runtime_pickups"):
		return main.get_runtime_pickups(group_name)
	return main.get_tree().get_nodes_in_group(group_name)

static func _get_node_position(node) -> Variant:
	if node != null and is_instance_valid(node) and node is Node2D:
		return (node as Node2D).global_position
	return null
