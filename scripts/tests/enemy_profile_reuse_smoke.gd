extends SceneTree

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const ENEMY_ARCHETYPE_DATABASE := preload("res://scripts/enemy/enemy_archetype_database.gd")


func _init() -> void:
	var failures: Array[String] = []
	var enemy := ENEMY_SCENE.instantiate()
	enemy.apply_enemy_profile("normal", ENEMY_ARCHETYPE_DATABASE.get_profile("normal", "shooter"))
	root.add_child(enemy)
	_expect_scale(enemy, 0.672, "new shooter scale", failures)
	_expect_scale_value(enemy.base_scale.x, 1.0, "new shooter base scale", failures)

	enemy.apply_enemy_profile("normal", ENEMY_ARCHETYPE_DATABASE.get_profile("normal", "shooter"))
	_expect_scale(enemy, 0.672, "reused shooter scale", failures)

	enemy.apply_enemy_profile("normal", ENEMY_ARCHETYPE_DATABASE.get_profile("normal", "swarm"))
	_expect_scale(enemy, 0.68, "reused swarm scale", failures)

	enemy.apply_enemy_profile("normal", ENEMY_ARCHETYPE_DATABASE.get_profile("normal", "shooter"))
	_expect_scale(enemy, 0.672, "swarm back to shooter scale", failures)

	enemy.queue_free()
	if failures.is_empty():
		print("ENEMY_PROFILE_REUSE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect_scale(enemy: Node2D, expected: float, label: String, failures: Array[String]) -> void:
	_expect_scale_value(enemy.scale.x, expected, label + " x", failures)
	_expect_scale_value(enemy.scale.y, expected, label + " y", failures)


func _expect_scale_value(actual: float, expected: float, label: String, failures: Array[String]) -> void:
	if not is_equal_approx(actual, expected):
		failures.append("%s expected %.4f got %.4f" % [label, expected, actual])
