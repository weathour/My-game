extends RefCounted

const DEFAULT_ACTIVE_ENEMY_LIMIT := 40
const DEFAULT_PLAYER_PROJECTILE_LIMIT := 220
const DEFAULT_ENEMY_PROJECTILE_LIMIT := 200
const DEFAULT_TEMPORARY_EFFECT_LIMIT := 120
const LOW_FPS_TEMPORARY_EFFECT_LIMIT := 50
const LOW_FPS_ENEMY_LIMIT := 40
const LOW_FPS_PROJECTILE_LIMIT := 140
const LOW_FPS_ENEMY_PROJECTILE_LIMIT := 120
const LOW_FPS_THRESHOLD := 52
const CRITICAL_FPS_ENEMY_LIMIT := 40
const CRITICAL_FPS_PROJECTILE_LIMIT := 90
const CRITICAL_FPS_THRESHOLD := 35
const RECOVERY_FPS_THRESHOLD := 58

static var cached_group_counts_frame: int = -1
static var cached_group_counts: Dictionary = {}

static func get_group_count(root: Node, group_name: String) -> int:
	if root == null or root.get_tree() == null:
		return 0
	var current_frame := Engine.get_process_frames()
	if cached_group_counts_frame != current_frame:
		cached_group_counts_frame = current_frame
		cached_group_counts.clear()
	var cache_key := "%s:%s" % [str(root.get_instance_id()), group_name]
	if cached_group_counts.has(cache_key):
		return int(cached_group_counts[cache_key])
	var count := _get_runtime_or_group_count(root, group_name)
	cached_group_counts[cache_key] = count
	return count

static func _get_runtime_or_group_count(root: Node, group_name: String) -> int:
	if root.has_method("get_runtime_enemies") and group_name == "enemies":
		return (root.get_runtime_enemies() as Array).size()
	if root.has_method("get_runtime_enemy_projectiles") and group_name == "enemy_projectiles":
		return (root.get_runtime_enemy_projectiles() as Array).size()
	if root.has_method("get_runtime_player_projectiles") and group_name == "player_projectiles":
		return (root.get_runtime_player_projectiles() as Array).size()
	if root.has_method("get_runtime_pickups") and (group_name == "exp_gems" or group_name == "heart_pickups"):
		return (root.get_runtime_pickups(group_name) as Array).size()
	return root.get_tree().get_node_count_in_group(group_name)

static func can_spawn_in_group(root: Node, group_name: String, limit: int) -> bool:
	if limit <= 0:
		return true
	return get_group_count(root, group_name) < limit

static func can_spawn_in_group_with_reserved(root: Node, group_name: String, limit: int, reserved_count: int) -> bool:
	if limit <= 0:
		return true
	return get_group_count(root, group_name) + max(0, reserved_count) < limit

static func get_remaining_capacity(root: Node, group_name: String, limit: int) -> int:
	if limit <= 0:
		return 999999
	return max(0, limit - get_group_count(root, group_name))

static func get_remaining_capacity_with_reserved(root: Node, group_name: String, limit: int, reserved_count: int) -> int:
	if limit <= 0:
		return 999999
	return max(0, limit - get_group_count(root, group_name) - max(0, reserved_count))

static func get_dynamic_limit(_root: Node, group_name: String, fallback_limit: int) -> int:
	var limit := fallback_limit
	var fps := Engine.get_frames_per_second()
	if fps <= 0:
		return limit
	if group_name == "enemies":
		if fps < CRITICAL_FPS_THRESHOLD:
			limit = min(limit, CRITICAL_FPS_ENEMY_LIMIT)
		elif fps < LOW_FPS_THRESHOLD:
			limit = min(limit, LOW_FPS_ENEMY_LIMIT)
		elif fps >= RECOVERY_FPS_THRESHOLD:
			limit = min(limit, DEFAULT_ACTIVE_ENEMY_LIMIT)
	elif group_name == "player_projectiles":
		if fps < CRITICAL_FPS_THRESHOLD:
			limit = min(limit, CRITICAL_FPS_PROJECTILE_LIMIT)
		elif fps < LOW_FPS_THRESHOLD:
			limit = min(limit, LOW_FPS_PROJECTILE_LIMIT)
	elif group_name == "enemy_projectiles":
		if fps < LOW_FPS_THRESHOLD:
			limit = min(limit, LOW_FPS_ENEMY_PROJECTILE_LIMIT)
	elif group_name == "temporary_effects":
		if fps < LOW_FPS_THRESHOLD:
			limit = min(limit, LOW_FPS_TEMPORARY_EFFECT_LIMIT)
	return limit

static func trim_requested_count(root: Node, group_name: String, requested_count: int, limit: int) -> int:
	return min(max(0, requested_count), get_remaining_capacity(root, group_name, limit))

static func trim_requested_count_with_reserved(root: Node, group_name: String, requested_count: int, limit: int, reserved_count: int) -> int:
	return min(max(0, requested_count), get_remaining_capacity_with_reserved(root, group_name, limit, reserved_count))
