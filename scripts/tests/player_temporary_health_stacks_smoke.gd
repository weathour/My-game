extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene

	var player = PLAYER_SCENE.instantiate()
	scene.add_child(player)
	await process_frame

	_verify_inherit_and_expire(player)
	_verify_damage_consumes_oldest_stack(player)

	scene.queue_free()
	await process_frame
	current_scene = null
	if failures.is_empty():
		print("PLAYER_TEMPORARY_HEALTH_STACKS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _verify_inherit_and_expire(player: Node) -> void:
	player._clear_temporary_health(false)
	player._add_temporary_health(10.0)
	player._tick_temporary_health_stacks(2.0)
	player._add_temporary_health(10.0)
	_expect_approx(player.current_temporary_health, 20.0, "temporary health should accumulate in stacks")
	player._tick_temporary_health_stacks(27.9)
	_expect_approx(player.current_temporary_health, 20.0, "temporary health should stay before first stack expires")
	player._tick_temporary_health_stacks(0.2)
	_expect_approx(player.current_temporary_health, 10.0, "only the first stack should expire after 30 seconds")
	player._tick_temporary_health_stacks(2.0)
	_expect_approx(player.current_temporary_health, 0.0, "second stack should expire on its own timer")
	player._add_temporary_health(10.0)
	player._try_switch_role(1)
	_expect_approx(player.current_temporary_health, 0.0, "swordsman temporary health should clear when switching out")


func _verify_damage_consumes_oldest_stack(player: Node) -> void:
	player._clear_temporary_health(false)
	player._add_temporary_health(10.0)
	player._tick_temporary_health_stacks(2.0)
	player._add_temporary_health(10.0)
	var absorbed: float = player._consume_temporary_health(5.0)
	_expect_approx(absorbed, 5.0, "damage should be absorbed by temporary health")
	_expect_approx(player.current_temporary_health, 15.0, "temporary health should shrink after absorbing damage")
	player._tick_temporary_health_stacks(28.1)
	_expect_approx(player.current_temporary_health, 10.0, "only the remaining first stack amount should expire after damage")


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s: %.4f != %.4f" % [message, actual, expected])
