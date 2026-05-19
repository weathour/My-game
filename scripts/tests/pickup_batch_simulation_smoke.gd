extends SceneTree

const PICKUP_BATCH_SIMULATION := preload("res://scripts/game/pickup_batch_simulation.gd")
const EXP_GEM_SCENE := preload("res://scenes/exp_gem.tscn")
const HEART_PICKUP_SCENE := preload("res://scenes/heart_pickup.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var target := Node2D.new()
	target.global_position = Vector2(240.0, 0.0)
	scene.add_child(target)

	var gem := EXP_GEM_SCENE.instantiate() as Node2D
	scene.add_child(gem)
	gem.reset_pickup(Vector2.ZERO, 1, 10)
	gem.set_attraction_target(target)

	var heart := HEART_PICKUP_SCENE.instantiate() as Node2D
	scene.add_child(heart)
	heart.reset_pickup(Vector2(64.0, 0.0), 50.0)
	heart.age_seconds = 44.95

	PICKUP_BATCH_SIMULATION.update_pickups(scene, 0.1)
	if not bool(gem.get("batch_simulation_enabled")):
		failures.append("active exp gem should be marked as batch-simulated")
	if gem.is_physics_processing():
		failures.append("batch-simulated exp gem should disable per-node physics callback")
	if gem.global_position.x <= 0.0:
		failures.append("batch-simulated attracted exp gem should still move toward target")
	if scene.get_runtime_pickups("heart_pickups").size() != 0:
		failures.append("batch-simulated heart pickup should keep despawn/recycle behavior")

	var first_position := gem.global_position
	PICKUP_BATCH_SIMULATION.update_pickups(scene, 0.1)
	if gem.global_position != first_position:
		failures.append("pickup batch simulation should run at most once per physics frame")

	await physics_frame
	PICKUP_BATCH_SIMULATION.update_pickups(scene, 0.1)
	if gem.global_position.x <= first_position.x:
		failures.append("batch-simulated exp gem should advance on the next physics frame")

	scene.free_pooled_pickups()
	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("PICKUP_BATCH_SIMULATION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class RuntimeRoot:
	extends Node2D

	var active_pickups: Dictionary = {
		"exp_gems": {},
		"heart_pickups": {}
	}
	var pooled_pickups: Dictionary = {
		"exp_gems": {},
		"heart_pickups": {}
	}

	func register_runtime_pickup(group_name: String, node: Node) -> void:
		_ensure_pickup_group(group_name)
		active_pickups[group_name][node.get_instance_id()] = node

	func unregister_runtime_pickup(group_name: String, node: Node) -> void:
		_ensure_pickup_group(group_name)
		active_pickups[group_name].erase(node.get_instance_id())

	func get_runtime_pickups(group_name: String) -> Array:
		_ensure_pickup_group(group_name)
		var result: Array = []
		for pickup in active_pickups[group_name].values():
			if pickup != null and is_instance_valid(pickup):
				result.append(pickup)
		return result

	func release_runtime_pickup(group_name: String, node: Node) -> void:
		_ensure_pickup_group(group_name)
		unregister_runtime_pickup(group_name, node)
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.hide()
		node.set_process(false)
		node.set_physics_process(false)
		pooled_pickups[group_name][node.get_instance_id()] = node

	func _ensure_pickup_group(group_name: String) -> void:
		if not active_pickups.has(group_name):
			active_pickups[group_name] = {}
		if not pooled_pickups.has(group_name):
			pooled_pickups[group_name] = {}

	func free_pooled_pickups() -> void:
		for pool in pooled_pickups.values():
			for pickup in (pool as Dictionary).values():
				if pickup != null and is_instance_valid(pickup):
					(pickup as Node).queue_free()
			(pool as Dictionary).clear()
