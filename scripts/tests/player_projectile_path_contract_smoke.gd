extends SceneTree

const BATCH := preload("res://scripts/player/player_projectile_batch.gd")
const GRID := preload("res://scripts/enemies/enemy_spatial_grid.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Runtime.new()
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(scene)
	current_scene = scene
	var owner := Node2D.new()
	scene.add_child(owner)
	var target := Target.new()
	scene.add_child(target)
	scene.enemies.append(target)
	_check_all_segments_and_expiry(scene, owner, target)
	_check_moving_target_reference(scene, owner, target)
	_check_curve_piercing_and_swap(scene, owner, target)
	_check_no_enemy_expiry(scene, owner)
	scene.free()
	current_scene = null
	print("PLAYER_PROJECTILE_PATH_CONTRACT_SMOKE_OK")
	quit(0)

func _new_batch(owner: Node) -> Node2D:
	var batch := BATCH.new()
	batch.configure(owner)
	return batch

func _add_workload(batch: Node, lifetime: float = 1.0) -> void:
	for index in range(1800):
		assert(batch.add_projectile({"position":Vector2(0, 1000) if index < 1799 else Vector2.ZERO, "direction":Vector2.RIGHT, "speed":620.0, "lifetime":1.0 if index < 1799 else lifetime, "damage":1.0, "hit_radius":1.0, "enemy_hit_radius_min":1.0, "enemy_hit_radius_max":1.0, "role_id":"probe"}))

func _check_all_segments_and_expiry(scene: Node, owner: Node, target: Node2D) -> void:
	for tail_lifetime in [5.0, 0.025]:
		var batch := _new_batch(owner)
		_add_workload(batch, tail_lifetime)
		target.position = Vector2(5 if tail_lifetime > 1 else 14, 0)
		GRID.cached_frame = -1
		batch._update_projectiles(1.0 / 60.0)
		batch._check_projectile_hits()
		if tail_lifetime < 1:
			assert(batch.positions.size() == 1800, "target is beyond the first motion segment")
			batch._update_projectiles(1.0 / 60.0)
			batch._check_projectile_hits()
		assert(batch.positions.size() == 1799, "every effective bullet and its expiry tail must be checked in this physics step")
		var queue := scene.get_node("PlayerDamageJobQueue")
		assert(queue.enemy_refs.size() == 1 and queue.damage_amounts[0] == 1.0)
		queue.free()
		batch.free()

func _check_moving_target_reference(scene: Node, owner: Node, target: Node2D) -> void:
	for initially_on_path in [true, false]:
		var batch := _new_batch(owner)
		_add_workload(batch)
		var reference_start := Vector2.ZERO
		var reference_alive := true
		var reference_hits := 0
		for tick in range(5):
			# One target leaves the old segment; the other enters only afterwards.
			var on_path: bool = initially_on_path if tick == 0 else not initially_on_path
			target.position = Vector2(5, 0 if on_path else 100)
			var reference_end := reference_start + Vector2.RIGHT * (620.0 / 60.0)
			if reference_alive and batch._projectile_swept_hits_enemy_shape(reference_start, reference_end, 1.0, target, 0.2, 1, 1):
				reference_hits += 1
				reference_alive = false
			reference_start = reference_end
			GRID.cached_frame = -1
			batch._update_projectiles(1.0 / 60.0)
			batch._check_projectile_hits()
		var queue := scene.get_node_or_null("PlayerDamageJobQueue")
		var actual_hits := 0.0 if queue == null else float(queue.damage_amounts[0])
		assert(actual_hits == reference_hits and reference_hits == (1 if initially_on_path else 0), "moving-target result must match the per-step reference, not historical path/current target geometry")
		if queue != null:
			queue.free()
		batch.free()

func _check_curve_piercing_and_swap(scene: Node, owner: Node, target: Node2D) -> void:
	var batch := _new_batch(owner)
	batch.add_projectile({"position":Vector2.ZERO, "direction":Vector2.RIGHT, "speed":120.0, "lifetime":1.0, "damage":1.0, "hit_radius":1.0, "enemy_hit_radius_min":1.0, "enemy_hit_radius_max":1.0, "wave_amplitude":50.0, "wave_frequency":TAU, "role_id":"probe", "pierce_count":2})
	target.position = Vector2(30, 0) + Vector2.RIGHT.orthogonal() * 50.0
	assert(not batch._projectile_swept_hits_enemy_shape(Vector2.ZERO, Vector2(120, 0), 1.0, target, 0.2, 1, 1), "the whole-curve chord misses this target")
	for tick in range(4):
		GRID.cached_frame = -1
		batch._update_projectiles(0.25)
		batch._check_projectile_hits()
	assert(batch.positions.is_empty(), "expired piercing bullet is released after its final checked segment")
	var queue := scene.get_node("PlayerDamageJobQueue")
	assert(queue.enemy_refs.size() == 1 and queue.damage_amounts[0] == 1.0, "curve hit is not repeated across steps")
	queue.free()

	var second := Target.new()
	scene.add_child(second)
	scene.enemies.append(second)
	target.position = Vector2(30, 0)
	second.position = Vector2(60, 0)
	batch.add_projectile({"position":Vector2.ZERO, "direction":Vector2.RIGHT, "speed":1000.0, "damage":1.0, "role_id":"probe", "pierce_count":1})
	GRID.cached_frame = -1
	batch._update_projectiles(0.1)
	batch._check_projectile_hits()
	queue = scene.get_node("PlayerDamageJobQueue")
	assert(queue.enemy_refs.size() == 2 and batch.positions.is_empty(), "piercing may hit multiple different targets in the same step")
	queue.free()
	scene.enemies.erase(second)
	second.free()

	batch.add_projectile({"position":Vector2(500, 500), "damage":1.0})
	batch.add_projectile({"position":Vector2(900, 900), "damage":1.0, "lifetime":0.01})
	batch._update_projectiles(0.01)
	var swapped_previous: Vector2 = batch.previous_positions[1]
	var swapped_position: Vector2 = batch.positions[1]
	batch._remove_projectile(0)
	assert(batch.positions.size() == 1 and batch.previous_positions[0] == swapped_previous and batch.positions[0] == swapped_position)
	batch._clear_projectiles()
	batch.free()

func _check_no_enemy_expiry(scene: Node, owner: Node) -> void:
	var batch := _new_batch(owner)
	batch.add_projectile({"position":Vector2.ZERO, "direction":Vector2.RIGHT, "speed":100.0, "lifetime":0.01, "damage":1.0})
	batch.add_projectile({"position":Vector2.ZERO, "lifetime":0.01, "damage":0.0})
	scene.enemies.clear()
	GRID.cached_frame = -1
	batch._update_projectiles(0.02)
	assert(batch.positions.size() == 1 and batch.positions[0].is_equal_approx(Vector2(1, 0)), "only active lifetime contributes motion; visual-only expiry stays immediate")
	batch._check_projectile_hits()
	assert(batch.positions.is_empty())
	batch.free()

class Runtime extends Node2D:
	var enemies: Array = []
	func get_runtime_enemies() -> Array:
		return enemies

class Target extends Node2D:
	var current_health := 100.0
	var pooled_inactive := false
	var rebirth_timer := 0.0
	var contact_radius := 20.0
	var enemy_kind := "normal"
	var behavior_id := ""
	var secondary_behavior_id := ""
	var _is_glutton := false
