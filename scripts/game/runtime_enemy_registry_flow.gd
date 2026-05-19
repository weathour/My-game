extends RefCounted

# Enemy scene instantiation/activation is a heavy spike source. Keep burst
# density unchanged by draining the queue over several render frames instead
# of allowing a whole warning wave to materialize in one frame.
const NORMAL_ENEMY_SPAWN_PROCESS_LIMIT := 4
const LOW_FPS_ENEMY_SPAWN_PROCESS_LIMIT := 3
const CRITICAL_FPS_ENEMY_SPAWN_PROCESS_LIMIT := 2
const NORMAL_ENEMY_SPAWN_BUDGET_US := 2600
const LOW_FPS_ENEMY_SPAWN_BUDGET_US := 1900
const CRITICAL_FPS_ENEMY_SPAWN_BUDGET_US := 1300


static func register_runtime_enemy(main: Node, enemy: Node) -> void:
	if enemy == null:
		return
	var instance_id: int = enemy.get_instance_id()
	main.runtime_enemy_pool_nodes.erase(instance_id)
	if not main.runtime_enemy_nodes.has(instance_id):
		main.runtime_enemy_nodes[instance_id] = enemy
		main.runtime_enemy_cache_dirty = true


static func unregister_runtime_enemy(main: Node, enemy: Node) -> void:
	if enemy == null:
		return
	var instance_id: int = enemy.get_instance_id()
	if main.runtime_enemy_nodes.erase(instance_id):
		main.runtime_enemy_cache_dirty = true


static func get_runtime_enemies(main: Node) -> Array:
	if main.runtime_enemy_cache_dirty:
		main.runtime_enemy_cache = main._rebuild_runtime_registry_cache(main.runtime_enemy_nodes)
		main.runtime_enemy_cache_dirty = false
	return main.runtime_enemy_cache


static func queue_runtime_enemy_spawn(main: Node, request: Dictionary) -> void:
	if request.is_empty():
		return
	main.pending_enemy_spawn_requests.append(request)


static func process_pending_enemy_spawns(main: Node) -> void:
	if main.pending_enemy_spawn_cursor >= main.pending_enemy_spawn_requests.size():
		clear_pending_enemy_spawn_requests_if_needed(main)
		return
	var processed: int = 0
	var process_limit: int = get_enemy_spawn_process_limit(main)
	var process_budget_us: int = get_enemy_spawn_process_budget_us(main)
	var start_us: int = Time.get_ticks_usec()
	while processed < process_limit and main.pending_enemy_spawn_cursor < main.pending_enemy_spawn_requests.size():
		if processed > 0 and Time.get_ticks_usec() - start_us >= process_budget_us:
			break
		var request: Dictionary = main.pending_enemy_spawn_requests[main.pending_enemy_spawn_cursor]
		main.pending_enemy_spawn_cursor += 1
		if not request.is_empty():
			spawn_queued_enemy_request(main, request)
		processed += 1
	clear_pending_enemy_spawn_requests_if_needed(main)


static func spawn_queued_enemy_request(main: Node, request: Dictionary) -> void:
	if main.game_over or main.player == null or main.enemy_scene == null:
		return
	var kind: String = str(request.get("kind", "normal"))
	var archetype: String = str(request.get("archetype", "chaser"))
	var health_multiplier: float = float(request.get("health_multiplier", 1.0))
	var speed_multiplier: float = float(request.get("speed_multiplier", 1.0))
	var damage_multiplier: float = float(request.get("damage_multiplier", 1.0))
	var spawn_position: Vector2 = request.get("spawn_position", Vector2.ZERO)
	main.ENEMY_SPAWN_FLOW.spawn_configured_enemy_at(main, kind, archetype, health_multiplier, speed_multiplier, spawn_position, damage_multiplier)


static func clear_pending_enemy_spawn_requests_if_needed(main: Node) -> void:
	if main.pending_enemy_spawn_cursor < main.pending_enemy_spawn_requests.size():
		return
	main.pending_enemy_spawn_requests.clear()
	main.pending_enemy_spawn_cursor = 0


static func get_enemy_spawn_process_limit(main: Node) -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < main.PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_ENEMY_SPAWN_PROCESS_LIMIT
	if fps > 0 and fps < main.PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_ENEMY_SPAWN_PROCESS_LIMIT
	return NORMAL_ENEMY_SPAWN_PROCESS_LIMIT


static func get_enemy_spawn_process_budget_us(main: Node) -> int:
	var fps := Engine.get_frames_per_second()
	if fps > 0 and fps < main.PERFORMANCE_GUARD.CRITICAL_FPS_THRESHOLD:
		return CRITICAL_FPS_ENEMY_SPAWN_BUDGET_US
	if fps > 0 and fps < main.PERFORMANCE_GUARD.LOW_FPS_THRESHOLD:
		return LOW_FPS_ENEMY_SPAWN_BUDGET_US
	return NORMAL_ENEMY_SPAWN_BUDGET_US


static func get_pending_enemy_spawn_count(main: Node) -> int:
	if main == null:
		return 0
	return max(0, main.pending_enemy_spawn_requests.size() - main.pending_enemy_spawn_cursor)


static func take_runtime_enemy_from_pool(main: Node) -> Node:
	for instance_id in main.runtime_enemy_pool_nodes.keys():
		var enemy = main.runtime_enemy_pool_nodes[instance_id]
		main.runtime_enemy_pool_nodes.erase(instance_id)
		if main._is_runtime_node_valid(enemy):
			return enemy
	return null


static func release_runtime_enemy(main: Node, enemy: Node) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	unregister_runtime_enemy(main, enemy)
	var instance_id: int = enemy.get_instance_id()
	if main.runtime_enemy_pool_nodes.size() >= main.runtime_enemy_pool_limit:
		enemy.queue_free()
		return
	var parent: Node = enemy.get_parent()
	if parent != null:
		parent.remove_child(enemy)
	enemy.hide()
	enemy.set_process(false)
	enemy.set_physics_process(false)
	main.runtime_enemy_pool_nodes[instance_id] = enemy
