extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

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
		"enemies": _count_group_nodes(tree, "enemies"),
		"player_projectiles": _count_group_nodes(tree, "player_projectiles"),
		"batched_projectiles": _count_batched_projectiles(tree.current_scene),
		"enemy_projectiles": _count_group_nodes(tree, "enemy_projectiles"),
		"exp_gems": _count_group_nodes(tree, "exp_gems"),
		"heart_pickups": _count_group_nodes(tree, "heart_pickups"),
		"temporary_effects": _count_group_nodes(tree, "temporary_effects"),
		"total_nodes": cached_total_nodes,
		"frame_counters": PERFORMANCE_COUNTERS.get_snapshot()
	}
	return cached_metrics

static func format_metrics(metrics: Dictionary) -> String:
	if metrics.is_empty():
		return "Performance: no data"
	var counters_text := _format_counter_snapshot(metrics.get("frame_counters", {}))
	return "FPS %d | Enemy %d | P.Bullet %d + Batch %d | E.Bullet %d\nGem %d | Heart %d | TempFX %d | Nodes %d%s" % [
		int(metrics.get("fps", 0)),
		int(metrics.get("enemies", 0)),
		int(metrics.get("player_projectiles", 0)),
		int(metrics.get("batched_projectiles", 0)),
		int(metrics.get("enemy_projectiles", 0)),
		int(metrics.get("exp_gems", 0)),
		int(metrics.get("heart_pickups", 0)),
		int(metrics.get("temporary_effects", 0)),
		int(metrics.get("total_nodes", 0)),
		counters_text
	]

static func _format_counter_snapshot(snapshot: Variant) -> String:
	if snapshot is not Dictionary:
		return ""
	var peak: Dictionary = (snapshot as Dictionary).get("peak", {})
	if peak.is_empty():
		return ""
	var current_frame: Dictionary = (snapshot as Dictionary).get("current_frame", {})
	return "\nSpike peak: switch %d | dmgQueries %d | candidates %d | hits %d | queued %d | merged %d | applied %d | qSize %d | fx %d | batch %d" % [
		int(peak.get("switch_jobs", 0)),
		int(peak.get("damage_queries", 0)),
		int(peak.get("damage_candidates", 0)),
		int(peak.get("damage_hits", 0)),
		int(peak.get("queued_damage_jobs", 0)),
		int(peak.get("merged_damage_jobs", 0)),
		int(peak.get("applied_damage_jobs", 0)),
		int(current_frame.get("damage_queue_size", peak.get("damage_queue_size", 0))),
		int(peak.get("temporary_effect_spawns", 0)),
		int(peak.get("batched_projectiles", 0))
	]

static func _count_nodes(node: Node) -> int:
	if node == null:
		return 0
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

static func _count_group_nodes(tree: SceneTree, group_name: String) -> int:
	if tree == null:
		return 0
	return tree.get_nodes_in_group(group_name).size()

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
