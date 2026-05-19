extends SceneTree

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_BULLET_SCENE := preload("res://scenes/enemy_bullet.tscn")
const EXP_GEM_SCENE := preload("res://scenes/exp_gem.tscn")
const HEART_PICKUP_SCENE := preload("res://scenes/heart_pickup.tscn")
const ENEMY_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_batch_simulation.gd")
const ENEMY_PROJECTILE_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_projectile_batch_simulation.gd")
const PICKUP_BATCH_SIMULATION := preload("res://scripts/game/pickup_batch_simulation.gd")
const PERFORMANCE_RECORDER := preload("res://scripts/game/performance_recorder.gd")
const PERFORMANCE_FEATURE_FLAGS := preload("res://scripts/game/performance_feature_flags.gd")

const FRAME_COUNT := 150
const DELTA := 1.0 / 60.0
const ENEMY_COUNT := 40
const PROJECTILE_COUNT := 96
const GEM_COUNT := 96
const HEART_COUNT := 24

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var results_dir := OS.get_environment("DENSE_COMBAT_BENCHMARK_RESULTS")
	if results_dir == "":
		results_dir = ProjectSettings.globalize_path("res://.omx/goals/performance/dense-combat-performance/results")
	DirAccess.make_dir_recursive_absolute(results_dir)
	var baseline := await _run_case("baseline", false)
	var candidate := await _run_case("candidate", true)
	_write_json(results_dir.path_join("baseline.json"), baseline)
	_write_json(results_dir.path_join("candidate.json"), candidate)
	_write_cpu_limitation(results_dir.path_join("cpu_core_utilization.txt"))
	if failures.is_empty():
		print("DENSE_COMBAT_BENCHMARK_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _run_case(label: String, use_batch: bool) -> Dictionary:
	PERFORMANCE_RECORDER.reset()
	PERFORMANCE_RECORDER.start_session(label)
	var scene := BenchmarkRuntimeRoot.new()
	scene.use_batch = use_batch
	root.add_child(scene)
	current_scene = scene
	PERFORMANCE_FEATURE_FLAGS.set_flags(scene, {
		PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_BATCH: use_batch,
		PERFORMANCE_FEATURE_FLAGS.FLAG_ENEMY_PROJECTILE_BATCH: use_batch,
		PERFORMANCE_FEATURE_FLAGS.FLAG_PICKUP_BATCH: use_batch
	})
	var target := TargetStub.new()
	target.global_position = Vector2(260.0, 0.0)
	scene.player = target
	scene.add_child(target)
	_populate_scene(scene, target)
	await physics_frame
	var frame_times: Array[float] = []
	for _frame in range(FRAME_COUNT):
		await physics_frame
		var physics_process_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		var process_ms := float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
		var active_ms = max(physics_process_ms, process_ms)
		if active_ms <= 0.0:
			active_ms = DELTA * 1000.0
		frame_times.append(max(0.001, active_ms))
		PERFORMANCE_RECORDER.record_frame(max(0.000001, active_ms / 1000.0))
	var recorder_snapshot := PERFORMANCE_RECORDER.stop_session()
	var frame_snapshot := _build_frame_snapshot(frame_times)
	var counters := {
		"enemy_count": scene.get_runtime_enemies().size(),
		"enemy_projectile_count": scene.get_runtime_enemy_projectiles().size(),
		"pickup_count": scene.get_runtime_pickups("exp_gems").size() + scene.get_runtime_pickups("heart_pickups").size(),
		"pooled_reactivations": scene.pooled_reactivations,
		"duplicate_tick_failures": scene.duplicate_tick_failures,
		"damage_dealt": 0,
		"damage_taken": target.damage_taken,
		"drops_generated": 0,
		"pickup_value": _sum_pickup_value(scene),
		"projectile_hits": target.hit_count
	}
	var result := {
		"label": label,
		"benchmark": "dense_combat_headless_smoke",
		"seed": 20260519,
		"frames": FRAME_COUNT,
		"duration_seconds": FRAME_COUNT * DELTA,
		"frame_time": frame_snapshot,
		"recorder": recorder_snapshot,
		"gameplay_counters": counters,
		"feature_flags": PERFORMANCE_FEATURE_FLAGS.get_snapshot(scene),
		"entity_targets": {
			"enemies": ENEMY_COUNT,
			"enemy_projectiles": PROJECTILE_COUNT,
			"exp_gems": GEM_COUNT,
			"heart_pickups": HEART_COUNT
		},
		"cpu_sampling_limitation": "Headless smoke records a CPU/core artifact placeholder; graphical profiling should attach pidstat/top -H output for release evidence."
	}
	scene.queue_free()
	await process_frame
	current_scene = null
	return result


func _populate_scene(scene: BenchmarkRuntimeRoot, target: Node2D) -> void:
	for i in range(ENEMY_COUNT):
		var enemy := ENEMY_SCENE.instantiate() as Node2D
		scene.add_child(enemy)
		enemy.target = target
		enemy.enemy_kind = "normal"
		enemy.archetype_id = "chaser"
		enemy.behavior_id = "chaser"
		enemy.secondary_behavior_id = ""
		enemy.current_health = enemy.max_health
		enemy.global_position = Vector2(-360.0 + float(i % 10) * 32.0, -160.0 + float(i / 10) * 42.0)
		enemy._sync_trait_flags()
		enemy.show()
		enemy.set_process(true)
		enemy.set_physics_process(true)
		scene.register_runtime_enemy(enemy)
	for i in range(PROJECTILE_COUNT):
		var projectile := ENEMY_BULLET_SCENE.instantiate() as Node2D
		scene.add_child(projectile)
		projectile.global_position = Vector2(-420.0 + float(i % 16) * 48.0, 220.0 + float(i / 16) * 10.0)
		projectile.direction = Vector2.RIGHT
		projectile.target = null
		projectile.lifetime = 20.0
		projectile.motion_mode = "straight"
		projectile._initialize_runtime_state()
	for i in range(GEM_COUNT):
		var gem := EXP_GEM_SCENE.instantiate() as Node2D
		scene.add_child(gem)
		gem.reset_pickup(Vector2(-280.0 + float(i % 16) * 36.0, -260.0 + float(i / 16) * 12.0), 1, 4)
	for i in range(HEART_COUNT):
		var heart := HEART_PICKUP_SCENE.instantiate() as Node2D
		scene.add_child(heart)
		heart.reset_pickup(Vector2(280.0 + float(i % 8) * 24.0, -180.0 + float(i / 8) * 18.0), 50.0)


func _build_frame_snapshot(samples: Array[float]) -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += value
	return {
		"count": sorted.size(),
		"avg_ms": total / max(1.0, float(sorted.size())),
		"p50_ms": _percentile(sorted, 0.50),
		"p95_ms": _percentile(sorted, 0.95),
		"p99_ms": _percentile(sorted, 0.99),
		"max_ms": sorted[sorted.size() - 1] if not sorted.is_empty() else 0.0
	}


func _percentile(sorted: Array, percentile: float) -> float:
	if sorted.is_empty():
		return 0.0
	var index := int(ceil(percentile * float(sorted.size()))) - 1
	return float(sorted[clamp(index, 0, sorted.size() - 1)])


func _sum_pickup_value(scene: BenchmarkRuntimeRoot) -> int:
	var total := 0
	for gem in scene.get_runtime_pickups("exp_gems"):
		if gem != null and is_instance_valid(gem):
			total += int(gem.get("value"))
	for heart in scene.get_runtime_pickups("heart_pickups"):
		if heart != null and is_instance_valid(heart):
			total += int(round(float(heart.get("heal_amount"))))
	return total


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("failed to write %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


func _write_cpu_limitation(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_line("CPU/core utilization: headless smoke placeholder.")
		file.store_line("Attach pidstat/top -H output from graphical benchmark runs before release acceptance.")


class TargetStub:
	extends Node2D
	var damage_taken: float = 0.0
	var hit_count: int = 0

	func get_hurtbox_center() -> Vector2:
		return global_position

	func get_hurtbox_radius() -> float:
		return 18.0

	func take_damage(amount: float) -> void:
		damage_taken += amount
		hit_count += 1


class BenchmarkRuntimeRoot:
	extends Node2D
	const LOCAL_ENEMY_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_batch_simulation.gd")
	const LOCAL_ENEMY_PROJECTILE_BATCH_SIMULATION := preload("res://scripts/enemies/enemy_projectile_batch_simulation.gd")
	const LOCAL_PICKUP_BATCH_SIMULATION := preload("res://scripts/game/pickup_batch_simulation.gd")

	var use_batch: bool = false
	var player: Node2D
	var runtime_enemy_nodes: Dictionary = {}
	var runtime_enemy_cache: Array = []
	var runtime_enemy_cache_dirty: bool = true
	var runtime_enemy_projectile_nodes: Dictionary = {}
	var runtime_enemy_projectile_cache: Array = []
	var runtime_enemy_projectile_cache_dirty: bool = true
	var runtime_enemy_projectile_pool_nodes: Dictionary = {}
	var runtime_pickup_nodes: Dictionary = {"exp_gems": {}, "heart_pickups": {}}
	var runtime_pickup_cache: Dictionary = {}
	var runtime_pickup_cache_dirty: Dictionary = {}
	var pooled_reactivations: int = 0
	var duplicate_tick_failures: int = 0

	func _physics_process(delta: float) -> void:
		if not use_batch:
			return
		LOCAL_ENEMY_BATCH_SIMULATION.update_simple_normal_enemies(self, delta)
		LOCAL_ENEMY_PROJECTILE_BATCH_SIMULATION.update_enemy_projectiles(self, delta)
		LOCAL_PICKUP_BATCH_SIMULATION.update_pickups(self, delta)

	func register_runtime_enemy(enemy: Node) -> void:
		runtime_enemy_nodes[enemy.get_instance_id()] = enemy
		runtime_enemy_cache_dirty = true

	func unregister_runtime_enemy(enemy: Node) -> void:
		if enemy != null:
			runtime_enemy_nodes.erase(enemy.get_instance_id())
			runtime_enemy_cache_dirty = true

	func get_runtime_enemies() -> Array:
		if runtime_enemy_cache_dirty:
			runtime_enemy_cache = _rebuild_runtime_registry_cache(runtime_enemy_nodes)
			runtime_enemy_cache_dirty = false
		return runtime_enemy_cache

	func register_runtime_enemy_projectile(projectile: Node, pooled: bool) -> void:
		var instance_id := projectile.get_instance_id()
		if pooled:
			runtime_enemy_projectile_nodes.erase(instance_id)
			runtime_enemy_projectile_pool_nodes[instance_id] = projectile
		else:
			runtime_enemy_projectile_pool_nodes.erase(instance_id)
			runtime_enemy_projectile_nodes[instance_id] = projectile
		runtime_enemy_projectile_cache_dirty = true

	func unregister_runtime_enemy_projectile(projectile: Node) -> void:
		if projectile != null:
			runtime_enemy_projectile_nodes.erase(projectile.get_instance_id())
			runtime_enemy_projectile_pool_nodes.erase(projectile.get_instance_id())
			runtime_enemy_projectile_cache_dirty = true

	func get_runtime_enemy_projectiles() -> Array:
		if runtime_enemy_projectile_cache_dirty:
			runtime_enemy_projectile_cache = _rebuild_runtime_registry_cache(runtime_enemy_projectile_nodes)
			runtime_enemy_projectile_cache_dirty = false
		return runtime_enemy_projectile_cache

	func get_runtime_enemy_projectile_pool() -> Array:
		return _rebuild_runtime_registry_cache(runtime_enemy_projectile_pool_nodes)

	func register_runtime_pickup(group_name: String, node: Node) -> void:
		if not runtime_pickup_nodes.has(group_name):
			runtime_pickup_nodes[group_name] = {}
		(runtime_pickup_nodes[group_name] as Dictionary)[node.get_instance_id()] = node
		runtime_pickup_cache_dirty[group_name] = true

	func unregister_runtime_pickup(group_name: String, node: Node) -> void:
		if runtime_pickup_nodes.has(group_name) and node != null:
			(runtime_pickup_nodes[group_name] as Dictionary).erase(node.get_instance_id())
			runtime_pickup_cache_dirty[group_name] = true

	func get_runtime_pickups(group_name: String) -> Array:
		if not runtime_pickup_nodes.has(group_name):
			return []
		if bool(runtime_pickup_cache_dirty.get(group_name, true)):
			runtime_pickup_cache[group_name] = _rebuild_runtime_registry_cache(runtime_pickup_nodes[group_name])
			runtime_pickup_cache_dirty[group_name] = false
		return runtime_pickup_cache.get(group_name, [])

	func release_runtime_pickup(group_name: String, node: Node) -> void:
		unregister_runtime_pickup(group_name, node)
		if node != null:
			pooled_reactivations += 1
			node.queue_free()

	func _rebuild_runtime_registry_cache(registry: Dictionary) -> Array:
		var cache: Array = []
		for node in registry.values():
			if node != null and is_instance_valid(node) and node is Node and not (node as Node).is_queued_for_deletion():
				cache.append(node)
		return cache
