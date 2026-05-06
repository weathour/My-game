extends RefCounted

const DEFAULT_ACTIVE_ENEMY_LIMIT := 220
const DEFAULT_PLAYER_PROJECTILE_LIMIT := 260
const DEFAULT_ENEMY_PROJECTILE_LIMIT := 240
const DEFAULT_TEMPORARY_EFFECT_LIMIT := 160
const LOW_FPS_TEMPORARY_EFFECT_LIMIT := 80
const LOW_FPS_ENEMY_LIMIT := 180
const LOW_FPS_THRESHOLD := 45
const RECOVERY_FPS_THRESHOLD := 58

static func get_group_count(root: Node, group_name: String) -> int:
	if root == null or root.get_tree() == null:
		return 0
	return root.get_tree().get_nodes_in_group(group_name).size()

static func can_spawn_in_group(root: Node, group_name: String, limit: int) -> bool:
	if limit <= 0:
		return true
	return get_group_count(root, group_name) < limit

static func get_remaining_capacity(root: Node, group_name: String, limit: int) -> int:
	if limit <= 0:
		return 999999
	return max(0, limit - get_group_count(root, group_name))

static func get_dynamic_limit(_root: Node, group_name: String, fallback_limit: int) -> int:
	var limit := fallback_limit
	if group_name == "enemies":
		var fps := Engine.get_frames_per_second()
		if fps > 0 and fps < LOW_FPS_THRESHOLD:
			limit = min(limit, LOW_FPS_ENEMY_LIMIT)
		elif fps >= RECOVERY_FPS_THRESHOLD:
			limit = min(limit, DEFAULT_ACTIVE_ENEMY_LIMIT)
	elif group_name == "temporary_effects":
		var fps := Engine.get_frames_per_second()
		if fps > 0 and fps < LOW_FPS_THRESHOLD:
			limit = min(limit, LOW_FPS_TEMPORARY_EFFECT_LIMIT)
	return limit

static func trim_requested_count(root: Node, group_name: String, requested_count: int, limit: int) -> int:
	return min(max(0, requested_count), get_remaining_capacity(root, group_name, limit))
