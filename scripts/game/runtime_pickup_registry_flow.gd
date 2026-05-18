extends RefCounted


static func ensure_runtime_pickup_registry(main: Node, group_name: String) -> Dictionary:
	if not main.runtime_pickup_nodes.has(group_name):
		main.runtime_pickup_nodes[group_name] = {}
		main.runtime_pickup_cache[group_name] = []
		main.runtime_pickup_cache_dirty[group_name] = false
		main.runtime_pickup_grid_cache[group_name] = {}
		main.runtime_pickup_grid_cache_dirty[group_name] = true
		main.runtime_pickup_grid_cache_frame[group_name] = -1
	return main.runtime_pickup_nodes[group_name]


static func mark_runtime_pickup_cache_dirty(main: Node, group_name: String) -> void:
	main.runtime_pickup_cache_dirty[group_name] = true
	main.runtime_pickup_grid_cache_dirty[group_name] = true


static func register_runtime_pickup(main: Node, group_name: String, node: Node) -> void:
	if node == null:
		return
	var nodes: Dictionary = ensure_runtime_pickup_registry(main, group_name)
	var instance_id: int = node.get_instance_id()
	if not nodes.has(instance_id):
		nodes[instance_id] = node
		mark_runtime_pickup_cache_dirty(main, group_name)


static func unregister_runtime_pickup(main: Node, group_name: String, node: Node) -> void:
	if node == null or not main.runtime_pickup_nodes.has(group_name):
		return
	var nodes: Dictionary = main.runtime_pickup_nodes[group_name]
	var instance_id: int = node.get_instance_id()
	if nodes.erase(instance_id):
		mark_runtime_pickup_cache_dirty(main, group_name)


static func get_runtime_pickups(main: Node, group_name: String) -> Array:
	var nodes: Dictionary = ensure_runtime_pickup_registry(main, group_name)
	if bool(main.runtime_pickup_cache_dirty.get(group_name, true)) or not main.runtime_pickup_cache.has(group_name):
		main.runtime_pickup_cache[group_name] = main._rebuild_runtime_registry_cache(nodes)
		main.runtime_pickup_cache_dirty[group_name] = false
	return main.runtime_pickup_cache[group_name]


static func get_runtime_pickups_in_radius(main: Node, group_name: String, center: Vector2, radius: float) -> Array:
	var grid: Dictionary = get_runtime_pickup_grid(main, group_name)
	if grid.is_empty():
		return []
	return collect_runtime_pickups_from_grid(main, grid, center, radius)


static func collect_runtime_pickups_from_grid(main: Node, grid: Dictionary, center: Vector2, radius: float) -> Array:
	var safe_radius: float = max(1.0, radius)
	var min_cell: Vector2i = pickup_grid_cell(main, center - Vector2.ONE * safe_radius)
	var max_cell: Vector2i = pickup_grid_cell(main, center + Vector2.ONE * safe_radius)
	var candidates: Array = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell: Vector2i = Vector2i(x, y)
			if grid.has(cell):
				candidates.append_array(grid[cell] as Array)
	return candidates


static func get_runtime_pickup_grid(main: Node, group_name: String) -> Dictionary:
	ensure_runtime_pickup_registry(main, group_name)
	var current_frame: int = Engine.get_physics_frames()
	if not bool(main.runtime_pickup_grid_cache_dirty.get(group_name, true)) \
			and int(main.runtime_pickup_grid_cache_frame.get(group_name, -1)) == current_frame \
			and main.runtime_pickup_grid_cache.has(group_name):
		return main.runtime_pickup_grid_cache[group_name]
	var grid: Dictionary = {}
	for pickup in get_runtime_pickups(main, group_name):
		if not main._is_runtime_node_valid(pickup) or pickup is not Node2D:
			continue
		var cell: Vector2i = pickup_grid_cell(main, (pickup as Node2D).global_position)
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(pickup)
	main.runtime_pickup_grid_cache[group_name] = grid
	main.runtime_pickup_grid_cache_dirty[group_name] = false
	main.runtime_pickup_grid_cache_frame[group_name] = current_frame
	return grid


static func pickup_grid_cell(main: Node, position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / main.PICKUP_GRID_CELL_SIZE), floori(position.y / main.PICKUP_GRID_CELL_SIZE))


static func release_runtime_pickup(main: Node, group_name: String, node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	unregister_runtime_pickup(main, group_name, node)
	if not main.runtime_pickup_pool_nodes.has(group_name):
		main.runtime_pickup_pool_nodes[group_name] = {}
	var pool: Dictionary = main.runtime_pickup_pool_nodes[group_name]
	if pool.size() >= main.runtime_pickup_pool_limit:
		node.queue_free()
		return
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.hide()
	node.set_process(false)
	node.set_physics_process(false)
	pool[node.get_instance_id()] = node


static func take_runtime_pickup_from_pool(main: Node, group_name: String) -> Node:
	if not main.runtime_pickup_pool_nodes.has(group_name):
		return null
	var pool: Dictionary = main.runtime_pickup_pool_nodes[group_name]
	for instance_id in pool.keys():
		var node = pool[instance_id]
		pool.erase(instance_id)
		if main._is_runtime_node_valid(node):
			return node
	return null
