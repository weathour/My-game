extends RefCounted

const PLAYER_DAMAGE_RESOLVER := preload("res://scripts/player/player_damage_resolver.gd")

const CLUSTER_CELL_SIZE := 120.0

static var owner_target_cache: Dictionary = {}
static var owner_target_cache_frame: int = -1

static func get_enemy_nodes(owner) -> Array:
	if owner != null and owner.has_method("_get_live_enemies"):
		return owner._get_live_enemies()
	if owner != null and owner.has_method("get_tree"):
		var tree: SceneTree = owner.get_tree()
		if tree != null:
			var scene: Node = tree.current_scene
			if scene != null and scene.has_method("get_runtime_enemies"):
				return scene.get_runtime_enemies()
			return tree.get_nodes_in_group("enemies")
	return []


static func get_owner_closest_enemy(owner) -> Node2D:
	var key: String = _owner_cache_key(owner, "closest")
	var cached: Dictionary = _get_cached_node2d_result(key)
	if bool(cached.get("hit", false)):
		return cached.get("value", null) as Node2D
	var value: Node2D = get_closest_enemy(get_enemy_nodes(owner), owner.global_position)
	_set_owner_cache(key, value)
	return value


static func get_owner_farthest_enemy(owner) -> Node2D:
	var key: String = _owner_cache_key(owner, "farthest")
	var cached: Dictionary = _get_cached_node2d_result(key)
	if bool(cached.get("hit", false)):
		return cached.get("value", null) as Node2D
	var value: Node2D = get_farthest_enemy(get_enemy_nodes(owner), owner.global_position)
	_set_owner_cache(key, value)
	return value


static func get_owner_enemy_targets(owner, count: int, prefer_farthest: bool = false) -> Array:
	var key: String = _owner_cache_key(owner, "targets_%d_%s" % [count, str(prefer_farthest)])
	if _has_owner_cache(key):
		return owner_target_cache[key]["value"] as Array
	var value: Array = get_enemy_targets(get_enemy_nodes(owner), owner.global_position, count, prefer_farthest)
	_set_owner_cache(key, value)
	return value


static func get_owner_low_health_enemy(owner) -> Node2D:
	var key: String = _owner_cache_key(owner, "low_health")
	var cached: Dictionary = _get_cached_node2d_result(key)
	if bool(cached.get("hit", false)):
		return cached.get("value", null) as Node2D
	var value: Node2D = get_low_health_enemy(get_enemy_nodes(owner))
	_set_owner_cache(key, value)
	return value


static func get_owner_enemy_in_aim_cone(owner, max_angle_degrees: float, max_distance: float = INF) -> Node2D:
	var key: String = _owner_cache_key(owner, "aim_cone_%.2f_%.2f_%.3f_%.3f" % [max_angle_degrees, max_distance, owner.facing_direction.x, owner.facing_direction.y])
	var cached: Dictionary = _get_cached_node2d_result(key)
	if bool(cached.get("hit", false)):
		return cached.get("value", null) as Node2D
	var value: Node2D = get_enemy_in_aim_cone(get_enemy_nodes(owner), owner.global_position, owner.facing_direction, max_angle_degrees, max_distance)
	_set_owner_cache(key, value)
	return value


static func get_owner_enemy_cluster_center(owner) -> Vector2:
	var key: String = _owner_cache_key(owner, "cluster_center")
	if _has_owner_cache(key):
		return owner_target_cache[key]["value"] as Vector2
	var value: Vector2 = get_enemy_cluster_center(get_enemy_nodes(owner))
	_set_owner_cache(key, value)
	return value


static func get_owner_random_enemy_cluster_centers(owner, count: int) -> Array:
	var key: String = _owner_cache_key(owner, "random_cluster_centers_%d" % count)
	if _has_owner_cache(key):
		return (owner_target_cache[key]["value"] as Array).duplicate()
	var value: Array = get_random_enemy_cluster_centers(get_enemy_nodes(owner), owner.global_position, count)
	_set_owner_cache(key, value)
	return value.duplicate()


static func get_closest_enemy(enemies: Array, origin: Vector2) -> Node2D:
	var closest_enemy: Node2D
	var closest_distance: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance_squared: float = origin.distance_squared_to(enemy.global_position)
		if distance_squared < closest_distance:
			closest_distance = distance_squared
			closest_enemy = enemy
	return closest_enemy

static func get_farthest_enemy(enemies: Array, origin: Vector2) -> Node2D:
	var farthest_enemy: Node2D
	var farthest_distance: float = 0.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance_squared: float = origin.distance_squared_to(enemy.global_position)
		if distance_squared > farthest_distance:
			farthest_distance = distance_squared
			farthest_enemy = enemy
	return farthest_enemy

static func get_enemy_targets(enemies: Array, origin: Vector2, count: int, prefer_farthest: bool = false) -> Array:
	var target_count: int = max(0, count)
	if target_count <= 0:
		return []
	var selected: Array = []
	var selected_scores: Array[float] = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var score: float = origin.distance_squared_to(enemy.global_position)
		_insert_scored_enemy(selected, selected_scores, enemy, score, target_count, prefer_farthest)
	return selected

static func get_low_health_enemy(enemies: Array) -> Node2D:
	var selected_enemy: Node2D
	var lowest_ratio: float = 1.1
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_health: float = float(enemy.get("current_health"))
		var enemy_max_health: float = max(float(enemy.get("max_health")), 1.0)
		var ratio: float = enemy_health / enemy_max_health
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			selected_enemy = enemy
	return selected_enemy

static func get_enemy_in_aim_cone(enemies: Array, origin: Vector2, facing_direction: Vector2, max_angle_degrees: float, max_distance: float = INF) -> Node2D:
	var selected_enemy: Node2D
	var best_score: float = -INF
	var max_dot: float = cos(deg_to_rad(max_angle_degrees))
	var max_distance_squared: float = max_distance * max_distance
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var to_enemy: Vector2 = enemy.global_position - origin
		var distance_squared: float = to_enemy.length_squared()
		if distance_squared <= 0.001 or distance_squared > max_distance_squared:
			continue
		var distance: float = sqrt(distance_squared)
		var direction_dot: float = facing_direction.dot(to_enemy / distance)
		if direction_dot < max_dot:
			continue
		var score: float = direction_dot * 1000.0 - distance
		if score > best_score:
			best_score = score
			selected_enemy = enemy
	return selected_enemy

static func get_enemy_cluster_center(enemies: Array) -> Vector2:
	if enemies.is_empty():
		return Vector2.ZERO

	var grid: Dictionary = _build_enemy_position_grid(enemies)
	return _get_best_cluster_center_from_grid(grid)

static func get_random_enemy_cluster_centers(enemies: Array, fallback_position: Vector2, count: int) -> Array:
	if enemies.is_empty():
		return [fallback_position]

	var grid: Dictionary = _build_enemy_position_grid(enemies)
	var scored_centers: Array = _get_scored_cluster_centers_from_grid(grid)

	scored_centers.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	var candidate_pool: Array = scored_centers.slice(0, min(6, scored_centers.size()))
	var picked_centers: Array = []
	while picked_centers.size() < count and not candidate_pool.is_empty():
		var chosen_index: int = randi() % candidate_pool.size()
		var chosen_center: Vector2 = candidate_pool[chosen_index]["center"]
		candidate_pool.remove_at(chosen_index)
		var too_close := false
		for picked_center in picked_centers:
			if chosen_center.distance_squared_to(picked_center) < 2304.0:
				too_close = true
				break
		if too_close:
			continue
		picked_centers.append(chosen_center)

	if picked_centers.is_empty():
		picked_centers.append(_get_best_cluster_center_from_grid(grid))
	while picked_centers.size() < count:
		picked_centers.append(picked_centers[picked_centers.size() - 1])
	return picked_centers

static func get_enemy_nearest_to_position(enemies: Array, position: Vector2) -> Node2D:
	var selected_enemy: Node2D
	var best_distance: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance_squared: float = position.distance_squared_to(enemy.global_position)
		if distance_squared < best_distance:
			best_distance = distance_squared
			selected_enemy = enemy
	return selected_enemy

static func get_enemy_near_position(enemies: Array, position: Vector2, max_distance: float) -> Node2D:
	var selected_enemy: Node2D
	var best_distance: float = max_distance * max_distance
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance_squared := position.distance_squared_to(enemy.global_position)
		if distance_squared > best_distance:
			continue
		best_distance = distance_squared
		selected_enemy = enemy
	return selected_enemy

static func _insert_scored_enemy(selected: Array, selected_scores: Array[float], enemy: Node2D, score: float, target_count: int, prefer_farthest: bool) -> void:
	var insert_index := selected_scores.size()
	for index in range(selected_scores.size()):
		if prefer_farthest:
			if score > selected_scores[index]:
				insert_index = index
				break
		elif score < selected_scores[index]:
			insert_index = index
			break
	if insert_index >= target_count:
		return
	selected.insert(insert_index, enemy)
	selected_scores.insert(insert_index, score)
	if selected.size() > target_count:
		selected.pop_back()
		selected_scores.pop_back()

static func _build_enemy_position_grid(enemies: Array) -> Dictionary:
	var grid: Dictionary = {}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var cell: Vector2i = _grid_cell(enemy.global_position)
		if not grid.has(cell):
			grid[cell] = []
		(grid[cell] as Array).append(enemy)
	return grid

static func _get_best_cluster_center_from_grid(grid: Dictionary) -> Vector2:
	if grid.is_empty():
		return Vector2.ZERO
	var best_center := Vector2.ZERO
	var best_score: int = -1
	for cell in grid.keys():
		var scored: Dictionary = _score_cluster_cell(grid, cell as Vector2i)
		var score: int = int(scored.get("score", 0))
		if score > best_score:
			best_score = score
			best_center = scored.get("center", Vector2.ZERO) as Vector2
	return best_center

static func _get_scored_cluster_centers_from_grid(grid: Dictionary) -> Array:
	var scored_centers: Array = []
	for cell in grid.keys():
		scored_centers.append(_score_cluster_cell(grid, cell as Vector2i))
	return scored_centers

static func _score_cluster_cell(grid: Dictionary, center_cell: Vector2i) -> Dictionary:
	var score := 0
	var position_sum := Vector2.ZERO
	for x in range(center_cell.x - 1, center_cell.x + 2):
		for y in range(center_cell.y - 1, center_cell.y + 2):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				continue
			for enemy in grid[cell] as Array:
				if not is_instance_valid(enemy):
					continue
				score += 1
				position_sum += (enemy as Node2D).global_position
	var center: Vector2 = position_sum / float(max(1, score))
	return {
		"center": center,
		"score": score
	}

static func _grid_cell(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CLUSTER_CELL_SIZE), floori(position.y / CLUSTER_CELL_SIZE))

static func _owner_cache_key(owner, suffix: String) -> String:
	var owner_id: int = owner.get_instance_id() if owner != null and is_instance_valid(owner) else 0
	return "%d:%s" % [owner_id, suffix]

static func _has_owner_cache(key: String) -> bool:
	_ensure_owner_cache_frame()
	if not owner_target_cache.has(key):
		return false
	return true

static func _get_cached_node2d_result(key: String) -> Dictionary:
	if not _has_owner_cache(key):
		return {
			"hit": false,
			"value": null
		}
	var cached_value: Variant = (owner_target_cache[key] as Dictionary).get("value", null)
	if cached_value == null:
		return {
			"hit": true,
			"value": null
		}
	if not is_instance_valid(cached_value):
		owner_target_cache.erase(key)
		return {
			"hit": false,
			"value": null
		}
	return {
		"hit": true,
		"value": cached_value as Node2D
	}

static func _set_owner_cache(key: String, value: Variant) -> void:
	_ensure_owner_cache_frame()
	owner_target_cache[key] = {
		"value": value
	}

static func _ensure_owner_cache_frame() -> void:
	var current_frame: int = Engine.get_physics_frames()
	if owner_target_cache_frame == current_frame:
		return
	owner_target_cache_frame = current_frame
	owner_target_cache.clear()
