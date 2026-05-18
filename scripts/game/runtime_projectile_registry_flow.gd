extends RefCounted


static func register_runtime_enemy_projectile(main: Node, projectile: Node, pooled: bool) -> void:
	if projectile == null:
		return
	var instance_id: int = projectile.get_instance_id()
	var active_changed: bool = bool(main.runtime_enemy_projectile_nodes.erase(instance_id))
	var pool_changed: bool = bool(main.runtime_enemy_projectile_pool_nodes.erase(instance_id))
	if pooled:
		if not main.runtime_enemy_projectile_pool_nodes.has(instance_id):
			main.runtime_enemy_projectile_pool_nodes[instance_id] = projectile
			pool_changed = true
	else:
		if not main.runtime_enemy_projectile_nodes.has(instance_id):
			main.runtime_enemy_projectile_nodes[instance_id] = projectile
			active_changed = true
	if active_changed:
		main.runtime_enemy_projectile_cache_dirty = true
	if pool_changed:
		main.runtime_enemy_projectile_pool_cache_dirty = true


static func unregister_runtime_enemy_projectile(main: Node, projectile: Node) -> void:
	if projectile == null:
		return
	var instance_id: int = projectile.get_instance_id()
	if main.runtime_enemy_projectile_nodes.erase(instance_id):
		main.runtime_enemy_projectile_cache_dirty = true
	if main.runtime_enemy_projectile_pool_nodes.erase(instance_id):
		main.runtime_enemy_projectile_pool_cache_dirty = true


static func get_runtime_enemy_projectiles(main: Node) -> Array:
	if main.runtime_enemy_projectile_cache_dirty:
		main.runtime_enemy_projectile_cache = main._rebuild_runtime_registry_cache(main.runtime_enemy_projectile_nodes)
		main.runtime_enemy_projectile_cache_dirty = false
	return main.runtime_enemy_projectile_cache


static func get_runtime_enemy_projectile_pool(main: Node) -> Array:
	if main.runtime_enemy_projectile_pool_cache_dirty:
		main.runtime_enemy_projectile_pool_cache = main._rebuild_runtime_registry_cache(main.runtime_enemy_projectile_pool_nodes)
		main.runtime_enemy_projectile_pool_cache_dirty = false
	return main.runtime_enemy_projectile_pool_cache


static func take_runtime_enemy_projectile_from_pool(main: Node) -> Node:
	for instance_id in main.runtime_enemy_projectile_pool_nodes.keys():
		var projectile = main.runtime_enemy_projectile_pool_nodes[instance_id]
		main.runtime_enemy_projectile_pool_nodes.erase(instance_id)
		main.runtime_enemy_projectile_pool_cache_dirty = true
		if main._is_runtime_node_valid(projectile):
			return projectile
	return null


static func register_runtime_player_projectile(main: Node, projectile: Node) -> void:
	if projectile == null:
		return
	var instance_id: int = projectile.get_instance_id()
	if not main.runtime_player_projectile_nodes.has(instance_id):
		main.runtime_player_projectile_nodes[instance_id] = projectile
		main.runtime_player_projectile_cache_dirty = true


static func unregister_runtime_player_projectile(main: Node, projectile: Node) -> void:
	if projectile == null:
		return
	var instance_id: int = projectile.get_instance_id()
	if main.runtime_player_projectile_nodes.erase(instance_id):
		main.runtime_player_projectile_cache_dirty = true


static func get_runtime_player_projectiles(main: Node) -> Array:
	if main.runtime_player_projectile_cache_dirty:
		main.runtime_player_projectile_cache = main._rebuild_runtime_registry_cache(main.runtime_player_projectile_nodes)
		main.runtime_player_projectile_cache_dirty = false
	return main.runtime_player_projectile_cache


static func release_runtime_player_projectile(main: Node, projectile: Node, pool_key: String = "") -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	var resolved_key: String = pool_key if pool_key != "" else projectile.scene_file_path
	if resolved_key == "":
		resolved_key = projectile.get_script().resource_path if projectile.get_script() != null else "default"
	if not main.runtime_player_projectile_pool_nodes.has(resolved_key):
		main.runtime_player_projectile_pool_nodes[resolved_key] = {}
		main.runtime_player_projectile_pool_cache[resolved_key] = []
		main.runtime_player_projectile_pool_cache_dirty[resolved_key] = false
	var pool: Dictionary = main.runtime_player_projectile_pool_nodes[resolved_key]
	if pool.size() >= main.runtime_player_projectile_pool_limit:
		projectile.queue_free()
		return
	var instance_id: int = projectile.get_instance_id()
	pool[instance_id] = projectile
	main.runtime_player_projectile_pool_cache_dirty[resolved_key] = true


static func take_runtime_player_projectile_from_pool(main: Node, pool_key: String = "") -> Node:
	var resolved_key: String = pool_key if pool_key != "" else "default"
	if not main.runtime_player_projectile_pool_nodes.has(resolved_key):
		return null
	var pool: Dictionary = main.runtime_player_projectile_pool_nodes[resolved_key]
	for instance_id in pool.keys():
		var projectile = pool[instance_id]
		pool.erase(instance_id)
		main.runtime_player_projectile_pool_cache_dirty[resolved_key] = true
		if main._is_runtime_node_valid(projectile):
			return projectile
	return null


static func get_runtime_player_projectile_pool(main: Node, pool_key: String = "") -> Array:
	var resolved_key: String = pool_key if pool_key != "" else "default"
	if not main.runtime_player_projectile_pool_nodes.has(resolved_key):
		return []
	if bool(main.runtime_player_projectile_pool_cache_dirty.get(resolved_key, true)) or not main.runtime_player_projectile_pool_cache.has(resolved_key):
		main.runtime_player_projectile_pool_cache[resolved_key] = main._rebuild_runtime_registry_cache(main.runtime_player_projectile_pool_nodes[resolved_key])
		main.runtime_player_projectile_pool_cache_dirty[resolved_key] = false
	return main.runtime_player_projectile_pool_cache[resolved_key]
