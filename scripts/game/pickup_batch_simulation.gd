extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const BATCH_FRAME_META_KEY := "__pickup_batch_simulation_frame"
const PICKUP_GROUPS := ["exp_gems", "heart_pickups"]


static func update_pickups(scene: Node, delta: float) -> void:
	if scene == null or delta <= 0.0:
		return
	var current_frame: int = Engine.get_physics_frames()
	if int(scene.get_meta(BATCH_FRAME_META_KEY, -1)) == current_frame:
		return
	scene.set_meta(BATCH_FRAME_META_KEY, current_frame)

	var updated_count := 0
	for group_name in PICKUP_GROUPS:
		for raw_pickup in _get_runtime_pickups(scene, group_name):
			if raw_pickup == null or not is_instance_valid(raw_pickup) or raw_pickup is not Node:
				continue
			var pickup_node := raw_pickup as Node
			if not pickup_node.has_method("can_use_batch_simulation") or not pickup_node.has_method("batch_physics_process"):
				continue
			if not bool(pickup_node.call("can_use_batch_simulation")):
				_restore_pickup_physics(pickup_node)
				continue

			if "batch_simulation_enabled" in pickup_node:
				pickup_node.set("batch_simulation_enabled", true)
			if pickup_node.is_physics_processing():
				pickup_node.set_physics_process(false)
			pickup_node.call("batch_physics_process", delta)
			updated_count += 1

	if updated_count > 0:
		PERFORMANCE_COUNTERS.add("batched_pickups", updated_count)


static func _get_runtime_pickups(scene: Node, group_name: String) -> Array:
	if scene.has_method("get_runtime_pickups"):
		return scene.call("get_runtime_pickups", group_name)
	return scene.get_tree().get_nodes_in_group(group_name) if scene.is_inside_tree() else []


static func _restore_pickup_physics(pickup_node: Node) -> void:
	if "batch_simulation_enabled" in pickup_node:
		pickup_node.set("batch_simulation_enabled", false)
	var pooled := false
	if "pooled" in pickup_node:
		pooled = bool(pickup_node.get("pooled"))
	if pickup_node.is_inside_tree() and not pooled and not pickup_node.is_physics_processing():
		pickup_node.set_physics_process(true)
