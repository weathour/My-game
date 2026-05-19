extends SceneTree

const RUNTIME_ENEMY_REGISTRY_FLOW := preload("res://scripts/game/runtime_enemy_registry_flow.gd")
const PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := FakeMain.new()
	root.add_child(main)
	main.player = main
	for index in range(10):
		RUNTIME_ENEMY_REGISTRY_FLOW.queue_runtime_enemy_spawn(main, {
			"kind": "normal",
			"archetype": "chaser",
			"spawn_position": Vector2(float(index), 0.0)
		})
	var process_limit := RUNTIME_ENEMY_REGISTRY_FLOW.get_enemy_spawn_process_limit(main)
	RUNTIME_ENEMY_REGISTRY_FLOW.process_pending_enemy_spawns(main)
	if main.spawned_count <= 0 or main.spawned_count > process_limit:
		failures.append("first spawn drain should process 1..%d, got %d" % [process_limit, main.spawned_count])
	var pending_after_first := RUNTIME_ENEMY_REGISTRY_FLOW.get_pending_enemy_spawn_count(main)
	if pending_after_first != 10 - main.spawned_count:
		failures.append("pending spawn count mismatch after first drain, got %d" % pending_after_first)
	var spawned_after_first := main.spawned_count
	RUNTIME_ENEMY_REGISTRY_FLOW.process_pending_enemy_spawns(main)
	var second_drain_count := main.spawned_count - spawned_after_first
	if second_drain_count <= 0 or second_drain_count > process_limit:
		failures.append("second spawn drain should process 1..%d, got %d" % [process_limit, second_drain_count])
	var pending_after_second := RUNTIME_ENEMY_REGISTRY_FLOW.get_pending_enemy_spawn_count(main)
	if pending_after_second != 10 - main.spawned_count:
		failures.append("pending spawn count mismatch after second drain, got %d" % pending_after_second)
	if failures.is_empty():
		print("RUNTIME_ENEMY_SPAWN_SMOOTHING_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


class FakeSpawnFlow:
	extends RefCounted

	func spawn_configured_enemy_at(main: Node, _kind: String, _archetype: String, _health_multiplier: float, _speed_multiplier: float, _spawn_position: Vector2, _damage_multiplier: float = 1.0) -> Node2D:
		main.spawned_count += 1
		return null


class FakeMain:
	extends Node

	var game_over: bool = false
	var player: Node = null
	var enemy_scene: PackedScene = PackedScene.new()
	var pending_enemy_spawn_requests: Array[Dictionary] = []
	var pending_enemy_spawn_cursor: int = 0
	var runtime_enemy_pool_nodes: Dictionary = {}
	var runtime_enemy_nodes: Dictionary = {}
	var runtime_enemy_cache: Array = []
	var runtime_enemy_cache_dirty: bool = true
	var runtime_enemy_pool_limit: int = 160
	var PERFORMANCE_GUARD := preload("res://scripts/game/performance_guard.gd")
	var ENEMY_SPAWN_FLOW := FakeSpawnFlow.new()
	var spawned_count: int = 0
