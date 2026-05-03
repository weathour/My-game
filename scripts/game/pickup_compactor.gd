extends RefCounted

const COMPACT_INTERVAL := 0.45
const EXP_GEM_HARD_LIMIT := 240
const EXP_GEM_TARGET_COUNT := 150
const HEART_HARD_LIMIT := 60
const HEART_TARGET_COUNT := 32
const MAX_PICKUP_MERGE_SCAN_COUNT := 96

static func compact_pickups(root: Node) -> Dictionary:
	if root == null or root.get_tree() == null:
		return {}
	return {
		"merged_gems": _compact_group(root, "exp_gems", EXP_GEM_HARD_LIMIT, EXP_GEM_TARGET_COUNT, "_merge_exp_gem"),
		"merged_hearts": _compact_group(root, "heart_pickups", HEART_HARD_LIMIT, HEART_TARGET_COUNT, "_merge_heart_pickup")
	}

static func should_merge_new_exp_gem(root: Node) -> bool:
	return _get_group_count(root, "exp_gems") >= EXP_GEM_HARD_LIMIT

static func should_merge_new_heart(root: Node) -> bool:
	return _get_group_count(root, "heart_pickups") >= HEART_HARD_LIMIT

static func merge_exp_value_into_existing(root: Node, position: Vector2, value: int, tier: int) -> bool:
	var target := _find_nearest_pickup(root, "exp_gems", position)
	if target == null:
		return false
	if target.has_method("merge_pickup_value"):
		target.merge_pickup_value(value, tier)
	else:
		target.set("value", int(target.get("value")) + max(0, value))
		target.set("tier", max(int(target.get("tier")), tier))
	return true

static func merge_heal_into_existing(root: Node, position: Vector2, heal_amount: float) -> bool:
	var target := _find_nearest_pickup(root, "heart_pickups", position)
	if target == null:
		return false
	if target.has_method("merge_heal_amount"):
		target.merge_heal_amount(heal_amount)
	else:
		target.set("heal_amount", float(target.get("heal_amount")) + max(0.0, heal_amount))
	return true

static func _compact_group(root: Node, group_name: String, hard_limit: int, target_count: int, merge_method: String) -> int:
	var nodes: Array = root.get_tree().get_nodes_in_group(group_name)
	var count := nodes.size()
	if count <= hard_limit:
		return 0
	var safe_target: int = clamp(target_count, 1, hard_limit)
	var keepers: Array = []
	var keeper_ids: Dictionary = {}
	for node in nodes:
		if is_instance_valid(node):
			keepers.append(node)
			keeper_ids[node.get_instance_id()] = true
			if keepers.size() >= safe_target:
				break
	if keepers.is_empty():
		return 0

	var merged_count := 0
	var merge_index := 0
	for node in nodes:
		if not is_instance_valid(node):
			continue
		if keeper_ids.has(node.get_instance_id()):
			continue
		var keeper: Node = keepers[merge_index % keepers.size()]
		merge_index += 1
		if not is_instance_valid(keeper):
			continue
		if merge_method == "_merge_exp_gem":
			_merge_exp_gem(keeper, node)
		elif merge_method == "_merge_heart_pickup":
			_merge_heart_pickup(keeper, node)
		node.queue_free()
		merged_count += 1
	return merged_count

static func _merge_exp_gem(target: Node, source: Node) -> void:
	var source_value: int = int(source.get("value"))
	var source_tier: int = int(source.get("tier"))
	if target.has_method("merge_pickup_value"):
		target.merge_pickup_value(source_value, source_tier)
		return
	target.set("value", int(target.get("value")) + max(0, source_value))
	target.set("tier", max(int(target.get("tier")), source_tier))

static func _merge_heart_pickup(target: Node, source: Node) -> void:
	var source_heal: float = float(source.get("heal_amount"))
	if target.has_method("merge_heal_amount"):
		target.merge_heal_amount(source_heal)
		return
	target.set("heal_amount", float(target.get("heal_amount")) + max(0.0, source_heal))

static func _get_group_count(root: Node, group_name: String) -> int:
	if root == null or root.get_tree() == null:
		return 0
	return root.get_tree().get_node_count_in_group(group_name)

static func _find_nearest_pickup(root: Node, group_name: String, position: Vector2) -> Node:
	if root == null or root.get_tree() == null:
		return null
	var best_node: Node = null
	var best_distance_squared := INF
	var scanned_count := 0
	for node in root.get_tree().get_nodes_in_group(group_name):
		if not is_instance_valid(node):
			continue
		if node is not Node2D:
			continue
		scanned_count += 1
		var distance_squared: float = position.distance_squared_to((node as Node2D).global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_node = node
		if scanned_count >= MAX_PICKUP_MERGE_SCAN_COUNT:
			break
	return best_node
