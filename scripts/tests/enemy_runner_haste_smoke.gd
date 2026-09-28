extends SceneTree

const ENEMY := preload("res://scenes/enemy.tscn")
const DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")
const DIFFICULTY := preload("res://scripts/game/difficulty_profile.gd")
const HASTE := preload("res://scripts/enemies/enemy_runner_haste.gd")
const MOVEMENT := preload("res://scripts/enemies/enemy_movement.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := RuntimeRoot.new()
	root.add_child(scene)
	current_scene = scene
	var target := Node2D.new()
	target.position = Vector2(300.0, 0.0)
	scene.add_child(target)
	var runner = _make_enemy(scene, target, "runner")

	for tier in [1, 2]:
		scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(tier)
		runner.batch_physics_process(20.0)
		_expect(is_zero_approx(HASTE.get_speed_bonus(runner)), "N%d must not unlock haste" % tier)
	scene.difficulty_profile = DIFFICULTY.get_profile("normal")
	runner.batch_physics_process(20.0)
	_expect(is_zero_approx(HASTE.get_speed_bonus(runner)), "non-endless mode must not unlock haste")

	scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(3)
	runner.speed = 150.0 * float(scene.difficulty_profile.enemy_speed_scale)
	var normal_speed: float = runner.speed
	runner.position = Vector2.ZERO
	runner._physics_process(0.25)
	_expect(is_equal_approx(runner.runner_haste_remaining, 3.75), "spawn-ready haste must start without an initial cooldown")
	_expect(is_equal_approx(runner.runner_haste_cooldown, 14.75), "cooldown must count from cast start")
	_expect(is_equal_approx(runner._compute_velocity(0.0).length(), (normal_speed + 50.0) * MOVEMENT.GLOBAL_UNIT_MOVE_SPEED_SCALE), "haste must add a flat 50 after difficulty scaling")
	_expect(is_equal_approx(runner.speed, normal_speed), "haste must not overwrite base movement speed")
	_expect(runner.can_use_batch_simulation(), "runner haste must preserve batch eligibility")
	_expect(is_equal_approx(runner.try_stalwart_body_damage(), 30.0), "haste must not change Stalwart Body damage")
	runner.slow_multiplier = 0.5
	_expect(is_equal_approx(runner._compute_velocity(0.0).length(), (normal_speed + 50.0) * 0.5 * MOVEMENT.GLOBAL_UNIT_MOVE_SPEED_SCALE), "slow must also affect the bonus movement speed")
	runner.slow_multiplier = 1.0

	var saved: Dictionary = JSON.parse_string(JSON.stringify(runner.get_save_data()))
	var restored = _make_enemy(scene, target, "runner")
	restored.apply_save_data(saved, target)
	_expect(is_equal_approx(restored.runner_haste_remaining, 3.75) and is_equal_approx(restored.runner_haste_cooldown, 14.75), "save restore must retain both timers")
	restored.batch_physics_process(3.75)
	_expect(is_zero_approx(HASTE.get_speed_bonus(restored)), "haste must expire exactly four seconds after cast")
	_expect(is_equal_approx(restored.runner_haste_cooldown, 11.0), "cooldown must keep running during the active duration")
	_expect(is_equal_approx(restored.speed, normal_speed), "expiry must retain the scaled base speed")
	restored.batch_physics_process(10.75)
	_expect(is_zero_approx(HASTE.get_speed_bonus(restored)), "haste must wait for the cooldown")
	restored.batch_physics_process(0.25)
	_expect(is_equal_approx(restored.runner_haste_remaining, 4.0) and is_equal_approx(restored.runner_haste_cooldown, 15.0), "haste must recast as soon as the fifteen-second cooldown finishes")
	restored.batch_physics_process(0.0)
	_expect(is_equal_approx(restored.runner_haste_remaining, 4.0), "zero elapsed time must not advance haste")

	# A large time step and many small steps must keep the same cast schedule.
	runner._reset_runtime_state(false)
	restored._reset_runtime_state(false)
	runner.batch_physics_process(31.0)
	for index in range(124):
		restored.batch_physics_process(0.25)
	_expect(is_equal_approx(runner.runner_haste_remaining, restored.runner_haste_remaining) and is_equal_approx(runner.runner_haste_cooldown, restored.runner_haste_cooldown), "cast schedule must be independent of update step size")

	scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(5)
	restored._reset_runtime_state(false)
	restored.batch_physics_process(0.25)
	_expect(is_equal_approx(HASTE.get_speed_bonus(restored), 50.0), "higher N tiers must also unlock haste")
	var other = _make_enemy(scene, target, "chaser")
	other.batch_physics_process(1.0)
	_expect(is_zero_approx(HASTE.get_speed_bonus(other)), "other enemies must not gain runner haste")
	restored._prepare_for_pool()
	_expect(is_zero_approx(restored.runner_haste_remaining) and is_zero_approx(restored.runner_haste_cooldown), "pool cleanup must reset both timers")
	restored.apply_enemy_profile("normal", DATABASE.get_profile("normal", "chaser"))
	restored.batch_physics_process(1.0)
	_expect(is_zero_approx(HASTE.get_speed_bonus(restored)), "pooled reuse as another enemy must not retain haste")
	restored.apply_enemy_profile("normal", DATABASE.get_profile("normal", "runner"))
	restored.batch_physics_process(0.25)
	_expect(is_equal_approx(HASTE.get_speed_bonus(restored), 50.0), "a newly spawned pooled runner must start ready")

	saved.erase("runner_haste_remaining")
	saved.erase("runner_haste_cooldown")
	restored.apply_save_data(saved, target)
	_expect(is_zero_approx(restored.runner_haste_remaining) and is_zero_approx(restored.runner_haste_cooldown), "missing save fields must restore a ready inactive skill")
	restored.batch_physics_process(0.25)
	_expect(is_equal_approx(HASTE.get_speed_bonus(restored), 50.0), "a save without haste fields must start the unlocked skill on the next tick")
	scene.difficulty_profile = DIFFICULTY.get_endless_tier_profile(2)
	restored.batch_physics_process(0.25)
	_expect(is_zero_approx(restored.runner_haste_remaining) and is_zero_approx(HASTE.get_speed_bonus(restored)), "lowering difficulty must disable haste")

	scene.free()
	current_scene = null
	if failures.is_empty():
		print("ENEMY_RUNNER_HASTE_SMOKE_OK")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)


func _make_enemy(scene: Node, target: Node2D, archetype: String):
	var enemy = ENEMY.instantiate()
	scene.add_child(enemy)
	enemy.target = target
	enemy.apply_enemy_profile("normal", DATABASE.get_profile("normal", archetype))
	enemy.set_physics_process(false)
	return enemy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


class RuntimeRoot:
	extends Node2D
	var difficulty_profile: Dictionary = {}
