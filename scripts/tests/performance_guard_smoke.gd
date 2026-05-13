extends SceneTree

const PerformanceGuard := preload("res://scripts/game/performance_guard.gd")
const ProjectileSpawner := preload("res://scripts/player/player_projectile_spawner.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_projectile_limit_capacity()
	_check_batched_projectiles_bypass_node_limit()
	if failures.is_empty():
		print("PERFORMANCE_GUARD_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _check_projectile_limit_capacity() -> void:
	var root := Node.new()
	get_root().add_child(root)
	for _index in range(PerformanceGuard.DEFAULT_PLAYER_PROJECTILE_LIMIT):
		var projectile := Node.new()
		projectile.add_to_group("player_projectiles")
		root.add_child(projectile)
	if PerformanceGuard.can_spawn_in_group(root, "player_projectiles", PerformanceGuard.DEFAULT_PLAYER_PROJECTILE_LIMIT):
		failures.append("player projectile group should reject spawns at limit")
	if PerformanceGuard.get_remaining_capacity(root, "player_projectiles", PerformanceGuard.DEFAULT_PLAYER_PROJECTILE_LIMIT) != 0:
		failures.append("player projectile remaining capacity should be zero at limit")
	root.queue_free()

func _check_batched_projectiles_bypass_node_limit() -> void:
	var root := Node.new()
	get_root().add_child(root)
	current_scene = root
	var owner := BatchedProjectileOwner.new()
	root.add_child(owner)
	for _index in range(PerformanceGuard.DEFAULT_PLAYER_PROJECTILE_LIMIT):
		var projectile := Node.new()
		projectile.add_to_group("player_projectiles")
		root.add_child(projectile)
	var spawned = ProjectileSpawner.spawn_directional_bullet(owner, null, Vector2.RIGHT, 12.0, Color.WHITE, "gunner", Vector2.ZERO)
	if spawned != null:
		failures.append("projectile spawner should skip visible node at projectile cap")
	var batched_spawned: bool = ProjectileSpawner.spawn_batched_directional_bullet(owner, Vector2.RIGHT, 12.0, Color.WHITE, "gunner", Vector2.ZERO, {
		"speed": 320.0,
		"lifetime": 0.8,
		"hit_radius": 9.0
	})
	if not batched_spawned:
		failures.append("batched projectile should still spawn at visible node limit")
	var batch := root.get_node_or_null("PlayerProjectileBatch")
	if batch == null:
		failures.append("batched projectile node should be created")
	elif int(batch.get("positions").size()) != 1:
		failures.append("batched projectile node should contain one projectile")
	if _count_projectile_group_children(root) != PerformanceGuard.DEFAULT_PLAYER_PROJECTILE_LIMIT:
		failures.append("batched projectile should not add player_projectiles nodes")
	root.queue_free()
	current_scene = null

func _count_projectile_group_children(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child.is_in_group("player_projectiles"):
			count += 1
	return count

class BatchedProjectileOwner:
	extends Node2D

	func _register_attack_result(_role_id: String, _hit_count: int, _killed: bool) -> void:
		pass

	func _get_active_role() -> Dictionary:
		return {"id": "gunner"}
