extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")
const PERFORMANCE_FEATURE_FLAGS := preload("res://scripts/game/performance_feature_flags.gd")

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
		"enemies": _count_runtime_or_group_nodes(root, tree, "enemies"),
		"player_projectiles": _count_runtime_or_group_nodes(root, tree, "player_projectiles"),
		"batched_projectiles": _count_batched_projectiles(tree.current_scene),
		"enemy_projectiles": _count_runtime_or_group_nodes(root, tree, "enemy_projectiles"),
		"exp_gems": _count_runtime_or_group_nodes(root, tree, "exp_gems"),
		"heart_pickups": _count_runtime_or_group_nodes(root, tree, "heart_pickups"),
		"temporary_effects": _count_group_nodes(tree, "temporary_effects"),
		"total_nodes": cached_total_nodes,
		"pending_enemy_spawns": _count_pending_enemy_spawns(root),
		"frame_counters": PERFORMANCE_COUNTERS.get_snapshot(),
		"frame_time": PERFORMANCE_RECORDER.get_rolling_snapshot(),
		"performance_flags": PERFORMANCE_FEATURE_FLAGS.get_snapshot(root)
	}
	return cached_metrics

static func format_metrics(metrics: Dictionary) -> String:
	if metrics.is_empty():
		return "Performance: no data"
	var counters_text := _format_counter_snapshot(metrics.get("frame_counters", {}))
	var flags_text := _format_flag_snapshot(metrics.get("performance_flags", {}))
	var frame_time: Dictionary = metrics.get("frame_time", {})
	var scope_peaks: Dictionary = frame_time.get("scope_peaks_ms", {})
	return "FPS %d | p95 %.1fms p99 %.1fms max %.1fms | SavePeak %.1fms | Enemy %d | SpawnQ %d | P.Bullet %d + Batch %d | E.Bullet %d\nGem %d | Heart %d | TempFX %d | Nodes %d%s%s" % [
		int(metrics.get("fps", 0)),
		float(frame_time.get("p95_ms", 0.0)),
		float(frame_time.get("p99_ms", 0.0)),
		float(frame_time.get("max_ms", 0.0)),
		float(scope_peaks.get("save_run_ms", 0.0)),
		int(metrics.get("enemies", 0)),
		int(metrics.get("pending_enemy_spawns", 0)),
		int(metrics.get("player_projectiles", 0)),
		int(metrics.get("batched_projectiles", 0)),
		int(metrics.get("enemy_projectiles", 0)),
		int(metrics.get("exp_gems", 0)),
		int(metrics.get("heart_pickups", 0)),
		int(metrics.get("temporary_effects", 0)),
		int(metrics.get("total_nodes", 0)),
		flags_text,
		counters_text
	]

static func _format_counter_snapshot(snapshot: Variant) -> String:
	if snapshot is not Dictionary:
		return ""
	var peak: Dictionary = (snapshot as Dictionary).get("peak", {})
	if peak.is_empty():
		return ""
	var current_frame: Dictionary = (snapshot as Dictionary).get("current_frame", {})
	return "\nSpike peak: switch %d | dmgQueries %d | candidates %d | hits %d | queued %d | merged %d | applied %d | qSize %d | fx %d | pBatch %d | eBatch %d | eProjBatch %d | pickupBatch %d\nSave peak: calls %d | %.1fms | %dKB | enemy %d | eProj %d | gem %d | heart %d\nSuppressed: flash %d | status %d | burst %d | tempFX %d" % [
		int(peak.get("switch_jobs", 0)),
		int(peak.get("damage_queries", 0)),
		int(peak.get("damage_candidates", 0)),
		int(peak.get("damage_hits", 0)),
		int(peak.get("queued_damage_jobs", 0)),
		int(peak.get("merged_damage_jobs", 0)),
		int(peak.get("applied_damage_jobs", 0)),
		int(current_frame.get("damage_queue_size", peak.get("damage_queue_size", 0))),
		int(peak.get("temporary_effect_spawns", 0)),
		int(peak.get("batched_projectiles", 0)),
		int(peak.get("batched_enemy_ticks", 0)),
		int(peak.get("batched_enemy_projectiles", 0)),
		int(peak.get("batched_pickups", 0)),
		int(peak.get("save_run_calls", 0)),
		float(peak.get("save_run_ms_x10", 0)) / 10.0,
		int(peak.get("save_payload_kb", 0)),
		int(peak.get("save_enemies", 0)),
		int(peak.get("save_enemy_projectiles", 0)),
		int(peak.get("save_gems", 0)),
		int(peak.get("save_hearts", 0)),
		int(peak.get("suppressed_hit_flash", 0)),
		int(peak.get("suppressed_status_visuals", 0)),
		int(peak.get("suppressed_status_bursts", 0)),
		int(peak.get("suppressed_temp_fx", 0))
	]

static func _format_flag_snapshot(snapshot: Variant) -> String:
	if snapshot is not Dictionary:
		return ""
	var flags := snapshot as Dictionary
	return "\nFlags: enemyBatch %s | eProjBatch %s | pickupBatch %s" % [
		_on_off(bool(flags.get(PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_BATCH, false))),
		_on_off(bool(flags.get(PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_PROJECTILE_BATCH, false))),
		_on_off(bool(flags.get(PERFORMANCE_FEATURE_FLAGS.FLAG_PICKUP_BATCH, false)))
	]

static func _on_off(value: bool) -> String:
	return "on" if value else "off"

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
	return tree.get_node_count_in_group(group_name)

static func _count_runtime_or_group_nodes(root: Node, tree: SceneTree, group_name: String) -> int:
	if root != null:
		if group_name == "enemies" and root.has_method("get_runtime_enemies"):
			return (root.get_runtime_enemies() as Array).size()
		if group_name == "enemy_projectiles" and root.has_method("get_runtime_enemy_projectiles"):
			return (root.get_runtime_enemy_projectiles() as Array).size()
		if group_name == "player_projectiles" and root.has_method("get_runtime_player_projectiles"):
			return (root.get_runtime_player_projectiles() as Array).size()
		if (group_name == "exp_gems" or group_name == "heart_pickups") and root.has_method("get_runtime_pickups"):
			return (root.get_runtime_pickups(group_name) as Array).size()
	return _count_group_nodes(tree, group_name)

static func _count_batched_projectiles(root: Node) -> int:
	if root == null:
		return 0
	var batch := root.get_node_or_null("PlayerProjectileBatch")
	if batch == null:
		return 0
	if "positions" in batch:
		return int(batch.positions.size())
	return 0

static func _count_pending_enemy_spawns(root: Node) -> int:
	if root == null:
		return 0
	if root.has_method("get_pending_enemy_spawn_count"):
		return int(root.get_pending_enemy_spawn_count())
	if "pending_enemy_spawn_requests" in root and "pending_enemy_spawn_cursor" in root:
		var requests: Variant = root.get("pending_enemy_spawn_requests")
		if requests is Array:
			return max(0, (requests as Array).size() - int(root.get("pending_enemy_spawn_cursor")))
	return 0
