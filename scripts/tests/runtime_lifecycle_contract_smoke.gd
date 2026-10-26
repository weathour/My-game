extends SceneTree

const MAIN := preload("res://scripts/main.gd")
const ENEMY := preload("res://scenes/enemy.tscn")
const LIFECYCLE := preload("res://scripts/enemies/enemy_pool_lifecycle.gd")
const QUEUE := preload("res://scripts/player/player_damage_job_queue.gd")
const BATCHER := preload("res://scripts/player/player_damage_batcher.gd")
const WARNING := preload("res://scripts/game/spawn_warning_batch.gd")

var finished_warnings: Array[int] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := BareMain.new()
	main.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(main)
	current_scene = main
	_check_activation_and_damage(main)
	_check_detached_pools(main)
	await _check_warning_duration()
	print("RUNTIME_LIFECYCLE_CONTRACT_SMOKE_OK")
	quit(0)

func _check_activation_and_damage(main: Node) -> void:
	var enemy := Target.new()
	main.add_child(enemy)
	var owner := DamageOwner.new()
	main.add_child(owner)
	var queue := QUEUE.new()
	queue.configure(owner)
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 17.0, 1, "gunner_basic:probe")
	var first_generation: int = queue.enemy_generations[0]
	enemy.current_health = 0.0
	enemy.pooled_inactive = true
	main.release_runtime_enemy(enemy)
	assert(main.take_runtime_enemy_from_pool() == enemy)
	main.add_child(enemy)
	enemy.current_health = 100.0
	LIFECYCLE.activate_pooled_enemy(enemy)
	assert(LIFECYCLE.ensure_activation_generation(enemy) > first_generation)
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 5.0, 1, "gunner_basic:probe")
	assert(queue.enemy_refs.size() == 2, "different lives must never merge")
	queue._apply_job_at_index(0)
	assert(owner.applications == 0 and enemy.current_health == 100.0)
	queue._apply_job_at_index(1)
	assert(owner.applications == 1 and enemy.current_health == 95.0)
	queue._clear_jobs()
	queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 9.0, 1, "gunner_basic:probe")
	enemy.remove_meta(LIFECYCLE.ACTIVATION_GENERATION_META)
	queue._apply_job_at_index(0)
	assert(owner.applications == 1, "missing activation identity must reject a deferred hit")
	queue._clear_jobs()
	for index in range(70):
		queue.enqueue_values(weakref(enemy), enemy.get_instance_id(), 1.0, 1, "mage_basic:%d" % index)
	queue.job_cursor = 64
	queue._compact_processed_jobs(false)
	assert(queue.enemy_generations.size() == 6 and queue.enemy_refs.size() == 6)
	queue._physics_process(0.0)
	queue._clear_jobs()
	assert(queue.enemy_generations.is_empty())
	queue.free()

	var health_before_batch: float = enemy.current_health
	var batcher := BATCHER.new(owner)
	batcher.add_enemy(enemy, 19.0, "probe")
	LIFECYCLE.advance_activation_generation(enemy)
	batcher.add_enemy(enemy, 3.0, "probe")
	assert(batcher.enemy_refs.size() == 2)
	batcher.flush()
	var live_queue = main.get_node("PlayerDamageJobQueue")
	assert(live_queue.enemy_refs.size() == 1 and live_queue.damage_amounts[0] == 3.0)
	live_queue._apply_job_at_index(0)
	assert(enemy.current_health == health_before_batch - 3.0)
	live_queue.free()
	for invalid_state in ["dead", "pooled", "freed"]:
		var invalid_target := Target.new()
		main.add_child(invalid_target)
		batcher.add_enemy(invalid_target, 10.0, "gunner_basic:invalid", 0.3, 2.0, 0.5, 2.0, null, 5.0)
		if invalid_state == "dead":
			invalid_target.current_health = 0.0
		elif invalid_state == "pooled":
			invalid_target.pooled_inactive = true
		else:
			invalid_target.free()
		var applications_before := owner.applications
		batcher.flush()
		assert(owner.gunner_role.calls == 0 and owner.applications == applications_before and main.get_node_or_null("PlayerDamageJobQueue") == null, "invalid targets must not consume gunner events or enqueue damage/status/energy side effects")
		if is_instance_valid(invalid_target):
			invalid_target.free()

	var profiled = ENEMY.instantiate()
	profiled.apply_enemy_profile("normal", {"archetype": "probe", "behavior": "chaser", "max_health": 100.0})
	var profile_generation := LIFECYCLE.ensure_activation_generation(profiled)
	LIFECYCLE.activate_pooled_enemy(profiled)
	assert(LIFECYCLE.ensure_activation_generation(profiled) == profile_generation, "configured spawn advances once")
	profiled.apply_enemy_profile("normal", {"archetype": "replacement", "behavior": "chaser", "max_health": 100.0})
	assert(LIFECYCLE.ensure_activation_generation(profiled) == profile_generation + 1, "profile transformation invalidates old hits")
	profiled.free()
	enemy.free()
	owner.free()

func _check_detached_pools(main: Node) -> void:
	var enemies: Array[Node] = []
	var pickups: Array[Node] = []
	for index in range(3):
		var enemy := Node2D.new()
		main.add_child(enemy)
		main.release_runtime_enemy(enemy)
		enemies.append(enemy)
		var pickup := Node2D.new()
		main.add_child(pickup)
		main.release_runtime_pickup("exp_gems" if index % 2 == 0 else "heart_pickups", pickup)
		pickups.append(pickup)
	main._cleanup_runtime_nodes()
	assert(main.runtime_enemy_pool_nodes.is_empty() and main.runtime_pickup_pool_nodes.is_empty())
	for node in enemies + pickups:
		assert(not is_instance_valid(node), "scene cleanup must own detached pooled nodes")
	main._cleanup_runtime_nodes()
	main.free()
	current_scene = null

func _check_warning_duration() -> void:
	Engine.max_fps = 30
	for frame in range(40):
		await process_frame
	var fps := Engine.get_frames_per_second()
	assert(fps > 0 and fps < 45, "exercise the former low-FPS bypass")
	var warning := WARNING.new()
	root.add_child(warning)
	warning.set_process(false)
	warning.warning_finished.connect(func(entry: Dictionary): finished_warnings.append(int(entry.payload.index)))
	for index in range(40):
		warning.add_warning(Vector2(index * 2, 0), 26, {"index": index})
	assert(warning.warnings.size() == 40 and warning.pending_finished_entries.is_empty())
	warning._process(0.01)
	assert(finished_warnings.is_empty(), "crowded warnings must not finish after 10ms")
	warning._process(0.92)
	assert(finished_warnings.is_empty(), "every warning keeps the full 0.94s reaction window")
	warning._process(0.02)
	assert(not finished_warnings.is_empty() and finished_warnings.size() <= 12)
	for frame in range(12):
		warning._process(0.0)
	assert(finished_warnings.size() == 40 and warning.warnings.is_empty() and warning.pending_finished_entries.is_empty())
	finished_warnings.sort()
	for index in range(40):
		assert(finished_warnings[index] == index, "no missing or duplicate completed warning")
	print("RUNTIME_WARNING_DURATION fps=%.1f count=40 minimum_seconds=0.94" % fps)
	warning.free()

class BareMain extends MAIN:
	func _ready() -> void:
		pass
	func _exit_tree() -> void:
		pass

class Target extends Node2D:
	var current_health := 100.0
	var pooled_inactive := false
	var rebirth_timer := 0.0

class DamageOwner extends Node2D:
	var applications := 0
	var gunner_role := GunnerEventSpy.new()
	func _deal_damage_to_enemy(enemy, amount, _source, _vulnerability, _duration, _slow, _slow_duration, _position, _suppress, _energy) -> bool:
		applications += 1
		enemy.current_health -= amount
		return false

class GunnerEventSpy extends RefCounted:
	var calls := 0
	func consume_damage_event_multiplier(_owner: Node, _role: String) -> float:
		calls += 1
		return 1.0
