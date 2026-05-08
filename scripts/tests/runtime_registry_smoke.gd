extends SceneTree

const MainSceneScript := preload("res://scripts/main.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainSceneScript.new()
	_check_enemy_registry(main)
	_check_pickup_registry(main)
	_check_enemy_projectile_registry(main)
	_check_player_projectile_registry(main)
	main.free()

	if failures.is_empty():
		print("RUNTIME_REGISTRY_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_enemy_registry(main: Node) -> void:
	var enemy_a := Node2D.new()
	var enemy_b := Node2D.new()
	main.register_runtime_enemy(enemy_a)
	main.register_runtime_enemy(enemy_a)
	main.register_runtime_enemy(enemy_b)
	_assert_size(main.get_runtime_enemies(), 2, "enemy registry should deduplicate by instance id")

	main.unregister_runtime_enemy(enemy_a)
	_assert_size(main.get_runtime_enemies(), 1, "enemy unregister should remove one cached entry")
	if not main.get_runtime_enemies().has(enemy_b):
		failures.append("enemy registry should keep remaining node")

	enemy_a.free()
	enemy_b.free()


func _check_pickup_registry(main: Node) -> void:
	var gem := Node2D.new()
	var heart := Node2D.new()
	main.register_runtime_pickup("exp_gems", gem)
	main.register_runtime_pickup("exp_gems", gem)
	main.register_runtime_pickup("heart_pickups", heart)
	_assert_size(main.get_runtime_pickups("exp_gems"), 1, "pickup registry should deduplicate same group")
	_assert_size(main.get_runtime_pickups("heart_pickups"), 1, "pickup registry should isolate groups")

	main.unregister_runtime_pickup("exp_gems", gem)
	_assert_size(main.get_runtime_pickups("exp_gems"), 0, "pickup unregister should update group cache")
	_assert_size(main.get_runtime_pickups("heart_pickups"), 1, "pickup unregister should not affect other groups")

	gem.free()
	heart.free()


func _check_enemy_projectile_registry(main: Node) -> void:
	var projectile := Node2D.new()
	main.register_runtime_enemy_projectile(projectile, false)
	_assert_size(main.get_runtime_enemy_projectiles(), 1, "active projectile registry should accept projectile")
	_assert_size(main.get_runtime_enemy_projectile_pool(), 0, "active projectile should not be in pool")

	main.register_runtime_enemy_projectile(projectile, true)
	_assert_size(main.get_runtime_enemy_projectiles(), 0, "pooled projectile should leave active registry")
	_assert_size(main.get_runtime_enemy_projectile_pool(), 1, "pooled projectile should enter pool registry")

	var taken: Node = main.take_runtime_enemy_projectile_from_pool()
	if taken != projectile:
		failures.append("projectile pool should return the registered pooled projectile")
	_assert_size(main.get_runtime_enemy_projectile_pool(), 0, "taking projectile should remove it from pool registry")

	main.register_runtime_enemy_projectile(projectile, false)
	main.unregister_runtime_enemy_projectile(projectile)
	_assert_size(main.get_runtime_enemy_projectiles(), 0, "projectile unregister should remove active projectile")

	projectile.free()


func _check_player_projectile_registry(main: Node) -> void:
	var projectile := Node2D.new()
	main.register_runtime_player_projectile(projectile)
	main.register_runtime_player_projectile(projectile)
	_assert_size(main.get_runtime_player_projectiles(), 1, "player projectile registry should deduplicate active nodes")

	main.unregister_runtime_player_projectile(projectile)
	_assert_size(main.get_runtime_player_projectiles(), 0, "player projectile unregister should update active cache")

	main.release_runtime_player_projectile(projectile, "test_projectile")
	_assert_size(main.get_runtime_player_projectile_pool("test_projectile"), 1, "player projectile release should enter keyed pool")
	var taken: Node = main.take_runtime_player_projectile_from_pool("test_projectile")
	if taken != projectile:
		failures.append("player projectile pool should return released projectile for matching key")
	_assert_size(main.get_runtime_player_projectile_pool("test_projectile"), 0, "player projectile take should remove pooled node")

	projectile.free()


func _assert_size(nodes: Array, expected_size: int, message: String) -> void:
	if nodes.size() != expected_size:
		failures.append("%s: expected %d, got %d" % [message, expected_size, nodes.size()])
