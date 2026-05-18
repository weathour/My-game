extends RefCounted

const GAME_MINIMAP_FLOW := preload("res://scripts/game/game_minimap_flow.gd")
const GAME_MAP_VIEW_FLOW := preload("res://scripts/game/game_map_view_flow.gd")

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
	GAME_MINIMAP_FLOW.update_minimap(main)

static func _setup_boundary_view(main: Node) -> void:
	GAME_MAP_VIEW_FLOW.setup_boundary_view(main)

static func _create_battle_map_view() -> Node2D:
	return GAME_MAP_VIEW_FLOW.create_battle_map_view()

static func _prepare_battle_map_scene(map_scene: Node) -> void:
	GAME_MAP_VIEW_FLOW.prepare_battle_map_scene(map_scene)

static func _add_grassland_background(map_scene: Node) -> void:
	GAME_MAP_VIEW_FLOW.add_grassland_background(map_scene)

static func _apply_tile_map_bounds_to_main(main: Node, map_scene: Node2D) -> void:
	GAME_MAP_VIEW_FLOW.apply_tile_map_bounds_to_main(main, map_scene)

static func _calculate_tile_map_bounds(map_scene: Node2D) -> Rect2:
	return GAME_MAP_VIEW_FLOW.calculate_tile_map_bounds(map_scene)

static func _calculate_layer_bounds(layer: TileMapLayer) -> Rect2:
	return GAME_MAP_VIEW_FLOW.calculate_layer_bounds(layer)

static func _apply_camera_limits(main: Node) -> void:
	GAME_MAP_VIEW_FLOW.apply_camera_limits(main)

static func _get_player_camera(main: Node) -> Camera2D:
	return GAME_MAP_VIEW_FLOW.get_player_camera(main)

static func _build_minimap_payload(main: Node) -> Dictionary:
	return GAME_MINIMAP_FLOW.build_minimap_payload(main)

static func _collect_group_points(main: Node, group_name: String, limit: int = 48) -> Array:
	return GAME_MINIMAP_FLOW.collect_group_points(main, group_name, limit)

static func _get_minimap_cursor(main: Node, group_name: String, node_count: int) -> int:
	return GAME_MINIMAP_FLOW.get_minimap_cursor(main, group_name, node_count)

static func _set_minimap_cursor(main: Node, group_name: String, cursor: int) -> void:
	GAME_MINIMAP_FLOW.set_minimap_cursor(main, group_name, cursor)

static func _get_runtime_group_nodes(main: Node, group_name: String) -> Array:
	return GAME_MINIMAP_FLOW.get_runtime_group_nodes(main, group_name)

static func _get_node_position(node) -> Variant:
	return GAME_MINIMAP_FLOW.get_node_position(node)
