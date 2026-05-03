extends RefCounted

const SAMPLE_INTERVAL := 1.0
const TOTAL_NODE_SAMPLE_STRIDE := 3
const GROUP_SAMPLE_STRIDE := 2

static var cached_metrics: Dictionary = {}
static var cached_total_nodes: int = 0
static var total_node_sample_index: int = TOTAL_NODE_SAMPLE_STRIDE
static var group_sample_index: int = GROUP_SAMPLE_STRIDE

static func collect_metrics(root: Node) -> Dictionary:
	if root == null:
		return {}
	var tree := root.get_tree()
	if tree == null:
		return {}
	group_sample_index += 1
	if group_sample_index < GROUP_SAMPLE_STRIDE and not cached_metrics.is_empty():
		cached_metrics["fps"] = Engine.get_frames_per_second()
		return cached_metrics
	group_sample_index = 0
	total_node_sample_index += 1
	if total_node_sample_index >= TOTAL_NODE_SAMPLE_STRIDE:
		total_node_sample_index = 0
		cached_total_nodes = _count_nodes(tree.current_scene)
	cached_metrics = {
		"fps": Engine.get_frames_per_second(),
		"enemies": tree.get_node_count_in_group("enemies"),
		"player_projectiles": tree.get_node_count_in_group("player_projectiles"),
		"batched_projectiles": _count_batched_projectiles(tree.current_scene),
		"enemy_projectiles": tree.get_node_count_in_group("enemy_projectiles"),
		"exp_gems": tree.get_node_count_in_group("exp_gems"),
		"heart_pickups": tree.get_node_count_in_group("heart_pickups"),
		"temporary_effects": tree.get_node_count_in_group("temporary_effects"),
		"total_nodes": cached_total_nodes
	}
	return cached_metrics

static func format_metrics(metrics: Dictionary) -> String:
	if metrics.is_empty():
		return "Performance: no data"
	return "FPS %d | Enemy %d | P.Bullet %d + Batch %d | E.Bullet %d\nGem %d | Heart %d | TempFX %d | Nodes %d" % [
		int(metrics.get("fps", 0)),
		int(metrics.get("enemies", 0)),
		int(metrics.get("player_projectiles", 0)),
		int(metrics.get("batched_projectiles", 0)),
		int(metrics.get("enemy_projectiles", 0)),
		int(metrics.get("exp_gems", 0)),
		int(metrics.get("heart_pickups", 0)),
		int(metrics.get("temporary_effects", 0)),
		int(metrics.get("total_nodes", 0))
	]

static func _count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

static func _count_batched_projectiles(root: Node) -> int:
	if root == null:
		return 0
	var batch := root.get_node_or_null("PlayerProjectileBatch")
	if batch == null:
		return 0
	if "positions" in batch:
		return int(batch.positions.size())
	if "projectiles" in batch:
		return int(batch.projectiles.size())
	return 0
