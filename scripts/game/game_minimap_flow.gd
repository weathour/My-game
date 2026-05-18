extends RefCounted

const MINIMAP_CURSOR_META_PREFIX := "__minimap_cursor_"


static func update_minimap(main: Node) -> void:
	if main.hud == null or not main.hud.has_method("update_minimap"):
		return
	main.hud.update_minimap(build_minimap_payload(main))


static func build_minimap_payload(main: Node) -> Dictionary:
	return {
		"bounds": main.map_bounds,
		"player_position": get_node_position(main.player),
		"enemies": collect_group_points(main, "enemies"),
		"boss_position": get_node_position(main.boss_enemy) if main.boss_enemy != null and is_instance_valid(main.boss_enemy) else null,
		"gems": collect_group_points(main, "exp_gems", 18),
		"hearts": collect_group_points(main, "heart_pickups", 8)
	}


static func collect_group_points(main: Node, group_name: String, limit: int = 48) -> Array:
	var points: Array = []
	var nodes: Array = get_runtime_group_nodes(main, group_name)
	var node_count: int = nodes.size()
	if node_count <= 0:
		return points
	var cursor: int = get_minimap_cursor(main, group_name, node_count)
	var scanned: int = 0
	while scanned < node_count and points.size() < limit:
		var node: Variant = nodes[(cursor + scanned) % node_count]
		scanned += 1
		if not is_instance_valid(node) or not (node is Node2D):
			continue
		var entry: Dictionary = {
			"position": (node as Node2D).global_position
		}
		if node.has_method("get_minimap_kind"):
			entry["kind"] = str(node.get_minimap_kind())
		elif node.get("enemy_kind") != null:
			entry["kind"] = str(node.get("enemy_kind"))
		points.append(entry)
	set_minimap_cursor(main, group_name, (cursor + max(scanned, limit)) % node_count)
	return points


static func get_minimap_cursor(main: Node, group_name: String, node_count: int) -> int:
	if main == null or node_count <= 0:
		return 0
	var key: String = MINIMAP_CURSOR_META_PREFIX + group_name
	return int(main.get_meta(key, 0)) % node_count if main.has_meta(key) else 0


static func set_minimap_cursor(main: Node, group_name: String, cursor: int) -> void:
	if main == null:
		return
	main.set_meta(MINIMAP_CURSOR_META_PREFIX + group_name, cursor)


static func get_runtime_group_nodes(main: Node, group_name: String) -> Array:
	if main == null:
		return []
	if group_name == "enemies" and main.has_method("get_runtime_enemies"):
		return main.get_runtime_enemies()
	if (group_name == "exp_gems" or group_name == "heart_pickups") and main.has_method("get_runtime_pickups"):
		return main.get_runtime_pickups(group_name)
	return main.get_tree().get_nodes_in_group(group_name)


static func get_node_position(node) -> Variant:
	if node != null and is_instance_valid(node) and node is Node2D:
		return (node as Node2D).global_position
	return null
