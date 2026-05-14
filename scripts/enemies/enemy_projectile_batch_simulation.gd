extends RefCounted

const PERFORMANCE_COUNTERS := preload("res://scripts/game/performance_counters.gd")

const BATCH_FRAME_META_KEY := "__enemy_projectile_batch_simulation_frame"


static func update_enemy_projectiles(scene: Node, delta: float) -> void:
	if scene == null or delta <= 0.0:
		return
	var current_frame: int = Engine.get_physics_frames()
	if int(scene.get_meta(BATCH_FRAME_META_KEY, -1)) == current_frame:
		return
	scene.set_meta(BATCH_FRAME_META_KEY, current_frame)

	var updated_count := 0
	for raw_projectile in _get_runtime_enemy_projectiles(scene):
		if raw_projectile == null or not is_instance_valid(raw_projectile) or raw_projectile is not Node:
			continue
		var projectile_node := raw_projectile as Node
		if not projectile_node.has_method("can_use_batch_simulation") or not projectile_node.has_method("batch_physics_process"):
			continue
		if not bool(projectile_node.call("can_use_batch_simulation")):
			_restore_projectile_physics(projectile_node)
			continue

		if "batch_simulation_enabled" in projectile_node:
			projectile_node.set("batch_simulation_enabled", true)
		if projectile_node.is_physics_processing():
			projectile_node.set_physics_process(false)
		projectile_node.call("batch_physics_process", delta)
		updated_count += 1

	if updated_count > 0:
		PERFORMANCE_COUNTERS.add("batched_enemy_projectiles", updated_count)


static func _get_runtime_enemy_projectiles(scene: Node) -> Array:
	if scene.has_method("get_runtime_enemy_projectiles"):
		return scene.call("get_runtime_enemy_projectiles")
	return scene.get_tree().get_nodes_in_group("enemy_projectiles") if scene.is_inside_tree() else []


static func _restore_projectile_physics(projectile_node: Node) -> void:
	if "batch_simulation_enabled" in projectile_node:
		projectile_node.set("batch_simulation_enabled", false)
	var pooled := false
	if "pooled" in projectile_node:
		pooled = bool(projectile_node.get("pooled"))
	if projectile_node.is_inside_tree() and not pooled and not projectile_node.is_physics_processing():
		projectile_node.set_physics_process(true)
