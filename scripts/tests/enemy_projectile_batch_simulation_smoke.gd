extends SceneTree

const ENEMY_PROJECTILE_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_projectile_batch_simulation.gd")
const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene

	var target := TargetStub.new()
	target.global_position = Vector2(240.0, 0.0)
	scene.add_child(target)

	var projectile := ENEMY_BULLET_SCENE.instantiate() as Node2D
	scene.add_child(projectile)
	projectile.reset_projectile({
		"position": Vector2.ZERO,
		"direction": Vector2.RIGHT,
		"speed": 100.0,
		"damage": 1.0,
		"lifetime": 2.0,
		"hit_radius": 8.0,
		"target": target
	})

	ENEMY_PROJECTILE_BATCH_SIMULATION.update_enemy_projectiles(scene, 0.1)
	if not bool(projectile.get("batch_simulation_enabled")):
		failures.append("active enemy projectile should be marked as batch-simulated")
	if projectile.is_physics_processing():
		failures.append("batch-simulated enemy projectile should disable per-node physics callback")
	if projectile.global_position.x <= 0.0:
		failures.append("batch-simulated enemy projectile should still move")

	var first_position := projectile.global_position
	ENEMY_PROJECTILE_BATCH_SIMULATION.update_enemy_projectiles(scene, 0.1)
	if projectile.global_position != first_position:
		failures.append("enemy projectile batch simulation should run at most once per physics frame")

	await physics_frame
	ENEMY_PROJECTILE_BATCH_SIMULATION.update_enemy_projectiles(scene, 0.1)
	if projectile.global_position.x <= first_position.x:
		failures.append("batch-simulated enemy projectile should advance on the next physics frame")

	var hit_projectile := ENEMY_BULLET_SCENE.instantiate() as Node2D
	scene.add_child(hit_projectile)
	hit_projectile.reset_projectile({
		"position": Vector2(230.0, 0.0),
		"direction": Vector2.RIGHT,
		"speed": 0.0,
		"damage": 7.0,
		"lifetime": 2.0,
		"hit_radius": 16.0,
		"target": target
	})
	await physics_frame
	ENEMY_PROJECTILE_BATCH_SIMULATION.update_enemy_projectiles(scene, 0.1)
	if target.damage_taken != 7.0:
		failures.append("batch-simulated enemy projectile should keep player hit behavior")
	if not bool(hit_projectile.get("pooled")):
		failures.append("enemy projectile should recycle after a batch-simulated hit")

	scene.queue_free()
	await process_frame
	current_scene = null

	if failures.is_empty():
		print("ENEMY_PROJECTILE_BATCH_SIMULATION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class TargetStub:
	extends Node2D

	var damage_taken: float = 0.0

	func get_hurtbox_center() -> Vector2:
		return global_position

	func get_hurtbox_radius() -> float:
		return 8.0

	func take_damage(amount: float) -> void:
		damage_taken += amount


class RuntimeRoot:
	extends Node2D

	var active_projectiles: Dictionary = {}
	var pooled_projectiles: Dictionary = {}

	func register_runtime_enemy_projectile(projectile: Node, pooled: bool) -> void:
		var instance_id := projectile.get_instance_id()
		active_projectiles.erase(instance_id)
		pooled_projectiles.erase(instance_id)
		if pooled:
			pooled_projectiles[instance_id] = projectile
		else:
			active_projectiles[instance_id] = projectile

	func unregister_runtime_enemy_projectile(projectile: Node) -> void:
		var instance_id := projectile.get_instance_id()
		active_projectiles.erase(instance_id)
		pooled_projectiles.erase(instance_id)

	func get_runtime_enemy_projectiles() -> Array:
		var result: Array = []
		for projectile in active_projectiles.values():
			if projectile != null and is_instance_valid(projectile):
				result.append(projectile)
		return result

	func get_runtime_enemy_projectile_pool() -> Array:
		var result: Array = []
		for projectile in pooled_projectiles.values():
			if projectile != null and is_instance_valid(projectile):
				result.append(projectile)
		return result
